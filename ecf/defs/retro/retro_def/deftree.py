"""Read, query and edit an ecflow suite definition as text.

The definition stays a list of lines, so every line no step touches is written back exactly as it
was read. Def.nodes indexes those lines as a tree of Node objects (suite, family, task), each with
its path in the suite, its children and the line numbers of its attributes (trigger, edit,
defstatus, ...).

Edits are queued against one parse of the definition and applied together by commit(), so the
line numbers held by the nodes stay valid while a step works out what to change:

    for task in d.find("task", name=r"jrrfs_det_prep_cyc"):
        d.and_trigger(task, "../ics == complete")
    d.commit()

Replacing a line keeps the tree valid, so nodes can still be read while replacements are
pending; an insert or a delete changes the line numbers, so they must be committed first.
"""

import collections
import re

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
