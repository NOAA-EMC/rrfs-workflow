#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1

#-----------------------------------------------------------------------
# Compute cycle time and previous cycle time (RRFS-style)
#-----------------------------------------------------------------------
CDATE="${PDY}${cyc}"              # current cycle: YYYYMMDDHH
PREV_CDATE="$("${NDATE}" -1 "${CDATE}")"
PREV_PDY="${PREV_CDATE:0:8}"     # previous cycle date
PREV_HOUR="${PREV_CDATE:8:2}"    # previous cycle hour

echo "CDATE=${CDATE}, PREV_CDATE=${PREV_CDATE}"
echo "PREV_PDY=${PREV_PDY}, PREV_HOUR=${PREV_HOUR}"

#-----------------------------------------------------------------------
# Copy VIIRS AOD converter into DATA
#-----------------------------------------------------------------------
HOMErdasapp="${HOMErrfs}/sorc/RDASApp"
${cpreq} "${HOMErdasapp}/sorc/iodaconv/src/compo/viirs_aod2ioda.py" .

#-----------------------------------------------------------------------
# Python libraries (RDASApp build)
#-----------------------------------------------------------------------
PYIODALIB=$(echo "${HOMErdasapp}"/build/lib/python3.*)
export PYTHONPATH="${PYIODALIB}:${PYTHONPATH}"

#-----------------------------------------------------------------------
# Locate VIIRS granules for this cycle
#-----------------------------------------------------------------------
AOD_DIR="${OBSPATH_VIIRS}/${PDY}"

# granules matching current cycle hour
FILES=$(ls "${AOD_DIR}"/JRR-AOD_v3r2_*_s"${PDY}${PREV_HOUR}"*.nc 2>/dev/null)

if [[ -z "${FILES}" ]]; then
  echo "FATAL ERROR: no VIIRS AOD granules found for CDATE=${PREV_CDATE} in ${AOD_DIR}"
  err_exit
fi

echo "Found VIIRS granules for CDATE=${PREV_CDATE}:"
printf '  %s\n' ${FILES}

#-----------------------------------------------------------------------
# Run VIIRS AOD → IODA for this single DA cycle
#-----------------------------------------------------------------------
THIN="0.94"
OUTFILE="VIIRS_AOD_CONUS_${PDY}_${cyc}.nc"

echo "Running VIIRS AOD → IODA:"
echo "  Input files : ${FILES}"
echo "  Output file : ${OUTFILE}"
echo "  Thinning    : ${THIN}"
echo "  Provider    : noaa"
echo "  Error method: nesdis"

python3 ./viirs_aod2ioda.py \
  -i ${FILES} \
  -o "${OUTFILE}" \
  --provider noaa \
  -n "${THIN}" \
  --error_method nesdis

#-----------------------------------------------------------------------
# Sanity check and copy to COMOUT
#-----------------------------------------------------------------------
if ls ./VIIRS_AOD_CONUS_"${PDY}"_"${cyc}".nc >/dev/null 2>&1; then
  ${cpreq} ./VIIRS_AOD_CONUS_"${PDY}"_"${cyc}".nc \
    "${COMOUT}/ioda_viirs/${WGF}"
else
  echo "FATAL ERROR: no VIIRS IODA files generated for NEXT_CDATE=${PREV_CDATE}"
  err_exit
fi

