#!/usr/bin/env bash
# shellcheck disable=SC2153,SC1091,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
cd "${DATA}"  || exit 1
#
#  copy excutable and fix files for this mesh
#
${cpreq} "${EXECrrfs}"/mpassit.x .

${cpreq} "${FIXrrfs}"/mpassit/diaglist                    diaglist
${cpreq} "${FIXrrfs}"/mpassit/histlist_2d                 histlist_2d
${cpreq} "${FIXrrfs}"/mpassit/histlist_3d                 histlist_3d
${cpreq} "${FIXrrfs}"/mpassit/histlist_soil               histlist_soil
#
if [[ "${DO_CHEMISTRY^^}" == "TRUE" ]]; then
  source "${USHrrfs}"/chem_mpassit.sh
fi
#
nx=${MPASSIT_NX:-480}
ny=${MPASSIT_NY:-280}
dx=${MPASSIT_DX:-12000.0}
ref_lat=${MPASSIT_REF_LAT:-"39.0"}
ref_lon=${MPASSIT_REF_LON:-"-97.5"}
#
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
    history_file=${UMBRELLA_FCST_DATA}/history.${timestr}.nc
    diag_file=${UMBRELLA_FCST_DATA}/diag.${timestr}.nc
    # wait for file available 
    for (( j=0; j < 20; j=j+1)); do
      if [[ -s ${diag_file} ]]; then
	break
      fi
      sleep 60s
    done
    # run mpassit
    if [[ -s "${history_file}" ]] && [[ -s "${diag_file}" ]]; then
      ln -sfn "${history_file}" .
      ln -sfn "${diag_file}" .

      # generate the naemlist on fly
      sed -e "s/@timestr@/${timestr}/" -e "s/@nx@/${nx}/" -e "s/@ny@/${ny}/" -e "s/@dx@/${dx}/" \
          -e "s/@ref_lat@/${ref_lat}/" -e "s/@ref_lon@/${ref_lon}/" "${PARMrrfs}/namelist.mpassit" > namelist.mpassit

      # run the executable
      source prep_step
      ${MPI_RUN_CMD} ./mpassit.x namelist.mpassit
      # check the status, copy output to UMBRELLA_MPASSIT_DATA
      if [[ -s "./mpassit.${timestr}.nc" ]]; then
        mv "./mpassit.${timestr}.nc" "${UMBRELLA_MPASSIT_DATA}/."
        mv namelist.mpassit "namelist.mpassit_${fhr}"
      else
        echo "FATAL ERROR: failed to genereate mpassit.${timestr}.nc"
        err_exit
      fi
    else
      echo "FATAL ERROR: cannot find history file at ${timestr}"
      err_exit
    fi
done
