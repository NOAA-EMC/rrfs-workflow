#!/bin/bash

set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)
# Use the same suite name and retro settings as the definition generator.
# shellcheck source=/dev/null
. "${repo}/ecf/defs/retro/load_config.sh"

echo "This will reset /${RRFS_SUITE} and /${PRODCLONE_SUITE} and discard their current ecFlow state."
echo "/${RRFS_SUITE} will be reloaded suspended for inspection; /${PRODCLONE_SUITE} will begin."
echo "Any active ecFlow tasks may be interrupted."
read -r -p "Type RESTART to continue: " confirmation
if [ "${confirmation}" != "RESTART" ]; then
  echo "Restart cancelled."
  exit 1
fi

read -r -p "Clean configured OUTPUTDIR, DEV_PTMP, and DEV_DATAROOT? [y/N] " clean_answer
case ${clean_answer,,} in
  y|yes) clean=YES ;;
  n|no|'') clean=NO ;;
  *) echo "Please answer y or n." >&2; exit 1 ;;
esac

if [ "${clean}" = "NO" ]; then
  exec "${repo}/ush/retro/start_retro.sh" --reload --hold
fi

# Resolve and constrain cleanup targets so a bad config cannot remove RETRO_WORK_BASE or its parent.
base=$(realpath -m -- "${RETRO_WORK_BASE}")
targets=()
for target in "${OUTPUTDIR}" "${DEV_PTMP}" "${DEV_DATAROOT}"; do
  resolved=$(realpath -m -- "${target}")
  case ${resolved} in
    "${base}"/*) targets+=("${resolved}") ;;
    *) echo "Refusing to clean path outside RETRO_WORK_BASE: ${resolved}" >&2; exit 1 ;;
  esac
done
if [ "${base}" = "/" ] || [ -z "${base}" ]; then
  echo "Refusing to clean with unsafe RETRO_WORK_BASE: ${base}" >&2
  exit 1
fi
echo "Will clean these directories:"
for target in "${targets[@]}"; do echo "  ${target}"; done

# Load ecFlow before removing the data directories, so loaded suites can be deleted first.
case ${MACHINE} in
  URSA)   default_port=$((1500 + $(id -u))) ;;
  WCOSS2) default_port=$((2000 + $(id -u))) ;;
  *) echo "MACHINE=${MACHINE} is not supported; restart_wx.sh runs on URSA and WCOSS2" >&2; exit 1 ;;
esac
port_requested=${ECF_PORT:-}
if ! type module >/dev/null 2>&1; then source /etc/profile; fi
module load "ecflow/${ECFLOW_VER}" >/dev/null 2>&1
export ECF_HOST=${ECFLOW_HOST}
export ECF_PORT=${port_requested:-${default_port}}

if ecflow_client --ping >/dev/null 2>&1; then
  for suite in "${RRFS_SUITE}" "${PRODCLONE_SUITE}"; do
    if ecflow_client --get_state "/${suite}" >/dev/null 2>&1; then
      ecflow_client --delete=force yes "/${suite}"
    fi
  done
fi

# Remove data only after deleting loaded suites, then let start_retro rebuild links and definitions.
rm -rf -- "${targets[@]}"
exec "${repo}/ush/retro/start_retro.sh" --hold
