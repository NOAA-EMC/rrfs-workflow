"""The toolbox the retro steps are built on. The steps themselves, the changes made to the NCO
definition, are in settings.py, ordering.py, simplify.py and chains.py; adding or changing a
retro option should only need those. Nothing here knows about a particular task.

Settings (Config, load_config)
    retro/config.sh (through load_config.sh) and the domain file are bash, shared with
    setup_retro_links.sh and the other retro scripts, so they are sourced by bash, under the same
    set -eu as those scripts, and every variable is read back from it. Environment variables still
    win, since the config files only set what is not set already.

The definition (Def, Node)
    The definition stays a list of lines, so every line no step touches is written back exactly
    as it was read. Def.nodes indexes those lines as a tree of Node objects (suite, family,
    task), each with its path in the suite, its children and the line numbers of its attributes
    (trigger, edit, defstatus, ...).

    Edits are queued against one parse of the definition and applied together by commit(), so
    the line numbers held by the nodes stay valid while a step works out what to change:

        for task in d.find("task", name=r"jrrfs_det_prep_cyc"):
            d.and_trigger(task, "../ics == complete")
        d.commit()

    Replacing a line keeps the tree valid, so nodes can still be read while replacements are
    pending; an insert or a delete changes the line numbers, so they must be committed first.

Trigger and complete expressions (parse_expr, unparse, fold, ...)
    An expression is a boolean expression over "primaries": a node state test (path == state),
    an event test (path:event), or anything else (:TIME >= 0300), which is opaque and passes
    through untouched. parse() gives a tree of ('or'|'and', [children]) with Prim leaves; fold()
    removes the TRUE and FALSE a rewrite leaves behind, so an expression left always true can be
    deleted rather than written out as a tautology, which ecflow rejects.

Switching tasks off (skip_tasks)
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

import collections
import os
import re
import subprocess
import sys


# =================================================================================================
# Settings
# =================================================================================================

# Source the settings, then print every variable as NUL-separated fields: "s", name, value for a
# string, or "a", name, count and the elements for an indexed array. Anything the config files
# print goes to stderr, so it cannot be mistaken for a setting.
_DUMP = r'''
set -eu
{
  . "$1/load_config.sh"
  . "$1/domains/${DOMAIN}.sh"
} 1>&2
for _v in $(compgen -v); do
  case ${_v} in _v|_r) continue ;; esac
  if [[ $(declare -p "${_v}" 2>/dev/null) =~ ^declare\ -[a-zA-Z]*a ]]; then
    declare -n _r=${_v}
    printf 'a\0%s\0%s\0' "${_v}" "${#_r[@]}"
    [ "${#_r[@]}" -eq 0 ] || printf '%s\0' "${_r[@]}"
    unset -n _r
  elif [[ ! $(declare -p "${_v}" 2>/dev/null) =~ ^declare\ -[a-zA-Z]*A ]]; then
    printf 's\0%s\0%s\0' "${_v}" "${!_v-}"
  fi
done
'''


class Config:
    """The settings, read with bash's ${NAME:-default} meaning: unset and empty are the same."""

    def __init__(self, scalars, arrays):
        self.scalars, self.arrays = scalars, arrays

    def __getitem__(self, name):
        """A setting that must be set (bash's set -u); it may still be empty."""
        if name not in self.scalars:
            sys.exit(f"ERROR: {name} is not set in the retro config")
        return self.scalars[name]

    def get(self, name, default=""):
        value = self.scalars.get(name, "")
        return value if value != "" else default

    def is_false(self, name):
        """True if the switch is FALSE; anything else, unset included, leaves it on."""
        return self.get(name, "TRUE") == "FALSE"

    def is_true(self, name):
        """True if the switch is TRUE; anything else, unset included, leaves it off."""
        return self.get(name, "FALSE") == "TRUE"

    def int(self, name, default):
        value = self.get(name, str(default))
        try:
            return int(value)
        except ValueError:
            sys.exit(f"ERROR: {name} must be a whole number, not '{value}'")

    def hours(self, name, default):
        """A space-separated list of hours, such as DET_COLD_START_HRS="03 15", as ints."""
        return [int(h) for h in self.get(name, default).split()]

    def array(self, name):
        return self.arrays.get(name, [])


