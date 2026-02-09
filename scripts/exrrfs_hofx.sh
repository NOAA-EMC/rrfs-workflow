#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1

do_DAcycling='true'
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
#
# create data directory
#
mkdir -p data; cd data || exit 1
mkdir -p obs satbias_in satbias_out
#for satllite radiance
ln -snf "${FIXrrfs}"/crtm/2.4.0_jedi crtm
cp "${FIXrrfs}"/satbias_init/*.tlapse.txt satbias_in/.
#cp "${UMBRELLA_PREP_IC_DATA}"/*satbias* satbias_in/.
#
cd "${DATA}" || exit 1
#
# generate namelist, streams, and hofx.yaml on the fly
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

# loop through all HOFX_FHRS
read -r -a hofx_array <<< "${HOFX_FHRS}"
for fhr in "${hofx_array[@]}"; do
  CDATEp=$( ${NDATE} "${fhr}" "${CDATE}" )
  start_time=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H:%M:%S) 
  timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S) 
  if [[ -s "${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc" ]]; then
    ln -snf "${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc" mpasout.nc
  else
    echo "f${fhr}h forecast not found"
    continue
  fi
  #
  # copy observations
  obspath="${IODA_PATH}/${RUN}.${CDATEp:0:8}/${CDATEp:8:2}/ioda_bufr/${WGF}"
  cp "${obspath}/ioda_adpsfc.nc" data/obs
  cp "${obspath}/ioda_adpupa.nc" data/obs
  cp "${obspath}/ioda_aircft.nc" data/obs
  cp "${obspath}/ioda_aircar.nc" data/obs
  #
  # generate namelists
  file_content=$(< "${PARMrrfs}/${physics_suite}/namelist.atmosphere") # read in all content
  eval "echo \"${file_content}\"" > namelist.atmosphere
  ${cpreq} "${PARMrrfs}"/streams.atmosphere.jedivar streams.atmosphere
  export analysisDate=""${CDATEp:0:4}-${CDATEp:4:2}-${CDATEp:6:2}T${CDATEp:8:2}:00:00Z""
  CDATEm2=$(${NDATE} -2 "${CDATEp}")
  export beginDate=""${CDATEm2:0:4}-${CDATEm2:4:2}-${CDATEm2:6:2}T${CDATEm2:8:2}:00:00Z""
  #
  # generate hofx.yaml
  sed -e "s/@beginDate@/${beginDate}/" -e "s/@analysisDate@/${analysisDate}/" \
    -e "s/@emptyObsSpaceAction@/${EMPTY_OBS_SPACE_ACTION}/" "${EXPDIR}/config/hofx.yaml" > hofx.yaml
  # run mpasjedi_hofx3d.x
  export OMP_NUM_THREADS=1
  source prep_step
  ${cpreq} "${EXECrrfs}"/mpasjedi_hofx3d.x .
  ${MPI_RUN_CMD} ./mpasjedi_hofx3d.x hofx.yaml log.out
  # check the status
  export err=$?
  err_chk

  # copy jdiag files to COMOUT and others
  rm -f data/obs/*
  mkdir -p "${COMOUT}/hofx/${WGF}/f${fhr}"
  mv "${DATA}"/jdiag* "${COMOUT}/hofx/${WGF}/f${fhr}"
  mv "${DATA}"/hofx*.yaml "${COMOUT}/hofx/${WGF}/f${fhr}"
  mv "${DATA}"/log.out "${COMOUT}/hofx/${WGF}/f${fhr}"
done

exit 0
