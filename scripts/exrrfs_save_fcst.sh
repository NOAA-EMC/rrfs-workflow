#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S)
history_interval=${HISTORY_INTERVAL:-1}
cyc_interval=${CYC_INTERVAL:-1}
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$( "${USHrrfs}/find_fcst_length.sh"  "${fcst_len_hrs_cycles}"  "${cyc}"  "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
#  move history files when it is done to umbrella
#  now check each until the last history is moved
#
history_all=$(seq 0 $((10#${history_interval})) $((10#${fcst_len_hrs_thiscyc} )) )
ii=0
for fhr in ${history_all}; do

    # get forecast hour and string
    CDATEp=$( ${NDATE}  "${fhr}"  "${CDATE}" )
    timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)

    # decide the history files
    history_file=${UMBRELLA_FCST_DATA}/history.${timestr}.nc
    diag_file=${UMBRELLA_FCST_DATA}/diag.${timestr}.nc
    mpasout_file=${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc

    # wait for file available for 20 min
    for (( j=0; j < 20; j=j+1)); do
      if [[ -s ${diag_file} ]]; then
        break
      fi
      sleep 60s
    done

    if [[ -s ${diag_file} ]] && [[ -s ${history_file} ]]; then
      sleep 10s #gge.tmp.debug: 10s may not be enough to finish file writing in some situations
      history_path=$(realpath "${history_file}")
      mv "${history_path}"  "${UMBRELLA_SAVE_FCST_DATA}/."
      diag_path=$(realpath "${diag_file}")
      mv "${diag_path}"  "${UMBRELLA_SAVE_FCST_DATA}/."
      # save to com
      if (( ii <= cyc_interval )) && (( ii > 0 )); then
        mpasout_path=$(realpath "${mpasout_file}")
        ${cpreq} "${mpasout_path}" "${COMOUT}/fcst/${WGF}${MEMDIR}/."
      fi
    else
      echo "ERROR, diag.${timestr}.nc or history.${timestr}.nc missing"
      err_exit
    fi

    ((ii+=1)) # increment ii by 1
done

exit 0
