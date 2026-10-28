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
        for target in "${OUTPUTDIR}" "${DEV_PTMP}" "${DEV_DATAROOT}" \
                      "${ECF_HOME}/${RRFS_SUITE}" "${ECF_HOME}/${PRODCLONE_SUITE}"; do
            resolved=$(realpath -m -- "${target}")
            case ${resolved} in
                "${base}"/*) clean_targets+=("${resolved}") ;;
                *) echo "Refusing to clean path outside RETRO_WORK_BASE: ${resolved}" >&2; exit 1 ;;
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
