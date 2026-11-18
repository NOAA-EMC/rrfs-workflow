#!/usr/bin/env python3
import argparse
import os
import re
import sys


def xtrace(msg):
    """Print an execution trace to stdout matching Bash 'set -x' style."""
    print(f"+ {msg}", flush=True)


# Central exemption registry: maps filenames to rules and 1-based line numbers
LINE_EXEMPTIONS = {
    "fix_rrfs_locations.sh": {
        "hardcoded_path": [8, 19],
    }
}


def is_line_skipped(filename, line_num, check_name, line_text):
    """
    Check if a standard check should be bypassed on a line via:
    1. Central LINE_EXEMPTIONS registry.
    2. Inline directives (e.g., # ci-skip: hardcoded-path, # ci-skip, # noqa).
    """
    norm_check = check_name.lower().replace("-", "_")

    # 1. Central registry lookup
    file_exemptions = LINE_EXEMPTIONS.get(filename, {})
    if line_num in file_exemptions.get(norm_check, []) or line_num in file_exemptions.get("all", []):
        return True, "file/line exemption registry"

    # 2. Inline comment directive lookup
    skip_match = re.search(
        r"#\s*(?:ci-skip|nco-ignore|noqa)(?::\s*([a-zA-Z0-9_-]+))?",
        line_text,
        re.IGNORECASE,
    )
    if skip_match:
        target_check = skip_match.group(1)
        if not target_check:
            return True, "inline skip directive (all checks)"
        if target_check.lower().replace("-", "_") in (norm_check, "all"):
            return True, f"inline skip directive ({target_check})"

    return False, None


def parse_args():
    xtrace("parse_args: initializing ArgumentParser")
    parser = argparse.ArgumentParser(
        description="NCO Implementation Standard Linter"
    )
    parser.add_argument(
        "--file-list",
        help="Manifest of files selected by CI; mutually exclusive with explicit targets",
    )
    parser.add_argument(
        "targets", nargs="*", help="Specific file targets to scan"
    )
    args = parser.parse_args()
    if bool(args.file_list) == bool(args.targets):
        parser.error("provide exactly one of --file-list or explicit file targets")
    xtrace(
        f"parse_args: parsed arguments -> file_list={args.file_list}, "
        f"targets={args.targets}"
    )
    return args


