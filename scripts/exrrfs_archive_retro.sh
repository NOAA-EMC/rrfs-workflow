#!/bin/bash
set -x

#-----------------------------------------------------------------------
# Source the workflow settings and utility functions
#-----------------------------------------------------------------------
source "${FIXrrfs}/workflow/det/workflow.conf"
. "${USHrrfs}/source_util_funcs.sh"

#-----------------------------------------------------------------------
# Get the full path to this script for the log messages
#-----------------------------------------------------------------------
scrfunc_fp=$(readlink -f "${BASH_SOURCE[0]}")
scrfunc_fn=$(basename "${scrfunc_fp}")
scrfunc_dir=$(dirname "${scrfunc_fp}")

print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This ex-script archives one completed deterministic cycle to HPSS.
========================================================================"

# The archive path mirrors the Rocoto retro: one tar per date and cycle,
# containing the cycle directory beneath COMrrfs/rrfs.PDY.
: "${ARCHIVEDIR:?ARCHIVEDIR must be set by the retro suite}"
: "${COMrrfs:?COMrrfs must identify the RRFS COM root}"
: "${PDY:?PDY must be set by the suite}"
: "${cyc:?cyc must be set by the ecFlow task}"

cycle_root="${COMrrfs}/rrfs.${PDY}"
if [ ! -d "${cycle_root}/${cyc}" ]; then
  # A retro definition can complete a cycle family even when its forecast task
  # was never run. Skip that archive only when ecFlow confirms try number zero.
  forecast_dir="${ECF_NAME%/archive/jrrfs_archive_retro}/det/forecast"
  forecast_query_ok=NO
  forecast_attempted=NO
  forecast_query_error=""

  for forecast_name in jrrfs_det_forecast jrrfs_det_forecast_long; do
    forecast_task="${forecast_dir}/${forecast_name}"
    if forecast_output=$(ecflow_client --query variable "${forecast_task}:ECF_TRYNO" 2>&1); then
      try_no=$(printf '%s\n' "${forecast_output}" | sed -nE \
        's/.*ECF_TRYNO[^=]*=[[:space:]]*([0-9]+).*/\1/p' | tail -1)
      # Some ecFlow client versions return only the queried value.
      if [ -z "${try_no}" ]; then
        try_no=$(printf '%s\n' "${forecast_output}" | sed -nE \
          's/^[[:space:]]*([0-9]+)[[:space:]]*$/\1/p' | tail -1)
      fi
      if [[ "${try_no}" =~ ^[0-9]+$ ]]; then
        forecast_query_ok=YES
        if [ "${try_no}" -gt 0 ]; then
          forecast_attempted=YES
        fi
      else
        forecast_query_error="Could not parse ECF_TRYNO for ${forecast_task}: ${forecast_output}"
      fi
    else
      forecast_query_error="Could not query ${forecast_task}: ${forecast_output}"
    fi
  done

  if [ "${forecast_query_ok}" != YES ]; then
    err_exit "Cycle COM directory is missing and forecast execution could not be verified: ${cycle_root}/${cyc}. ${forecast_query_error}"
  fi
  if [ "${forecast_attempted}" = YES ]; then
    err_exit "Cycle COM directory is missing although a forecast task was attempted: ${cycle_root}/${cyc}"
  fi

  print_info_msg "Skipping retro archive for ${PDY} ${cyc}z: no matching forecast task has run and the cycle COM directory is absent."
  exit 0
fi

hsi "mkdir -p ${ARCHIVEDIR%/}/rrfs.${PDY}"
export err=$?; err_chk

cd "${cycle_root}"
htar -cvf "${ARCHIVEDIR%/}/rrfs.${PDY}/${cyc}.tar" "${cyc}" >>"${pgmout}"
export err=$?; err_chk

print_info_msg "
========================================================================
ARCHIVE PROCESS completed successfully for ${PDY} ${cyc}z.

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
