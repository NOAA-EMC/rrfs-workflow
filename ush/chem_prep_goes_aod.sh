#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2153,SC2012
# Remove any old files
rm -f "${UMBRELLA_PREP_CHEM_DATA}"/goes.aod.init*nc # why we need this?
# 
GOES_INPUT=/scratch4/BMC/zrtrr/jdduda/smoke_mask/GOES
# output directories
GOES_OUTPUTDIR=${DATA}
# OUTPUTFILE=${UMBRELLA_PREP_CHEM_DATA}/goes.aod.init.nc

#
srun python -u "${SCRIPT}" \
               "GOES" \
               "${DATA}" \
               "${GOES_INPUT}" \
               "${GOES_OUTPUTDIR}" \
               "${INTERP_WEIGHTS_DIR}" \
               "${YYYY}${MM}${DD}${HH}"
mkdir -p logs
mv ./*.log ./*.ESMF_LogFile logs || echo "could not move logs"

