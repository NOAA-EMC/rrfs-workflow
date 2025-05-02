#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1

start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
time_min=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%M)
#
# determine whether to begin new cycles
#
if [[ -r "${UMBRELLA_PREP_IC_DATA}/init.nc" ]]; then
  start_type='cold'
  do_DAcycling='false'
  initial_file=${UMBRELLA_PREP_IC_DATA}/init.nc
else
  start_type='warm'
  do_DAcycling='true'
  initial_file=${UMBRELLA_PREP_IC_DATA}/mpasin.nc
fi
#
# link fix files from physics, meshes, graphinfo, stream list, and jedi
#
ln -snf "${FIXrrfs}/physics/${PHYSICS_SUITE}"/*  .
ln -snf "${FIXrrfs}/meshes/${MESH_NAME}.ugwp_oro_data.nc"  ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
ln -snf "${FIXrrfs}/meshes/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix}"  ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf "${FIXrrfs}"/graphinfo/*  graphinfo/
ln -snf "${FIXrrfs}/stream_list/${PHYSICS_SUITE}"/*  stream_list/
${cpreq} "${FIXrrfs}"/jedi/obsop_name_map.yaml .
${cpreq} "${FIXrrfs}"/jedi/keptvars.yaml .
${cpreq} "${FIXrrfs}"/jedi/geovars.yaml .
#
# create data directory
#
mkdir -p data; cd data || exit 1
mkdir -p obs ens static_bec satbias_in satbias_out
#
#  bump files and static BEC files
#
ln -snf "${FIXrrfs}/bumploc/${MESH_NAME}_L${nlevel}_${NTASKS}_401km11levels"  bumploc
ln -snf "${FIXrrfs}/static_bec/${MESH_NAME}_L${nlevel}/stddev.nc"  static_bec/stddev.nc
ln -snf "${FIXrrfs}/static_bec/${MESH_NAME}_L${nlevel}/nicas_${NTASKS}"  static_bec/nicas
ln -snf "${FIXrrfs}/static_bec/${MESH_NAME}_L${nlevel}/vbal_${NTASKS}"  static_bec/vbal

#for satllite radiance
ln -snf "${FIXrrfs}"/crtm/2.4.0_jedi crtm
cp "${FIXrrfs}"/satbias_init/*.tlapse.txt satbias_in/.
cp "${UMBRELLA_PREP_IC_DATA}"/*satbias* satbias_in/.

#
# copy observations files
#
obspath_bufr="${COMOUT}/ioda_bufr/${WGF}"
obs_files_source[0]="${obspath_bufr}"/ioda_adpupa.nc
obs_files_target[0]=ioda_adpupa.nc

obs_number=${#obs_files_source[@]}
obs_files_source[obs_number]="${obspath_bufr}"/ioda_aircar.nc
obs_files_target[obs_number]=ioda_aircar.nc

if [ "${DO_ENVAR_RADAR_REF}" == "true" ];then
  obspath_refl="${COMOUT}/ioda_mrms_refl/${WGF}"
  obs_number=${#obs_files_source[@]}
  obs_files_source[obs_number]="${obspath_refl}/ioda_mrms_${CDATE}_${time_min}".nc4
  obs_files_target[obs_number]=ioda_mrms.nc
fi

obs_number=${#obs_files_source[@]}
for (( i=0; i<obs_number; i++ ));
do
  obs_file=${obs_files_source[$i]}
  obs_file_t=${obs_files_target[$i]}
  if [ -r "${obs_file}" ]; then
    cp "${obs_file}" obs/"${obs_file_t}"
  else
    echo "WARNING: ${obs_file} does not exist!"
  fi
done
#
#  find ensemble forecasts based on user settings
#
if [[ "${HYB_WGT_ENS}" != "0" ]] && [[ "${HYB_WGT_ENS}" != "0.0" ]]; then # using ensembles
  if [[ "${HYB_ENS_TYPE}" == "1"  ]]; then # rrfsens
    echo "use rrfs ensembles"
    mpasout_file=mpasout.${timestr}.nc
    for (( ii=0; ii<4; ii=ii+1 )); do
       CDATEp=$(${NDATE} "-${ii}" "${CDATE}" )
       ensdir=${COMINrrfs}/rrfs.${CDATEp:0:8}/${CDATEp:8:2}
       ensdir_m001=${ensdir}/fcst/enkf/mem001
       if [[ -s "${ensdir_m001}/${mpasout_file}" ]]; then
         for (( iii=1; iii<31; iii=iii+1 )); do
            memid=$(printf %03d "${iii}")
            ln -s "${ensdir}/fcst/enkf/mem${memid}/${mpasout_file}" "ens/mem${memid}.nc"
         done
       fi
    done
  elif [[ "${HYB_ENS_TYPE}" == "2"  ]]; then # interpolated GDAS/GEFFS
    echo "use interpolated GDAS/GEFS ensembles"
    init_file=init.nc
    for (( ii=0; ii<7; ii=ii+1 )); do
       CDATEp=$(${NDATE} "-${ii}" "${CDATE}" )
       if [[ "${HYB_ENS_PATH}" == "" ]]; then
         ensdir=${COMINrrfs}/rrfs.${CDATEp:0:8}/${CDATEp:8:2}
       else
         ensdir=${HYB_ENS_PATH}/rrfs.${CDATEp:0:8}/${CDATEp:8:2}
       fi
       ensdir_m001=${ensdir}/ic/enkf/mem001
       if [[ -s "${ensdir_m001}/${init_file}" ]]; then
         for (( iii=1; iii<31; iii=iii+1 )); do
            memid=$(printf %03d "${iii}")
            ln -s "${ensdir}/ic/enkf/mem${memid}/${init_file}" "ens/mem${memid}.nc"
         done
       fi
    done

  elif [[ "${HYB_ENS_TYPE}" == "0"  ]]; then # rrfsens->GDAS->3DVAR
    echo "determine the ensemble type on the fly"
    echo "==== to be implemented ===="
  fi
fi
#
#  link background
#
cd "${DATA}" || exit 1
ln -snf "${initial_file}"  mpasin.nc
#
# generate namelist, streams, and jedivar.yaml on the fly
run_duration=1:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="true" #true
pio_num_iotasks=${NODES}
pio_stride=${PPN}
if [[ "${MESH_NAME}" == "conus12km" ]]; then
  dt=60
  substeps=2
  radt=30
elif [[ "${MESH_NAME}" == "conus3km" ]]; then
  dt=20
  substeps=4
  radt=15
else
  echo "Unknown MESH_NAME, exit!"
  err_exit
fi
file_content=$(< "${PARMrrfs}/${physics_suite}/namelist.atmosphere") # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere
${cpreq} "${PARMrrfs}"/streams.atmosphere.jedivar streams.atmosphere
analysisDate=""${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z""
CDATEm2=$(${NDATE} -2 "${CDATE}")
beginDate=""${CDATEm2:0:4}-${CDATEm2:4:2}-${CDATEm2:6:2}T${CDATEm2:8:2}:00:00Z""
#
# generate jedivar.yaml based on how YAML_GEN_METHOD is set
case ${YAML_GEN_METHOD:-1} in
  1) # from ${PARMrrfs}
    source "${USHrrfs}"/yaml_from_parm.sh "jedivar"
    ;;
  2) # update placeholders in static yaml from gen_jedivar_yaml_nonjcb.sh
    source "${USHrrfs}"/yaml_replace_placeholders.sh
    ;;
  3) # JCB
    source "${USHrrfs}"/yaml_jcb.sh
    ;;
  *)
    echo "unknown YAML_GEN_METHOD:${YAML_GEN_METHOD}"
    err_exit
    ;;
esac

if [[ ${start_type} == "warm" ]] || [[ ${start_type} == "cold" && ${COLDSTART_CYCS_DO_DA} == "true" ]]; then
  # run mpasjedi_variational.x
  #export OOPS_TRACE=1
  #export OOPS_DEBUG=1
  export OMP_NUM_THREADS=1

  source prep_step
  ${cpreq} "${EXECrrfs}"/mpasjedi_variational.x .
  ${MPI_RUN_CMD} ./mpasjedi_variational.x jedivar.yaml log.out
  # check the status
  export err=$?
  err_chk
  #
  # ncks increments to cold_start IC
  if [[ ${start_type} == "cold" ]]; then
    var_list="pressure_p,rho,qv,qc,qr,qi,qs,qg,ni,nr,ng,nc,nifa,nwfa,volg,surface_pressure,theta,u,uReconstructZonal,uReconstructMeridional"
    ncks -A -H -v "${var_list}" ana.nc mpasin.nc
    export err=$?
    err_chk
    mv ana.nc ..
  fi
  #
  # the input/output file are linked from the umbrella directory, so no need to copy
  cp "${DATA}"/jdiag* "${COMOUT}/jedivar/${WGF}"
  cp "${DATA}"/jedivar*.yaml "${COMOUT}/jedivar/${WGF}"
  cp "${DATA}"/log.out "${COMOUT}/jedivar/${WGF}"
  cp "${DATA}"/mpasin.nc "${COMOUT}/jedivar/${WGF}/mpasout.${timestr}.nc"

else
  echo "INFO: No DA at the cold start cycle"
fi

# copy satbias files which are not updated in the current cycle to satbias_out/
# this happens when some satellite data is missing or no DA at this cycle. 
# We need to roll them over for future cycles
#
nullglob_save=$(shopt -p nullglob) # Save current nullglob state
shopt -s nullglob # Enable nullglob
for path in data/satbias_in/*satbias*.nc; do
  file=${path##*/}
  if [[ ! -s "data/satbias_out/${file}" ]]; then
    echo "${file}" >> data/satbias_out/satbias.roll_over_list
    cp "${path}" data/satbias_out
  fi
done
#
# copy satabias_out to com/
satbias_list=(data/satbias_out/*satbias*.nc)
if (( ${#satbias_list[@]} > 0 )); then
#if ls ./data/satbias_out/*satbias*.nc >/dev/null 2>&1; then
  cp "${DATA}"/data/satbias_out/*satbias*.nc "${COMOUT}/jedivar/${WGF}"
fi
eval "${nullglob_save}" # Restore previous nullglob state


exit 0
