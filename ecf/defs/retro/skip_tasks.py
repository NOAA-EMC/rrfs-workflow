#!/usr/bin/env python3
"""Switch tasks off in a generated retro suite definition, and repair what depended on them.

A task is switched off by giving it "defstatus complete": ecflow then treats it as finished
without ever submitting it. On its own that is only safe for a task nothing waits on, because
a trigger that names the task is satisfied the moment the suite begins. This script therefore
also rewrites every trigger (and complete expression) that refers to a task it switches off:

  --mode inline   the reference is replaced by the switched-off task's own trigger, so whatever
                  waited on it now waits on what it waited on. This keeps a chain in order when
                  a step is taken out of the middle of it: with the non-variational cloud
                  analysis off, for instance, the forecast waits on the analysis step before it
                  instead of starting as soon as the cycle opens.
  --mode ignore   the reference is dropped (a "== complete" test becomes true, a test for any
                  other state becomes false). This is for a whole workflow group that is not
                  running at all, where inlining would drag that group's dependencies into the
                  group that is running.

Expressions are parsed, rewritten and folded, so one left always true is deleted rather than
written out as a tautology, which ecflow rejects. Relative node paths in an inlined expression
become absolute, since the expression moves to a node elsewhere in the tree.

Usage:
  skip_tasks.py <def> [--mode inline|ignore] [--label TEXT] [--post-manager]
                      [--name REGEX]... [--path REGEX]...

  --name          full-match regex on the task name, e.g. 'jrrfs_det_.*_spinup'
  --path          search regex on the task's path in the suite, e.g. '/enkf/'
                  A task is switched off when it matches any --name or any --path.
  --post-manager  also repoint the post tasks of a switched-off post manager at the forecast
                  task; their trigger is one of the manager's events rather than a node state,
                  and an event of a task that never runs is never set.
"""

import argparse
import re
import sys

TRUE, FALSE = "TRUE", "FALSE"
# ecflow node states a trigger can test; complete is the only one a task that never runs reaches
STATES = ("unknown", "complete", "queued", "aborted", "submitted", "active", "suspended")
NODE_KW = ("suite", "family", "task")
# the attributes that hold an expression over other nodes
EXPR_KW = ("trigger", "complete")


# ---------------------------------------------------------------------------------------------
# Expressions. A trigger is a boolean expression over "primaries": a node state test
# (path == state), an event test (path:event), or anything else (:TIME >= 0300), which is opaque
# and passes through untouched.
# ---------------------------------------------------------------------------------------------

class Prim:
    """One leaf of an expression, kept alongside the text it was written as."""

    def __init__(self, text, ref=None, state=None, event=None, base=None):
        self.text, self.ref, self.state, self.event, self.base = text, ref, state, event, base


def tokenize(expr):
    """Split into '(', ')', 'and', 'or' and the primary text between them."""
    out, buf, i = [], "", 0
    while i < len(expr):
        ch = expr[i]
        if ch in "()":
            if buf.strip():
                out.append(buf.strip())
            buf = ""
            out.append(ch)
            i += 1
            continue
        m = re.match(r"(and|or)\b", expr[i:])
        # only where a word starts, so the "or" inside e.g. jrrfs_det_forecast is not an operator
        if m and (not buf or not (buf[-1].isalnum() or buf[-1] in "_./")):
            if buf.strip():
                out.append(buf.strip())
            buf = ""
            out.append(m.group(1))
            i += len(m.group(1))
            continue
        buf += ch
        i += 1
    if buf.strip():
        out.append(buf.strip())
    return out


def make_prim(text, base):
    m = re.fullmatch(r"([^\s=<>!:]+)\s*==\s*(\w+)", text)
    if m and m.group(2) in STATES:
        return Prim(text, ref=m.group(1), state=m.group(2), base=base)
    m = re.fullmatch(r"([^\s:]+):(\w+)", text)
    if m:
        return Prim(text, ref=m.group(1), event=m.group(2), base=base)
    return Prim(text, base=base)


def parse(tokens, base):
    """Tokens to a tree of ('or'|'and', [children]) with Prim leaves."""
    pos = [0]

    def peek():
        return tokens[pos[0]] if pos[0] < len(tokens) else None

    def expression():
        parts = [term()]
        while peek() == "or":
            pos[0] += 1
            parts.append(term())
        return parts[0] if len(parts) == 1 else ("or", parts)

    def term():
        parts = [factor()]
        while peek() == "and":
            pos[0] += 1
            parts.append(factor())
        return parts[0] if len(parts) == 1 else ("and", parts)

    def factor():
        t = peek()
        if t == "(":
            pos[0] += 1
            node = expression()
            if peek() == ")":
                pos[0] += 1
            return node
        pos[0] += 1
        return make_prim(t, base)

    return expression()


def unparse(node, parent_op=None):
    if node in (TRUE, FALSE):
        return node
    if isinstance(node, Prim):
        return node.text
    op, parts = node
    text = f" {op} ".join(unparse(p, op) for p in parts)
    return f"( {text} )" if parent_op == "and" and op == "or" else text


def fold(node):
    """Constant-fold the TRUE and FALSE that rewriting leaves behind."""
    if node in (TRUE, FALSE) or isinstance(node, Prim):
        return node
    op, parts = node
    kept = []
    for p in (fold(c) for c in parts):
        if op == "and":
            if p == FALSE:
                return FALSE
            if p == TRUE:
                continue
        else:
            if p == TRUE:
                return TRUE
            if p == FALSE:
                continue
        kept.append(p)
    if not kept:
        return TRUE if op == "and" else FALSE
    return kept[0] if len(kept) == 1 else (op, kept)


# ---------------------------------------------------------------------------------------------
# The definition: its nodes, their paths and the expressions attached to them
# ---------------------------------------------------------------------------------------------

