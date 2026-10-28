#!/bin/bash

set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)
# Use the same ecFlow settings as the retro suite definitions.
# shellcheck source=/dev/null
. "${repo}/ecf/defs/retro/load_config.sh"

case ${MACHINE} in
  URSA)   default_port=$((1500 + $(id -u))) ;;
  WCOSS2) default_port=$((2000 + $(id -u))) ;;
  *) echo "MACHINE=${MACHINE} is not supported by this tool" >&2; exit 1 ;;
esac

# Preserve caller-selected connection settings before loading the ecFlow module.
host_requested=${ECF_HOST:-}
port_requested=${ECF_PORT:-}
if ! type module >/dev/null 2>&1; then source /etc/profile; fi
module load "ecflow/${ECFLOW_VER}"
export ECF_HOST=${host_requested:-${ECFLOW_HOST}}
export ECF_PORT=${port_requested:-${default_port}}

if ! ecflow_client --ping >/dev/null 2>&1; then
  echo "No ecFlow server answers on ${ECF_HOST}:${ECF_PORT}." >&2
  exit 1
fi

suites=$(ecflow_client --suites)
echo "This will halt and terminate the ecFlow server on ${ECF_HOST}:${ECF_PORT}."
echo "All suites currently loaded on that server will be affected:"
printf '  %s\n' "${suites}"
echo "Afterward, reload each experiment you want using its start_retro.sh --hold."
read -r -p "Type TERMINATE to continue: " confirmation
if [ "${confirmation}" != "TERMINATE" ]; then
  echo "Server termination cancelled."
  exit 1
fi

# Halt scheduling before terminating the server process.
ecflow_client --halt=yes
ecflow_client --terminate=yes
echo "Terminated ecFlow server on ${ECF_HOST}:${ECF_PORT}."
