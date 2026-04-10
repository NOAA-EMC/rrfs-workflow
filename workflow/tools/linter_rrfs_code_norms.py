#!/usr/bin/env python
"""
RRFS Code Norm Linting
Checks shell scripts against RRFS coding norms, include some NCO implementation standards

Supports inline suppression: # rrfslint: disable=RRFS001,RRFS002
Supports next line suppression: # rrfslint: disable-next-line=RRFS001,RRFS002
Supports file-level suppression at top of file: # rrfslint: file-disable=RRFS001
More information: https://github.com/RRFSx/linter_rrfs_code_norms
"""

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class Violation:
    filepath: str
    line_no: int
    col: int
    rule_id: str
    severity: str          # "error" or "warning"
    message: str
    suggestion: str
    source_line: str


@dataclass
class RuleContext:
    """Context passed to every rule check."""
    filepath: str
    lines: list[str]       # all lines, 0-indexed
    line_no: int           # 1-based current line number
    line: str              # current line text (with newline stripped)
    in_jobs: bool          # file is under a jobs/ directory
    in_scripts: bool       # file is under a scripts/ directory


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_INLINE_DISABLE_RE = re.compile(r"#\s*rrfslint:\s*disable=([A-Z0-9_,\s]+)", re.IGNORECASE)
_FILE_DISABLE_RE = re.compile(r"#\s*rrfslint:\s*file-disable=([A-Z0-9_,\s]+)", re.IGNORECASE)

# Shell special / positional parameters that should use bare $
_SHELL_SPECIALS = {"$", "?", "!", "#", "@", "*", "-", "0", "1", "2", "3",
                   "4", "5", "6", "7", "8", "9", "_"}


def _is_comment_or_blank(line: str) -> bool:
    stripped = line.lstrip()
    return stripped == "" or stripped.startswith("#")


def _in_single_quotes(line: str, pos: int) -> bool:
    """Rough check if position is inside single quotes."""
    in_sq = False
    i = 0
    while i < pos and i < len(line):
        if line[i] == "'" and (i == 0 or line[i - 1] != "\\"):
            in_sq = not in_sq
        i += 1
    return in_sq


def _in_comment(line: str, pos: int) -> bool:
    """Rough check if position is in a trailing comment."""
    in_sq = False
    in_dq = False
    for i in range(pos):
        ch = line[i]
        if ch == "'" and not in_dq:
            in_sq = not in_sq
        elif ch == '"' and not in_sq:
            in_dq = not in_dq
        elif ch == '#' and not in_sq and not in_dq:
            return True
    return False


def _get_file_level_disables(lines: list[str]) -> set[str]:
    """Collect file-level rule disables from top comments.
    Supports ``file-disable=all`` to suppress every rule for the entire file.
    """
    disables: set[str] = set()
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            m = _FILE_DISABLE_RE.search(stripped)
            if m:
                for rule_id in m.group(1).split(","):
                    token = rule_id.strip().upper()
                    if token == "ALL":
                        disables.add("ALL")
                    else:
                        disables.add(token)
        else:
            break  # stop at first non-comment, non-blank line
    return disables


def _get_line_disables(line: str) -> set[str]:
    """Collect inline rule disables from a single line."""
    disables: set[str] = set()
    m = _INLINE_DISABLE_RE.search(line)
    if m:
        for rule_id in m.group(1).split(","):
            disables.add(rule_id.strip().upper())
    return disables


# ---------------------------------------------------------------------------
# Rule implementations — each returns a list of Violation or empty list
# ---------------------------------------------------------------------------

def rule_rrfs001_source_not_dot(ctx: RuleContext) -> list[Violation]:
    """RRFS001: Use 'source' instead of '.' for sourcing files."""
    violations = []
    # Match ". /path" or ". file" at word boundary, but not "..." or "./"
    # We look for lines starting with `. ` that source a file.
    pattern = re.compile(r'(?:^|;\s*)\.\s+(/\S+|\$\S+|"\S+)')
    for m in pattern.finditer(ctx.line):
        col = m.start() + 1
        if not _in_comment(ctx.line, m.start()) and not _in_single_quotes(ctx.line, m.start()):
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=col,
                rule_id="RRFS001",
                severity="warning",
                message="Use 'source' instead of '.' for better readability.",
                suggestion=ctx.line[:m.start()] + ctx.line[m.start():].replace(". ", "source ", 1),
                source_line=ctx.line,
            ))
    return violations