def load_config(defs_dir):
    proc = subprocess.run(["bash", "-c", _DUMP, "load_config", defs_dir], stdout=subprocess.PIPE)
    if proc.returncode:
        sys.exit(proc.returncode)
    fields = proc.stdout.decode().split("\0")
    scalars, arrays, i = {}, {}, 0
    while i < len(fields) - 1:
        kind, name = fields[i], fields[i + 1]
        if kind == "s":
            scalars[name] = fields[i + 2]
            i += 3
        else:
            n = int(fields[i + 2])
            arrays[name] = fields[i + 3:i + 3 + n]
            i += 3 + n
    return Config(scalars, arrays)


def package_home(cfg, defs_dir):
    """PACKAGEHOME, by default the clone this script is in."""
    return cfg.get("PACKAGEHOME", os.path.normpath(os.path.join(defs_dir, "..", "..", "..")))


# =================================================================================================
# The definition
# =================================================================================================

NODE_KW = ("suite", "family", "task")
END_KW = ("endfamily", "endsuite")
CYCLE_NAME = re.compile(r"\d\dz")       # the hourly cycle families, 00z to 23z
SIX_HOURLY_NAME = re.compile(r"\d\d")   # the 00, 06, 12 and 18 families that hold them


def indent_of(line):
    return line[:len(line) - len(line.lstrip())]


class Node:
    """A suite, family or task, and the lines it spans."""

    def __init__(self, kind, name, path, parent, start):
        self.kind, self.name, self.path, self.parent, self.start = kind, name, path, parent, start
        # one past the endfamily/endsuite line, or for a task the next node or end line
        self.end = None
        self.children = []
        self.attrs = []          # line numbers of the node's attribute lines
        self.defstatus = set()   # the values of its defstatus lines

    def _after(self, pattern):
        """The path component after the last one that fully matches pattern, and that one."""
        parts = self.path.split("/")
        for k in range(len(parts) - 1, -1, -1):
            if pattern.fullmatch(parts[k]):
                return parts[k], (parts[k + 1] if k + 1 < len(parts) else None)
        return None, None

    @property
    def cycle(self):
        """The hourly cycle the node is in, as an int (3 for .../03z/...), or None."""
        name, _ = self._after(CYCLE_NAME)
        return int(name[:2]) if name else None

    @property
    def group(self):
        """The workflow group (det, enkf, ensf, firewx) the node is in, or None."""
        name, nxt = self._after(CYCLE_NAME)
        return nxt if name else None

    @property
    def six_hourly(self):
        """The 00, 06, 12 or 18 family the node is in, as text, or None."""
        name, _ = self._after(SIX_HOURLY_NAME)
        return name


