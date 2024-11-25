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
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$(${USHrrfs}/find_fcst_length.sh "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
# determine whether to begin new cycles
#
if [[ -r "${UMBRELLA_DATA}/cycinit/init.nc" ]]; then
  ln -snf ${UMBRELLA_DATA}/cycinit/init.nc .
  do_restart='false'
else
  ln -snf ${UMBRELLA_DATA}/cycinit/restart.${timestr}.nc .
  do_restart='true'
fi

#
#  link bdy and fix files
#
ln -snf ${UMBRELLA_DATA}/cycbdys/lbc*.nc .

ln -snf ${FIXrrfs}/physics/${PHYSICS_SUITE}/* .
ln -snf ${FIXrrfs}/meshes/3km_conus.ugwp_oro_data.nc .
mkdir -p graphinfo stream_list
ln -snf ${FIXrrfs}/graphinfo/* graphinfo/
ln -snf ${FIXrrfs}/stream_list/${PHYSICS_SUITE}/* stream_list/

# generate the namelist on the fly
# do_restart already defined in the above
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
run_duration=${fcst_len_hrs_thiscyc:-1}:00:00
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
restart_interval=${RESTART_INTERVAL:-61}
history_interval=${HISTORY_INTERVAL:-1}
#diag_interval=${DIAG_INTERVAL:-1}
diag_interval=${HISTORY_INTERVAL:-1}
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
${cpreq} ${DATA}/diag.*.nc ${dstdir}
${cpreq} ${DATA}/history.*.nc ${dstdir}
