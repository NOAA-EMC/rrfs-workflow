#!/usr/bin/env bash
# shellcheck disable=SC1091
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${run_dir}/detect_machine.sh"
source "${run_dir}/linter_get_EXEC_DIR.sh"

"${EXEC_DIR}/autopep8" --max-line-length 300 --in-place --recursive "$@"
