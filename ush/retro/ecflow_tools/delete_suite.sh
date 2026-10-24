#!/bin/bash

set -euo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/suite_selection.sh"
retro_init_ecflow
# With no names, let the operator choose from loaded suites; arguments remain supported.
retro_select_suite_paths "$@"

echo "This will delete the selected ecFlow suite(s):"
printf '  %s\n' "${RETRO_SELECTED_PATHS[@]}"
read -r -p "Type DELETE to continue: " confirmation
if [ "${confirmation}" != "DELETE" ]; then
    echo "Deletion cancelled."
    exit 1
fi

set -x

ecflow_client --delete=force yes "${RETRO_SELECTED_PATHS[@]}"
echo "Deleted the selected suite(s); leaving the ecFlow server running for other experiments."
