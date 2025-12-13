#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2017,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1
#
# find start and end time
#
fhr_chunk=$(( (10#${LENGTH}/10#${INTERVAL} + 1) / 10#${GROUP_TOTAL_NUM}*10#${INTERVAL} ))
fhr_begin=$((10#${OFFSET} + (10#${GROUP_INDEX} - 1 )*10#${fhr_chunk} ))
if (( 10#${GROUP_INDEX} == 10#${GROUP_TOTAL_NUM} )); then
  fhr_end=$(( 10#${OFFSET} + 10#${LENGTH}))
else
  fhr_end=$((10#${OFFSET} + (10#${GROUP_INDEX})*10#${fhr_chunk} - 10#${INTERVAL} ))
fi
fhr_all=$(seq $((10#${fhr_begin})) $((10#${INTERVAL})) $((10#${fhr_end} )) )

#
# generate the namelist on the fly
# required variables: init_case, start_time, end_time, nvertlevels, nsoillevels, nfglevles, nfgsoillevels,
# prefix, inerval_seconds, zeta_levels, decomp_file_prefix
#
init_case=9
CDATEin=$(${NDATE} "-${OFFSET}" "${CDATE}")
EDATE=$(${NDATE} "${fhr_begin}" "${CDATEin}")
start_time=$(date -d "${EDATE:0:8} ${EDATE:8:2}" +%Y-%m-%d_%H:%M:%S)
EDATE=$(${NDATE} "${fhr_end}" "${CDATEin}")
end_time=$(date -d "${EDATE:0:8} ${EDATE:8:2}" +%Y-%m-%d_%H:%M:%S)

if [[ "${prefix}" == "RAP" || "${prefix}" == "HRRR" ]]; then
  nfglevels=51
  nfgsoillevels=9
elif  [[ "${prefix}" == "RRFS" ]]; then
  nfglevels=66
  nfgsoillevels=9
elif  [[ "${prefix}" == "GFS" ]]; then
  nfglevels=58
  nfgsoillevels=4
elif  [[ "${prefix}" == "GEFS" ]]; then
  nfglevels=32
  nfgsoillevels=4
fi
nsoillevels=${NSOIL_LEVELS}

zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
ztop=$(tail -1 "${zeta_levels}")
nvertlevels=$(( $(wc -l < "${zeta_levels}") - 1 ))

interval_seconds=$((10#${INTERVAL}*3600)) # just a place holder as we use metatask to run lbc hour by hour
decomp_file_prefix="${MESH_NAME}.graph.info.part."
#
physics_suite=${PHYSICS_SUITE:-'PHYSICS_SUITE_not_defined'}
file_content=$(< "${PARMrrfs}/${physics_suite}/namelist.init_atmosphere") # read in all content
eval "echo \"${file_content}\"" > namelist.init_atmosphere

# update namelist.init_atmosphere if do_chemistry
if [[ "${DO_CHEMISTRY^^}" == "TRUE" ]]; then
  source "${USHrrfs}"/chem_namelist_init.sh
fi
#
# generate the streams file on the fly
# using sed as this file contains "filename_template='lbc.$Y-$M-$D_$h.$m.$s.nc'"
#
sed -e "s/@input_stream@/invariant.nc/" -e "s/@output_stream@/foo.nc/" \
    -e "s/@lbc_interval@/${INTERVAL}/" "${PARMrrfs}"/streams.init_atmosphere > streams.init_atmosphere

#
#prepare fix files and ungrib files for init_atmosphere
#
for fhr in  ${fhr_all}; do
  EDATE=$(${NDATE} "${fhr}" "${CDATEin}")
  timestring=$(date -d "${EDATE:0:8} ${EDATE:8:2}" +%Y-%m-%d_%H:%M:%S)
  ln -snf "${UMBRELLA_UNGRIB_LBC_DATA}/${prefix}:${timestring:0:13}" .
done
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
ln -snf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix}" ./invariant.nc
${cpreq} "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.static.nc" static.nc
${cpreq} "${FIXrrfs}/${MESH_NAME}/graphinfo/${MESH_NAME}.graph.info.part.${NTASKS}" .
ln -snf "${FIXrrfs}/physics/${PHYSICS_SUITE}/QNWFA_QNIFA_SIGMA_MONTHLY.dat" .

# run init_atmosphere_model
source prep_step
${cpreq} "${EXECrrfs}"/init_atmosphere_model.x .
${MPI_RUN_CMD} ./init_atmosphere_model.x
export err=$?; err_chk
if ! ls ./lbc*.nc; then
  echo "FATAL ERROR: failed to generate lbc files"
  err_exit
fi

# INFO: chem_lbc_update is unnecessary for smoke/dust w/ RAP/RRFS, but may be necessary for future mixed-model cases
#if [[ "${DO_CHEMISTRY^^}" == "TRUE" ]]; then
#  source "${USHrrfs}"/chem_lbc_update.sh
#fi

# copy lbc*.nc to COMOUT
${cpreq} "${DATA}"/lbc*.nc "${COMOUT}/lbc/${WGF}${MEMDIR}"
cp "${DATA}"/log.*.out "${COMOUT}/lbc/${WGF}${MEMDIR}"
