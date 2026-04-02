#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1
mpasout_interval=${MPASOUT_INTERVAL:-1}
cyc_interval=${CYC_INTERVAL:-1}
#
CDATEp=$( ${NDATE}  "${cyc_interval}"  "${CDATE}" )
timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
#
export CMDFILE="${DATA}/poescript_savefcst"
mkdir -p "$(dirname "$CMDFILE")"
: > "$CMDFILE"

# Populate the list for the ensemble members, or deterministic member
if [[ "${ENS_SIZE:-0}" -gt 2 ]]; then
  mapfile -t mem_list < <(printf "/mem%03d\n" $(seq 1 "$ENS_SIZE"))
else
  mem_list=("/") # if determinitic
fi

for memdir in "${mem_list[@]}"; do
  # Determine path
  if [[ ${#memdir} -gt 1 ]]; then
    comoutdir=${COMOUT}/fcst/${WGF}${memdir}
    mpasout_file=${UMBRELLA_FCST_DATA}${memdir}/mpasout.${timestr}.nc
  else
    comoutdir=${COMOUT}/fcst/${WGF}
    mpasout_file=${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc
  fi

  mkdir -p "$comoutdir"

#
# save to com
if [[ "${mpasout_interval,,}" != "none"  ]]; then
  mpasout_path=$(realpath "${mpasout_file}")
  echo "${cpreq} ${mpasout_path} ${comoutdir}/." >> "${CMDFILE}"
fi

done

#
# parallel run the serial tasks
#
${cpreq} "${EXECrrfs}"/rank_run.x .
${MPI_RUN_CMD} ./rank_run.x "$CMDFILE"

# Check for errors
export err=$?
if (( err != 0 )) ; then
  echo "save_for_next failed with error code ${err} "
  err_exit
fi

exit 0
