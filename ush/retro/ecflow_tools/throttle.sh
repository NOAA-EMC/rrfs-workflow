#!/bin/bash
# Set how many cycles a RETRO_LAYOUT=chains retro runs at once (CYCLE_THROTTLE).
# The retro driver reads it on its next pass. Reloading the suites (start_retro.sh --reload)
# restores the value from retro/config.sh.
#
# With no suite names, choose from loaded suites. If a selected suite has a production clone,
# the throttle is changed on that runnable clone.
#
# Usage: throttle.sh [SUITE ...]

set -euo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/suite_selection.sh"
retro_init_ecflow

# With no names, let the operator choose from loaded suites; arguments remain supported.
retro_select_suite_paths "$@"

# Map each selected retro suite to its runnable production clone. The selector returns both paths
# for interactive selections, while explicit suite arguments may contain only the retro suite.
target_paths=()
for selected_path in "${RETRO_SELECTED_PATHS[@]}"; do
  suite_name=${selected_path#/}
  case ${suite_name} in
    prod_clone|*_prod_clone)
      target_path="/${suite_name}"
      ;;
    *)
      pair=$(retro_pair_for_suite "${suite_name}")
      if [ -n "${pair}" ]; then
        target_path="/${pair}"
      else
        target_path=${selected_path}
      fi
      ;;
  esac

  if [[ " ${target_paths[*]} " != *" ${target_path} "* ]]; then
    target_paths+=("${target_path}")
  fi
done

echo "CYCLE_THROTTLE will be set on:"
printf '  %s\n' "${target_paths[@]}"

while true; do
  if ! read -r -p "How many cycles should run at once? " throttle; then
    echo "No throttle entered; leaving the suites unchanged." >&2
    exit 1
  fi
  if [[ "${throttle}" =~ ^[1-9][0-9]*$ ]]; then
    break
  fi
  echo "Enter a positive whole number." >&2
done

for target_path in "${target_paths[@]}"; do
  ecflow_client --alter change variable CYCLE_THROTTLE "${throttle}" "${target_path}"
  echo "CYCLE_THROTTLE set to ${throttle} on ${target_path}"
done
