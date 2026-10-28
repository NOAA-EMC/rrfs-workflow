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
  # The shared server may have been started from another experiment's ECF_HOME.
  # Prefer the configured directory, then search this retro work root for a unique checkpoint.
  checkpoint=${ECF_HOME}/${ECF_HOST}.${ECF_PORT}.ecf.check
  checkpoint_backup=${checkpoint}.b
  if [ ! -f "${checkpoint}" ] && [ ! -f "${checkpoint_backup}" ]; then
    checkpoint_files=()
    if [ -n "${RETRO_WORK_ROOT:-}" ]; then
      shopt -s nullglob
      checkpoint_files=(
        "${RETRO_WORK_ROOT}"/*/submit/"${ECF_HOST}.${ECF_PORT}.ecf.check"
        "${RETRO_WORK_ROOT}"/*/submit/"${ECF_HOST}.${ECF_PORT}.ecf.check".b
      )
      shopt -u nullglob
    fi

    checkpoint_dirs=()
    for candidate in "${checkpoint_files[@]}"; do
      candidate_dir=${candidate%/*}
      found=NO
      for existing_dir in "${checkpoint_dirs[@]}"; do
        if [ "${existing_dir}" = "${candidate_dir}" ]; then
          found=YES
          break
        fi
      done
      if [ "${found}" = NO ]; then
        checkpoint_dirs+=("${candidate_dir}")
      fi
    done

    if [ "${#checkpoint_dirs[@]}" -eq 1 ]; then
      ECF_HOME=${checkpoint_dirs[0]}
      checkpoint=${ECF_HOME}/${ECF_HOST}.${ECF_PORT}.ecf.check
      checkpoint_backup=${checkpoint}.b
      echo "Using server checkpoint directory found under RETRO_WORK_ROOT: ${ECF_HOME}"
    elif [ "${#checkpoint_dirs[@]}" -gt 1 ]; then
      echo "Multiple ecFlow checkpoint directories found for ${ECF_HOST}:${ECF_PORT}:" >&2
      printf '  %s\n' "${checkpoint_dirs[@]}" >&2
      echo "Set ECF_HOME to the server's checkpoint directory and retry." >&2
      exit 1
    else
      echo "No ecFlow checkpoint found for ${ECF_HOST}:${ECF_PORT}." >&2
      echo "Checked ${ECF_HOME} and searched ${RETRO_WORK_ROOT:-<unset>}; refusing to start an empty server." >&2
      exit 1
    fi
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
