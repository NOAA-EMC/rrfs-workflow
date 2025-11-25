#!/usr/bin/env bash
# copy ioda observation files from com/ to the run directory
#
# shellcheck disable=SC2154
if [[ "$1" == "jedivar" ]]; then
  jedivar=true
else
  jedivar=false
fi

declare -A mappings  # Declare an associative array

if ${jedivar}; then
  obspath="${COMOUT}/ioda_bufr/${WGF}"
else # getkf
  obspath="${COMOUT}/ioda_bufr/${IODA_BUFR_WGF}"
fi
mappings["ioda_adpsfc.nc"]="${obspath}/ioda_adpsfc.nc"
mappings["ioda_adpupa.nc"]="${obspath}/ioda_adpupa.nc"
mappings["ioda_aircar.nc"]="${obspath}/ioda_aircar.nc"
mappings["ioda_aircft.nc"]="${obspath}/ioda_aircft.nc"
mappings["ioda_ascatw.nc"]="${obspath}/ioda_ascatw.nc"
mappings["ioda_msonet.nc"]="${obspath}/ioda_msonet.nc"
mappings["ioda_proflr.nc"]="${obspath}/ioda_proflr.nc"
mappings["ioda_rassda.nc"]="${obspath}/ioda_rassda.nc"
mappings["ioda_sfcshp.nc"]="${obspath}/ioda_sfcshp.nc"
mappings["ioda_vadwnd.nc"]="${obspath}/ioda_vadwnd.nc"
mappings["ioda_gnss_ztd.nc"]="${obspath}/ioda_gnss_ztd.nc"
# satellite observations
mappings["ioda_abi_g16.nc"]="${obspath}/ioda_abi_g16.nc"
mappings["ioda_abi_g18.nc"]="${obspath}/ioda_abi_g18.nc"
mappings["ioda_atms_npp.nc"]="${obspath}/ioda_atms_npp.nc"
mappings["ioda_atms_n20.nc"]="${obspath}/ioda_atms_n20.nc"
mappings["ioda_atms_n21.nc"]="${obspath}/ioda_atms_n21.nc"
mappings["ioda_crisf4_n20.nc"]="${obspath}/ioda_crisf4_n20.nc"
mappings["ioda_crisf4_n21.nc"]="${obspath}/ioda_crisf4_n21.nc"

if [[ "${DO_RADAR_REF^^}" == "TRUE" ]]; then
  if ${jedivar}; then
    obspath="${COMOUT}/ioda_mrms_refl/${WGF}"
  else # getkf
    obspath="${COMOUT}/ioda_mrms_refl/${IODA_BUFR_WGF}"
  fi
  mappings["ioda_mrms_refl.nc"]="${obspath}/ioda_mrms_${CDATE}_${time_min}.nc4"
fi

# loop through and copy files
for dst_file in "${!mappings[@]}"; do
  src_file=${mappings[${dst_file}]}
  if [[ -s "${src_file}" ]]; then
    cp "${src_file}"  "obs/${dst_file}"
  else
    echo "WARNING: ${src_file} does not exist!"
  fi
done
