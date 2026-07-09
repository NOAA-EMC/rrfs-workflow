#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2153

DUST_INITFILE=${UMBRELLA_PREP_CHEM_DATA}/dust.init.nc

DUST_INPUTDIR=${CHEM_INPUT}/dust/raw/
DUST_OUTPUTDIR=${DATA}
#
DUST_EXTERNAL=${CHEM_INPUT}/dust/processed/fengsha_dust_inputs.${MESH_NAME}.nc
#
if [[ -s ${DUST_EXTERNAL} ]]; then
   echo "Dust file exists, linking"
   ln -sf "${DUST_EXTERNAL}" "${DUST_INITFILE}"
else
   echo "Interpolated dust file: ${DUST_EXTERNAL} does not exist, will attempt to create"
   srun python -u "${SCRIPT}" \
              "FENGSHA_2D" \
              "${DATA}" \
              "${DUST_INPUTDIR}" \
              "${DUST_OUTPUTDIR}" \
              "${INTERP_WEIGHTS_DIR}" \
              "${YYYY}${MM}${DD}${HH}"
   OUTFILE_2D=${DUST_OUTPUTDIR}/fengsha_dust_inputs.2D.${MESH_NAME}.nc
   srun python -u "${SCRIPT}" \
              "FENGSHA_2D_Time" \
              "${DATA}" \
              "${DUST_INPUTDIR}" \
              "${DUST_OUTPUTDIR}" \
              "${INTERP_WEIGHTS_DIR}" \
              "${YYYY}${MM}${DD}${HH}"
   OUTFILE_2D_Time=${DUST_OUTPUTDIR}/fengsha_dust_inputs.2D_Time.${MESH_NAME}.nc

   ncrename -d Time,nMonths "${OUTFILE_2D_Time}"
   ncpdq -O -a nCells,nMonths "${OUTFILE_2D_Time}" "${OUTFILE_2D_Time}"

   ncks -A -v sandfrac,clayfrac,ssm,uthres "${OUTFILE_2D}" "${OUTFILE_2D_Time}"

   cp "${OUTFILE_2D_Time}" "${DUST_INITFILE}"
   ncrename -v ssm,ssm_in -v sandfrac,sandfrac_in -v clayfrac,clayfrac_in -v uthres,uthres_in -v rdrag,rdrag_m_in "${DUST_INITFILE}"

   ncks -O -x -v xtime "${DUST_INITFILE}" "${DUST_INITFILE}"
   ncks -A -v Time,xtime init.nc "${DUST_INITFILE}"

   ncks -O -6 "${DUST_INITFILE}" "${DUST_INITFILE}"
fi
