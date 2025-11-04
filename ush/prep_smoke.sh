#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2153,SC2012
# Remove any old files
rm -f "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init*nc # why we need this?
#
if [[ ! ${RAVE_DIR} ]]; then
  RAVE_INPUTDIR=/public/data/grids/nesdis/3km_fire_emissions/
else
  RAVE_INPUTDIR=${RAVE_DIR}/raw/
fi
ECO_INPUTDIR=${DATADIR_CHEM}/aux/ecoregion/raw/
FMC_INPUTDIR=${DATADIR_CHEM}/aux/FMC/raw/${YYYY}/${MM}/

if [[ "${CREATE_OWN_DATA}" == "TRUE" ]]; then
  RAVE_OUTPUTDIR=${DATA}
  ECO_OUTPUTDIR=${DATA}
  FMC_OUTPUTDIR=${DATA}
else
  # TODO, check for pregenerated data
  RAVE_OUTPUTDIR=${RAVE_DIR}/processed/
  ECO_OUTPUTDIR=${DATADIR_CHEM}/aux/ecoregion/processed/
  FMC_OUTPUTDIR=${DATADIR_CHEM}/aux/FMC/processed/${YYYY}/${MM}/
fi
#
dummyRAVE=${RAVE_DIR}/processed/RAVE.dummy.${MESH_NAME}.nc
if [[ ! -e ${dummyRAVE} ]]; then
   shared_dummy_rave=${DATADIR_CHEM}/emissions/RAVE/processed/RAVE.dummy.${MESH_NAME}.nc
   if [[ -e ${shared_dummy_rave} ]]; then
      echo "Dummy RAVE file being copied from ${shared_dummy_rave} to ${dummyRAVE}"
      cp "${shared_dummy_rave}" "${dummyRAVE}"
   else
      echo "Shared dummy RAVE does not exist for this mesh"
      echo "If any RAVE files are missing, your simulation will error.. (for now)"
   fi
else
   echo "Will use dummy RAVE file: ${dummyRAVE}"
fi
mkdir -p "${RAVE_OUTPUTDIR}"
mkdir -p "${ECO_OUTPUTDIR}"
mkdir -p "${FMC_OUTPUTDIR}"
#
srun python -u "${SCRIPT}" \
               "RAVE" \
               "${DATA}" \
               "${RAVE_INPUTDIR}" \
               "${RAVE_OUTPUTDIR}" \
               "${INTERP_WEIGHTS_DIR}" \
               "${YYYY}${MM}${DD}${HH}" \
               "${MESH_NAME}"  # CDATE?