def rule_rrfs002_double_bracket(ctx: RuleContext) -> list[Violation]:
    """RRFS002: Use [[ ]] instead of [ ]."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Match single [ that is NOT [[
    pattern = re.compile(r'(?<!\[)\[\s(?!\[)')
    for m in pattern.finditer(ctx.line):
        if not _in_comment(ctx.line, m.start()) and not _in_single_quotes(ctx.line, m.start()):
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start() + 1,
                rule_id="RRFS002",
                severity="error",
                message="Use '[[' instead of '[' for test expressions.",
                suggestion="Replace '[ ... ]' with '[[ ... ]]'.",
                source_line=ctx.line,
            ))
    return violations


def rule_rrfs003_double_equals(ctx: RuleContext) -> list[Violation]:
    """RRFS003: Use == instead of = for string comparison inside [[ ]]."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Look inside [[ ... ]] for = that is not == and not !=, =~
    bracket_match = re.finditer(r'\[\[(.+?)]]', ctx.line)
    for bm in bracket_match:
        inner = bm.group(1)
        offset = bm.start(1)
        # Find bare = (not ==, !=, =~, +=)
        for em in re.finditer(r'(?<!=)(?<!!)(?<!\+)=(?!=|~)', inner):
            # skip if it's part of a -* flag
            before = inner[:em.start()].rstrip()
            if before.endswith(("-z", "-n", "-f", "-s", "-d", "-e", "-r", "-w", "-x")):
                continue
            col = offset + em.start() + 1
            if not _in_comment(ctx.line, col - 1):
                violations.append(Violation(
                    filepath=ctx.filepath,
                    line_no=ctx.line_no,
                    col=col,
                    rule_id="RRFS003",
                    severity="error",
                    message="Use '==' instead of '=' for string comparison inside [[ ]].",
                    suggestion="Replace '=' with '==' and double-quote the compared strings.",
                    source_line=ctx.line,
                ))
    return violations


def rule_rrfs004_use_dash_s(ctx: RuleContext) -> list[Violation]:
    """RRFS004: Use -s instead of -f to check if a file exists and is not size zero."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    pattern = re.compile(r'\[\[?\s+-f\s')
    for m in pattern.finditer(ctx.line):
        if not _in_comment(ctx.line, m.start()):
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start() + 1,
                rule_id="RRFS004",
                severity="warning",
                message="Use '-s' instead of '-f' to check if a file exists and is not size zero.",
                suggestion=ctx.line.replace(" -f ", " -s ", 1),
                source_line=ctx.line,
            ))
    return violations


def rule_rrfs005_ndate_not_date(ctx: RuleContext) -> list[Violation]:
    """RRFS005: Use ${NDATE} for cycle/date arithmetic; 'date' only for format strings."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Flag `date -d` or `date --date` patterns that look like date arithmetic.
    # If the string argument after -d contains only digits, variable refs, colons,
    # spaces, and braces (e.g. "${CDATEp:0:8} ${CDATEp:8:2}"), it is just
    # reformatting an existing date — not computing a new one.  If it contains
    # alphabetic / non-digit words (e.g. "yesterday", "2 days ago"), that is
    # date arithmetic and should use ${NDATE}.
    pattern = re.compile(r'\bdate\s+(-d|--date)\s+("([^"]*)"|\'([^\']*)\'|(\S+))')
    for m in pattern.finditer(ctx.line):
        if not _in_comment(ctx.line, m.start()) and not _in_single_quotes(ctx.line, m.start()):
            # Extract the argument string (from whichever capture group matched)
            date_arg = m.group(3) or m.group(4) or m.group(5) or ""
            # Strip variable references like ${VAR}, ${VAR:0:8} etc.
            stripped = re.sub(r'\$\{[^}]*\}', '', date_arg)
            stripped = re.sub(r'\$[A-Za-z_]\w*', '', stripped)
            # After removing vars, if what remains has letters it's arithmetic
            if not re.search(r'[a-zA-Z]', stripped):
                continue  # digits-only / var-only — just formatting
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start() + 1,
                rule_id="RRFS005",
                severity="warning",
                message="Use ${NDATE} to find previous or future cycles/dates. "
                        "The 'date' command should only be used for format strings.",
                suggestion="Replace date arithmetic with ${NDATE}.",
                source_line=ctx.line,
            ))
    return violations


