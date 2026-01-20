#!/usr/bin/env bash
# shellcheck disable=SC2153,SC1091,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
cd "${DATA}"  || exit 1

export CMDFILE=${DATA}/poescript_ncea
: > "${CMDFILE}"  # Clear or create the CMDFILE

#
# find forecst length for this cycle
#
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$("${USHrrfs}/find_fcst_length.sh" "${fcst_len_hrs_cycles}" "${cyc}" )
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
# loop through forecast history files for this group
#
fhr_string=$( seq 0 $((10#${HISTORY_INTERVAL})) $((10#${fcst_len_hrs_thiscyc} )) | paste -sd ' ' )
read -ra fhr_all <<< "${fhr_string}"  # convert fhr_string to an array
num_fhrs=${#fhr_all[@]}
group_total_num=$((10#${GROUP_TOTAL_NUM}))
group_index=$((10#${GROUP_INDEX}))

for (( ii=0; ii<"${num_fhrs}"; ii=ii+"${group_total_num}" )); do
    i=$(( ii + "${group_index}" - 1 ))
    if (( i >= num_fhrs )); then
      break
    fi
    # get forecast hour and string
    fhr=${fhr_all[$i]}
    CDATEp=$(${NDATE} "${fhr}" "${CDATE}" )
    timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)

    # decide the history files
    history_mean="${UMBRELLA_ENSMEAN_DATA}/history.${timestr}.nc"
    diag_mean="${UMBRELLA_ENSMEAN_DATA}/diag.${timestr}.nc"
    # wait for history file available
    while true; do
        historyfiles=("${UMBRELLA_FCST_DATA}"/mem*/"history.${timestr}.nc")
        num_historyfiles=${#historyfiles[@]}
        if [[ ${num_historyfiles} == "${ENS_SIZE}" ]]; then
           echo "find enough ensemble history forecast files: ${num_historyfiles} files"
           break
        else
           echo "${num_historyfiles} ensemble history file(s) available, waiting for more ..."
           sleep 5
        fi
    done
    rm -f  "${history_mean}"
    echo "Processing ensemble mean for history.${timestr}.nc ..."
    echo ncea --no_tmp_fl  "${UMBRELLA_FCST_DATA}"/mem*/"history.${timestr}.nc"  "${history_mean}"  >> "${CMDFILE}"
    # wait for diag file available
    while true; do
        diagfiles=("${UMBRELLA_FCST_DATA}"/mem*/"diag.${timestr}.nc")
        num_diagfiles=${#diagfiles[@]}
        if [[ ${num_diagfiles} == "${ENS_SIZE}" ]]; then
           echo "find enough ensemble diag forecast files: ${num_diagfiles} files"
           break
        else
           echo "${num_diagfiles} ensemble diag file(s) available, waiting for more ..."
           sleep 5
        fi
    done
    rm -f "${diag_mean}"
    echo "Processing ensemble mean for diag.${timestr}.nc ..."
    echo ncea --no_tmp_fl  "${UMBRELLA_FCST_DATA}"/mem*/"diag.${timestr}.nc"  "${diag_mean}"  >> "${CMDFILE}"
done

NUM_CMDS=$(wc -l < "${CMDFILE}")

#
# add rank numbers (0, 1, 2, ...) at the start of each command line
# so it can be used with srun --multi-prog
nl -v 0 -w 1 -s ' ' "${CMDFILE}" > "${CMDFILE}".multi

if (( NTASKS > NUM_CMDS )); then
  for ((i=NUM_CMDS; i<NTASKS; i++)); do
    echo "$i /bin/true" >> "${CMDFILE}".multi
  done
elif (( NTASKS < NUM_CMDS )); then
  echo "ERROR: SLURM_NTASKS (${NTASKS}) < number of commands (${NUM_CMDS})"
  err_exit
fi

echo "Running all NCEA commands with ${NTASKS} tasks for ${NUM_CMDS} commands"
srun --multi-prog "${CMDFILE}".multi

# Check for errors
export err=$?
if (( err != 0 )); then
    echo "NCEA parallel execution failed with error code ${err}"
    err_exit
else
    echo "NCEA parallel execution completed successfully"
fi

