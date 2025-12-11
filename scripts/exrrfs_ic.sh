#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1
#
# generate the namelist on the fly
# required variables: init_case, start_time, end_time, nvertlevels, nsoillevels, nfglevles, nfgsoillevels,
# prefix, inerval_seconds, zeta_levels, decomp_file_prefix
#
init_case=7
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S)
end_time=${start_time}

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

interval_seconds=3600 # just a place holder
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
sed -e "s/@input_stream@/static.nc/" -e "s/@output_stream@/init.nc/" \
    -e "s/@lbc_interval@/3/" "${PARMrrfs}/streams.init_atmosphere" > streams.init_atmosphere
#
#prepare fix files and ungrib files for init_atmosphere
#
ln -snf "${UMBRELLA_UNGRIB_IC_DATA}/${prefix}:${start_time:0:13}" .
${cpreq} "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.static.nc" static.nc
${cpreq} "${FIXrrfs}/${MESH_NAME}/graphinfo/${MESH_NAME}.graph.info.part.${NTASKS}" .
ln -snf "${FIXrrfs}/physics/${PHYSICS_SUITE}/QNWFA_QNIFA_SIGMA_MONTHLY.dat" .

# run init_atmosphere_model
source prep_step
${cpreq} "${EXECrrfs}/init_atmosphere_model.x" .
${MPI_RUN_CMD} ./init_atmosphere_model.x
export err=$?; err_chk
if [[ ! -s './init.nc' ]]; then
  echo "FATAL ERROR: failed to generate init.nc"
  err_exit
fi

# add/update chemistry species to init.nc
if [[ "${DO_CHEMISTRY^^}" == "TRUE" ]]; then
  source "${USHrrfs}"/chem_ic_update.sh
fi

# copy init.nc to COMOUT
${cpreq} "${DATA}/init.nc" "${COMOUT}/ic/${WGF}${MEMDIR}"
cp "${DATA}"/log.*.out "${COMOUT}/ic/${WGF}${MEMDIR}"
