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
              "FENGSHA_1" \
              "${DATA}" \
              "${DUST_INPUTDIR}" \
              "${DUST_OUTPUTDIR}" \
              "${INTERP_WEIGHTS_DIR}" \
              "${YYYY}${MM}${DD}${HH}" \
              "${MESH_NAME}"
   OUTFILE_1=${DUST_OUTPUTDIR}/FENGSHA_2022_NESDIS_inputs_${MESH_NAME}_v3.2.nc

   srun python -u "${SCRIPT}" \
              "FENGSHA_2" \
              "${DATA}" \
              "${DUST_INPUTDIR}" \
              "${DUST_OUTPUTDIR}" \
              "${INTERP_WEIGHTS_DIR}" \
              "${YYYY}${MM}${DD}${HH}" \
              "${MESH_NAME}"
   OUTFILE_2=${DUST_OUTPUTDIR}/LAI_GVF_PC_DRAG_CLIMATOLOGY_2024v1.0.${MESH_NAME}.nc
   ncks -A -v feff "${OUTFILE_2}" "${OUTFILE_1}"
   cp "${OUTFILE_1}" "${DUST_INITFILE}"
   ncrename -d Time,nMonths "${DUST_INITFILE}"
   ncrename -v sep,sep_in -v sandfrac,sandfrac_in -v clayfrac,clayfrac_in -v uthres,uthres_in -v uthres_sg,uthres_sg_in -v feff,feff_m_in "${DUST_INITFILE}"
   ncdump -hv albedo_drag "${DUST_INITFILE}"
   #shellcheck disable=SC2181
   if [[ $? -eq 0 ]]; then
      # Processed old drag
      ncrename -v albedo_drag,albedo_drag_m_in "${DUST_INITFILE}"
   else
      # Old drag = new drag
      ncap2 -O -s 'albedo_drag_m_in=feff_m_in' "${DUST_INITFILE}" "${DUST_INITFILE}"
   fi   
   ncks -O -6 "${DUST_INITFILE}" "${DUST_INITFILE}"
fi
