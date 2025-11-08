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
CDATEp=CDATE
while ! found; do
  CDATEp=$(${NDATE} -"${increment_hours}" "${CDATEp}")
  mpasout=${COMINrrfs}/${RUN}.${CDATEp:0:8}/${CDATEp:8:2}/fcst/${WGF}${MEMDIR}/mpasout.${timestr}.nc
  if [[ -s "${mpasout}" ]]; then
    found=true
    break
  fi
done

if ${found}; then
   for species in "${species_list[@]}"; do
      # Check to see if the species is in the file
      ncdump -hv ${species} ${mpasout}
      if [[ $? -eq 0 ]]; then
        ncks -A -v ${species} ${mpasout} init.nc
      fi
   done
else
   for species in "${species_list[@]}"; do
     ncap2 -O -s "${species}=1.e-12*qv" init.nc init.nc
   done
fi