def check_standards(files_to_scan):
    xtrace("check_standards: starting standards evaluation")
    failed = False

    launcher_exec_re = re.compile(
        r"(?:^|[;&|]\s*|\beval\s+|\btime\s+|\bexec\s*)"
        r"(?:(?:export|local|readonly)\s+)?"
        r"(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)*"
        r"("
        r"\$\{APRUN\}|\$APRUN\b|\baprun\b|"
        r"\$\{launcher\}|\$launcher\b|\blauncher\b|"
        r"\$\{LAUNCHER\}|\$LAUNCHER\b|\bLAUNCHER\b|"
        r"\$\{mpiexec\}|\$mpiexec\b|\bmpiexec\b|"
        r"\$\{MPIEXEC\}|\$MPIEXEC\b|\bMPIEXEC\b"
        r")"
        r"(?:\s+|$)"
    )
    err_chk_re = re.compile(
        r"(?:export\s+)?err=\$?\?\s*(?:;|\n|$)\s*err_chk\b"
    )

    xtrace(f"check_standards: scanning {len(files_to_scan)} candidate file(s)")
    for path in files_to_scan:
        norm_path = path[2:] if path.startswith("./") else path

        xtrace(f"check_standards: inspect_file '{path}'")
        filename = os.path.basename(path)
        path_parts = norm_path.split("/")

        is_job = "jobs" in path_parts
        is_script = "scripts" in path_parts
        is_ush = "ush" in path_parts

        if is_job:
            xtrace(f"check_standards: checking job script naming -> {filename}")
            stem, _ = os.path.splitext(filename)
            if not stem.isupper():
                print(f"FAIL: Job script stem not uppercase: {filename} in {path}")
                failed = True

        if is_script:
            xtrace(f"check_standards: checking ex-script naming -> {filename}")
            if not filename.startswith("ex") or not filename.islower():
                print(
                    f"FAIL: ex-script does not start with 'ex' or is not lowercase: "
                    f"{filename} in {path}"
                )
                failed = True

        try:
            with open(path, "r", errors="ignore") as fp:
                lines = fp.readlines()
            xtrace(f"check_standards: reading {len(lines)} lines from {path}")
        except OSError as e:
            print(f"FAIL: Unable to read listed file '{path}': {e}")
            failed = True
            continue

        content = "".join(lines)
        total_lines = len(lines)

        for idx, line in enumerate(lines):
            line_num = idx + 1

            # Shebang verification (must be line 1)
            if idx == 0 and not line.startswith("#!"):
                skipped, reason = is_line_skipped(filename, line_num, "shebang", line)
                if skipped:
                    xtrace(f"[{filename}] step: line {line_num} skipped for shebang ({reason})")
                else:
                    print(
                        f"FAIL: Missing interpreter shebang (#!/...) at top of interpreted "
                        f"script in {path}:{line_num}"
                    )
                    failed = True

            # Trailing whitespace check
            # line.rstrip('\r\n') removes the newline character(s) so $ accurately anchors to the visual end of the line
            if re.search(r"[ \t]+$", line.rstrip('\r\n')):
                skipped, reason = is_line_skipped(filename, line_num, "trailing_whitespace", line)
                if skipped:
                    xtrace(f"[{filename}] step: line {line_num} skipped for trailing_whitespace ({reason})")
                else:
                    print(f"FAIL: Trailing whitespace found in {path}:{line_num}")
                    failed = True

            stripped_line = line.strip()
            if not stripped_line or stripped_line.startswith("#"):
                continue

            # /dev/null redirection check
            if re.search(r">(?:&|\d)?\s*/dev/null", line):
                skipped, reason = is_line_skipped(filename, line_num, "dev_null", line)
                if skipped:
                    xtrace(f"[{filename}] step: line {line_num} skipped for dev_null ({reason})")
                else:
                    print(f"FAIL: '> /dev/null' found in {path}:{line_num}")
                    failed = True

            # Hardcoded scratch/cluster paths check
            if re.search(r'=(?:["\']?)/(?:lfs|gpfs|scratch|work)/', line) or re.search(r"(=/lfs/|=/gpfs/|=/scratch/|=/work/)", line):
                skipped, reason = is_line_skipped(filename, line_num, "hardcoded_path", line)
                if skipped:
                    xtrace(f"[{filename}] step: line {line_num} skipped for hardcoded_path ({reason})")
                else:
                    print(f"FAIL: Hardcoded path in {path}:{line_num}")
                    failed = True

            # DCOM check
            if re.search(r">\s*\$?DCOM", line) or ("DCOM" in line and ">" in line):
                skipped, reason = is_line_skipped(filename, line_num, "dcom", line)
                if skipped:
                    xtrace(f"[{filename}] step: line {line_num} skipped for dcom ({reason})")
                else:
                    print(f"FAIL: Output written to DCOM in {path}:{line_num}")
                    failed = True

            # RUN_ENVIR check
            if "RUN_ENVIR" in line:
                skipped, reason = is_line_skipped(filename, line_num, "run_envir", line)
                if skipped:
                    xtrace(f"[{filename}] step: line {line_num} skipped for run_envir ({reason})")
                else:
                    print(f"FAIL: Reference to RUN_ENVIR found in {path}:{line_num}")
                    failed = True

            # rm -rf $DATA safety check
            if re.search(r"rm\s+-r[f]*\s+\$DATA", line) or re.search(r"rm\s+-f[r]*\s+\$DATA", line):
                skipped, reason = is_line_skipped(filename, line_num, "rm_data", line)
                if skipped:
                    xtrace(f"[{filename}] step: line {line_num} skipped for rm_data ({reason})")
                else:
                    if not is_job:
                        print(f"FAIL: rm -rf $DATA found outside j-job in {path}:{line_num}")
                        failed = True
                    else:
                        if "KEEPDATA" not in content:
                            print(f"FAIL: rm -rf $DATA used without KEEPDATA check in {path}")
                            failed = True

            # Launcher exception handling (${APRUN}, ${launcher}, $mpiexec)
            code_line = line.split("#")[0].strip()
            if (
                code_line
                and not re.match(r"^(?:echo|printf)\b", code_line)
                and not re.match(r"^(?:if\s+|elif\s+|while\s+|until\s+)?\[{1,2}.*\]{1,2}", code_line)
                and not re.match(
                    r"^(?:export\s+|local\s+|readonly\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=\s*"
                    r'(?:["\'][^"\']*["\']|[^\s;]+)\s*$',
                    code_line,
                )
            ):
                match = launcher_exec_re.search(code_line)
                if match:
                    token = match.group(1)

                    curr = idx
                    while curr < total_lines and lines[curr].rstrip().endswith("\\"):
                        curr += 1

                    has_err_chk = False
                    same_line_code = lines[curr].split("#")[0]
                    if err_chk_re.search(same_line_code):
                        has_err_chk = True
                    else:
                        nxt = curr + 1
                        collected = []
                        while nxt < total_lines:
                            c = lines[nxt].split("#")[0].strip()
                            if not c or c.startswith("#"):
                                nxt += 1
                                continue
                            collected.append(c)
                            if lines[nxt].rstrip().endswith("\\"):
                                nxt += 1
                                continue

                            combined = "\n".join(collected)
                            if err_chk_re.search(combined):
                                has_err_chk = True
                                break

                            if any(collected[0].startswith(p) for p in ["export err=$?", "err=$?"]):
                                nxt_chk = nxt + 1
                                while nxt_chk < total_lines:
                                    c2 = lines[nxt_chk].split("#")[0].strip()
                                    if not c2 or c2.startswith("#"):
                                        nxt_chk += 1
                                        continue
                                    if re.match(r"^err_chk\b", c2):
                                        has_err_chk = True
                                    break
                            break

                    if not has_err_chk:
                        skipped, reason = is_line_skipped(filename, line_num, "launcher_trap", line)
                        if skipped:
                            xtrace(f"[{filename}] step: line {line_num} skipped for launcher_trap ({reason})")
                        else:
                            print(
                                f"FAIL: {token} missing 'export err=$?; err_chk' "
                                f"handling in {path}:{line_num}"
                            )
                            failed = True

            # j-job reserved variables check
            if is_script or is_ush:
                if re.search(r"export\s+(HOME[a-zA-Z0-9_]+|pid|outid|COM(?!PRESS)[a-zA-Z0-9_]*|DATAROOT)=", line):
                    skipped, reason = is_line_skipped(filename, line_num, "reserved_variable", line)
                    if skipped:
                        xtrace(f"[{filename}] step: line {line_num} skipped for reserved_variable ({reason})")
                    else:
                        print(f"FAIL: j-job reserved variable exported in {path}:{line_num}")
                        failed = True

            # Naked exit() check in Python scripts
            if path.endswith(".py"):
                if re.search(r"^\s*exit\(", line):
                    skipped, reason = is_line_skipped(filename, line_num, "naked_exit", line)
                    if skipped:
                        xtrace(f"[{filename}] step: line {line_num} skipped for naked_exit ({reason})")
                    else:
                        print(
                            f"FAIL: Naked exit() found in Python script (use sys.exit instead) "
                            f"in {path}:{line_num}"
                        )
                        failed = True

    xtrace(f"check_standards: completed scan; failed={failed}")
    return failed


def main():
    xtrace("main: starting linter execution")
    args = parse_args()
    if args.file_list:
        xtrace(f"main: loading CI-selected targets from manifest '{args.file_list}'")
        try:
            with open(args.file_list, "r", encoding="utf-8", errors="strict") as manifest:
                files_to_scan = [
                    line.strip()
                    for line in manifest
                    if line.strip() and not line.lstrip().startswith("#")
                ]
        except OSError as e:
            print(f"FAIL: Unable to read file manifest '{args.file_list}': {e}")
            sys.exit(1)
    else:
        files_to_scan = args.targets

    if not files_to_scan:
        print("FAIL: No target files were provided.")
        sys.exit(1)

    xtrace(f"main: scanning {len(files_to_scan)} file(s): {files_to_scan}") 
    failed = check_standards(files_to_scan)

    if not failed:
        print("No implementation standard violations found.")

    xtrace(f"main: exiting with status code {1 if failed else 0}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()