#!/bin/bash

set -euo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/suite_selection.sh"
retro_init_ecflow
# With no names, let the operator choose from loaded suites; arguments remain supported.
retro_select_suite_paths "$@"
set -x

ecflow_client --resume  "${RETRO_SELECTED_PATHS[@]}"
ecflow_client --suspend "${RETRO_SELECTED_PATHS[@]}"
