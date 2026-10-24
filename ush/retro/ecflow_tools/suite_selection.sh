#!/bin/bash
# Shared server discovery and selection for retro suite control tools.

retro_tools_dir=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
retro_repo=$(cd "${retro_tools_dir}/../../.." && pwd)
# shellcheck source=/dev/null
. "${retro_repo}/ecf/defs/retro/load_config.sh"

retro_init_ecflow() {
  local retro_suite_line retro_suite
  local -a retro_suite_items=()

  case ${MACHINE} in
    URSA)   retro_default_port=$((1500 + $(id -u))) ;;
    WCOSS2) retro_default_port=$((2000 + $(id -u))) ;;
    *) echo "MACHINE=${MACHINE} is not supported by the ecFlow tools" >&2; return 1 ;;
  esac

  retro_requested_host=${ECF_HOST:-}
  retro_requested_port=${ECF_PORT:-}
  if ! type module >/dev/null 2>&1; then source /etc/profile; fi
  module load "ecflow/${ECFLOW_VER}"
  export ECF_HOST=${retro_requested_host:-${ECFLOW_HOST}}
  export ECF_PORT=${retro_requested_port:-${retro_default_port}}

  if ! ecflow_client --ping >/dev/null 2>&1; then
    echo "No ecFlow server answers on ${ECF_HOST}:${ECF_PORT}." >&2
    return 1
  fi

  retro_loaded_suites=()
  retro_suite_output=$(ecflow_client --suites) || {
    echo "Could not list suites on ${ECF_HOST}:${ECF_PORT}." >&2
    return 1
  }
  # The suites response is text and can contain multiple suite names on one line.
  while IFS= read -r retro_suite_line; do
    read -r -a retro_suite_items <<< "${retro_suite_line}"
    for retro_suite in "${retro_suite_items[@]}"; do
      retro_suite=${retro_suite#/}
      retro_suite=${retro_suite%,}
      retro_suite=${retro_suite%/}
      if [ -n "${retro_suite}" ]; then
        retro_loaded_suites+=("${retro_suite}")
      fi
    done
  done <<< "${retro_suite_output}"
  if [ "${#retro_loaded_suites[@]}" -eq 0 ]; then
    echo "No suites are loaded on ${ECF_HOST}:${ECF_PORT}." >&2
    return 1
  fi
}

retro_suite_is_loaded() {
  local wanted=$1 loaded
  for loaded in "${retro_loaded_suites[@]}"; do
    [ "${loaded}" = "${wanted}" ] && return 0
  done
  return 1
}

retro_pair_for_suite() {
  local suite=$1 candidate
  if [ "${suite}" = "${RRFS_SUITE}" ] && retro_suite_is_loaded "${PRODCLONE_SUITE}"; then
    printf '%s' "${PRODCLONE_SUITE}"
    return 0
  fi
  if [ "${suite}" = "para" ] && retro_suite_is_loaded "prod_clone"; then
    printf '%s' "prod_clone"
    return 0
  fi
  candidate="${suite}_prod_clone"
  if retro_suite_is_loaded "${candidate}"; then
    printf '%s' "${candidate}"
  fi
}

retro_select_suite_paths() {
  local argument suite pair choice item index
  local -a candidates=() chosen=() selection_items=()
  RETRO_SELECTED_PATHS=()

  # Explicit suite names target only those suites; otherwise use the loaded server list.
  if [ "$#" -gt 0 ]; then
    for argument in "$@"; do
      # Add one leading slash while avoiding a duplicate for absolute paths.
      suite=${argument#/}
      if ! retro_suite_is_loaded "${suite}"; then
        echo "Suite /${suite} is not loaded on ${ECF_HOST}:${ECF_PORT}." >&2
        return 1
      fi
      RETRO_SELECTED_PATHS+=("/${suite}")
    done
    return 0
  fi

  for suite in "${retro_loaded_suites[@]}"; do
    case ${suite} in
      prod_clone|*_prod_clone) continue ;;
    esac
    candidates+=("${suite}")
  done
  if [ "${#candidates[@]}" -eq 0 ]; then
    echo "No RRFS suite choices were found among the loaded suites." >&2
    return 1
  fi

  echo "Loaded RRFS suites on ${ECF_HOST}:${ECF_PORT}:"
  for index in "${!candidates[@]}"; do
    suite=${candidates[index]}
    pair=$(retro_pair_for_suite "${suite}")
    if [ -n "${pair}" ]; then
      printf '  %d) /%s (+ /%s)\n' "$((index + 1))" "${suite}" "${pair}"
    else
      printf '  %d) /%s\n' "$((index + 1))" "${suite}"
    fi
  done
  read -r -p "Select suite number(s), comma separated, or 'a' for all: " choice
  choice=${choice//,/ }
  read -r -a selection_items <<< "${choice}"
  if [ "${choice}" = "a" ] || [ "${choice}" = "A" ]; then
    chosen=("${candidates[@]}")
  else
    for item in "${selection_items[@]}"; do
      case ${item} in
        ''|*[!0-9]*) echo "Invalid suite selection: ${item}" >&2; return 1 ;;
      esac
      index=$((item - 1))
      if [ "${index}" -lt 0 ] || [ "${index}" -ge "${#candidates[@]}" ]; then
        echo "Selection is out of range: ${item}" >&2
        return 1
      fi
      chosen+=("${candidates[index]}")
    done
  fi
  if [ "${#chosen[@]}" -eq 0 ]; then
    echo "No suites selected." >&2
    return 1
  fi

  for suite in "${chosen[@]}"; do
    RETRO_SELECTED_PATHS+=("/${suite}")
    pair=$(retro_pair_for_suite "${suite}")
    if [ -n "${pair}" ]; then
      RETRO_SELECTED_PATHS+=("/${pair}")
    fi
  done
}
