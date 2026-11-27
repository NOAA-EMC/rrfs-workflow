#!/usr/bin/env python3
"""Lay a generated retro definition out by day and cold-start chain (RETRO_LAYOUT=chains).

The NCO definition holds one day: /primary/00, 06, 12 and 18, each with six hourly cycles, and the
retro driver steps those four families through the retro by requeueing them with a new PDY. With
the deterministic chain cold starting at DET_COLD_START_HRS instead, each stretch of cycles from
one cold start to the next stands on its own, so the whole retro can be written out at once:

  /<suite>/primary/<PDY>_<HH>/rrfs/v1.0/<cycles of the chain>     one family per chain and day
  /<clone>/primary/<PDY>_<FF>/...                                 one family per GFS cycle and day

Each chain family carries PDY and its own DEV_DATAROOT (<dataroot>/<PDY>), because the working
directories are named by cycle hour alone. A chain that runs past midnight (15z to 02z) gives
those cycles the next day's PDY. Every cycle family starts suspended; the retro driver resumes
them oldest first, CYCLE_THROTTLE at a time (exretroprodclone.py). The retro normally covers RETRO_START
00z to RETRO_END 23z; an optional end hour can shorten the final day, cycles before the first cold start only make the LBCs it reads.

References between the old families are rewritten for each day:
  - to a cycle in the same chain: the new absolute path
  - to an earlier chain: dropped (a "== complete" test becomes true); the chain cold starts,
    but still waits on the LBCs it reads from there (03z reads 00z's)
  - to a cycle outside the retro: dropped
  - to a later chain (clean waits on the next cycles): the last cycle of its own chain instead
  - to /prod_clone: the clone family of that GFS cycle at or before the cycle's 6-hourly family
cycle_end tasks go, and so do tasks that never run (defstatus complete) and families left empty,
unless something waits on one of their events.

Usage:
  chain_suite.py rrfs  <def> --suite S --clone C --start YYYYMMDD --end YYYYMMDD
                             --chains "03 15" --dataroot DIR
  chain_suite.py clone <def> --start YYYYMMDD --end YYYYMMDD
"""

import argparse
import datetime
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from skip_tasks import FALSE, TRUE, Prim, fold, parse, resolve, tokenize, unparse  # noqa: E402

NODE_KW = ("suite", "family", "task")


class Block:
    """A node of the definition and the lines it spans, [start, end)."""

    def __init__(self, kind, name, path, start):
        self.kind, self.name, self.path, self.start = kind, name, path, start
        self.end = None
        self.children = []
        self.defstatus_complete = False


def read_blocks(lines):
    """Every node of the definition by path, and for each line the path of the node it is in.
    Tasks end where the next node or endfamily starts."""
    nodes, stack, task, owner = {}, [], None, [None] * len(lines)
    for i, line in enumerate(lines):
        words = line.split()
        if not words:
            continue
        kw = words[0]
        if kw in NODE_KW or kw in ("endfamily", "endsuite"):
            if task:
                task.end = i
                task = None
        if kw in NODE_KW:
            parent = stack[-1] if stack else None
            node = Block(kw, words[1], (parent.path if parent else "") + "/" + words[1], i)
            nodes[node.path] = node
            if parent:
                parent.children.append(node)
            if kw == "task":
                task = node
            else:
                stack.append(node)
        elif kw in ("endfamily", "endsuite"):
            stack.pop().end = i + 1
        elif kw == "defstatus" and words[1:2] == ["complete"]:
            (task or stack[-1]).defstatus_complete = True
        if kw not in ("endfamily", "endsuite") and (task or stack):
            owner[i] = (task or stack[-1]).path
    return nodes, owner


def expr_refs(expr, base):
    """(absolute path, prim) for each node reference in an expression."""
    out = []

    def walk(node):
        if isinstance(node, Prim):
            if node.ref is not None:
                out.append((resolve(node.ref, base), node))
        elif node not in (TRUE, FALSE):
            for child in node[1]:
                walk(child)
    walk(parse(tokenize(expr), base))
    return out


def parent_of(path):
    return path.rsplit("/", 1)[0]


def is_pruned_in(path, pruned):
    """True if the node at path, or a family above it inside its cycle, is in pruned."""
    while path.count("/") > 3:
        if path in pruned:
            return True
        path = parent_of(path)
    return False


def days(start, end):
    day = datetime.datetime.strptime(start, "%Y%m%d")
    while day.strftime("%Y%m%d") <= end:
        yield day
        day += datetime.timedelta(days=1)


