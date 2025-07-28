#!/usr/bin/env bash
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# shellcheck disable=SC1091
source "${run_dir}/detect_machine.sh"
source "${run_dir}/linter_get_EXEC_DIR.sh"

# ${EXEC_DIR}/shellcheck --color=always "$@"
"${EXEC_DIR}/shellcheck" "$@"
