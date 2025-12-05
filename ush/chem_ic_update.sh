#!/usr/bin/env bash
# Configure appropriate chemistry settings for the ic or lbc task
#
# shellcheck disable=SC2154,SC2153

species_list=(unspc_fine unspc_coarse dust_fine dust_coarse polp_tree polp_grass polp_weed pols_all polp_all ssalt_fine ssalt_coarse ch4)
# TODO, for now, only either cycle from previous output or reinitialize
# The realtime system and retros system will be able to use smoke and dust
# from the RRFS as initial and boundary conditions

# found a previous mpasout.nc, if found, copy its species content to init.nc
# otherwise, set small initial species values
found=false
look_back_hours=48
increment_hours=24
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S)
offset_hours=${increment_hours}
while [[ "${found}" == "false" ]] && (( 10#${offset_hours} <= 10#${look_back_hours} )); do
  CDATEp=$(${NDATE} -"${offset_hours}" "${CDATE}")
  mpasout=${COMINrrfs}/${RUN}.${CDATEp:0:8}/${CDATEp:8:2}/fcst/${WGF}${MEMDIR}/mpasout.${timestr}.nc
  if [[ -s "${mpasout}" ]]; then
    found=true
    break
  fi
  offset_hours=$(( 10#${offset_hours} + 10#${increment_hours} ))
done

if [[ "${found}" == "true" ]]; then
   for species in "${species_list[@]}"; do
      # Check to see if the species is in the file
      if ncdump -hv "${species}" "${mpasout}" 1>/dev/null; then
        ncks -A -v "${species}" "${mpasout}" init.nc
      fi
   done
else
   if [[ "${CHEM_GROUPS,,}" == *dust* ]]; then
     ncap2 -O -s "dust_fine=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "dust_coarse=1.e-12*qv" init.nc init.nc
   fi
   if [[ "${CHEM_GROUPS,,}" == *smoke* ]]; then
     ncap2 -O -s "smoke_fine=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "smoke_coarse=1.e-12*qv" init.nc init.nc
   fi
   if [[ "${CHEM_GROUPS,,}" == *pollen* ]]; then
     ncap2 -O -s "polp_tree=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "polp_grass=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "polp_weed=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "pols_all=1.e-12*qv" init.nc init.nc
   fi
   if [[ "${CHEM_GROUPS,,}" == *anthro* ]]; then
     ncap2 -O -s "smoke_fine=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "smoke_coarse=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "dust_fine=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "dust_coarse=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "unspc_fine=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "unspc_coarse=1.e-12*qv" init.nc init.nc
   fi
   if [[ "${CHEM_GROUPS,,}" == *ssalt* ]]; then
     ncap2 -O -s "ssalt_fine=1.e-12*qv" init.nc init.nc
     ncap2 -O -s "ssalt_coarse=1.e-12*qv" init.nc init.nc
   fi
fi
