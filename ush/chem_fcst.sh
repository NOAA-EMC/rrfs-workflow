#!/usr/bin/env bash
# Configure appropriate chemistry settings for the fcst task
#
# shellcheck disable=SC2154,SC2153

num_chem=0
#
# add chemistry information to the namelist and stream_list
cat "${PARMrrfs}/chemistry/namelist.atmosphere" >> namelist.atmosphere
cat "${FIXrrfs}/chemistry/stream_list/stream_list.atmosphere.output" >> ./stream_list/stream_list.atmosphere.output
#
# Check if fire heat and moisture fluxes are turned on in the config
if [[ "${CONFIG_FIRE_HEATFLUX^^}" == "TRUE" ]]; then
  sed -i "s/\(add_fire_heat_flux\s*=\s*\).*/\1true/" namelist.atmosphere
fi
if [[ "${CONFIG_FIRE_MOISTFLUX^^}" == "TRUE" ]]; then
  sed -i "s/\(add_fire_moist_flux\s*=\s*\).*/\1true/" namelist.atmosphere
fi
# Biogenic/Pollen
if [[ "${CHEM_GROUPS,,}" == *pollen* ]]; then
   if [[ -s "${UMBRELLA_PREP_CHEM_DATA}/bio.init.nc" ]]; then
      sed -i "\$ e cat ${PARMrrfs}/chemistry/streams.atmosphere.pollen" streams.atmosphere # append before the last line (i.e. </stream>)
      cat "${FIXrrfs}/chemistry/stream_list/stream_list.atmosphere.output.pollen" >> ./stream_list/stream_list.atmosphere.output
      ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/bio.init.nc bio.init.nc
      sed -i "s/config_pollen_scheme\s*=\s*'off'/config_pollen_scheme  = 'speciated_primary'/g" namelist.atmosphere
      num_chem=$(( num_chem + 4 ))
   else
      echo "WARNING: No pollen emission file exists"
   fi
fi
# Sea Salt
if [[ "${CHEM_GROUPS,,}" == *ssalt* ]]; then
      sed -i "s/config_ssalt_scheme\s*=\s*'off'/config_ssalt_scheme  = 'on'/g" namelist.atmosphere
      num_chem=$(( num_chem + 2 ))
fi

# Dust
if [[ "${CHEM_GROUPS,,}" == *dust* ]]; then
  if [[ -s "${FIXrrfs}/chemistry/dust/fengsha_dust_inputs.${MESH_NAME}.nc" ]]; then
     ln -snf "${FIXrrfs}/chemistry/dust/fengsha_dust_inputs.${MESH_NAME}.nc" dust.init.nc
     cat "${FIXrrfs}/chemistry/stream_list/stream_list.atmosphere.output.dust" >> ./stream_list/stream_list.atmosphere.output
     sed -i "\$ e cat ${PARMrrfs}/chemistry/streams.atmosphere.dust" streams.atmosphere
     sed -i "s/config_dust_scheme\s*=\s*'off'/config_dust_scheme  = 'on'/g" namelist.atmosphere
     num_chem=$(( num_chem + 2 ))
     # Append the xtime variable if it is missing
     if ! ncdump -hv xtime dust.init.nc 1>/dev/null 2>&1; then
        ncks -A -v xtime init.nc dust.init.nc
     fi
  else
     echo "No fengsha_dust_input.${MESH_NAME}.nc file exists in ${FIXrrfs}, you can attempt to copy from one created in ${UMBRELLA_PREP_CHEM_DATA}, but otherwise cannot do dust, turning off in namelist"
     sed -i "s/config_dust_scheme\s*=\s*'on'/config_dust_scheme  = 'off'/g" namelist.atmosphere
  fi
fi
#
# save current nullglob setting and enable nullglob for this script
save_nullglob=$(shopt -p nullglob)
shopt -s nullglob

