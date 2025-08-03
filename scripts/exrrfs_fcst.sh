#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1
#
# determine time steps and etc according to the mesh
#
if [[ ${MESH_NAME} == "conus12km" ]]; then
  dt=60
  substeps=2
  radt=30
elif [[ ${MESH_NAME} == "conus3km" ]]; then
  dt=20
  substeps=4
  radt=15
elif [[ ${MESH_NAME} == "south3.5km" ]]; then
  dt=25
  substeps=4
  radt=15
else
  echo "Unknown MESH_NAME, exit!"
  err_exit
fi
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$("${USHrrfs}/find_fcst_length.sh" "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
# determine whether to begin new cycles
#
if [[ -r "${UMBRELLA_PREP_IC_DATA}/init.nc" ]]; then
  ln -snf "${UMBRELLA_PREP_IC_DATA}/init.nc" init.nc
  start_type='cold'
  do_DAcycling='false'
else
  timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S)
  ln -snf "${UMBRELLA_PREP_IC_DATA}/mpasout.nc" "mpasout.${timestr}.nc"
  start_type='warm'
  do_DAcycling='true'
fi

#
#  link bdy and fix files
#
ln -snf "${UMBRELLA_PREP_LBC_DATA}"/lbc*.nc .

ln -snf "${FIXrrfs}/physics/${PHYSICS_SUITE}"/* .
ln -snf "${FIXrrfs}/meshes/${MESH_NAME}.ugwp_oro_data.nc" ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
ln -snf "${FIXrrfs}/meshes/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix}" ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf "${FIXrrfs}"/graphinfo/* graphinfo/
ln -snf "${FIXrrfs}/stream_list/${PHYSICS_SUITE}"/* stream_list/

# generate the namelist on the fly
# do_restart already defined in the above
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
run_duration=${fcst_len_hrs_thiscyc:-1}:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="true" #true

if [[ "${MESH_NAME}" == "conus12km" ]]; then
  pio_num_iotasks=1
  pio_stride=40
elif [[ "${MESH_NAME}" == "conus3km" ]]; then
  pio_num_iotasks=40
  pio_stride=20
elif [[ "${MESH_NAME}" == "south3.5km" ]]; then
  pio_num_iotasks=10
  pio_stride=24
fi
file_content=$(< "${PARMrrfs}/${physics_suite}/namelist.atmosphere") # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere

# generate the streams file on the fly using sed as this file contains "filename_template='lbc.$Y-$M-$D_$h.$m.$s.nc'"
lbc_interval=${LBC_INTERVAL:-3}
restart_interval=${RESTART_INTERVAL:-99}
history_interval=${HISTORY_INTERVAL:-1}
diag_interval=${HISTORY_INTERVAL:-1}
sed -e "s/@restart_interval@/${restart_interval}/" -e "s/@history_interval@/${history_interval}/" \
    -e "s/@diag_interval@/${diag_interval}/" -e "s/@lbc_interval@/${lbc_interval}/" \
    "${PARMrrfs}"/streams.atmosphere  > streams.atmosphere
#
# prelink the forecast output files to umbrella
history_all=$(seq 0 $((10#${history_interval})) $((10#${fcst_len_hrs_thiscyc} )) )
for fhr in ${history_all}; do
  CDATEp=$( ${NDATE} "${fhr}" "${CDATE}" )
  timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
  if [[ "${DO_SPINUP:-FALSE}" != "TRUE" ]];  then
    ln -snf "${DATA}/history.${timestr}.nc" "${UMBRELLA_FCST_DATA}"
    ln -snf "${DATA}/diag.${timestr}.nc" "${UMBRELLA_FCST_DATA}"
    ln -snf "${DATA}/mpasout.${timestr}.nc" "${UMBRELLA_FCST_DATA}"
    ln -snf "${DATA}/log.atmosphere.0000.out" "${UMBRELLA_FCST_DATA}"
  fi
done

# run the MPAS model
source prep_step
${cpreq} "${EXECrrfs}"/atmosphere_model.x .
${MPI_RUN_CMD} ./atmosphere_model.x 
export err=$?
err_chk
#
# double check status as sometimes atmosphere_model.x exit with 0 but there are still errors (log.atmosphere*err)
#
num_err_log=$(find ./log.atmosphere*.err 2>/dev/null | wc -l)
if (( "${num_err_log}" > 0 )) ; then
  echo "FATAL ERROR: MPAS model run failed"
  err_exit
else
  # spinup cycles copy mpasout and log file to com/ directly, don't need the save_fcst task
  if [[ "${DO_SPINUP:-FALSE}" == "TRUE" ]];  then
    CDATEp=$( ${NDATE} 1 "${CDATE}" )
    timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
    ${cpreq} "${DATA}/mpasout.${timestr}.nc" "${COMOUT}/fcst_spinup/${WGF}${MEMDIR}"
    ${cpreq} "${DATA}/log.atmosphere.0000.out" "${COMOUT}/fcst_spinup/${WGF}${MEMDIR}"
  fi
  exit 0
fi
