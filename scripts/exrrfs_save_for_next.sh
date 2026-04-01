#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1
#
export CMDFILE="${DATA}/poescript_savefcst"
mkdir -p "$(dirname "$CMDFILE")"
: > "$CMDFILE"
#
if  [[ "${MPASOUT_TIMELEVELS}" != "" ]]; then
  if  [[ "${MPASOUT_TIMELEVELS_MORE}" != "" ]]; then
    for hr in ${MPASOUT_TIMELEVELS_MORE_CYCS:-"99"}; do
     if [ "${cyc}" == "${hr}" ]; then
       MPASOUT_TIMELEVELS="${MPASOUT_TIMELEVELS_MORE}"
     fi
    done
  fi
  mpasout_list=$(echo "${MPASOUT_TIMELEVELS}" | sed 's/^0 //')
else
  mpasout_list=${MPASOUT_INTERVAL:-1}
fi
#
if [[ "${mpasout_interval,,}" = "none"  ]]; then
 echo Not saving mpasout files since mpasout_interval="${mpasout_interval,,}"
 exit 0
fi

read -a mpasout_list <<< "$mpasout_list"

for mpasout_interval in "${mpasout_list[@]}"; do

CDATEp=$( ${NDATE}  "${mpasout_interval}"  "${CDATE}" )
timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)

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
timeout=1200  # Maximum seconds to wait
elapsed=0

until [[ -s "${mpasout_file}" || $elapsed -ge $timeout ]]; do
  sleep 10
  ((elapsed++))
done

if [[ -s "${mpasout_file}" ]]; then
  mpasout_path=$(realpath "${mpasout_file}")
  echo "${cpreq} ${mpasout_path} ${comoutdir}/." >> "${CMDFILE}"
else
  echo "Error: ${mpasout_file} not found or empty after ${timeout} seconds." >&2
  exit 1
fi

done
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
