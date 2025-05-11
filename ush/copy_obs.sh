#!/usr/bin/env bash
# copy ioda observation files from com/ to the run directory
#
# shellcheck disable=SC2154,SC2034
if [[ "$1" == "jedivar" ]]; then
  jedivar=true
else
  jedivar=false
fi

declare -A mappings  # Declare an associative array

if jedivar; then
  obspath="${COMOUT}/ioda_bufr/${WGF}"
else # getkf
  obspath="${COMOUT}/ioda_bufr/${IODA_BUFR_WGF}"
fi
mappings["${obspath}/ioda_adpsfc.nc"]="ioda_adpsfc.nc"
mappings["${obspath}/ioda_adpupa.nc"]="ioda_adpupa.nc"
mappings["${obspath}/ioda_aircar.nc"]="ioda_aircar.nc"
mappings["${obspath}/ioda_aircft.nc"]="ioda_aircft.nc"
mappings["${obspath}/ioda_ascatw.nc"]="ioda_ascatw.nc"
mappings["${obspath}/ioda_msonet.nc"]="ioda_msonet.nc"
mappings["${obspath}/ioda_proflr.nc"]="ioda_proflr.nc"
mappings["${obspath}/ioda_rassda.nc"]="ioda_rassda.nc"
mappings["${obspath}/ioda_sfcshp.nc"]="ioda_sfcshp.nc"
mappings["${obspath}/ioda_vadwnd.nc"]="ioda_vadwnd.nc"

if [[ "${DO_ENVAR_RADAR_REF}" == "true" ]] && jedivar; then
  obspath="${COMOUT}/ioda_mrms_refl/${WGF}"
  mappings["${obspath}/ioda_mrms_${CDATE}_${time_min}.nc4"]="ioda_mrms_refl.nc"
fi

# loop through and copy files
for src_file in "${!mappings[@]}"; do
  if [[ ! -s "${src_file}" ]]; then
    cp "${src_file}"  "${mappings[${src_file}]}"
  else
    echo "WARNING: ${src_file} does not exist!"
  fi
done
