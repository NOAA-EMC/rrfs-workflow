"""Switch tasks off in a retro suite definition, and repair what depended on them.

A task is switched off by giving it "defstatus complete": ecflow then treats it as finished
without ever submitting it. On its own that is only safe for a task nothing waits on, because
a trigger that names the task is satisfied the moment the suite begins. skip_tasks() therefore
also rewrites every trigger (and complete expression) that refers to a task it switches off:

  mode="inline"   the reference is replaced by the switched-off task's own trigger, so whatever
                  waited on it now waits on what it waited on. This keeps a chain in order when
                  a step is taken out of the middle of it: with the non-variational cloud
                  analysis off, for instance, the forecast waits on the analysis step before it
                  instead of starting as soon as the cycle opens.
  mode="ignore"   the reference is dropped (a "== complete" test becomes true, a test for any
                  other state becomes false). This is for a whole workflow group that is not
                  running at all, where inlining would drag that group's dependencies into the
                  group that is running.

Expressions are parsed, rewritten and folded, so one left always true is deleted rather than
written out as a tautology, which ecflow rejects. Relative node paths in an inlined expression
become absolute, since the expression moves to a node elsewhere in the tree.
"""

import re
import sys

from .expr import FALSE, TRUE, Prim, absolutize, fold, parse_expr, resolve, unparse

def skip_tasks(d, label, names=(), paths=(), mode="inline", post_manager=True):
    """Switch off the tasks whose name fully matches one of the names regexes, or whose path
    contains a match of one of the paths regexes.

    post_manager: also repoint the post tasks of a switched-off post manager at the forecast
    task; their trigger is one of the manager's events rather than a node state, and an event of
    a task that never runs is never set.
    """
    if not names and not paths:
        sys.exit(f"skip_tasks: nothing selected for {label}")
    nodes = d.nodes
    name_res = [re.compile(p) for p in names]
    path_res = [re.compile(p) for p in paths]
    skipped = {n.path: n for n in nodes.values() if n.kind == "task"
               and (any(r.fullmatch(n.name) for r in name_res)
                    or any(r.search(n.path) for r in path_res))}
    if not skipped:
        print(f"  {label}: no task matched")
        return

    # Each switched-off task's own trigger, as an absolute expression, for mode="inline"
    own = {}
    for path, node in skipped.items():
        trig = d.trigger_line(node)
        own[path] = TRUE if trig is None else \
            absolutize(parse_expr(d.expression(trig), node.parent.path))

    # A post manager releases its post tasks through events rather than a node state, so point
    # them at the forecast task instead. Not at "== active", which the manager's own trigger
    # accepts: with the manager gone nothing checks that the hour has been written, so a post
    # can only start once the forecast has finished.
    release = {}
    if post_manager:
        for path, node in skipped.items():
            if not node.name.endswith("_post_manager"):
                continue
            wgf = node.parent.parent
            fcst = next((c.path for f in wgf.children if f.name == "forecast"
                         for c in f.children
                         if re.fullmatch(r"jrrfs_\w+?_forecast(_long)?", c.name)), None)
            if fcst:
                release[path] = Prim(f"{fcst} == complete", ref=fcst, state="complete", base="")

    touched = [False]

    def rewrite(node, base, depth=0):
        if node in (TRUE, FALSE):
            return node
        if isinstance(node, Prim):
            if node.ref is None:
                return node
            target = resolve(node.ref, base if node.base is None else node.base)
            if target not in skipped:
                return node
            touched[0] = True
            if node.event:
                return release.get(target, FALSE)
            if mode == "ignore":
                return TRUE if node.state == "complete" else FALSE
            if node.state not in ("complete", "active"):
                return FALSE
            if depth > 20:
                sys.exit(f"skip_tasks: trigger inlining loops at {target}")
            return rewrite(own[target], base, depth + 1)
        op, parts = node
        return (op, [rewrite(p, base, depth) for p in parts])

    changed = 0
    for path, node in nodes.items():
        if path in skipped:
            # a task that never runs: its own dependencies no longer mean anything, and they
            # routinely name other switched-off tasks, so leave them as they were
            continue
        base = node.parent.path if node.kind == "task" else path
        for ln in node.attrs:
            line = d.line(ln)
            if line.split()[:1] not in (["trigger"], ["complete"]):
                continue
            kw, expr = line.strip().split(" ", 1)
            touched[0] = False
            new = fold(rewrite(parse_expr(expr, base), base))
            if not touched[0]:
                # nothing in it referred to a switched-off task; leave the line exactly as written
                continue
            if new == FALSE:
                sys.exit(f"skip_tasks: the {kw} of {path} can never be satisfied")
            if new == TRUE:
                # nothing left to wait for; drop the attribute rather than write a tautology
                d.delete_line(ln)
                changed += 1
                continue
            out = f"{line[:len(line) - len(line.lstrip())]}{kw} {unparse(new)}"
            if out != line:
                d.replace_line(ln, out)
                changed += 1

    # Stamp the tasks last, so their own triggers were still readable above
    for node in skipped.values():
        if not node.defstatus:
            header = d.lines[node.start]
            d.insert_after(node.start, " " * (len(header) - len(header.lstrip()) + 2) + "defstatus complete")
    d.commit()
    print(f"  {label}: {len(skipped)} task(s) set to defstatus complete, "
          f"{changed} dependent expression(s) rewritten")
