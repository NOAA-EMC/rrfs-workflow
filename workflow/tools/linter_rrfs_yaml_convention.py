#!/usr/bin/env python
from __future__ import annotations

"""check RRFS YAML convetions"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import hifiyaml
except ImportError:
    hifiyaml = None


@dataclass
class Violation:
    filepath: str
    line_no: int
    rule_id: str
    message: str
    source_line: str


OBS_SPACE_RE = re.compile(r"^(\s*)(-\s+)?obs space\s*:")
FILTER_RE = re.compile(r"^(\s*)-\s+filter\s*:\s*(.*?)\s*(?:#.*)?$")
KEY_RE = re.compile(r"([^:#][^:]*):(?:\s|$)")
IDENTIFIER_RE = re.compile(r"^[A-Z][A-Za-z0-9]*_?$")
CONVENTIONAL_OBS_NAME_RE = re.compile(
    r"^[a-z][a-z0-9]*_(?:t|q|uv|ps)\d{3}(?:_\d{3})?$"
)
SIS_OBS_NAME_RE = re.compile(r"^[a-z][a-z0-9-]*_[a-z][a-z0-9-]*$")
SPECIAL_OBS_NAMES = {"refl10cm", "gnss_ztd"}
TERMINAL_FILTER_KEYS = {"action", "actions", "defer to post"}


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _key_at_indent(line: str, expected_indent: int) -> str | None:
    if not line.strip() or line.lstrip().startswith("#") or _indent(line) != expected_indent:
        return None
    content = line[expected_indent:]
    if content.startswith("- "):
        return None
    match = KEY_RE.match(content)
    return match.group(1).strip() if match else None


def _value_after_key(line: str, key: str) -> str | None:
    match = re.match(rf"\s*(?:-\s+)?{re.escape(key)}\s*:\s*(.*?)\s*(?:#.*)?$", line)
    if not match:
        return None
    value = match.group(1).strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def _blocks(lines: list[str], start: int, start_indent: int):
    end = len(lines)
    for index in range(start + 1, len(lines)):
        line = lines[index]
        if line.strip() and not line.lstrip().startswith("#") and _indent(line) <= start_indent:
            end = index
            break
    return range(start, end)


def _obs_spaces(lines: list[str]):
    for index, line in enumerate(lines):
        match = OBS_SPACE_RE.match(line)
        if not match or line.lstrip().startswith("#"):
            continue
        base_indent = len(match.group(1))
        is_sequence_item = bool(match.group(2))
        key_indent = base_indent + (2 if is_sequence_item else 0)
        yield index, _blocks(lines, index, base_indent), key_indent + 2


def _filter_blocks(lines: list[str], obs_space_range: range):
    stop = obs_space_range.stop
    for index in obs_space_range:
        match = FILTER_RE.match(lines[index])
        if not match or lines[index].lstrip().startswith("#"):
            continue
        entry_indent = len(match.group(1))
        end = stop
        for candidate in range(index + 1, stop):
            line = lines[candidate]
            if line.strip() and not line.lstrip().startswith("#") and _indent(line) <= entry_indent:
                end = candidate
                break
        yield index, range(index, end), entry_indent, match.group(2).strip()


def _identifier_name(lines: list[str], block: range, entry_indent: int) -> tuple[str | None, int | None]:
    identifier_indent = entry_indent + 2
    name_indent = identifier_indent + 2
    for index in block:
        if _key_at_indent(lines[index], identifier_indent) != "identifier":
            continue
        for child in range(index + 1, block.stop):
            line = lines[child]
            if line.strip() and not line.lstrip().startswith("#") and _indent(line) <= identifier_indent:
                break
            if _key_at_indent(line, name_indent) == "name":
                return _value_after_key(line, "name"), child
        return None, index
    return None, None


def _check_obs_name(filepath: str, line_no: int, name: str, source: str) -> Violation | None:
    is_special_name = name in SPECIAL_OBS_NAMES
    is_conventional_name = CONVENTIONAL_OBS_NAME_RE.fullmatch(name)
    is_sis_name = SIS_OBS_NAME_RE.fullmatch(name)
    valid = is_special_name or is_conventional_name or is_sis_name
    if valid:
        return None
    return Violation(
        filepath, line_no, "YAML001",
        "Obs-space name must follow platform_variable### naming (including documented SIS/special forms).",
        source,
    )


def lint_lines(filepath: str, lines: list[str]) -> list[Violation]:
    violations: list[Violation] = []

    for obs_index, obs_range, name_indent in _obs_spaces(lines):
        obs_line_no = obs_index + 1
        obs_name = None
        obs_name_line = obs_index
        for index in range(obs_index + 1, obs_range.stop):
            if _key_at_indent(lines[index], name_indent) == "name":
                obs_name = _value_after_key(lines[index], "name")
                obs_name_line = index
                break
        if not obs_name:
            violations.append(Violation(
                filepath, obs_line_no, "YAML001", "Obs space must define a name.", lines[obs_index]
            ))
        else:
            name_violation = _check_obs_name(filepath, obs_name_line + 1, obs_name, lines[obs_name_line])
            if name_violation:
                violations.append(name_violation)

        filter_blocks = list(_filter_blocks(lines, obs_range))
        identifiers: dict[str, int] = {}
        if filter_blocks:
            first_index, first_block, first_indent, first_filter = filter_blocks[0]
            first_identifier, _ = _identifier_name(lines, first_block, first_indent)
            has_apply_at_iterations = any(
                _key_at_indent(lines[index], first_indent + 2) == "apply at iterations"
                for index in first_block
            )
            invalid_filter = first_filter != "AcceptList"
            invalid_identifier = first_identifier != "NewLoopReset"
            if invalid_filter or invalid_identifier or not has_apply_at_iterations:
                violations.append(Violation(
                    filepath, first_index + 1, "YAML002",
                    "The first filter must be AcceptList with apply at iterations and identifier NewLoopReset.",
                    lines[first_index],
                ))

        for filter_index, block, entry_indent, filter_name in filter_blocks:
            direct_keys = [(key, index) for index in block
                           if (key := _key_at_indent(lines[index], entry_indent + 2)) is not None]
            key_names = [key for key, _ in direct_keys]
            if "apply at iterations" in key_names and key_names.index("apply at iterations") != 0:
                violations.append(Violation(
                    filepath, direct_keys[key_names.index("apply at iterations")][1] + 1,
                    "YAML004", "apply at iterations must be the first key after - filter.",
                    lines[direct_keys[key_names.index("apply at iterations")][1]],
                ))

            identifier_pos = key_names.index("identifier") if "identifier" in key_names else None
            expected_identifier_pos = 1 if "apply at iterations" in key_names else 0
            if identifier_pos is None:
                violations.append(Violation(
                    filepath, filter_index + 1, "YAML003", "Every filter must have an identifier.name.",
                    lines[filter_index],
                ))
            elif identifier_pos != expected_identifier_pos:
                key_line = direct_keys[identifier_pos][1]
                violations.append(Violation(
                    filepath, key_line + 1, "YAML004",
                    "identifier must follow - filter and optional apply at iterations, before filter-specific keys.",
                    lines[key_line],
                ))

            identifier, identifier_line = _identifier_name(lines, block, entry_indent)
            if identifier_pos is not None and not identifier:
                violations.append(Violation(
                    filepath, direct_keys[identifier_pos][1] + 1, "YAML003",
                    "Every filter must have an identifier.name.", lines[direct_keys[identifier_pos][1]],
                ))
            elif identifier:
                if not IDENTIFIER_RE.fullmatch(identifier):
                    violations.append(Violation(
                        filepath, (identifier_line or filter_index) + 1, "YAML003",
                        "Filter identifier names must use CamelCase (a trailing underscore is allowed).",
                        lines[identifier_line or filter_index],
                    ))
                if identifier in identifiers:
                    violations.append(Violation(
                        filepath, (identifier_line or filter_index) + 1, "YAML003",
                        f"Filter identifier {identifier!r} is duplicated in this obs space.",
                        lines[identifier_line or filter_index],
                    ))
                identifiers[identifier] = filter_index

            terminal_positions = [
                index for index, key in enumerate(key_names) if key in TERMINAL_FILTER_KEYS
            ]
            has_action_block = any(key in {"action", "actions"} for key in key_names)
            is_perform_action_exception = filter_name == "Perform Action" and has_action_block
            last_terminal_position = max(terminal_positions, default=-1)
            terminal_block_is_last = last_terminal_position == len(key_names) - 1
            invalid_terminal_position = terminal_positions and not terminal_block_is_last
            if invalid_terminal_position and not is_perform_action_exception:
                terminal_line = direct_keys[terminal_positions[-1]][1]
                violations.append(Violation(
                    filepath, terminal_line + 1, "YAML004",
                    "The action, actions, or defer to post block must be last in the filter.",
                    lines[terminal_line],
                ))

    return violations


def find_yaml_files(paths: list[str]) -> list[Path]:
    files: set[Path] = set()
    for value in paths:
        path = Path(value)
        if path.is_file() and path.suffix.lower() in {".yaml", ".yml"}:
            files.add(path)
        elif path.is_dir():
            files.update(file for file in path.rglob("*")
                         if file.is_file() and file.suffix.lower() in {".yaml", ".yml"})
    return sorted(files)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check RRFS YAML Convention"
    )
    parser.add_argument("paths", nargs="*", default=["parm/observers"],
                        help="Observer YAML files or directories (default: parm/observers).")
    args = parser.parse_args()

    if hifiyaml is None:
        print("linter_rrfs_yaml_convention: install hifiyaml to run this linter.", file=sys.stderr)
        return 2

    files = find_yaml_files(args.paths)
    if not files:
        print("linter_rrfs_yaml_convention: no YAML files found.", file=sys.stderr)
        return 2

    violations: list[Violation] = []
    for filepath in files:
        try:
            lines = hifiyaml.load(str(filepath))
        except OSError as exc:
            print(f"linter_rrfs_yaml_convention: cannot read {filepath}: {exc}", file=sys.stderr)
            return 2
        violations.extend(lint_lines(str(filepath), lines))

    for violation in violations:
        print(f"{violation.filepath}:{violation.line_no}:1: error {violation.rule_id}: {violation.message}")
        print(f"  {violation.source_line}")
    print(f"RRFS YAML convention: {len(violations)} violation(s) in {len(files)} file(s).")
    return 1 if violations else 0


if __name__ == "__main__":
    raise SystemExit(main())