def rule_rrfs006_no_tabs(ctx: RuleContext) -> list[Violation]:
    """RRFS006: Use 2 spaces for indentation; no TABs."""
    violations = []
    if "\t" in ctx.line:
        col = ctx.line.index("\t") + 1
        violations.append(Violation(
            filepath=ctx.filepath,
            line_no=ctx.line_no,
            col=col,
            rule_id="RRFS006",
            severity="error",
            message="Use 2 spaces for indentation in BASH scripts. Avoid TABs.",
            suggestion=ctx.line.replace("\t", "  "),
            source_line=ctx.line,
        ))
    return violations


def rule_rrfs007_export_uppercase(ctx: RuleContext) -> list[Violation]:
    """RRFS007: Exported variables should start with uppercase."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Match `export varname` or `export varname=`
    pattern = re.compile(r'\bexport\s+([a-z_]\w*)')
    for m in pattern.finditer(ctx.line):
        if not _in_comment(ctx.line, m.start()):
            varname = m.group(1)
            # Allow 'export err=$?', 'export pgm=...', etc as well-known idioms
            if varname == "err" or varname == "pgm" or varname == "pid" or varname == "cyc" or varname == "jobid" or varname == "pgmout":
                continue
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start(1) + 1,
                rule_id="RRFS007",
                severity="error",
                message=f"Exported variable '{varname}' should be capitalized or start with an uppercase letter.",
                suggestion=f"Rename '{varname}' to '{varname.upper()}' or '{varname[0].upper() + varname[2:]}'.",
                source_line=ctx.line,
            ))
    return violations


def rule_rrfs008_default_colon_dash(ctx: RuleContext) -> list[Violation]:
    """RRFS008: Use :- (not just :) for default values in parameter expansion."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Match ${VAR:value} where there's a colon NOT followed by -
    # But avoid matching ${VAR:-value}, ${VAR:+value}, ${VAR:?value}, ${VAR:offset:length}
    pattern = re.compile(r'\$\{(\w+):(?![-+?=\d])([^}]*)\}')
    for m in pattern.finditer(ctx.line):
        if not _in_comment(ctx.line, m.start()) and not _in_single_quotes(ctx.line, m.start()):
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start() + 1,
                rule_id="RRFS008",
                severity="error",
                message=f"Use ':-' instead of ':' alone for default value in ${{{m.group(1)}}}.",
                suggestion=ctx.line[:m.start()] + "${" + m.group(1) + ":-" + m.group(2) + "}" + ctx.line[m.end():],
                source_line=ctx.line,
            ))
    return violations


def rule_rrfs009_braced_variables(ctx: RuleContext) -> list[Violation]:
    """RRFS009: Use ${var} instead of $var. Bare $ allowed for specials/positional."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Match $VARNAME that is NOT ${VARNAME} and not a special
    pattern = re.compile(r'\$([A-Za-z_]\w*)')
    for m in pattern.finditer(ctx.line):
        # Check it's not already braced: char before $ should not make it ${
        pos = m.start()
        if pos > 0 and ctx.line[pos - 1] == '{':
            continue
        if _in_comment(ctx.line, pos) or _in_single_quotes(ctx.line, pos):
            continue
        violations.append(Violation(
            filepath=ctx.filepath,
            line_no=ctx.line_no,
            col=pos + 1,
            rule_id="RRFS009",
            severity="warning",
            message=f"Use '${{{m.group(1)}}}' instead of '${m.group(1)}'.",
            suggestion=f"${{{m.group(1)}}}",
            source_line=ctx.line,
        ))
    return violations


def rule_rrfs010_arithmetic_parens(ctx: RuleContext) -> list[Violation]:
    """RRFS010: Use (( )) instead of [[ ]] for arithmetic operations."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Detect [[ ... -eq/-ne/-lt/-le/-gt/-ge ... ]]
    pattern = re.compile(r'\[\[.*\s-(eq|ne|lt|le|gt|ge)\s.*]]')
    m = pattern.search(ctx.line)
    if m and not _in_comment(ctx.line, m.start()):
        violations.append(Violation(
            filepath=ctx.filepath,
            line_no=ctx.line_no,
            col=m.start() + 1,
            rule_id="RRFS010",
            severity="warning",
            message="Use (( )) instead of [[ ]] for arithmetic operations and comparisons.",
            suggestion="Replace '[[ ... -eq ... ]]' with '(( ... == ... ))'.",
            source_line=ctx.line,
        ))
    return violations


