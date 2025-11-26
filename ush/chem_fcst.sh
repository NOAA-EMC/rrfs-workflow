#!/usr/bin/env bash
# Configure appropriate chemistry settings for the fcst task
#
# shellcheck disable=SC2154,SC2153

num_chem=0
#
# add chemistry information to the namelist and stream_list
cat "${PARMrrfs}/chemistry/namelist.atmosphere" >> namelist.atmosphere
cat "${FIXrrfs}/stream_list/chemistry/stream_list.atmosphere.output" >> ./stream_list/stream_list.atmosphere.output
#
# Biogenic/Pollen
if [[ -r "${UMBRELLA_PREP_CHEM_DATA}/bio.init.nc" ]]; then
  sed -i "\$e cat ${PARMrrfs}/chemistry/streams.atmosphere.pollen" streams.atmosphere # append before the last line (i.e. </stream>)
  ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/bio.init.nc bio.init.nc
  #
  if [[ "${CHEM_GROUPS,,}" == *pollen* ]]; then
     sed -i "s/config_pollen_scheme\s*=\s*'off'/config_pollen_scheme  = 'speciated_pollen_primary'/g" namelist.atmosphere
     num_chem=$(( num_chem + 4 ))
  fi
fi
# Dust
if [[ "${CHEM_GROUPS,,}" == *dust* ]]; then
   ln -snf "${FIXrrfs}/chem_input/dust/fengsha_dust_inputs.${MESH_NAME}.nc" dust.init.nc
   sed -i "s/config_dust_scheme\s*=\s*'off'/config_dust_scheme  = 'on'/g" namelist.atmosphere
   num_chem=$(( num_chem + 2 ))
fi
#
# save current nullglob setting and enable nullglob for this script
save_nullglob=$(shopt -p nullglob)
shopt -s nullglob

# Anthropogenic
files=("${UMBRELLA_PREP_CHEM_DATA}"/anthro.init*)
if (( ${#files[@]}  )); then  # at least one file exists
  sed -i "\$e cat ${PARMrrfs}/chemistry/streams.atmosphere.anthro" streams.atmosphere
  ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/anthro.init* ./
  #
  if [[ "${CHEM_GROUPS,,}" == *anthro* ]]; then
     sed -i "s/config_anthro_scheme\s*=\s*'off'/config_anthro_scheme  = 'on'/g" namelist.atmosphere
     num_chem=$(( num_chem + 6 ))
     if [[ "${CHEM_GROUPS,,}" == *dust* ]]; then
        num_chem=$(( num_chem - 2 ))
     fi
     if [[ "${CHEM_GROUPS,,}" == *smoke* ]]; then
        num_chem=$(( num_chem - 2 ))
     fi
  fi
fi

# Smoke/Wildfire
files=("${UMBRELLA_PREP_CHEM_DATA}"/smoke.init*)
if (( ${#files[@]}  )); then  # at least one file exists
  cat "${FIXrrfs}/stream_list/chemistry/stream_list.atmosphere.output.smoke" >> ./stream_list/stream_list.atmosphere.output
  #
  if [[ "${EBB_DCYCLE}" -eq 1 ]]; then  # Diurnal cycle for EBB (Emissions from Biomass Burning)
     sed -i "\$e cat ${PARMrrfs}/chemistry/streams.atmosphere.smoke_retro" streams.atmosphere
  elif [[ "${EBB_DCYCLE}" -eq 2 ]]; then
     sed -i "\$e cat ${PARMrrfs}/chemistry/streams.atmosphere.smoke_forecast" streams.atmosphere
  else
     echo "Not appending any smoke stream"
  fi
  # TODO, retro vs. forecast option
  ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init* ./
  #
  if [[ "${CHEM_GROUPS,,}" == *smoke* ]]; then
     sed -i "s/config_smoke_scheme\s*=\s*'off'/config_smoke_scheme = 'on'/g" namelist.atmosphere
     num_chem=$(( num_chem + 2 ))
  fi
  # Set EBB_DCYCLE
  sed -i -e "s/@ebb_dcycle@/${EBB_DCYCLE}/" namelist.atmosphere 
fi

# RWC - Residual Wood Combustion
if [[ -r "${UMBRELLA_PREP_CHEM_DATA}/rwc.init.nc" ]]; then
  sed -i "\$e cat ${PARMrrfs}/chemistry/streams.atmosphere.rwc" streams.atmosphere
  ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/rwc.init.nc rwc.init.nc
  # Set namelist
  #sed -e "s/@online_rwc_emis@/1/" "${PARMrrfs}"/namelist.atmosphere  > namelist.atmosphere 
fi
#
# Replace the num_chem value with the correct number
sed -i "s/num_chem\s*=\s*[0-9]*/num_chem  = ${num_chem}/" namelist.atmosphere
#
# Restore previous nullglob setting
eval "${save_nullglob}"
