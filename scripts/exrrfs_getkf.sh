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
ln -snf "${FIXrrfs}/physics/${PHYSICS_SUITE}"/* .
ln -snf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.ugwp_oro_data.nc" ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
ln -snf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix}" ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf "${FIXrrfs}/${MESH_NAME}"/graphinfo/* graphinfo/
${cpreq} "${FIXrrfs}/stream_list/${PHYSICS_SUITE}"/* stream_list/
${cpreq} "${FIXrrfs}"/jedi/obsop_name_map.yaml .
${cpreq} "${FIXrrfs}"/jedi/keptvars.yaml .
${cpreq} "${FIXrrfs}"/jedi/geovars.yaml .
#
# create data directory 
#
mkdir -p data; cd data || exit 1
mkdir -p obs ens jdiag
#
# copy observations files
#
if [[ "${GETKF_TYPE}" == "observer" ]]; then
  source "${USHrrfs}/copy_obs.sh" "getkf"
else
  ln -snf "${UMBRELLA_GETKF_OBSERVER_DATA}"/jdiag* jdiag/
fi
#
# determine whether to begin new cycles and link correct ensembles
#
do_DAcycling='false'
if [[ -r "${UMBRELLA_PREP_IC_DATA}/mem001/init.nc" ]]; then
  export start_type='cold'
  initial_file='init.nc'
else
  export start_type='warm'
  initial_file='mpasout.nc'
fi
# if cold_start or not do_radar_ref, remove refl10cm and w from stream_list.atmosphere.analysis
if [[ "${start_type}" == "cold"  ]] || ! ${DO_RADAR_REF} ; then
  sed -i '$d;N;$d' stream_list/stream_list.atmosphere.analysis
fi
# link ensembles to data/ens/
for i in $(seq -w 001 "${ENS_SIZE}"); do
  ln -snf "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}" "ens/mem${i}.nc"
done
#
# enter the run directory again
#
cd "${DATA}" || exit 1
#
# generate namelist, streams, and getkf.yaml on the fly
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
${cpreq} "${PARMrrfs}"/streams.atmosphere.getkf streams.atmosphere
export analysisDate="${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z"
CDATEm2=$(${NDATE} -2 "${CDATE}")
export beginDate="${CDATEm2:0:4}-${CDATEm2:4:2}-${CDATEm2:6:2}T${CDATEm2:8:2}:00:00Z"
#
# generate getkf.yaml based on how YAML_GEN_METHOD is set
case ${YAML_GEN_METHOD:-1} in
  1) # from ${PARMrrfs}
    cp "${EXPDIR}/config/getkf.yaml" getkf.yaml
    cp "${EXPDIR}/config/convinfo" .
    cp "${EXPDIR}/config/satinfo" .
    cp "${USHrrfs}/hifiyaml4rrfs.py" .
    cp "${USHrrfs}/yamltools4rrfs.py" .
    cp "${USHrrfs}/yaml_finalize" .
    ./yaml_finalize getkf.yaml
    ;;
  2) # cat together from inside sorc/RDASApp
    source "${USHrrfs}"/yaml_cat_together.sh
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
  # run mpasjedi_enkf.x
  #export OOPS_TRACE=1
  export OMP_NUM_THREADS=1

  source prep_step
  ${cpreq} "${EXECrrfs}"/mpasjedi_enkf.x .
  ${MPI_RUN_CMD} ./mpasjedi_enkf.x getkf.yaml log.out
  # check the status
  export err=$?
  err_chk
  #
  cp "${DATA}"/getkf*.yaml "${COMOUT}/getkf_${GETKF_TYPE}/${WGF}"
  cp "${DATA}"/log.* "${COMOUT}/getkf_${GETKF_TYPE}/${WGF}"

  # rename ombg to oman for posterior observer jdiag files
  if [[ "${GETKF_TYPE}" == "post" ]]; then
    for jdiag in "${DATA}"/jdiag*; do
      jdiag_tmp="${jdiag%.nc}_tmp.nc"
      nccopy -k 3 "${jdiag}" "${jdiag_tmp}"
      ncrename -g ombg,oman "${jdiag_tmp}"
      mv "${jdiag_tmp}" "${jdiag}"
    done
  fi

  # move jdiag* files to the umbrella directory if observer
  if [[ "${GETKF_TYPE}" == "observer" || "${GETKF_TYPE}" == "post" ]]; then
    cp "${DATA}"/jdiag* "${COMOUT}/getkf_${GETKF_TYPE}/${WGF}"
    mv jdiag* "${UMBRELLA_GETKF_DATA}"/.
  else # move post mean to umbrella if solver
    mv "${DATA}"/data/ens/mem000.nc "${UMBRELLA_GETKF_DATA}"/post_mean.nc
  fi

  # Save analysis files if requested
  if [[ "${GETKF_TYPE}" == "post" && "${SAVE_GETKF_ANL^^}" == "TRUE" ]]; then
    for mem in $(seq -w 1 030); do
      cp -rL "${DATA}"/data/ens/mem"${mem}".nc "${COMOUT}"/getkf_"${GETKF_TYPE}"/"${WGF}"/mem"${mem}".nc
    done
  fi

else
  echo "INFO: No DA at the cold start cycle"
fi
