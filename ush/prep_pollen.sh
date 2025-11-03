#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2153
#
EMISINPUTDIR=${DATADIR_CHEM}/emissions/pollen/raw/${YYYY}/
if [[ "${CREATE_OWN_DATA}" == "TRUE" ]]; then
   EMISOUTPUTDIR=${DATA}
else
   EMISOUTPUTDIR=${DATADIR_CHEM}/emissions/pollen/processed/${YYYY}/
fi
mkdir -p "${EMISOUTPUTDIR}"
#
# --- Do we have emissions regridded to our domain?
# --- If we already have the emissions, link them..
#
EMISFILE=${EMISOUTPUTDIR}/pollen_ef_${MESH_NAME}_${YYYY}_${DOY}.nc
LINKEDEMISFILE=${UMBRELLA_PREP_CHEM_DATA}/bio.init.nc
if [ ! -r "${EMISFILE}" ]; then
   echo "No pollen input file regridded to this specific day and mesh: ${EMISFILE}, will look for a file to interpolate"
else
   ln -sf "${EMISFILE}" "${LINKEDEMISFILE}"
   echo "Linked pollen file ${EMISFILE}, exiting"
   exit 0  # do we need to exit the whole exrrfs_prep_chem.sh?
fi
#
# -- Look for the base emission file
#
EMISFILE_BASE=${EMISINPUTDIR}/pollen_obs_${YYYY}_BELD6_ef_T_${DOY}.nc
if [[ -r "${EMISFILE_BASE}" ]];then
   echo "Found base emission file: ${EMISFILE_BASE}"
else
   echo "Cannot regrid, no base emission file: ${EMISFILE_BASE}"
   exit 1  # do we need to exit the whole exrrfs_prep_chem.sh?
fi
srun python -u "${SCRIPT}" \
           "PECM" \
           "${DATA}" \
           "${EMISINPUTDIR}" \
           "${EMISOUTPUTDIR}" \
           "${INTERP_WEIGHTS_DIR}" \
           "${YYYY}${MM}${DD}${HH}" \
           "${MESH_NAME}"
if [ ! -r "${EMISFILE}" ]; then
   echo "Regrid failed, check the logs"
   exit 1 # do we need to exit the whole exrrfs_prep_chem.sh?
else
   ncrename -v GRA_POLL,e_bio_in_polp_grass -v RAG_POLL,e_bio_in_polp_weed -v TREE_POLL,e_bio_in_polp_tree "${EMISFILE}"
   ncks -O -6 "${EMISFILE}" "${EMISFILE}"
   ln -sf "${EMISFILE}" "${LINKEDEMISFILE}"
   echo "Linked pollen file ${EMISFILE}, exiting"
fi
