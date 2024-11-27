#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S)
if [[ -z "${ENS_INDEX}" ]]; then
  IFS=' ' read -r -a array <<< "${PROD_BGN_AT_HRS}"
  ensindexstr=""
  restart_interval=${RESTART_INTERVAL:-61}
  history_interval=${HISTORY_INTERVAL:-1}
else
  IFS=' ' read -r -a array <<< "${ENS_PROD_BGN_AT_HRS}"
  ensindexstr="/mem${ENS_INDEX}"
  restart_interval=${ENS_RESTART_INTERVAL:-61}
  history_interval=${ENS_HISTORY_INTERVAL:-1}
fi
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$(${USHrrfs}/find_fcst_length.sh "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"

#
#  find the sequence of the history and restaryt files
#
history_all=$(seq $((10#${history_interval})) $((10#${history_interval})) $((10#${fcst_len_hrs_thiscyc} )) )
restart_all=$(seq $((10#${restart_interval})) $((10#${restart_interval})) $((10#${fcst_len_hrs_thiscyc} )) )
#
#  decide the last forecast file 
#
CDATElast=$($NDATE $((10#${fcst_len_hrs_thiscyc} )) ${CDATE} )
last_timestr=$(date -d "${CDATElast:0:8} ${CDATElast:8:2}" +%Y-%m-%d_%H.%M.%S) 
last_diag_file=diag.${last_timestr}.nc
#
# decide the location of run and umbrella
#
if [[ -z "${ENS_INDEX}" ]]; then
  ensindexstr=""
else
  ensindexstr="/mem${ENS_INDEX}"
fi
workdir="${DATAROOT}${ensindexstr}/${RUN}_fcst_${cyc}"
umbrelladir="${UMBRELLA_DATA}/${jobid}"

#
#  move history files when it is done to umbrella
#
#  move the first history file 
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
if [[ -s "${workdir}/diag.${timestr}.nc" ]] && [[ -s "${workdir}/history.${timestr}.nc" ]] ;then
  mv ${workdir}/history.${timestr}.nc ${umbrelladir}/.
  mv ${workdir}/diag.${timestr}.nc    ${umbrelladir}/.
  first_file_age=$(date -r ${umbrelladir}/diag.${timestr}.nc +%s)
else
  echo "history files do not exist, something is wrong!"
  err_exit
fi
#
#  now check each until the last history is moved
#
max_wait_time_sec=1200  # wait for 20 minutes
while [[ ${min_file_age} -le ${max_wait_time_sec} ]]; do

  sleep 60s
  last_file_age=${first_file_age}

  for fhr in ${history_all}; do
    CDATEp=$($NDATE $((10#${fhr} )) ${CDATE} )
    timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S) 
    if [[ -s ${umbrelladir}/diag.${timestr}.nc ]]; then
      file_age=$(date -r ${umbrelladir}/diag.${timestr}.nc +%s)
      if (( ${last_file_age} <= ${file_age} )); then
        last_file_age=${file_age}
      fi
    fi
    if [[ -s ${workdir}/diag.${timestr}.nc ]]; then
      sleep 10s
      mv ${workdir}/history.${timestr}.nc ${umbrelladir}/.
      mv ${workdir}/diag.${timestr}.nc    ${umbrelladir}/.
      if (( ${fhr} == ${fcst_len_hrs_thiscyc} )); then
	echo "Moved the last history file diag.${timestr}.nc. ALL DONE"
	exit 0
      fi
    fi

  done

  time_now=$(date +%s)
  min_file_age=$(( ${time_now}-${last_file_age}))

done

exit 0
