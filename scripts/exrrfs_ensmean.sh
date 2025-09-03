#!/usr/bin/env bash
# shellcheck disable=SC2153,SC1091,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
cd "${DATA}"  || exit 1
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$("${USHrrfs}/find_fcst_length.sh" "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
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
    history_file="${UMBRELLA_ENSMEAN_DATA}/history.${timestr}.nc"
    diag_file="${UMBRELLA_ENSMEAN_DATA}/diag.${timestr}.nc"
    # wait for history file available
    while true; do
        historyfiles="${UMBRELLA_SAVE_FCST_DATA}/mem*/history.${timestr}.nc"
        num_historyfiles=$( files=("${historyfiles}") && echo ${#files[@]} )
        if [[ ${num_historyfiles} == "${ENS_SIZE}" ]]; then
           echo "find enough ensemble history forecast files: ${num_historyfiles} files"
           break
        else
           echo "no enough ensemble history forecast files: ${num_historyfiles} files"
           sleep 5
        fi
    done
    rm -f  "${history_file}"
    echo "Processing ensemble mean for history.${timestr}.nc ..."
    ncea --no_tmp_fl  "${historyfiles}"  "${history_file}" &
    # wait for diag file available
    while true; do
        diagfiles="${UMBRELLA_SAVE_FCST_DATA}/mem*/diag.${timestr}.nc"
        num_diagfiles=$( files=("${diagfiles}") && echo ${#files[@]} )
        if [[ ${num_diagfiles} == "${ENS_SIZE}" ]]; then
           echo "find enough ensemble diag forecast files: ${num_historyfiles} files"
           break
        else
           echo "no enough ensemble diag forecast files: ${num_diagfiles} files"
           sleep 5
        fi
    done
    rm -f "${diag_file}"
    echo "Processing ensemble mean for diag.${timestr}.nc ..."
    ncea --no_tmp_fl  "${diagfiles}"  "${diag_file}" &
done

# Wait for all background jobs to finish
#wait
while true; do
  wait -n || {
    code="$?"
    ([[ $code = "127" ]] && exit 0 || exit "$code")
    break
  }
done

echo " All ensemble means computed by forecast hour and saved in ${UMBRELLA_ENSMEAN_DATA}"