def rule_rrfs011_z_quoted(ctx: RuleContext) -> list[Violation]:
    """RRFS011: Double-quote variable in -z / -n tests."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Match -z ${var} or -n ${var} without quotes
    pattern = re.compile(r'-(z|n)\s+(\$\{[^}]+\})(?!")')
    for m in pattern.finditer(ctx.line):
        # Verify the ${var} is NOT already quoted
        before_pos = m.start(2)
        if before_pos > 0 and ctx.line[before_pos - 1] == '"':
            continue
        after_pos = m.end(2)
        if after_pos < len(ctx.line) and ctx.line[after_pos] == '"':
            continue
        if _in_comment(ctx.line, m.start()):
            continue
        flag = m.group(1)
        var = m.group(2)
        violations.append(Violation(
            filepath=ctx.filepath,
            line_no=ctx.line_no,
            col=m.start(2) + 1,
            rule_id="RRFS011",
            severity="error",
            message=f"Double-quote the variable in '-{flag}' test: use \"-{flag} \\\"{var}\\\"\".",
            suggestion=f'-{flag} "{var}"',
            source_line=ctx.line,
        ))
    return violations


def _find_header_lines(lines: list[str], expected: list[str]) -> list[tuple[int, str, str]]:
    """Match expected header lines against file lines, skipping comment/blank
    lines between the shebang and the rest of the header.

    Returns a list of (0-based line index, actual text, expected text) for each
    expected header entry.  The shebang (expected[0]) is always checked at
    line 0.  Subsequent expected lines are matched against the first
    non-comment, non-blank lines after the shebang.
    """
    results: list[tuple[int, str, str]] = []
    # First entry is always the shebang at line 0
    actual0 = lines[0].rstrip() if lines else ""
    results.append((0, actual0, expected[0]))

    # For the remaining expected lines, skip over comment / blank lines
    exp_idx = 1
    for file_idx in range(1, len(lines)):
        if exp_idx >= len(expected):
            break
        stripped = lines[file_idx].strip()
        if stripped == "" or stripped.startswith("#"):
            continue  # skip comments and blanks between header lines
        results.append((file_idx, lines[file_idx].rstrip(), expected[exp_idx]))
        exp_idx += 1

    # If we ran out of file lines before matching all expected entries
    while exp_idx < len(expected):
        results.append((len(lines), "", expected[exp_idx]))
        exp_idx += 1

    return results


def rule_rrfs012_job_header(ctx: RuleContext) -> list[Violation]:
    """RRFS012: Job files (jobs/) must start with the required header."""
    violations = []
    if not ctx.in_jobs:
        return violations
    if ctx.line_no != 1:
        return violations  # only check once

    expected = [
        "#!/usr/bin/env bash",
        "declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-\"Unknown\"}})[${LINENO}]: '",
        "set -x",
        "date",
    ]
    for file_idx, actual, exp in _find_header_lines(ctx.lines, expected):
        if actual != exp:
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=file_idx + 1,
                col=1,
                rule_id="RRFS012",
                severity="error",
                message=f"Job file header should contain: {exp}",
                suggestion=exp,
                source_line=actual,
            ))
    return violations


def rule_rrfs013_script_header(ctx: RuleContext) -> list[Violation]:
    """RRFS013: Script files (scripts/) must start with the required header."""
    violations = []
    if not ctx.in_scripts:
        return violations
    if ctx.line_no != 1:
        return violations

    expected = [
        "#!/usr/bin/env bash",
        "declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-\"Unknown\"}})[${LINENO}]: '",
    ]
    for file_idx, actual, exp in _find_header_lines(ctx.lines, expected):
        if actual != exp:
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=file_idx + 1,
                col=1,
                rule_id="RRFS013",
                severity="error",
                message=f"Script file header should contain: {exp}",
                suggestion=exp,
                source_line=actual,
            ))
    return violations


def rule_rrfs014_no_backticks(ctx: RuleContext) -> list[Violation]:
    """RRFS014: Use $(command) instead of backticks."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Find backticks that aren't in comments or single quotes
    for m in re.finditer(r'`', ctx.line):
        if not _in_comment(ctx.line, m.start()) and not _in_single_quotes(ctx.line, m.start()):
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start() + 1,
                rule_id="RRFS014",
                severity="error",
                message="Use $(command) instead of backticks for command substitution.",
                suggestion="Replace `command` with $(command).",
                source_line=ctx.line,
            ))
            break  # one warning per line is enough for backtick pairs
    return violations


