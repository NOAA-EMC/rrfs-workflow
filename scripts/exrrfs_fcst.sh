#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1
#
dt=${FCST_DT:-60}
substeps=${FCST_SUBSTEPS:-2}
radt=${FCST_RADT:-30}
#
# find forecst length for this cycle
#
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$("${USHrrfs}/find_fcst_length.sh" "${fcst_len_hrs_cycles}" "${cyc}" )
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
  ln -snf "${UMBRELLA_PREP_IC_DATA}/mpasout.nc" "${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc"
  start_type='warm'
  do_DAcycling='true'
fi

#
#  link bdy and fix files
#
ln -snf "${UMBRELLA_PREP_LBC_DATA}"/lbc*.nc .

ln -snf "${FIXrrfs}/physics/${PHYSICS_SUITE}"/* .
ln -snf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.ugwp_oro_data.nc" ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
ln -snf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix}" ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf "${FIXrrfs}/${MESH_NAME}"/graphinfo/* graphinfo/
${cpreq} "${FIXrrfs}/stream_list/${PHYSICS_SUITE}"/* stream_list/

# generate the namelist on the fly
# do_restart already defined in the above
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
run_duration=${fcst_len_hrs_thiscyc:-1}:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="true" #true

pio_num_iotasks=${NODES}
pio_stride=${PPN}
file_content=$(< "${PARMrrfs}/${physics_suite}/namelist.atmosphere") # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere

if [[ "${FCST_CONVECTION_SCHEME^^}" == "TRUE" ]]; then
  sed -i -e "s/    config_physics_suite = 'hrrrv5'/\
    config_physics_suite = 'hrrrv5'\n\
    config_convection_scheme = 'cu_ntiedtke'\n\
    config_gfl_sub3d = 1/" namelist.atmosphere
fi

# generate the streams file on the fly using sed as this file contains "filename_template='lbc.$Y-$M-$D_$h.$m.$s.nc'"
lbc_interval=${LBC_INTERVAL:-3}
restart_interval=${RESTART_INTERVAL:-none}
history_interval=${HISTORY_INTERVAL:-1}
diag_interval=${HISTORY_INTERVAL:-1}
mpasout_interval=${MPASOUT_INTERVAL:-1}
[[ ${restart_interval} =~ ^[0-9]+$ ]] && restart_interval="${restart_interval}:00:00"
[[ ${mpasout_interval} =~ ^[0-9]+$ ]] && mpasout_interval="${mpasout_interval}:00:00"
sed -e "s/@restart_interval@/${restart_interval}/" -e "s/@history_interval@/${history_interval}/" \
    -e "s/@diag_interval@/${diag_interval}/" -e "s/@lbc_interval@/${lbc_interval}/" \
    -e "s/@mpasout_interval@/${mpasout_interval}/" "${PARMrrfs}"/streams.atmosphere  > streams.atmosphere
#
if [[ "${mpasout_interval,,}" == "none" ]]; then  # remove the da_state stream for coldstart only forecasts
  sed -i '/<stream name="da_state"/,/<\/stream>/d' streams.atmosphere
fi
#
# chemistry related processing
if [[ "${DO_CHEMISTRY^^}" == "TRUE" ]]; then
  source "${USHrrfs}"/chem_fcst.sh
fi
#
# prelink the forecast output files to umbrella
history_all=$(seq 0 $((10#${history_interval})) $((10#${fcst_len_hrs_thiscyc} )) )
for fhr in ${history_all}; do
  CDATEp=$( ${NDATE} "${fhr}" "${CDATE}" )
  timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
  if [[ "${DO_SPINUP:-FALSE}" != "TRUE" ]];  then
    ln -snf "${UMBRELLA_FCST_DATA}/history.${timestr}.nc" "${DATA}"
    ln -snf "${UMBRELLA_FCST_DATA}/diag.${timestr}.nc" "${DATA}"
    if [[ "${mpasout_interval,,}" != "none" ]]; then
      ln -snf "${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc" "${DATA}"
    fi
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
  # spinup cycles copy f001 mpasout to com/ directly, don't need the save_for_next task
  if [[ "${DO_SPINUP:-FALSE}" == "TRUE" ]];  then
    CDATEp=$( ${NDATE} 1 "${CDATE}" )
    timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
    ${cpreq} "${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc" "${COMOUT}/fcst_spinup/${WGF}${MEMDIR}"
    cp "${DATA}/log.atmosphere.0000.out" "${COMOUT}/fcst_spinup/${WGF}${MEMDIR}"
    cp "${DATA}/namelist.atmosphere" "${COMOUT}/fcst_spinup/${WGF}${MEMDIR}"
    cp "${DATA}/streams.atmosphere" "${COMOUT}/fcst_spinup/${WGF}${MEMDIR}"

  else # prod cycles, cycling mpasout is copied by the save_for_next task so that next cycle can start much earlier; other mpasout files can be copied when fcst completes
    ${cpreq} "${DATA}/log.atmosphere.0000.out" "${COMOUT}/fcst/${WGF}${MEMDIR}"
    cp "${DATA}/namelist.atmosphere" "${COMOUT}/fcst/${WGF}${MEMDIR}"
    cp "${DATA}/streams.atmosphere" "${COMOUT}/fcst/${WGF}${MEMDIR}"
    if [[ "${mpasout_interval,,}" != "none"  ]] && [[ -n "${MPASOUT_SAVE2COM_HRS}" ]]; then  # copy mpasout based on the $MPASOUT_SAVE2COM_HRS setting
      read -ra array <<< "${MPASOUT_SAVE2COM_HRS}"
      # shellcheck disable=SC2068
      for fhr in ${array[@]}; do
        CDATEp=$( ${NDATE} "${fhr}" "${CDATE}" )
        timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
        mpasout_file=${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc
        if [[ -s ${mpasout_file} ]]; then
          ${cpreq} "${mpasout_file}" "${COMOUT}/fcst/${WGF}${MEMDIR}"
        else
          echo "WARNING: mpasout_file not found - ${mpasout_file}"
        fi
      done
    fi
  fi
  exit 0
fi