class Def:
    """An ecflow suite definition: its lines, the node tree over them, and queued edits."""

    def __init__(self, lines):
        self.lines = lines
        self._nodes = None
        self._replace = {}                          # line number -> new text (None deletes it)
        self._before = collections.defaultdict(list)
        self._after = collections.defaultdict(list)

    @classmethod
    def read(cls, path):
        with open(path) as f:
            text = f.read()
        if text and not text.endswith("\n"):
            text += "\n"
        return cls(text.split("\n"))

    def write(self, path):
        self.commit()
        with open(path, "w") as f:
            f.write("\n".join(self.lines))

    # -----------------------------------------------------------------------------------------
    # The tree
    # -----------------------------------------------------------------------------------------

    @property
    def nodes(self):
        """Every node by its path, in the order they appear."""
        if self._before or self._after or None in self._replace.values():
            raise RuntimeError("insert or delete pending: commit() before reading the tree again")
        if self._nodes is None:
            self._nodes = self._parse()
        return self._nodes

    def _parse(self):
        nodes, stack, task = {}, [], None
        for i, line in enumerate(self.lines):
            words = line.split()
            if not words:
                continue
            kw = words[0]
            if (kw in NODE_KW or kw in END_KW) and task:
                task.end, task = i, None
            if kw in NODE_KW:
                parent = stack[-1] if stack else None
                path = (parent.path if parent else "") + "/" + words[1]
                node = Node(kw, words[1], path, parent, i)
                nodes[path] = node
                if parent:
                    parent.children.append(node)
                if kw == "task":
                    task = node
                else:
                    stack.append(node)
            elif kw in END_KW:
                if stack:
                    stack.pop().end = i + 1
            else:
                # attributes go to the task above them, or to the family whose children they follow
                owner = task or (stack[-1] if stack else None)
                if owner:
                    owner.attrs.append(i)
                    if kw == "defstatus" and len(words) > 1:
                        owner.defstatus.add(words[1])
        if task:
            task.end = len(self.lines)
        return nodes

    def find(self, kind=None, name=None, path=None):
        """Nodes of this kind whose name fully matches the name regex and whose path contains a
        match of the path regex; either can be left out."""
        name_re = re.compile(name) if name else None
        path_re = re.compile(path) if path else None
        return [n for n in self.nodes.values()
                if (kind is None or n.kind == kind)
                and (name_re is None or name_re.fullmatch(n.name))
                and (path_re is None or path_re.search(n.path))]

    def suite(self):
        return next(n for n in self.nodes.values() if n.kind == "suite")

    # -----------------------------------------------------------------------------------------
    # Attributes
    # -----------------------------------------------------------------------------------------

    def line(self, i):
        """Line i, with any replacement that is waiting to be committed."""
        return self._replace.get(i, self.lines[i])

    def attr_lines(self, node, kw):
        """Line numbers of the node's attributes whose first word is kw."""
        return [i for i in node.attrs if self.line(i).split()[:1] == [kw]]

    def trigger_line(self, node):
        """Line number of the node's (first) trigger, or None."""
        return next(iter(self.attr_lines(node, "trigger")), None)

    def expression(self, i):
        """The expression of a trigger or complete line."""
        return self.line(i).strip().split(" ", 1)[1]

    def set_trigger(self, node, expr):
        """Replace the node's trigger, keeping the line's indent."""
        i = self.trigger_line(node)
        self.replace_line(i, f"{indent_of(self.line(i))}trigger {expr}")

    def and_trigger(self, node, term):
        """Make the node wait for term as well as whatever its trigger already waits for; a node
        with no trigger is given one, right after its header."""
        i = self.trigger_line(node)
        if i is None:
            self.add_attr(node, f"trigger {term}")
        else:
            self.replace_line(i, f"{indent_of(self.line(i))}trigger ( {self.expression(i)} ) and {term}")

    def add_attr(self, node, text):
        """Add an attribute line right after the node's header, indented under it."""
        self.insert_after(node.start, indent_of(self.lines[node.start]) + "  " + text)

    # -----------------------------------------------------------------------------------------
    # Line edits, queued until commit()
    # -----------------------------------------------------------------------------------------

    def replace_line(self, i, text):
        self._replace[i] = text

    def delete_line(self, i):
        self._replace[i] = None

    def insert_before(self, i, *lines):
        self._before[i].extend(lines)

    def insert_after(self, i, *lines):
        self._after[i].extend(lines)

    def commit(self):
        """Apply the queued edits; the tree is parsed again the next time it is read."""
        if not (self._replace or self._before or self._after):
            return
        out = []
        for i, line in enumerate(self.lines):
            out.extend(self._before.get(i, ()))
            line = self._replace.get(i, line)
            if line is not None:
                out.append(line)
            out.extend(self._after.get(i, ()))
        out.extend(self._before.get(len(self.lines), ()))
        self.lines = out
        self._replace.clear()
        self._before.clear()
        self._after.clear()
        self._nodes = None

    def changed(self):
        """Say that self.lines was replaced wholesale; the tree is parsed again when next read."""
        self._nodes = None

    def sub(self, pattern, repl, line_filter=None):
        """re.sub on every line (only those containing line_filter, if given), applied at once.
        Returns the number of lines changed."""
        self.commit()
        regex, n = re.compile(pattern), 0
        for i, line in enumerate(self.lines):
            if line_filter is not None and line_filter not in line:
                continue
            new = regex.sub(repl, line)
            if new != line:
                self.lines[i] = new
                n += 1
        if n:
            self._nodes = None
        return n

    def count(self, pattern):
        """Number of lines matching the regex pattern (re.match, from the start of the line)."""
        regex = re.compile(pattern)
        return sum(1 for i in range(len(self.lines)) if regex.match(self.line(i)))


# =================================================================================================
# Trigger and complete expressions
# =================================================================================================

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


# =================================================================================================
# Switching tasks off
# =================================================================================================

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
