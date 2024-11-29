#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x

ulimit -s unlimited
ulimit -v unlimited
ulimit -a

cpreq=${cpreq:-cpreq}
cd ${DATA}
#
#  cpy excutable and fix files; decide mesh
#

${cpreq} ${FIXrrfs}/mpassit/${MESH_NAME}/* .
${cpreq} ${EXECrrfs}/mpassit.x .

if [[ "${MESH_NAME}" == "conus12km" ]]; then
  nx=480
  ny=280
  dx=12000.0
  ref_lat=39.0
elif [[ "${MESH_NAME}" == "conus3km" ]]; then
  nx=1800
  ny=1060
  dx=3000.0
  ref_lat=38.5
fi
#
#  find cycle time
#
YYYYMMDDHH=${CDATE}
YYYYMMDD=${CDATE:0:8}
HH=${CDATE:8:2}
#
#  find the localtion of the history files
#
if [[ -z "${ENS_INDEX}" ]]; then
  ensindexstr=""
else
  ensindexstr="/mem${ENS_INDEX}"
fi
history_dir=${UMBRELLA_DATA}${ensindexstr}/${RUN}_fcst_${cyc}
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$(${USHrrfs}/find_fcst_length.sh "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
# loop through forecast history files for this group
#
fhr_string=$( seq 0 $((10#${HISTORY_INTERVAL})) $((10#${fcst_len_hrs_thiscyc} )) )
fhr_all=(${fhr_string})
num_fhrs=${#fhr_all[@]}
group_total_num=$((10#${GROUP_TOTAL_NUM}))
group_index=$((10#${GROUP_INDEX}))

for (( ii=0; ii<${num_fhrs}; ii=ii+${group_total_num} )); do
    i=$(( ii + ${group_index} - 1 ))
    if (( $i >= ${num_fhrs} )); then
      break
    fi
    # get forecast hour and string
    fhr=${fhr_all[$i]}
    CDATEp=$($NDATE ${fhr} ${CDATE} )
    timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S) 
    # decide the history files   
    history_file=${history_dir}/history.${timestr}.nc
    diag_file=${history_dir}/diag.${timestr}.nc
    # wait for file available 
    for (( j=0; j < 20; j=j+1)); do
      if [[ -s ${diag_file} ]]; then
	break
      fi
      sleep 60s
    done
    # run mpassit
    if [[ -s ${history_file} ]] && [[ -s ${diag_file} ]]; then
      ln -sfn ${history_file} .
      ln -sfn ${diag_file} .

      # generate the naemlist on fly
      sed -e "s/@timestr@/${timestr}/" -e "s/@nx@/${nx}/" -e "s/@ny@/${ny}/" -e "s/@dx@/${dx}/" \
          -e "s/@ref_lat@/${ref_lat}/" ${PARMrrfs}/namelist.mpassit > namelist.mpassit

      # run the executable
      source prep_step
      ${MPI_RUN_CMD} ./mpassit.x namelist.mpassit
      # check the status, copy output to UMBRELLA_DATA
      if [[ -s "./mpassit.${timestr}.nc" ]]; then
        mv ./mpassit.${timestr}.nc ${UMBRELLA_DATA}${ensindexstr}/mpassit/.
        mv namelist.mpassit namelist.mpassit_${fhr}
      else
        echo "FATAL ERROR: failed to genereate mpassit.${timestr}.nc"
        err_exit
      fi
    else
      echo "FATAL ERROR: cannot find history file at ${timestr}"
      err_exit
    fi
done