def rule_rrfs015_bool_no_quotes(ctx: RuleContext) -> list[Violation]:
    """RRFS015: Use true/false without quotes for boolean variables."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Only match assignments like VAR="true" or VAR="false" (lowercase only),
    # immediately after = with no space.  Do not match comparisons like == "TRUE"
    # or != "true" or default values like :-"false".
    pattern = re.compile(r'(?<!=)(?<!!)(?<!-)="(true|false)"')
    for m in pattern.finditer(ctx.line):
        if not _in_comment(ctx.line, m.start()):
            val = m.group(1)
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start() + 1,
                rule_id="RRFS015",
                severity="warning",
                message=f"Use {val} without quotes instead of \"{val}\".",
                suggestion=ctx.line[:m.start()] + "=" + val + ctx.line[m.end():],
                source_line=ctx.line,
            ))
    return violations


def rule_rrfs016_uppercase_compare(ctx: RuleContext) -> list[Violation]:
    """RRFS016: Use ${var^^} to uppercase before comparing to TRUE/FALSE/YES/NO."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    # Detect comparisons like ${VAR} == "TRUE" or == "YES" etc. without ^^
    pattern = re.compile(
        r'\$\{(\w+)\}\s*==\s*["\']?(TRUE|FALSE|YES|NO|true|false|yes|no)["\']?'
    )
    for m in pattern.finditer(ctx.line):
        varname = m.group(1)
        # Already using ^^ ?
        if f"${{{varname}^^}}" in ctx.line:
            continue
        if _in_comment(ctx.line, m.start()):
            continue
        violations.append(Violation(
            filepath=ctx.filepath,
            line_no=ctx.line_no,
            col=m.start() + 1,
            rule_id="RRFS016",
            severity="warning",
            message=f"Use '${{{varname}^^}}' to convert to uppercase before comparing.",
            suggestion=f'Use "${{{varname}^^}}" == "{m.group(2).upper()}".',
            source_line=ctx.line,
        ))
    return violations


