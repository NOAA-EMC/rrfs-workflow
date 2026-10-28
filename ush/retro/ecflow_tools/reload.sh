#!/bin/bash

set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)
# Load the same host, port, suite, and machine settings used to create the retro.
. "${repo}/ecf/defs/retro/load_config.sh"

case ${MACHINE} in
  URSA)   default_port=$((1500 + $(id -u))) ;;
  WCOSS2) default_port=$((2000 + $(id -u))) ;;
  *) echo "MACHINE=${MACHINE} is not supported; reload runs on URSA and WCOSS2" >&2; exit 1 ;;
esac

# Preserve a caller-selected port before loading ecFlow, which can set its own default.
port_requested=${ECF_PORT:-}
if ! type module >/dev/null 2>&1; then source /etc/profile; fi
module load "ecflow/${ECFLOW_VER}"
export ECF_HOST=${ECFLOW_HOST}
export ECF_PORT=${port_requested:-${default_port}}

suite_path="/${RRFS_SUITE}"
generated_def=
cleanup() {
  if [ -n "${generated_def}" ]; then rm -f "${generated_def}"; fi
}
trap cleanup EXIT

if ! ecflow_client --ping >/dev/null 2>&1; then
  echo "No ecFlow server answers on ${ECF_HOST}:${ECF_PORT}." >&2
  exit 1
fi
if ! ecflow_client --get_state="${suite_path}" >/dev/null 2>&1; then
  echo "Suite ${suite_path} is not loaded on ${ECF_HOST}:${ECF_PORT}." >&2
  exit 1
fi
if [ ! -d "${ECF_HOME}" ]; then
  echo "ECF_HOME does not exist: ${ECF_HOME}" >&2
  exit 1
fi

# Keep the generated definition outside the repository; only ecFlow's in-memory suite is replaced.
generated_def=$(mktemp "${ECF_HOME}/rrfs_retro.reload.XXXXXX")
echo "Generating retro definition: ${generated_def}"
"${repo}/ecf/defs/retro/make_rrfs_retro_def.sh" "${generated_def}"

# Pause submissions before replacement and keep the suite paused for inspection afterward.
ecflow_client --suspend "${suite_path}"
if ! ecflow_client --replace="${suite_path}" "${generated_def}"; then
  echo "Replacement failed. ${suite_path} remains suspended; no force replacement was attempted." >&2
  echo "Resume it to drain queued, active, or submitted tasks, suspend it again, then rerun reload.sh." >&2
  exit 1
fi

echo "Updated ${suite_path}; it remains suspended. Inspect it, then resume it with:"
echo "  ${repo}/ush/retro/ecflow_tools/resume.sh ${RRFS_SUITE}"