def expand_rrfs(args):
    lines = open(args.deffile).read().split("\n")
    nodes, owner = read_blocks(lines)
    suite, clone = args.suite, args.clone
    chains = sorted(int(h) for h in args.chains.split())
    if not chains or any(h < 0 or h > 23 for h in chains):
        sys.exit(f"chain_suite.py: chain start hours must be 00-23, not '{args.chains}'")
    primary = nodes[f"/{suite}/primary"]
    fams = {f.name: f for f in primary.children}
    if sorted(fams) != ["00", "06", "12", "18"]:
        sys.exit(f"chain_suite.py: expected /{suite}/primary/00, 06, 12 and 18, found {sorted(fams)}")

    def chain_start(hour):
        return max([h for h in chains if h <= hour] or [chains[-1] - 24])

    def chain_of(dt):
        start = chain_start(dt.hour)
        return datetime.datetime(dt.year, dt.month, dt.day) + datetime.timedelta(hours=start)

    def chain_name(cdt):
        return cdt.strftime("%Y%m%d_%H")

    def chain_cycles(start):
        nxt = next((h for h in chains if h > start), chains[0] + 24)
        return list(range(start, nxt))

    # Tasks that never run, and families with nothing else in them. An event of a task that never
    # runs is never set, so a task something that does run waits on through one has to stay.
    events = []
    for i, line in enumerate(lines):
        words = line.split(None, 1)
        if words[:1] not in (["trigger"], ["complete"]) or owner[i] is None:
            continue
        events += [(owner[i], target) for target, prim in expr_refs(words[1], parent_of(owner[i]))
                   if prim.event]

    def prune(node, keep, pruned):
        if node.kind == "task":
            gone = (node.defstatus_complete and node.path not in keep) or node.name == "cycle_end"
        else:
            kids = [prune(c, keep, pruned) for c in node.children]
            gone = bool(node.children) and all(kids) and node.path not in keep
        if gone:
            pruned.add(node.path)
        return gone

    # first without the events, then keeping what the remaining tasks wait on, until it settles
    pruned, keep = set(), None
    while True:
        new = set()
        for fam in fams.values():
            for cyc in nodes[f"{fam.path}/rrfs/v1.0"].children:
                prune(cyc, keep or set(), new)
        pruned = new
        new_keep = {t for src, t in events if not is_pruned_in(src, pruned)}
        if new_keep == keep:
            break
        keep = new_keep

    def is_pruned(path):
        return is_pruned_in(path, pruned)

    # Cycles before the first cold start only make the LBCs it reads (det/ics).
    # The optional end hour truncates the last day; otherwise it ends at 23z.
    first = datetime.datetime.strptime(args.start, "%Y%m%d")
    first_cold = first + datetime.timedelta(hours=chains[0])
    retro_last = datetime.datetime.strptime(args.end, "%Y%m%d") + datetime.timedelta(hours=args.end_hour)
    if retro_last < first_cold:
        sys.exit("chain_suite.py: end time precedes the first cold start")

    def omitted_after_analysis(path, cycle_time):
        """Keep final-cycle setup and analysis, but not its forecast or other output work."""
        if not args.stop_after_analysis or cycle_time != retro_last:
            return False
        match = re.match(r"/[^/]+/primary/\d\d/rrfs/v1\.0/\d\dz(?:/(.*))?$", path)
        if not match or not match.group(1):
            return False
        parts = match.group(1).split("/")
        if parts[0] == "preclean":
            return False
        if parts[0] != "det":
            return True
        return len(parts) > 1 and parts[1] not in ("ics", "init", "prep", "analysis")

    def lbc_only(path):
        """True if path is a cycle's det/ics family, inside it, or one of the families above it."""
        m = re.match(r"(/[^/]+/primary/\d\d/rrfs/v1\.0/\d\dz)(/.*)?$", path)
        if not m:
            return False
        rest = m.group(2) or ""
        return rest in ("", "/det", "/det/ics") or rest.startswith("/det/ics/")

    stats = {"same chain": 0, "earlier chain": 0, "earlier-chain LBCs": 0, "later chain": 0,
             "clone": 0, "never-run": 0, "outside the retro": 0}
    externs = set()
    rrfs_re = re.compile(rf"/{re.escape(suite)}/primary/(\d\d)/rrfs/v1\.0/(\d\d)z(/.*)?$")
    clone_re = re.compile(rf"/{re.escape(clone)}/primary/(\d\d)(/.*)?$")

    def rewrite_expr(expr, base_old, src_fam, src_dt):
        """The expression for a node of cycle src_dt; None to leave it exactly as written."""
        touched = [False]
        own_chain = chain_of(src_dt)

        def new_prim(prim, path):
            text = f"{path} == {prim.state}" if prim.state else f"{path}:{prim.event}"
            return Prim(text, ref=path, state=prim.state, event=prim.event, base="")

        def true_if_complete(prim):
            return TRUE if prim.state == "complete" or prim.event else FALSE

        def walk(node):
            if node in (TRUE, FALSE):
                return node
            if not isinstance(node, Prim):
                return (node[0], [walk(c) for c in node[1]])
            if node.ref is None:
                return node
            target = resolve(node.ref, base_old)
            if is_pruned(target):
                touched[0] = True
                stats["never-run"] += 1
                return TRUE if node.state == "complete" else FALSE
            m = rrfs_re.match(target)
            if m:
                tfam, th, rest = m.group(1), int(m.group(2)), m.group(3) or ""
                delta = (th - src_dt.hour) % 24
                if delta > 6:
                    delta -= 24
                tdt = src_dt + datetime.timedelta(hours=delta)
                if tdt > retro_last or tdt < first or (src_dt < first_cold and not lbc_only(target)):
                    touched[0] = True
                    stats["outside the retro"] += 1
                    return true_if_complete(node)
                # References to omitted final-cycle work cannot remain in the generated suite.
                if omitted_after_analysis(target, tdt):
                    touched[0] = True
                    stats["outside the retro"] += 1
                    return true_if_complete(node)
                tchain = chain_of(tdt)
                if tfam == src_fam and not node.ref.startswith("/") and tchain == own_chain:
                    return node          # relative, inside the old family: still right as written
                touched[0] = True
                if tchain == own_chain:
                    stats["same chain"] += 1
                    return new_prim(node, f"/{suite}/primary/{chain_name(tchain)}/rrfs/v1.0/{th:02d}z{rest}")
                if tchain < own_chain:
                    # a cold start still needs LBCs made in an earlier chain (03z reads 00z's)
                    if lbc_only(target) and rest.startswith("/det/ics"):
                        stats["earlier-chain LBCs"] += 1
                        return new_prim(node, f"/{suite}/primary/{chain_name(tchain)}/rrfs/v1.0/{th:02d}z{rest}")
                    stats["earlier chain"] += 1
                    return true_if_complete(node)
                stats["later chain"] += 1
                last = chain_cycles(own_chain.hour)[-1] % 24
                if last == src_dt.hour or node.state != "complete":
                    return TRUE if node.state == "complete" else FALSE
                return new_prim(node, f"/{suite}/primary/{chain_name(own_chain)}/rrfs/v1.0/{last:02d}z")
            m = clone_re.match(target)
            if m:
                touched[0] = True
                stats["clone"] += 1
                ff = int(m.group(1))
                day = src_dt.date()
                if ff > src_dt.hour // 6 * 6:
                    day -= datetime.timedelta(days=1)
                path = f"/{clone}/primary/{day.strftime('%Y%m%d')}_{ff:02d}{m.group(2) or ''}"
                externs.add(path)
                return new_prim(node, path)
            if target.startswith(f"/{suite}/"):
                sys.exit(f"chain_suite.py: cannot place the reference {node.ref} from {base_old}")
            return node

        new = fold(walk(parse(tokenize(expr), base_old)))
        return new if touched[0] else None

    def emit_node(node, out, src_fam, src_dt, chain_day):
        """The lines of a cycle family or anything in it, rewritten for the cycle at src_dt."""
        if (node.path in pruned or omitted_after_analysis(node.path, src_dt)
                or (src_dt < first_cold and not lbc_only(node.path))):
            return
        body_end = node.children[0].start if node.children else (node.end - 1 if node.kind != "task" else node.end)
        for i in range(node.start, body_end):
            line = lines[i]
            words = line.split(None, 1)
            if words[:1] in (["trigger"], ["complete"]) and len(words) == 2:
                new = rewrite_expr(words[1], parent_of(node.path), src_fam, src_dt)
                if new is not None:
                    if new == TRUE:
                        continue
                    if new == FALSE:
                        sys.exit(f"chain_suite.py: the {words[0]} of {node.path} can never be met")
                    line = line[:len(line) - len(line.lstrip())] + f"{words[0]} {unparse(new)}"
            out.append(line)
            if i == node.start and re.fullmatch(r"\d\dz", node.name):
                out.append(line[:len(line) - len(line.lstrip())] + "  defstatus suspended")
                # a cycle past midnight belongs to the next day
                if src_dt.date() != chain_day.date():
                    out.append(line[:len(line) - len(line.lstrip())] + f"  edit PDY '{src_dt:%Y%m%d}'")
        for child in node.children:
            emit_node(child, out, src_fam, src_dt, chain_day)
        if node.kind != "task":
            out.append(lines[node.end - 1])

    out_primary, ncycles, nchains = [], 0, 0
    fam_indent = lines[fams["00"].start][:len(lines[fams["00"].start]) - len(lines[fams["00"].start].lstrip())]
    # from the day before, whose last chain may run into RETRO_START (15z to 02z)
    for day in days((first - datetime.timedelta(days=1)).strftime("%Y%m%d"), args.end):
        pdy = day.strftime("%Y%m%d")
        for start in chains:
            cdt = day + datetime.timedelta(hours=start)
            body = []
            for h in chain_cycles(start):
                hdt = cdt + datetime.timedelta(hours=h - start)
                src = fams[f"{h % 24 // 6 * 6:02d}"]
                cyc = nodes[f"{src.path}/rrfs/v1.0/{h % 24:02d}z"]
                if hdt < first or hdt > retro_last:
                    continue
                ics = f"{cyc.path}/det/ics"
                if hdt < first_cold and (ics not in nodes or is_pruned(ics)):
                    continue
                n = len(body)
                emit_node(cyc, body, src.name, hdt, cdt)
                ncycles += len(body) > n
            if not body:
                continue
            fam = fams[f"{start // 6 * 6:02d}"]
            rrfs = nodes[f"{fam.path}/rrfs"]
            v10 = nodes[f"{rrfs.path}/v1.0"]
            nchains += 1
            out_primary.append(f"{fam_indent}family {chain_name(cdt)}")
            out_primary.append(f"{fam_indent}  edit PDY '{pdy}'")
            out_primary.append(f"{fam_indent}  edit DEV_DATAROOT '{args.dataroot}/{pdy}'")
            out_primary.extend(lines[rrfs.start:v10.start + 1])
            for i in range(v10.start + 1, v10.children[0].start):
                if lines[i].split()[:2] != ["defstatus", "complete"]:
                    out_primary.append(lines[i])
            out_primary.extend(body)
            out_primary.append(lines[v10.end - 1])
            out_primary.append(lines[rrfs.end - 1])
            out_primary.append(f"{fam_indent}endfamily")

    head = [ln for ln in lines[:primary.start + 1] if not ln.startswith(f"extern /{clone}/")]
    suite_at = next(i for i, ln in enumerate(head) if ln.startswith("suite "))
    head[suite_at:suite_at] = [f"extern {p}" for p in sorted(externs)] + [""]
    text = head + out_primary + lines[primary.end - 1:]
    with open(args.deffile, "w") as f:
        f.write("\n".join(text))
    ntasks = sum(1 for ln in out_primary if ln.split()[:1] == ["task"])
    print(f"  chains: {ncycles} cycles in {nchains} chain families, {ntasks} tasks ({len([p for p in pruned if nodes[p].kind == 'task'])} never-run"
          f" tasks of the one-day definition left out)")
    print("  chains: references " + ", ".join(f"{k} {v}" for k, v in stats.items()))


