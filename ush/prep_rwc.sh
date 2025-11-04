#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2153
#
# --- Set the file expression and lat/lon dimension names
#
INPUTDIR=${DATADIR_CHEM}/emissions/anthro/raw/NEMO/RWC/total/
NARR_INPUTDIR=${DATADIR_CHEM}/aux/narr_reanalysis_t2m/raw/

if [[ "${CREATE_OWN_DATA}" == "TRUE" ]]; then
   NARR_OUTPUTDIR=${DATA}
   OUTPUTDIR=${DATA}
else
   NARR_OUTPUTDIR=${DATADIR_CHEM}/aux/narr_reanalysis_t2m/processed/
   OUTPUTDIR=${DATADIR_CHEM}/emissions/anthro/processed/NEMO/RWC/total
fi
#
mkdir -p "${OUTPUTDIR}" 
mkdir -p "${NARR_OUTPUTDIR}"
# 
EMISFILE_RWC_PROCESSED=${OUTPUTDIR}/NEMO_RWC_ANNUAL_TOTAL_${MESH_NAME}.nc
#
if [[ ! -r "${EMISFILE_RWC_PROCESSED}" ]]; then
   srun python -u "${SCRIPT}" \
                    "NEMO" \
                    "${DATA}" \
                    "${INPUTDIR}" \
                    "${OUTPUTDIR}" \
                    "${INTERP_WEIGHTS_DIR}" \
                    "${YYYY}${MM}${DD}${HH}" \
                    "${MESH_NAME}"

   # Convert to how we want it
   ncap2 -O -s 'RWC_annual_sum=PEC+POC+PMOTHR' "${EMISFILE_RWC_PROCESSED}" "${EMISFILE_RWC_PROCESSED}"
   ncap2 -O -s 'RWC_annual_sum_smoke_fine=PEC+POC' "${EMISFILE_RWC_PROCESSED}"  "${EMISFILE_RWC_PROCESSED}"
   ncap2 -O -s 'RWC_annual_sum_smoke_coarse=0*RWC_annual_sum_smoke_fine' "${EMISFILE_RWC_PROCESSED}"  "${EMISFILE_RWC_PROCESSED}"
   ncrename -v PMOTHR,RWC_annual_sum_unspc_fine "${EMISFILE_RWC_PROCESSED}"
   ncrename -v PMC,RWC_annual_sum_unspc_coarse "${EMISFILE_RWC_PROCESSED}"
fi

# Regrid the summed minimum temperature equation:
EMISFILE_DENOM_PROCESSED=${NARR_OUTPUTDIR}/NEMO_RWC_DENOMINATOR_2017_${MESH_NAME}.nc
#
if [[ ! -r "${EMISFILE_DENOM_PROCESSED}" ]] ; then
     
  srun python -u "${SCRIPT}" \
         "NARR" \
         "${DATA}" \
         "${NARR_INPUTDIR}" \
         "${NARR_OUTPUTDIR}" \
         "${INTERP_WEIGHTS_DIR}" \
         "${YYYY}${MM}${DD}${HH}" \
         "${MESH_NAME}"

#
  ncks -A -v RWC_annual_sum,RWC_annual_sum_smoke_fine,RWC_annual_sum_smoke_coarse,RWC_annual_sum_unspc_fine,RWC_annual_sum_unspc_coarse "${EMISFILE_RWC_PROCESSED}" "${EMISFILE_DENOM_PROCESSED}"
  timestr3=$(date +%Y-%m-%d_%H:00:00 -d "$current_day")
  #shellcheck disable=SC2086
  ncap2 -O -s xtime=\"${timestr3}\"  "${EMISFILE_DENOM_PROCESSED}"  "${EMISFILE_DENOM_PROCESSED}"  
  ncks -O -6 "${EMISFILE_DENOM_PROCESSED}" "${EMISFILE_DENOM_PROCESSED}"
  #
  LINKEDEMISFILE=${UMBRELLA_PREP_CHEM_DATA}/rwc.init.nc
  #
  ln -sf "${EMISFILE_DENOM_PROCESSED}" "${LINKEDEMISFILE}"   

else
  ln -sf "${EMISFILE_DENOM_PROCESSED}" "${LINKEDEMISFILE}"
fi
