"""Trigger and complete expressions: parse them, rewrite their node references, write them back.

An expression is a boolean expression over "primaries": a node state test (path == state), an
event test (path:event), or anything else (:TIME >= 0300), which is opaque and passes through
untouched. parse() gives a tree of ('or'|'and', [children]) with Prim leaves; fold() removes the
TRUE and FALSE a rewrite leaves behind, so an expression left always true can be deleted rather
than written out as a tautology, which ecflow rejects.
"""

import re

TRUE, FALSE = "TRUE", "FALSE"
# ecflow node states a trigger can test; complete is the only one a task that never runs reaches
STATES = ("unknown", "complete", "queued", "aborted", "submitted", "active", "suspended")


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


def parse_expr(expr, base):
    """An expression's text to its tree, with relative references read from the node at base."""
    return parse(tokenize(expr), base)


def leaves(node):
    """The Prim leaves of an expression tree."""
    if isinstance(node, Prim):
        yield node
    elif node not in (TRUE, FALSE):
        for child in node[1]:
            yield from leaves(child)


def refs(expr, base):
    """(absolute path, prim) for each node reference in an expression."""
    return [(resolve(p.ref, base), p) for p in leaves(parse_expr(expr, base)) if p.ref is not None]