mv ./*.log ./*.ESMF_LogFile logs || echo "could not move logs"
#
# Look for a file to create a dummy file if one doesn't already exist
if [[ ! -e ${dummyRAVE} ]]; then
 if [[ $(ls -A "${RAVE_OUTPUTDIR}/${MESH_NAME}*") ]]; then
    dummyRAVEtemplate=$(ls "${RAVE_OUTPUTDIR}/${MESH_NAME}*" | head -n 1)
    echo "Dummy RAVE file doesn't exist, but creating one using: ${dummyRAVEtemplate}"
    cp "${dummyRAVEtemplate}" "${dummyRAVE}"
    ncap2 -O -s 'e_bb_in_smoke_fine=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
    ncap2 -O -s 'e_bb_in_smoke_coarse=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
    ncap2 -O -s 'e_bb_in_smoke_so2=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
    ncap2 -O -s 'e_bb_in_smoke_ch4=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
    ncap2 -O -s 'e_bb_in_smoke_nh3=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
    ncap2 -O -s 'frp_in=0.*frp_in' "${dummyRAVE}" "${dummyRAVE}"
    ncap2 -O -s 'fre_in=0.*fre_in' "${dummyRAVE}" "${dummyRAVE}"
  else
      echo "Do not have and cannot create dummy RAVE file as no RAVE data is available"
 fi 
fi
# Loop through the hours and link the files so they have the correct filename and variable names 
# TODO - Update variable names via outside script or within regrid.py -- mapping table?
for ihour in $(seq 0 "${FCST_LENGTH}"); 
do
#
   if [[ ${ihour} -gt 24 ]]; then
      ihour2=$((ihour-24))
   else
      ihour2=${ihour}
   fi
   timestr1=$(date +%Y%m%d%H -d "$previous_day + $ihour2 hours")
   timestr2=$(date +%Y-%m-%d_%H -d "$current_day + $ihour hours")
   timestr3=$(date +%Y-%m-%d_%H:00:00 -d "$current_day + $ihour hours")
#
   EMISFILE=${UMBRELLA_PREP_CHEM_DATA}/smoke.init.retro.${timestr2}.00.00.nc
   EMISFILE2="${RAVE_OUTPUTDIR}/${MESH_NAME}-RAVE-${timestr1}.nc"
   if [[ -r "${EMISFILE2}" ]]; then
      ncrename -v PM25,e_bb_in_smoke_fine "${EMISFILE2}"
      ncrename -v FRP_MEAN,frp_in -v FRE,fre_in "${EMISFILE2}"
      ncrename -v SO2,e_bb_in_so2 -v NH3,e_bb_in_nh3 "${EMISFILE2}"
      ncrename -v CH4,e_bb_in_ch4 "${EMISFILE2}"
      ncrename -v PM10,e_bb_in_smoke_coarse "${EMISFILE2}"
      ln -sf "${EMISFILE2}" "${EMISFILE}"
   else
      cp "${dummyRAVE}" "${EMISFILE}"
   fi
   ncks -O -6 "${EMISFILE}" "${EMISFILE}"
   ncks -A -v xtime "${DATA}/${MESH_NAME}.init.nc" "${EMISFILE}"
   #shellcheck disable=SC2086
   ncap2 -O -s xtime=\"${timestr3}\" "${EMISFILE}" "${EMISFILE}"  
#
done
#
#
echo "Concatenating hourly files for use in forecast mode"
# Concatenate for ebb2
ncrcat "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.retro.*.00.00.nc "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc
#
# Calculate previous 24 hour average HWP
#
# TODO - presently hwp and totprcp have constant values
ncap2 -O -s 'hwp_prev24=0.0*frp_in+30.' -s 'totprcp_prev24=0.0*frp_in+0.1' "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc
ncrename -v frp_in,frp_prev24 -v fre_in,fre_prev24 "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc
#
# Emissions to be calculated inside of model
if [[ ! -r "${ECO_OUTPUTDIR}/ecoregions_${MESH_NAME}_mpas.nc" ]] && [[ -r "${ECO_INPUTDIR}/veg_map.nc" ]]; then
   echo "Regridding ECO_REGION"
   srun python -u "${SCRIPT}"   \
                   "ECOREGION" \
                   "${DATA}" \
                   "${ECO_INPUTDIR}" \
                   "${ECO_OUTPUTDIR}" \
                   "${INTERP_WEIGHTS_DIR}" \
                   "${YYYY}${MM}${DD}${HH}" \
                   "${MESH_NAME}"

  ncks -A -v ecoregion_ID "${ECO_OUTPUTDIR}/ecoregions_${MESH_NAME}_mpas.nc" "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc
fi
# 
n_fmc=$(ls "${FMC_INPUTDIR}/fmc_${YYYY}${MM}${DD}"* | wc -l)
if [[ ${n_fmc} -gt 0 ]]; then
  echo "Have at least some soil moisture information, will interpolate"
     ln -s "${FMC_INPUTDIR}"/* "${DATA}"/
     srun python -u "${SCRIPT}"   \
                     "FMC" \
                     "${DATA}" \
                     "${FMC_INPUTDIR}" \
                     "${FMC_OUTPUTDIR}" \
                     "${INTERP_WEIGHTS_DIR}" \
                     "${YYYY}${MM}${DD}${HH}" \
                     "${MESH_NAME}"
  # Average for ebb2
  ncrcat "${FMC_OUTPUTDIR}"/fmc*"${MESH_NAME}"*nc "${UMBRELLA_PREP_CHEM_DATA}"/fmc.init.nc
  ncks -A -v 10h_dead_fuel_moisture_content "${UMBRELLA_PREP_CHEM_DATA}"/fmc.init.nc "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc
  ncrename -v 10h_dead_fuel_moisture_content,fmc_prev24 "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc
else
  echo "No soil moisture information available, using static value of 0.2"
  ncap2 -O -s 'fmc_prev24=0*frp_prev24+0.2' "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc "${UMBRELLA_PREP_CHEM_DATA}"/smoke.init.nc
fi
