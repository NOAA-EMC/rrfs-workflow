#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1

# link the AIRNOW files
${cpreq} "${OBSPATH_AIRNOW}/HourlyData_${CDATE}.dat" airnow
${cpreq} "${OBSPATH_AIRNOW}/monitoring_site_locations_${PDY}.dat" sites

HOMErdasapp=${HOMErrfs}/sorc/RDASApp/
${cpreq} "${HOMErdasapp}"/sorc/iodaconv/src/compo/airnow2ioda_nc.py .

# pyioda libraries
PYIODALIB=$(echo "$HOMErdasapp"/build/lib/python3.*)
export PYTHONPATH="${PYIODALIB}:${PYTHONPATH}"

# run the converter
./airnow2ioda_nc.py -i airnow -s sites -o ioda_airnow.nc

# file count sanity check and copy to COMOUT
if ls ./ioda*nc; then
  ${cpreq} "${DATA}"/ioda*.nc "${COMOUT}/ioda_airnow/${WGF}"
else
  echo "FATAL ERROR: no airnow ioda files generated."
  err_exit # err_exit if no ioda files generated at the development stage
fi