def expand_clone(args):
    lines = open(args.deffile).read().split("\n")
    nodes, _ = read_blocks(lines)
    suite = next(p for p, n in nodes.items() if n.kind == "suite")
    primary = nodes[f"{suite}/primary"]
    out = []
    first = datetime.datetime.strptime(args.start, "%Y%m%d") - datetime.timedelta(days=1)
    for day in days(first.strftime("%Y%m%d"), args.end):
        pdy = day.strftime("%Y%m%d")
        for fam in primary.children:
            head = lines[fam.start]
            indent = head[:len(head) - len(head.lstrip())]
            out.append(f"{indent}family {pdy}_{fam.name}")
            out.append(f"{indent}  edit PDY '{pdy}'")
            out.extend(lines[fam.start + 1:fam.end])
    with open(args.deffile, "w") as f:
        f.write("\n".join(lines[:primary.start + 1] + out + lines[primary.end - 1:]))
    print(f"  chains: /prod_clone families for {first.strftime('%Y%m%d')} to {args.end}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("which", choices=("rrfs", "clone"))
    ap.add_argument("deffile")
    ap.add_argument("--suite")
    ap.add_argument("--clone")
    ap.add_argument("--start", required=True)
    ap.add_argument("--end", required=True)
    ap.add_argument("--chains", default="03 15")
    ap.add_argument("--dataroot")
    ap.add_argument("--end-hour", type=int, choices=range(24), default=23)
    ap.add_argument("--stop-after-analysis", action="store_true")
    args = ap.parse_args()
    if args.which == "rrfs":
        expand_rrfs(args)
    else:
        expand_clone(args)


if __name__ == "__main__":
    main()