class Node:
    def __init__(self, name, path, kind, line):
        self.name, self.path, self.kind, self.line = name, path, kind, line
        self.expr_lines = []      # line numbers of this node's trigger and complete attributes
        self.has_defstatus = False
        self.children = []


def read_defs(lines):
    """Walk the definition and return every node, keyed by its path."""
    nodes, stack, last = {}, [], None
    for i, line in enumerate(lines):
        text = line.strip()
        if not text:
            continue
        kw = text.split()[0]
        if kw in NODE_KW:
            parent = stack[-1] if stack else None
            path = (parent.path if parent else "") + "/" + text.split()[1]
            node = Node(text.split()[1], path, kw, i)
            nodes[path] = node
            if parent:
                parent.children.append(node)
            if kw != "task":
                stack.append(node)
            last = node
        elif kw == "endfamily":
            if stack:
                stack.pop()
            last = stack[-1] if stack else None
        elif last is not None:
            if kw in EXPR_KW:
                last.expr_lines.append(i)
            elif kw == "defstatus":
                last.has_defstatus = True
    return nodes


def resolve(ref, base):
    """Absolute path of a node reference written relative to the node at path base."""
    if ref.startswith("/"):
        return ref.rstrip("/")
    parts = base.split("/")
    for seg in ref.split("/"):
        if seg in ("", "."):
            continue
        if seg == "..":
            parts = parts[:-1]
        else:
            parts.append(seg)
    return "/".join(parts)


def absolutize(node):
    """Copy an expression with its relative references rewritten as absolute paths."""
    if node in (TRUE, FALSE):
        return node
    if isinstance(node, Prim):
        if node.ref is None:
            return node
        path = resolve(node.ref, node.base)
        text = f"{path} == {node.state}" if node.state else f"{path}:{node.event}"
        return Prim(text, ref=path, state=node.state, event=node.event, base="")
    op, parts = node
    return (op, [absolutize(p) for p in parts])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("deffile")
    ap.add_argument("--mode", choices=("inline", "ignore"), default="inline")
    ap.add_argument("--label", default="tasks")
    ap.add_argument("--name", action="append", default=[])
    ap.add_argument("--path", action="append", default=[])
    ap.add_argument("--post-manager", action="store_true")
    args = ap.parse_args()
    if not args.name and not args.path:
        sys.exit("skip_tasks.py: nothing selected (give --name or --path)")

    lines = open(args.deffile).read().split("\n")
    nodes = read_defs(lines)
    names = [re.compile(p) for p in args.name]
    paths = [re.compile(p) for p in args.path]

    skipped = {}
    for path, node in nodes.items():
        if node.kind != "task":
            continue
        if any(r.fullmatch(node.name) for r in names) or any(r.search(path) for r in paths):
            skipped[path] = node
    if not skipped:
        print(f"  {args.label}: no task matched")
        return

    # Each switched-off task's own trigger, as an absolute expression, for --mode inline
    own = {}
    for path, node in skipped.items():
        base = path.rsplit("/", 1)[0]
        trig = next((ln for ln in node.expr_lines
                     if lines[ln].strip().startswith("trigger ")), None)
        own[path] = TRUE if trig is None else \
            absolutize(parse(tokenize(lines[trig].strip()[len("trigger "):]), base))

    # A post manager releases its post tasks through events rather than a node state, so point
    # them at the forecast task instead. Not at "== active", which the manager's own trigger
    # accepts: with the manager gone nothing checks that the hour has been written, so a post
    # can only start once the forecast has finished.
    release = {}
    if args.post_manager:
        for path, node in skipped.items():
            if not node.name.endswith("_post_manager"):
                continue
            wgf = nodes[path.rsplit("/", 2)[0]]
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
            if args.mode == "ignore":
                return TRUE if node.state == "complete" else FALSE
            if node.state not in ("complete", "active"):
                return FALSE
            if depth > 20:
                sys.exit(f"skip_tasks.py: trigger inlining loops at {target}")
            return rewrite(own[target], base, depth + 1)
        op, parts = node
        return (op, [rewrite(p, base, depth) for p in parts])

    changed = 0
    for path, node in nodes.items():
        if path in skipped:
            # a task that never runs: its own dependencies no longer mean anything, and they
            # routinely name other switched-off tasks, so leave them as they were
            continue
        base = path.rsplit("/", 1)[0] if node.kind == "task" else path
        for ln in node.expr_lines:
            kw, expr = lines[ln].strip().split(" ", 1)
            touched[0] = False
            new = fold(rewrite(parse(tokenize(expr), base), base))
            if not touched[0]:
                # nothing in it referred to a switched-off task; leave the line exactly as written
                continue
            if new == FALSE:
                sys.exit(f"skip_tasks.py: the {kw} of {path} can never be satisfied")
            if new == TRUE:
                # nothing left to wait for; drop the attribute rather than write a tautology
                lines[ln] = None
                changed += 1
                continue
            indent = lines[ln][:len(lines[ln]) - len(lines[ln].lstrip())]
            out = indent + f"{kw} {unparse(new)}"
            if out != lines[ln]:
                lines[ln] = out
                changed += 1

    # Stamp the tasks last, so their own triggers were still readable above
    for ln in sorted((n.line for n in skipped.values() if not n.has_defstatus), reverse=True):
        indent = " " * (len(lines[ln]) - len(lines[ln].lstrip()) + 2)
        lines.insert(ln + 1, indent + "defstatus complete")

    with open(args.deffile, "w") as out:
        out.write("\n".join(ln for ln in lines if ln is not None))
    print(f"  {args.label}: {len(skipped)} task(s) set to defstatus complete, "
          f"{changed} dependent expression(s) rewritten")


if __name__ == "__main__":
    main()
