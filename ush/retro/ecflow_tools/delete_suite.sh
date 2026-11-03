#!/bin/bash

set -euo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/suite_selection.sh"
retro_init_ecflow
# With no names, let the operator choose from loaded suites; arguments remain supported.
retro_select_suite_paths "$@"

echo "This will delete the selected ecFlow suite(s):"
printf '  %s\n' "${RETRO_SELECTED_PATHS[@]}"

# Disk cleanup is safe only when the selection is exactly the configured experiment pair.
clean=NO
clean_targets=()
if [ "${#RETRO_SELECTED_PATHS[@]}" -eq 2 ] && \
   [[ " ${RETRO_SELECTED_PATHS[*]} " == *" /${RRFS_SUITE} "* ]] && \
   [[ " ${RETRO_SELECTED_PATHS[*]} " == *" /${PRODCLONE_SUITE} "* ]]; then
    read -r -p "Clean configured output, ptmp, stmp, and suite job/log files? [y/N] " clean_answer
    case ${clean_answer,,} in
        y|yes) clean=YES ;;
        n|no|'') clean=NO ;;
        *) echo "Please answer y or n." >&2; exit 1 ;;
    esac

    if [ "${clean}" = YES ]; then
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
        for target in "${OUTPUTDIR}" "${DEV_PTMP}" "${DEV_DATAROOT}" \
                      "${ECF_HOME}/${RRFS_SUITE}" "${ECF_HOME}/${PRODCLONE_SUITE}"; do
            resolved=$(realpath -m -- "${target}")
            if [ "${resolved}" = "${base}" ] || [ "${resolved}" = "${server_home}" ] || \
               [ "${resolved}" = "${data_root}" ] || [ "${resolved}" = "${output_root}" ]; then
              echo "Refusing to clean a shared or experiment root: ${resolved}" >&2
              exit 1
            fi
            case ${resolved} in
                "${base}"/*) clean_targets+=("${resolved}") ;;
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
                    clean_targets+=("${resolved}")
                  else
                    echo "Refusing to clean outside the configured experiment directories: ${resolved}" >&2
                    exit 1
                  fi
                  ;;
            esac
        done
        echo "Will also clean these directories:"
        printf '  %s\n' "${clean_targets[@]}"
    fi
else
    echo "Disk cleanup is available only when selecting exactly the configured pair:"
    echo "  /${RRFS_SUITE} and /${PRODCLONE_SUITE}"
fi

read -r -p "Type DELETE to continue: " confirmation
if [ "${confirmation}" != "DELETE" ]; then
    echo "Deletion cancelled."
    exit 1
fi

set -x

ecflow_client --delete=force yes "${RETRO_SELECTED_PATHS[@]}"
echo "Deleted the selected suite(s); leaving the ecFlow server running for other experiments."
if [ "${clean}" = YES ]; then
    rm -rf -- "${clean_targets[@]}"
    echo "Cleaned the configured experiment directories."
fi