# Anthropogenic
if [[ "${CHEM_GROUPS,,}" == *anthro* ]]; then
files=("${UMBRELLA_PREP_CHEM_DATA}"/anthro.init*)
if (( ${#files[@]}  )); then  # at least one file exists
  sed -i "\$ e cat ${PARMrrfs}/chemistry/streams.atmosphere.anthro" streams.atmosphere
  ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/anthro.init* ./
  ptfiles=("${UMBRELLA_PREP_CHEM_DATA}"/anthro_pt.*)
  if (( ${#ptfiles[@]} )); then
     sed -i "\$ e cat ${PARMrrfs}/chemistry/streams.atmosphere.anthro_pt" streams.atmosphere
     sed -i "s/config_anthro_pt_scheme\s*=\s*'off'/config_anthro_pt_scheme = 'on'/g" namelist.atmosphere
     ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/anthro_pt.* ./
  fi
  for ifl in anthro*.nc 
  do
    ncks -O -6 "${ifl}" "${ifl}"
  done
  #
  sed -i "s/config_anthro_scheme\s*=\s*'off'/config_anthro_scheme  = 'simple_aero'/g" namelist.atmosphere
  #
  if [[ "${ANTHRO_EMISINV}" == *"GRA2PES"* ]] ; then
    sed -i "s/\(kanthro\s*=\s*\).*/\120/" namelist.atmosphere
  elif [[ "${ANTHRO_EMISINV}" == "NEMO" ]] ; then
    sed -i "s/\(kanthro\s*=\s*\).*/\11/" namelist.atmosphere
  else
    # Sets it to 1, but also prints your warning
    sed -i "s/\(kanthro\s*=\s*\).*/\11/" namelist.atmosphere
    echo "UNKNOWN ANTHRO_EMISINV = ${ANTHRO_EMISINV} .. unexpected results may occur, user beware"
  fi
  #
  num_chem=$(( num_chem + 1 ))
  if [[ "${CONFIG_COARSE}" == "TRUE" ]]; then
     num_chem=$(( num_chem + 1 ))
  fi
fi
fi

# Smoke/Wildfire
files=("${UMBRELLA_PREP_CHEM_DATA}"/smoke.init*)
if (( ${#files[@]}  )); then  # at least one file exists
  cat "${FIXrrfs}/chemistry/stream_list/stream_list.atmosphere.output.smoke" >> ./stream_list/stream_list.atmosphere.output
  #
  if (( EBB_DCYCLE == 1 )) || (( EBB_DCYCLE == -1 )); then  # Diurnal cycle for EBB (Emissions from Biomass Burning)
     sed -i "\$ e cat ${PARMrrfs}/chemistry/streams.atmosphere.smoke_retro" streams.atmosphere
  elif (( EBB_DCYCLE == 2 )); then
     sed -i "\$ e cat ${PARMrrfs}/chemistry/streams.atmosphere.smoke_forecast" streams.atmosphere
  else
     echo "Not appending any smoke stream"
  fi
  # TODO, retro vs. forecast option
  ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init* ./
  #
  if [[ "${CHEM_GROUPS,,}" == *smoke* ]]; then
     sed -i "s/config_smoke_scheme\s*=\s*'off'/config_smoke_scheme = 'on'/g" namelist.atmosphere
     num_chem=$(( num_chem + 1 ))
  fi
  if [[ "${CONFIG_COARSE}" == "TRUE" ]]; then
     num_chem=$(( num_chem + 1 ))
  fi
  added_smoke="TRUE"
  # Set EBB_DCYCLE
  sed -i -e "s/@ebb_dcycle@/${EBB_DCYCLE}/" namelist.atmosphere 
fi

# RWC - Residual Wood Combustion
if [[ -s "${UMBRELLA_PREP_CHEM_DATA}/rwc.init.nc" ]]; then
  sed -i "\$ e cat ${PARMrrfs}/chemistry/streams.atmosphere.rwc" streams.atmosphere
  ln -snf "${UMBRELLA_PREP_CHEM_DATA}"/rwc.init.nc rwc.init.nc
  # Set namelist
  sed -i "s/config_rwc_scheme\s*=\s*'off'/config_rwc_scheme = 'on'/g" namelist.atmosphere
  if [[ "${added_smoke}" == "TRUE" ]]; then
     echo "Smoke already added and num_chem adjusted"
  else
     num_chem=$(( num_chem + 1 ))
  fi
fi
#
# Extra chemical tracers
if (( "${#EXTRA_CHEMICAL_TRACERS[@]}" > 0 )); then
   n_extra=$(echo "${EXTRA_CHEMICAL_TRACERS//,/ }" | wc -w)
   echo "adding ${#EXTRA_CHEMICAL_TRACERS[@]} to the tracer list"
   sed -i "s/config_extra_chemical_tracers[[:space:]]*=[[:space:]]*''/config_extra_chemical_tracers = ',${EXTRA_CHEMICAL_TRACERS},'/g" namelist.atmosphere
   num_chem=$(( num_chem + n_extra ))
fi 

# MIE tables
if (( CONFIG_MIE_AOD_OPT > 0 )); then
   sed -i '/^&physics$/a \    aer_opt = 2' namelist.atmosphere
   if [[ -e "${FIXrrfs}/chemistry/optics/AERO_OPT.TBL" ]]; then
      echo "AERO_OPT.TBL exists in fix directory, linking to run dir"
      ln -s "${FIXrrfs}/chemistry/optics/AERO_OPT.TBL" .
      sed -i "s/\(config_mie_aod_opt\s*=\s*\).*/\1${CONFIG_MIE_AOD_OPT}/" namelist.atmosphere
   else
      # Linke the refract text files
      ln -s "${FIXrrfs}/chemistry/optics/refract*.txt" .
      srun -u python -u "${HOMErrfs}/ush/chem_prep_for_optics.py"
      if [[ -e "AERO_OPT.TBL" ]] ; then
         echo "AERO_OPT.TBL created successfully"
         sed -i "s/\(config_mie_aod_opt\s*=\s*\).*/\1${CONFIG_MIE_AOD_OPT}/" namelist.atmosphere
      else
         echo "Could not create AERO_OPT.TBL necessary for config_mie_aod_opt=${CONFIG_MIE_AOD_OPT}, resetting to 0"
         sed -i "s/\(config_mie_aod_opt\s*=\s*\).*/\10/"
      fi
   fi 
fi

#
# Replace the num_chem value with the correct number
sed -i "s/num_chem\s*=\s*[0-9]*/num_chem  = ${num_chem}/" namelist.atmosphere
# Make sure we didn't create any duplicates
awk '!seen[$0]++' ./stream_list/stream_list.atmosphere.output  > ./stream_list/temp_stream_list.atmosphere.output && mv ./stream_list/temp_stream_list.atmosphere.output ./stream_list/stream_list.atmosphere.output

#
# Restore previous nullglob setting
eval "${save_nullglob}"
