#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S)
restart_interval=${RESTART_INTERVAL:-61}
history_interval=${HISTORY_INTERVAL:-1}
cyc_interval=${CYC_INTERVAL:-1}
comoutdir=${COMOUT}${MEMDIR}/fcst
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$(${USHrrfs}/find_fcst_length.sh "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
# decide the location of run and umbrella
#
workdir="${DATAROOT}/${RUN}_fcst${MEMID}_${cyc}"
umbrelladir="${UMBRELLA_ROOT}/fcst"
#
#  move history files when it is done to umbrella
#  now check each until the last history is moved
#
history_all=$(seq 0 $((10#${history_interval})) $((10#${fcst_len_hrs_thiscyc} )) )
restart_all=$(seq 0 $((10#${restart_interval})) $((10#${fcst_len_hrs_thiscyc} )) )
fhr_all=(${history_all})
num_fhrs=${#fhr_all[@]}

for (( ii=0; ii<${num_fhrs}; ii=ii+1 )); do

    # get forecast hour and string
    fhr=${fhr_all[$ii]}
    CDATEp=$($NDATE ${fhr} ${CDATE} )
    timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)

    # decide the history files
    history_file=${workdir}/history.${timestr}.nc
    diag_file=${workdir}/diag.${timestr}.nc
    mpasout_file=${workdir}/mpasout.${timestr}.nc

    # wait for file available for 20 min
    for (( j=0; j < 20; j=j+1)); do
      if [[ -s ${diag_file} ]]; then
        break
      fi
      sleep 60s
    done

    if [[ -s ${diag_file} ]] && [[ -s ${history_file} ]]; then
      sleep 10s
      mv ${history_file} ${umbrelladir}/.
      mv ${diag_file}    ${umbrelladir}/.
      # save to com
      if (( ${ii} == ${cyc_interval} )); then
        ${cpreq} ${mpasout_file} ${comoutdir}/.
      fi
    else
      echo "ERROR, cannot find diag.${timestr}.nc"
      err_exit
    fi
done

exit 0
