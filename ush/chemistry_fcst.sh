#!/usr/bin/env bash
# find ensemble forecasts based on user settings
#
# shellcheck disable=SC2154,SC2153
num_chem=0
#
# If any chemistry is activated, cat chemistry information to the namelist and stream_list
cat "${PARMrrfs}/chemistry/namelist.atmosphere" >> namelist.atmosphere
cat "${FIXrrfs}/stream_list/chemistry/stream_list.atmosphere.output" >> ./stream_list/stream_list.atmosphere.output
#
# Biogenic/Pollen
if [[ -r "${UMBRELLA_PREP_CHEM_DATA}/bio.init.nc" ]]; then
  sed -i '$e cat "${PARMrrfs}"/chemistry/streams.atmosphere.pollen' streams.atmosphere
  ln -snf ${UMBRELLA_PREP_CHEM_DATA}/bio.init.nc bio.init.nc
  #
  # Make sure pollen scheme is on
  if [[ "${DO_POLLEN}" -eq "TRUE" ]]; then
     sed -i "s/config_pollen_scheme\s*=\s*'off'/config_pollen_scheme  = 'speciated_pollen_primary'/g" namelist.atmosphere
     num_chem=$(( ${num_chem} + 4 ))
  fi
fi
# Dust
if [[ -r "${UMBRELLA_PREP_CHEM_DATA}/dust.init.nc" ]]; then
  sed -i '$e cat "${PARMrrfs}"/chemistry/streams.atmosphere.dust' streams.atmosphere
  ln -snf ${UMBRELLA_PREP_CHEM_DATA}/dust.init.nc dust.init.nc
  #
  # Make sure pollen scheme is on
  if [[ "${DO_DUST}" -eq "TRUE" ]]; then
     sed -i "s/config_dust_scheme\s*=\s*'off'/config_dust_scheme  = 'on'/g" namelist.atmosphere
     num_chem=$(( ${num_chem} + 2 ))
  fi
fi
# Anthropogenic
nanthrofiles=`ls ${UMBRELLA_PREP_CHEM_DATA}/anthro.init* | wc -l`
if [[ ${nanthrofiles} -gt 0 ]]; then
  sed -i '$e cat "${PARMrrfs}"/chemistry/streams.atmosphere.anthro' streams.atmosphere
  ln -snf ${UMBRELLA_PREP_CHEM_DATA}/anthro.init* ./
  #
  # Make sure anthro scheme is on
  if [[ "${DO_ANTHRO}" -eq "TRUE" ]]; then
     sed -i "s/config_anthro_scheme\s*=\s*'off'/config_anthro_scheme  = 'on'/g" namelist.atmosphere
     num_chem=$(( ${num_chem} + 6 ))
     if [[ "${DO_DUST}" -eq "TRUE" ]]; then
        num_chem=$(( ${num_chem} - 2 ))
     fi
     if [[ "${DO_SMOKE}" -eq "TRUE" ]]; then
        num_chem=$(( ${num_chem} - 2 ))
     fi
  fi
  
fi
# Smoke/Wildfire
nfirefiles=`ls ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.* | wc -l`
if [[ ${nfirefiles} -gt 0 ]]; then
  #
  cat "${FIXrrfs}/stream_list/chemistry/stream_list.atmosphere.smoke.output" >> ./stream_list/stream_list.atmosphere.output
  #
  if [[ "${EBB_DCYCLE}" -eq 1 ]]; then
     sed -i '$e cat "${PARMrrfs}"/chemistry/streams.atmosphere.smoke_retro' streams.atmosphere
  elif [[ "${EBB_DCYCLE}" -eq 2 ]]; then
     sed -i '$e cat "${PARMrrfs}"/chemistry/streams.atmosphere.smoke_forecast' streams.atmosphere
  else
     echo "Not appending any smoke stream"
  fi
  # TODO, retro vs. forecast option
  ln -snf ${UMBRELLA_PREP_CHEM_DATA}/smoke.init* ./
  #
  # Make sure smoke scheme is on
  if [[ "${DO_SMOKE}" -eq "TRUE" ]]; then
     sed -i "s/config_smoke_scheme\s*=\s*'off'/config_smoke_scheme = 'on'/g" namelist.atmosphere
     num_chem=$(( ${num_chem} + 2 ))
  fi
  # Set EBB_DCYCLE
  sed -e "s/@ebb_dcycle@/${EBB_DCYCLE}/" namelist.atmosphere 
fi
# RWC
if [[ -r "${UMBRELLA_PREP_CHEM_DATA}/rwc.init.nc" ]]; then
  sed -i '$e cat "${PARMrrfs}"/chemistry/streams.atmosphere.rwc' streams.atmosphere
  ln -snf ${UMBRELLA_PREP_CHEM_DATA}/rwc.init.nc rwc.init.nc
  # Set namelist
#      sed -e "s/@online_rwc_emis@/1/" "${PARMrrfs}"/namelist.atmosphere  > namelist.atmosphere 
fi
# Replace the num_chem value with the correct number
sed -i "s/num_chem\s*=\s*[0-9]*/num_chem  = ${num_chem}/" namelist.atmosphere
