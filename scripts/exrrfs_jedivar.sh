#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1

start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
time_min="${subcyc:-00}"
#
# determine whether to begin new cycles
#
if [[ -r "${UMBRELLA_PREP_IC_DATA}/init.nc" ]]; then
  export start_type='cold'
  do_DAcycling='false'
  initial_file=init.nc
else
  export start_type='warm'
  do_DAcycling='true'
  initial_file=mpasout.nc
fi
#
# link fix files from physics, meshes, graphinfo, stream list, and jedi
#
ln -snf "${FIXrrfs}/physics/${PHYSICS_SUITE}"/*  .
ln -snf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.ugwp_oro_data.nc"  ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
ln -snf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix}"  ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf "${FIXrrfs}/${MESH_NAME}"/graphinfo/*  graphinfo/
${cpreq} "${FIXrrfs}/stream_list/${PHYSICS_SUITE}"/*  stream_list/
${cpreq} "${FIXrrfs}"/jedi/obsop_name_map.yaml .
${cpreq} "${FIXrrfs}"/jedi/keptvars.yaml .
${cpreq} "${FIXrrfs}"/jedi/geovars.yaml .
# if cold_start or not do_radar_ref, remove refl10cm and w from stream_list.atmosphere.analysis
if [[ "${start_type}" == "cold"  ]] || ! ${DO_RADAR_REF} ; then
  sed -i '$d;N;$d' stream_list/stream_list.atmosphere.analysis
fi
#
# create data directory
#
mkdir -p data; cd data || exit 1
mkdir -p obs ens satbias_in satbias_out
#
#  bump files and static BEC files
#
ln -snf "${FIXrrfs}/${MESH_NAME}/bumploc/${MESH_NAME}_L${nlevel}_${NTASKS}_401km11levels"  bumploc

if [[ ${STATIC_BEC_MODEL} == "GSIBEC" ]]; then
  # gsibec
  ln -snf "${FIXrrfs}/gsi_bec/berror_stats" "${DATA}"/berror_stats
  ln -snf "${FIXrrfs}/gsi_bec/mpas_pave_L${nlevel}.txt" "${DATA}"/mpas_pave.txt
  ${cpreq} "${FIXrrfs}/gsi_bec/gsiparm_regional.anl" "${DATA}"/gsiparm_regional.anl
  nlevelm1=$((nlevel - 1))
  sed -i -e "s/@GSIBEC_NLAT@/${GSIBEC_NLAT}/" -e "s/@GSIBEC_NLON@/${GSIBEC_NLON}/" -e "s/@GSIBEC_NSIG@/${nlevelm1}/" \
         -e "s/@GSIBEC_LAT_START@/${GSIBEC_LAT_START}/" -e "s/@GSIBEC_LAT_END@/${GSIBEC_LAT_END}/" \
         -e "s/@GSIBEC_LON_START@/${GSIBEC_LON_START}/" -e "s/@GSIBEC_LON_END@/${GSIBEC_LON_END}/" \
         -e "s/@GSIBEC_NORTH_POLE_LAT@/${GSIBEC_NORTH_POLE_LAT}/"  -e "s/@GSIBEC_NORTH_POLE_LON@/${GSIBEC_NORTH_POLE_LON}/"  \
         -e "s/@GSIBEC_NSIGP1@/${nlevel}/"       "${DATA}"/gsiparm_regional.anl
else
  # bump bec
  mkdir -p static_bec
  ln -snf "${FIXrrfs}/${MESH_NAME}/static_bec/${MESH_NAME}_L${nlevel}/stddev.nc"  static_bec/stddev.nc
  ln -snf "${FIXrrfs}/${MESH_NAME}/static_bec/${MESH_NAME}_L${nlevel}/nicas_${NTASKS}"  static_bec/nicas
  ln -snf "${FIXrrfs}/${MESH_NAME}/static_bec/${MESH_NAME}_L${nlevel}/vbal_${NTASKS}"  static_bec/vbal
  ${cpreq}  "${EXPDIR}/config/bec_bump.yaml" "${DATA}"/bec_bump.yaml
fi

#for satllite radiance
ln -snf "${FIXrrfs}"/crtm/2.4.0_jedi crtm
cp "${FIXrrfs}"/satbias_init/*.tlapse.txt satbias_in/.
cp "${UMBRELLA_PREP_IC_DATA}"/*satbias* satbias_in/.

#
# copy observations files
#
source "${USHrrfs}/copy_obs.sh" "jedivar"
#
#  find ensemble forecasts based on user settings
#
source "${USHrrfs}/find_ensembles.sh"
#
#  link background
#
cd "${DATA}" || exit 1
ln -snf "${UMBRELLA_PREP_IC_DATA}/${initial_file}" .
if [[ ${start_type} == "warm" ]] && [[ ${SNUDGETYPES} != "" ]]; then
    var_list="qv,surface_pressure,theta,tslb,smois,snowh,soilt1,skintemp"
    ncks -C -v ${var_list} ${initial_file} soilbg.nc
fi
#
# generate namelist, streams, and jedivar.yaml on the fly
run_duration=1:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="true" #true
pio_num_iotasks=${NODES}
pio_stride=${PPN}

# We set dt, substeps, radt values to avoid errors in reading namelist.atmosphere
# but they will NOT be used since no model integration in DA steps
dt=60
substeps=2
radt=30

file_content=$(< "${PARMrrfs}/${physics_suite}/namelist.atmosphere") # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere
${cpreq} "${PARMrrfs}"/streams.atmosphere.jedivar streams.atmosphere
export analysisDate=""${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z""
CDATEm2=$(${NDATE} -2 "${CDATE}")
export beginDate=""${CDATEm2:0:4}-${CDATEm2:4:2}-${CDATEm2:6:2}T${CDATEm2:8:2}:00:00Z""
#
# generate jedivar.yaml based on how YAML_GEN_METHOD is set
case ${YAML_GEN_METHOD:-1} in
  1) # from ${PARMrrfs}
    cp "${EXPDIR}/config/jedivar.yaml" jedivar.yaml
    cp "${EXPDIR}/config/convinfo" .
    cp "${EXPDIR}/config/satinfo" .
    cp "${USHrrfs}/hifiyaml4rrfs.py" .
    cp "${USHrrfs}/yamltools4rrfs.py" .
    cp "${USHrrfs}/yaml_finalize" .
    ./yaml_finalize jedivar.yaml
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

if [[ ${start_type} == "warm" ]] || [[ ${start_type} == "cold" && ${COLDSTART_CYCS_DO_DA^^} == "TRUE" ]]; then
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
  if [[ ${start_type} == "warm" ]] && [[ ${SNUDGETYPES} != "" ]]; then
      # pyioda libraries
      PYIODALIB=$(echo "$HOMErdasapp"/build/lib/python3.*)
      export PYTHONPATH="${PYIODALIB}:${PYTHONPATH}"
      "${USHrrfs}"/snudge.py "${CDATE}" "${SNUDGETYPES}" "${DATA}/${initial_file}"
      if [[ ! -s "soil_analyzed.nc" ]]; then
        echo "Warning: soil nudging failed"
      else
        var_list="tslb,smois,soilt1,skintemp"
        ncks -A -v ${var_list} soil_analyzed.nc "${UMBRELLA_PREP_IC_DATA}/${initial_file}"
      fi
  fi
  # the input/output file are linked from the umbrella directory, so no need to copy
  cp "${DATA}/${initial_file}" "${COMOUT}/jedivar/${WGF}/${initial_file%.nc}.${timestr}.nc"
  cp "${DATA}"/jdiag* "${COMOUT}/jedivar/${WGF}"
  cp "${DATA}"/jedivar*.yaml "${COMOUT}/jedivar/${WGF}"
  cp "${DATA}"/log.out "${COMOUT}/jedivar/${WGF}"

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
