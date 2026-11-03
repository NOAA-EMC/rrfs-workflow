#!/bin/bash

set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)
workaround=NO
for arg in "$@"; do
  case ${arg} in
    --workaround) workaround=YES ;;
    -h|--help) echo "Usage: ${BASH_SOURCE[0]} [--workaround]"; exit 0 ;;
    *) echo "unknown option: ${arg} (try --help)" >&2; exit 1 ;;
  esac
done
# Use the same suite name and retro settings as the definition generator.
# shellcheck source=/dev/null
. "${repo}/ecf/defs/retro/load_config.sh"

echo "This will reset /${RRFS_SUITE} and /${PRODCLONE_SUITE} and discard their current ecFlow state."
echo "/${RRFS_SUITE} will be reloaded suspended for inspection; /${PRODCLONE_SUITE} will begin."
echo "Any active ecFlow tasks may be interrupted."
if [ "${workaround}" = YES ]; then
  echo "The GSI workaround files will be copied into the suite fix tree."
fi
read -r -p "Type RESTART to continue: " confirmation
if [ "${confirmation}" != "RESTART" ]; then
  echo "Restart cancelled."
  exit 1
fi

read -r -p "Clean OUTPUTDIR, DEV_PTMP, DEV_DATAROOT, and suite job/log files? [y/N] " clean_answer
case ${clean_answer,,} in
  y|yes) clean=YES ;;
  n|no|'') clean=NO ;;
  *) echo "Please answer y or n." >&2; exit 1 ;;
esac

if [ "${clean}" = "NO" ]; then
  if [ "${workaround}" = YES ]; then
    exec "${repo}/ush/retro/start_retro.sh" --reload --hold --workaround
  fi
  exec "${repo}/ush/retro/start_retro.sh" --reload --hold
fi

# Resolve and constrain cleanup targets so a bad config cannot remove RETRO_WORK_BASE or its parent.
base=$(realpath -m -- "${RETRO_WORK_BASE}")
if [ "${base}" = "/" ] || [ -z "${base}" ]; then
  echo "Refusing to clean with unsafe RETRO_WORK_BASE: ${base}" >&2
  exit 1
fi
# WCOSS2 keeps each experiment's working files on a separate stmp filesystem.
# Allow only that experiment's child directory, never the shared stmp root.
stmp_target=
if [ "${MACHINE}" = WCOSS2 ] && [ -n "${RETRO_STMP_ROOT:-}" ] && [ -n "${EXPT_ID:-}" ]; then
  case ${EXPT_ID} in
    .|..|*/*) echo "Refusing to clean with unsafe EXPT_ID: ${EXPT_ID}" >&2; exit 1 ;;
  esac
  stmp_root=$(realpath -m -- "${RETRO_STMP_ROOT}")
  if [ "${stmp_root}" = / ]; then
    echo "Refusing to clean with unsafe RETRO_STMP_ROOT: ${stmp_root}" >&2
    exit 1
  fi
  stmp_target=${stmp_root}/${EXPT_ID}
fi
# Shared noscrub storage permits only the selected suites and this experiment's output.
# Resolve parents but not child names, so a child symlink cannot redirect cleanup elsewhere.
persistent_targets=()
server_home=$(realpath -m -- "${ECF_HOME}")
data_root=
output_root=
if [ "${MACHINE}" = WCOSS2 ] && [ -n "${ECF_DATA_ROOT:-}" ]; then
  data_root=$(realpath -m -- "${ECF_DATA_ROOT}")
  output_root=$(realpath -m -- "${ECF_OUTPUTDIR:-${data_root}/output}")
  if [ "${data_root}" = / ]; then
    echo "Refusing to clean with unsafe ECF_DATA_ROOT: ${data_root}" >&2
    exit 1
  fi
  for parent in "${server_home}" "${output_root}"; do
    case ${parent} in
      "${data_root}"/*) ;;
      *) echo "Refusing to clean outside the persistent ecFlow workspace: ${parent}" >&2; exit 1 ;;
    esac
  done
  for child in "${RRFS_SUITE}" "${PRODCLONE_SUITE}" "${EXPT_ID:-}"; do
    case ${child} in
      ''|.|..|*/*) echo "Refusing to clean with unsafe experiment or suite name: ${child}" >&2; exit 1 ;;
    esac
  done
  persistent_targets=("${server_home}/${RRFS_SUITE}" "${server_home}/${PRODCLONE_SUITE}"
                      "${output_root}/${EXPT_ID}")
fi
targets=()
# Remove only the selected suites' generated job files and logs; keep ECF_HOME for the server.
for target in "${OUTPUTDIR}" "${DEV_PTMP}" "${DEV_DATAROOT}" \
             "${ECF_HOME}/${RRFS_SUITE}" "${ECF_HOME}/${PRODCLONE_SUITE}"; do
  resolved=$(realpath -m -- "${target}")
  if [ "${resolved}" = "${base}" ] || [ "${resolved}" = "${server_home}" ] || \
     [ "${resolved}" = "${data_root}" ] || [ "${resolved}" = "${output_root}" ]; then
    echo "Refusing to clean a shared or experiment root: ${resolved}" >&2
    exit 1
  fi
  case ${resolved} in
    "${base}"/*) targets+=("${resolved}") ;;
    *)
      # Allow only this experiment stmp directory or the exact selected persistent children.
      allowed=NO
      if [ -n "${stmp_target}" ] && [ "${target}" = "${DEV_DATAROOT}" ] && \
         [ "${resolved}" = "${stmp_target}" ]; then
        allowed=YES
      fi
      for persistent_target in "${persistent_targets[@]}"; do
        if [ "${resolved}" = "${persistent_target}" ]; then allowed=YES; fi
      done
      if [ "${allowed}" = YES ]; then
        targets+=("${resolved}")
      else
        echo "Refusing to clean outside the configured experiment directories: ${resolved}" >&2
        exit 1
      fi
      ;;
  esac
done
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
if [ "${workaround}" = YES ]; then
  exec "${repo}/ush/retro/start_retro.sh" --hold --workaround
fi
exec "${repo}/ush/retro/start_retro.sh" --hold
