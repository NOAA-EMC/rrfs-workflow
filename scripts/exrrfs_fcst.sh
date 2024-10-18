#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
if [[ -z "${ENS_INDEX}" ]]; then
  IFS=' ' read -r -a array <<< "${PROD_BGN_AT_HRS}"
  ensindexstr=""
  lbc_interval=${LBC_INTERVAL:-3}
else
  IFS=' ' read -r -a array <<< "${ENS_PROD_BGN_AT_HRS}"
  ensindexstr="/mem${ENS_INDEX}"
  lbc_interval=${ENS_LBC_INTERVAL:-3}
fi
# determine whether to begin new cycles
begin="NO"
for hr in "${array[@]}"; do
  if [[ "${cyc}" == "$(printf '%02d' ${hr})" ]]; then
    begin="YES"; break
  fi
done
if [[ "${begin}" == "YES" ]]; then
  ${cpreq} ${COMINrrfs}/${RUN}.${PDY}/${cyc}${ensindexstr}/ic/init.nc .
  do_restart='false'
else
  ${cpreq} ${COMINrrfs}/${RUN}.${PDY}/${cyc}${ensindexstr}/da/restart.${timestr}.nc .
  do_restart='true'
fi
offset=$((10#${cyc}%6))
CDATElbc=$($NDATE -${offset} ${CDATE})
${cpreq} ${COMINrrfs}/${RUN}.${CDATElbc:0:8}/${CDATElbc:8:2}${ensindexstr}/lbc/lbc*.nc .
${cpreq} ${FIXrrfs}/physics/${PHYSICS_SUITE}/* .
ln -snf VEGPARM.TBL.fcst VEGPARM.TBL #gge.debug temp
mkdir -p graphinfo stream_list
${cpreq} ${FIXrrfs}/graphinfo/* graphinfo/
cpreq ${FIXrrfs}/stream_list/${PHYSICS_SUITE}/* stream_list/

# generate the namelist on the fly
# do_restart already defined in the above
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
run_duration=${FCST_LENGTH:-6}:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="false" #true

if [[ "${MESH_NAME}" == "conus12km" ]]; then
  pio_num_iotasks=6
  pio_stride=20
elif [[ "${MESH_NAME}" == "conus3km" ]]; then
  pio_num_iotasks=40
  pio_stride=20
fi
file_content=$(< ${PARMrrfs}/${physics_suite}/namelist.atmosphere) # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere

# generate the streams file on the fly using sed as this file contains "filename_template='lbc.$Y-$M-$D_$h.$m.$s.nc'"
# lbc_interval is defined in the beginning
restart_interval=${RESTART_INTERVAL:-1}
history_interval=${HISTORY_INTERVAL:-1}
diag_interval=${DIAG_INTERVAL:-1}
sed -e "s/@restart_interval@/${restart_interval}/" -e "s/@history_interval@/${history_interval}/" \
    -e "s/@diag_interval@/${diag_interval}/" -e "s/@lbc_interval@/${lbc_interval}/" \
    ${PARMrrfs}/streams.atmosphere_fcst > streams.atmosphere

# run the MPAS model
ulimit -s unlimited
ulimit -v unlimited
ulimit -a
source prep_step
${cpreq} ${EXECrrfs}/atmosphere_model.x .
${MPI_RUN_CMD} ./atmosphere_model.x 
# check the status
if [[ -f './log.atmosphere.0000.err' ]]; then # has to use '-f" as the 0000 err file may be size 0
  echo "FATAL ERROR: MPAS model run failed"
  err_exit
fi

# copy output to COMOUT
CDATEp1=$($NDATE 1 ${CDATE})
timestr=$(date -d "${CDATEp1:0:8} ${CDATEp1:8:2}" +%Y-%m-%d_%H.%M.%S) 
if [[ -z "${ENS_INDEX}" ]]; then
  dstdir="${COMOUT}/fcst/"
else
  dstdir="${COMOUT}/mem${ENS_INDEX}/fcst/"
fi
${cpreq} ${DATA}/restart.${timestr}.nc ${dstdir}
${cpreq} ${DATA}/diag.*.nc ${dstdir}
${cpreq} ${DATA}/history.*.nc ${dstdir}
