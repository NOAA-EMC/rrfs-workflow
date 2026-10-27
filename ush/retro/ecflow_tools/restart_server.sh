#!/bin/bash

set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)
# Use the same ecFlow settings as the retro suite definitions.
# shellcheck source=/dev/null
. "${repo}/ecf/defs/retro/load_config.sh"

for arg in "$@"; do
  case ${arg} in
    -h|--help)
      echo "Usage: ${BASH_SOURCE[0]}"
      echo "Start the configured ecFlow server from its saved checkpoint; scheduling stays halted."
      exit 0
      ;;
    *) echo "unknown option: ${arg} (try --help)" >&2; exit 1 ;;
  esac
done

case ${MACHINE} in
  URSA)   default_port=$((1500 + $(id -u))) ;;
  WCOSS2) default_port=$((2000 + $(id -u))) ;;
  *) echo "MACHINE=${MACHINE} is not supported by this tool" >&2; exit 1 ;;
esac

# Preserve caller-selected connection settings before loading the ecFlow module.
host_requested=${ECF_HOST:-}
port_requested=${ECF_PORT:-}
if ! type module >/dev/null 2>&1; then source /etc/profile; fi
module load "ecflow/${ECFLOW_VER}" || {
  echo "Cannot load ecflow/${ECFLOW_VER}." >&2
  exit 1
}
export ECF_HOST=${host_requested:-${ECFLOW_HOST}}
export ECF_PORT=${port_requested:-${default_port}}

if ! ecflow_client --ping >/dev/null 2>&1; then
  if [ ! -d "${ECF_HOME}" ]; then
    echo "ECF_HOME does not exist: ${ECF_HOME}" >&2
    exit 1
  fi

  # Require a checkpoint so a typo in ECF_HOME cannot start a blank server.
  checkpoint=${ECF_HOME}/${ECF_HOST}.${ECF_PORT}.ecf.check
  checkpoint_backup=${checkpoint}.b
  if [ ! -f "${checkpoint}" ] && [ ! -f "${checkpoint_backup}" ]; then
    echo "No ecFlow checkpoint found for ${ECF_HOST}:${ECF_PORT} in ${ECF_HOME}." >&2
    echo "Expected ${checkpoint} or ${checkpoint_backup}; refusing to start an empty server." >&2
    exit 1
  fi

  echo "Starting ecFlow server on ${ECF_HOST}:${ECF_PORT} from ${ECF_HOME}."
  # Start on the server host from its original ECF_HOME so ecFlow can recover the checkpoint.
  timeout 60 ssh -n -o BatchMode=yes "${ECF_HOST}" \
    "bash -lc 'module load ecflow/${ECFLOW_VER} >/dev/null 2>&1 && cd ${ECF_HOME} && setsid -f nohup ecflow_server --port ${ECF_PORT} >> ${ECF_HOME}/ecflow_server.out 2>&1 < /dev/null'" \
    || echo "(ssh returned $?; checking whether the server came up anyway)"

  for _ in $(seq 1 30); do
    ecflow_client --ping >/dev/null 2>&1 && break
    sleep 2
  done
fi

if ! ecflow_client --ping >/dev/null 2>&1; then
  echo "No ecFlow server answers on ${ECF_HOST}:${ECF_PORT}." >&2
  echo "Server log: ${ECF_HOME}/ecflow_server.out" >&2
  if [ -f "${ECF_HOME}/ecflow_server.out" ]; then
    tail -40 "${ECF_HOME}/ecflow_server.out" >&2
  fi
  exit 1
fi

echo "ecFlow server is responding on ${ECF_HOST}:${ECF_PORT}."
echo "Loaded suites:"
ecflow_client --suites
echo "Scheduling was not restarted. Inspect suite state, then run ecflow_client --restart when ready."