def rule_rrfs017_standard_varnames(ctx: RuleContext) -> list[Violation]:
    """RRFS017: Use standard variable names (PDY, cyc, subcyc, CDATE)."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    renames = {
        "YYYYMMDD": "PDY",
        "YYYYMMDDHH": "CDATE",
    }
    for old, new in renames.items():
        # Match as variable names: ${YYYYMMDD}, $YYYYMMDD, YYYYMMDD=
        pattern = re.compile(r'(?<!\w)' + re.escape(old) + r'(?!\w)')
        for m in pattern.finditer(ctx.line):
            if _in_comment(ctx.line, m.start()) or _in_single_quotes(ctx.line, m.start()):
                continue
            # Skip if it's inside a format string like +%Y%m%d%H
            before = ctx.line[:m.start()]
            if "+" in before and ("%" in before[before.rfind("+"):]):
                continue
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start() + 1,
                rule_id="RRFS017",
                severity="warning",
                message=f"Use '{new}' instead of '{old}'.",
                suggestion=f"Rename '{old}' to '{new}'.",
                source_line=ctx.line,
            ))
    return violations


def rule_rrfs018_no_python_invocation(ctx: RuleContext) -> list[Violation]:
    """RRFS018: Call Python scripts directly with shebang, not via 'python script.py'."""
    violations = []
    if _is_comment_or_blank(ctx.line):
        return violations
    pattern = re.compile(r'\b(python[23]?|python\.[0-9]+)\s+\S+\.py\b')
    for m in pattern.finditer(ctx.line):
        if not _in_comment(ctx.line, m.start()) and not _in_single_quotes(ctx.line, m.start()):
            violations.append(Violation(
                filepath=ctx.filepath,
                line_no=ctx.line_no,
                col=m.start() + 1,
                rule_id="RRFS018",
                severity="error",
                message="Call Python scripts directly with a shebang instead of 'python script.py'.",
                suggestion="Add '#!/usr/bin/env python' shebang to the Python script, make it executable, and call it directly.",
                source_line=ctx.line,
            ))
    return violations


# ---------------------------------------------------------------------------
# Rule registry
# ---------------------------------------------------------------------------

ALL_RULES = [
    ("RRFS001", "Use 'source' instead of '.'", rule_rrfs001_source_not_dot),
    ("RRFS002", "Use [[ instead of [", rule_rrfs002_double_bracket),
    ("RRFS003", "Use == for string comparison", rule_rrfs003_double_equals),
    ("RRFS004", "Use -s instead of -f", rule_rrfs004_use_dash_s),
    ("RRFS005", "Use ${NDATE} for date math", rule_rrfs005_ndate_not_date),
    ("RRFS006", "No TABs; use 2 spaces", rule_rrfs006_no_tabs),
    ("RRFS007", "Exported vars start uppercase", rule_rrfs007_export_uppercase),
    ("RRFS008", "Use :- for defaults", rule_rrfs008_default_colon_dash),
    ("RRFS009", "Use ${var} not $var", rule_rrfs009_braced_variables),
    ("RRFS010", "Use (( )) for arithmetic", rule_rrfs010_arithmetic_parens),
    ("RRFS011", "Quote var in -z/-n test", rule_rrfs011_z_quoted),
    ("RRFS012", "Job file header", rule_rrfs012_job_header),
    ("RRFS013", "Script file header", rule_rrfs013_script_header),
    ("RRFS014", "No backticks", rule_rrfs014_no_backticks),
    ("RRFS015", "No quoted true/false", rule_rrfs015_bool_no_quotes),
    ("RRFS016", "Uppercase before compare", rule_rrfs016_uppercase_compare),
    ("RRFS017", "Use standard var names", rule_rrfs017_standard_varnames),
    ("RRFS018", "No 'python script.py' calls", rule_rrfs018_no_python_invocation),
]

RULE_MAP = {rule_id: (desc, fn) for rule_id, desc, fn in ALL_RULES}


# ---------------------------------------------------------------------------
# Linter engine
# ---------------------------------------------------------------------------

def lint_file(
    filepath: str,
    enabled_rules: Optional[set[str]] = None,
    disabled_rules: Optional[set[str]] = None,
) -> list[Violation]:
    """Lint a single file and return violations."""
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            raw_lines = f.readlines()
    except OSError as exc:
        print(f"linter_rrfs_code_norms: cannot read {filepath}: {exc}", file=sys.stderr)
        return []

    lines = [line.rstrip("\n\r") for line in raw_lines]
    abs_path = os.path.abspath(filepath)
    path_parts = Path(abs_path).parts
    in_jobs = "jobs" in path_parts
    in_scripts = "scripts" in path_parts

    file_disables = _get_file_level_disables(lines)

    # file-disable=all skips the entire file
    if "ALL" in file_disables:
        return []

    violations: list[Violation] = []

    for idx, line in enumerate(lines):
        line_no = idx + 1
        line_disables = _get_line_disables(line)

        # Also check previous line for "next-line" disable
        prev_disables: set[str] = set()
        if idx > 0:
            prev_stripped = lines[idx - 1].strip()
            m = re.search(r"#\s*rrfslint:\s*disable-next-line=([A-Z0-9_,\s]+)", prev_stripped, re.IGNORECASE)
            if m:
                for rid in m.group(1).split(","):
                    prev_disables.add(rid.strip().upper())

        ctx = RuleContext(
            filepath=abs_path,
            lines=lines,
            line_no=line_no,
            line=line,
            in_jobs=in_jobs,
            in_scripts=in_scripts,
        )

        for rule_id, _desc, rule_fn in ALL_RULES:
            # Apply filtering
            if enabled_rules and rule_id not in enabled_rules:
                continue
            if disabled_rules and rule_id in disabled_rules:
                continue
            if rule_id in file_disables:
                continue
            if rule_id in line_disables:
                continue
            if rule_id in prev_disables:
                continue

            violations.extend(rule_fn(ctx))

    return violations


def find_shell_scripts(paths: list[str], recursive: bool = True) -> list[str]:
    """Find shell scripts in the given paths."""
    scripts = []
    for p in paths:
        p_path = Path(p)
        if p_path.is_file():
            scripts.append(str(p_path))
        elif p_path.is_dir() and recursive:
            for ext in ("*.sh", "*.bash", "*.ksh"):
                scripts.extend(str(f) for f in p_path.rglob(ext))
            # Also find files with bash/sh shebang but no extension
            for f in p_path.rglob("*"):
                if f.is_file() and f.suffix == "":
                    try:
                        with open(f, "r", encoding="utf-8", errors="replace") as fh:
                            first = fh.readline()
                        if first.startswith("#!") and ("bash" in first or "/sh" in first):
                            scripts.append(str(f))
                    except OSError:
                        pass
    return sorted(set(scripts))


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

def format_default(violations: list[Violation]) -> str:
    """GCC-style output."""
    lines = []
    for v in violations:
        lines.append(
            f"{v.filepath}:{v.line_no}:{v.col}: {v.severity} {v.rule_id}: {v.message}"
        )
        lines.append(f"  {v.source_line}")
        lines.append(f"  Suggestion: {v.suggestion}")
        lines.append("")
    return "\n".join(lines)


def format_compact(violations: list[Violation]) -> str:
    """One line per violation."""
    return "\n".join(
        f"{v.filepath}:{v.line_no}:{v.col}: [{v.rule_id}] {v.message}"
        for v in violations
    )


def format_json(violations: list[Violation]) -> str:
    """JSON output."""
    import json
    data = [
        {
            "file": v.filepath,
            "line": v.line_no,
            "column": v.col,
            "rule": v.rule_id,
            "severity": v.severity,
            "message": v.message,
            "suggestion": v.suggestion,
            "source": v.source_line,
        }
        for v in violations
    ]
    return json.dumps(data, indent=2)


def format_sarif(violations: list[Violation]) -> str:
    """SARIF 2.1.0 output for GitHub Code Scanning integration."""
    import json

    rules_seen: dict[str, int] = {}  # rule_id -> index
    rule_descriptors = []
    for rule_id, desc, _fn in ALL_RULES:
        rules_seen[rule_id] = len(rule_descriptors)
        rule_descriptors.append({
            "id": rule_id,
            "name": rule_id,
            "shortDescription": {"text": desc},
            "helpUri": f"https://github.com/NOAA-EMC/rrfs-workflow/blob/develop/workflow/tools/linter_rrfs_code_norm_check.py#{rule_id}",
            "properties": {"tags": ["rrfs", "coding-standards"]},
        })

    results = []
    cwd = os.getcwd()
    for v in violations:
        # SARIF severity levels: error, warning, note
        level = "error" if v.severity == "error" else "warning"
        # Use path relative to cwd for GitHub Code Scanning
        rel_path = os.path.relpath(v.filepath, cwd)
        result = {
            "ruleId": v.rule_id,
            "ruleIndex": rules_seen.get(v.rule_id, 0),
            "level": level,
            "message": {
                "text": f"{v.message}\nSuggestion: {v.suggestion}",
            },
            "locations": [
                {
                    "physicalLocation": {
                        "artifactLocation": {
                            "uri": rel_path,
                            "uriBaseId": "%SRCROOT%",
                        },
                        "region": {
                            "startLine": v.line_no,
                            "startColumn": v.col,
                        },
                    }
                }
            ],
        }
        results.append(result)

    sarif = {
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "version": "2.1.0",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": "RRFS Code Norm Linting",
                        "informationUri": "https://github.com/NOAA-EMC/rrfs-workflow",
                        "version": "1.0.0",
                        "rules": rule_descriptors,
                    }
                },
                "results": results,
            }
        ],
    }
    return json.dumps(sarif, indent=2)


def format_github(violations: list[Violation]) -> str:
    """GitHub Actions workflow command format.

    Emits ::error and ::warning commands that produce inline annotations
    on pull request diffs, plus a human-readable summary in the step log
    """
    lines = []
    for v in violations:
        # Human-readable log line (visible in the Actions step detail page)
        sev_tag = "RRFS_ERROR" if v.severity == "error" else "RRFS_WARNING"
        lines.append(f"Error: {sev_tag}:")
        lines.append(f"{v.filepath}:{v.line_no}:{v.col}: {v.severity}[{v.rule_id}]: {v.message}")
        lines.append(f"  Suggestion: {v.suggestion}")
        lines.append("")

        # Workflow command (produces inline annotation on PR diff)
        msg = v.message.replace('%', '%25').replace('\n', '%0A').replace('\r', '%0D')
        sug = v.suggestion.replace('%', '%25').replace('\n', '%0A').replace('\r', '%0D')
        cmd = "error" if v.severity == "error" else "warning"
        lines.append(
            f"::{cmd} file={v.filepath},line={v.line_no},col={v.col},"
            f"title={v.rule_id}::{msg} | Suggestion: {sug}"
        )
        lines.append("")

    # Summary
    if violations:
        errors = sum(1 for v in violations if v.severity == "error")
        warnings = sum(1 for v in violations if v.severity == "warning")
        files = len(set(v.filepath for v in violations))
        lines.append("=" * 60)
        lines.append(f"RRFS Code Norm: {len(violations)} defects ({errors} errors, {warnings} warnings) in {files} file(s), NEEDS INSPECTION")
    else:
        lines.append("RRFS Code Norm: all files passed.")

    return "\n".join(lines)


FORMATTERS = {
    "default": format_default,
    "compact": format_compact,
    "json": format_json,
    "sarif": format_sarif,
    "github": format_github,
}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def list_rules():
    """Print all available rules."""
    print("Available RRFS lint rules:\n")
    print(f"  {'ID':<10} {'Description'}")
    print(f"  {'—' * 9}  {'—' * 40}")
    for rule_id, desc, _fn in ALL_RULES:
        print(f"  {rule_id:<10} {desc}")
    print(f"\nTotal: {len(ALL_RULES)} rules")


def main():
    parser = argparse.ArgumentParser(
        prog="linter_rrfs_code_norms",
        description="RRFS Code Norm Linter — lint shell scripts against RRFS coding norms.",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        default=["."],
        help="Files or directories to check (default: current directory).",
    )
    parser.add_argument(
        "--format", "-f",
        choices=FORMATTERS.keys(),
        default="default",
        help="Output format: default, compact, json, sarif, github (default: default).",
    )
    parser.add_argument(
        "--disable",
        type=str,
        default="",
        help="Comma-separated rule IDs to disable globally, e.g. --disable RRFS001,RRFS006.",
    )
    parser.add_argument(
        "--enable",
        type=str,
        default="",
        help="Comma-separated rule IDs to enable (only these will run).",
    )
    parser.add_argument(
        "--no-recursive",
        action="store_true",
        help="Do not recurse into directories.",
    )
    parser.add_argument(
        "--list-rules",
        action="store_true",
        help="List all available rules and exit.",
    )
    parser.add_argument(
        "--severity",
        choices=["all", "error", "warning"],
        default="all",
        help="Filter output by severity.",
    )
    # Print help if invoked with no arguments at all
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    args = parser.parse_args()

    if args.list_rules:
        list_rules()
        sys.exit(0)

    enabled = set(r.strip().upper() for r in args.enable.split(",") if r.strip()) or None
    disabled = set(r.strip().upper() for r in args.disable.split(",") if r.strip()) or None

    scripts = find_shell_scripts(args.paths, recursive=not args.no_recursive)

    if not scripts:
        print("linter_rrfs_code_norms: no shell scripts found.", file=sys.stderr)
        # Still emit valid output for structured formats
        if args.format in ("sarif", "json", "github"):
            print(FORMATTERS[args.format]([]))
        sys.exit(0)

    all_violations: list[Violation] = []
    for script in scripts:
        all_violations.extend(lint_file(script, enabled_rules=enabled, disabled_rules=disabled))

    # Filter by severity
    if args.severity != "all":
        all_violations = [v for v in all_violations if v.severity == args.severity]

    formatter = FORMATTERS[args.format]

    if all_violations:
        print(formatter(all_violations))
        # Summary
        if args.format == "default":
            errors = sum(1 for v in all_violations if v.severity == "error")
            warnings = sum(1 for v in all_violations if v.severity == "warning")
            files_with_issues = len(set(v.filepath for v in all_violations))
            print(f"\n{'=' * 60}")
            print(f"linter_rrfs_code_norms: {len(all_violations)} issues ({errors} errors, {warnings} warnings) "
                  f"in {files_with_issues} file(s).")
        sys.exit(1)
    else:
        # Always emit valid output for structured formats
        if args.format in ("sarif", "json", "github"):
            print(formatter([]))
        elif args.format == "default":
            print(f"linter_rrfs_code_norms: all {len(scripts)} file(s) passed.")
        sys.exit(0)


if __name__ == "__main__":
    main()
