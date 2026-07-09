#!/usr/bin/env bash
#
# Author: Jordan Schnell, CIRES/NOAA GSL
#
# This script prepares the emissions for an MPAS Aerosols simulation based on 
# user selections/task name, MPAS domain, and time period.
#
# The script first checks to see if emissions are already available 
# (regridded for the domain and time period) and links to the ${DATA} (i.e., the main run directory)
# If emissions are not available, the program attempts to create them.
#
## Required Input Arguments
#
# 1. CHEM_GROUP    -- which chem emission group is this task performing? (anthro, pollen, dust)
# 2. ANTHRO_EMISINV            -- undecided, may merge for custom dataset, or leave option to combine
# 3. CHEM_INPUT             -- location of interpolated files, ready to be used
# 4. MESH_NAME                -- name of the MPAS domain, required to know if we have weights or data intepolated to the domain
#
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
# rrfslint: file-disable=all
declare -rx PS4='+${SECONDS}s $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
nt=${SLURM_NTASKS}
cpreq=${cpreq:-cpreq}
cd "${DATA}" || exit 1
#
# find forecst length for this cycle
#
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
my_fcst_length=$("${USHrrfs}/find_fcst_length.sh" "${fcst_len_hrs_cycles}" "${cyc}" )
export FCST_LENGTH="${my_fcst_length}"  # FCST_LENGTH is needed by chem-regrid
echo "forecast length for this cycle is ${my_fcst_length}"
#
# ... Set some date variables
#
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S)
JJJ=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%j)
YYYY=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y)
MM=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%m)
DD=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%d)
HH=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%H)
DOW=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%u)  # 1-7, Monday-Sunday
#
YYYY_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${my_fcst_length} hours" +%Y)
MM_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${my_fcst_length} hours" +%m)
DD_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${my_fcst_length} hours" +%d)
HH_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${my_fcst_length} hours" +%H)
DOW_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${my_fcst_length} hours " +%A)  # 1-7, Monday-Sunday
#
YYYYp=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 1 day" +%Y)
MMp=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 1 day" +%m)
DDp=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 1 day" +%d)
HHp=$(date -d "${CDATE:0:8} ${CDATE:8:2}- 1 day" +%H)
#
current_day="${YYYY}${MM}${DD}"
current_hh="${HH}"
#
#prev_hh=$(date -d "$current_hh -24 hour" +"%H")
previous_day=$(date '+%C%y%m%d' -d "$current_day-1 days")
previous_day="${previous_day} ${HH}"
#
if [[ ${DOW} -le 5 ]]; then
   DOW_STRING=weekdy
elif [[ ${DOW} -eq 6 ]]; then
   DOW_STRING=satdy
else
   DOW_STRING=sundy
fi
if [[ ${DOW_END} -le 5 ]]; then
   DOW_END_STRING=weekdy
elif [[ ${DOW_END} -eq 6 ]]; then
   DOW_END_STRING=satdy
else
   DOW_END_STRING=sundy
fi
#
MOY=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%B)  # full month name (e.g., January)
MOY_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${my_fcst_length} hours" +%B)  # full month name (e.g., January)
DOY=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%j)  # Julian day 
#
if [[ "${DOY}" -ne 0 ]]; then
  DOY_m1=$(( 10#${DOY} - 1 ))
else
  DOY_m1=0
fi
#
DOY_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${my_fcst_length} hours" +%j)  # Julian day
#
# Set the init/mesh file name and link here:\
if [[ -r "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.static.nc" ]]; then
   ln -sf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.static.nc" init.nc
   INIT_FILE=./init.nc
elif [[ -r "${UMBRELLA_PREP_IC_DATA}"/init.nc ]]; then
   ln -sf "${UMBRELLA_PREP_IC_DATA}"/init.nc init.nc
   INIT_FILE=./init.nc
elif [[ -r "${UMBRELLA_PREP_IC_DATA}"/mpasout.nc ]]; then
   ln -sf "${UMBRELLA_PREP_IC_DATA}"/mpasout.nc init.nc
   INIT_FILE=./init.nc
else
   echo "FATAL: NO Init File available, cannot reinterpolate if files are missing, did you run the task out of order?"
   err_exit
fi
SCRIPT=${USHrrfs}/chem_regrid.py
VINTERP_SCRIPT=${USHrrfs}/chem_vinterp.py
INTERP_WEIGHTS_DIR=${CHEM_INPUT}/grids/interpolation_weights/
SCRIP_FILES_DIR=${CHEM_INPUT}/grids/scrip_files/
# Now set the same for the scrip file:
if [[ -s "${SCRIP_FILES_DIR}/mpas_${MESH_NAME}_scrip.nc" ]]; then
   ln -s "${SCRIP_FILES_DIR}/mpas_${MESH_NAME}_scrip.nc" ./
else
   echo "WARNING: NO SCRIP file available for this domain in ${SCRIP_FILES_DIR}, you will need to supply it as an argument to ${SCRIPT}"
fi
#
#
# Set a few things for the CONDA environment
export REGRID_WRAPPER_LOG_DIR=${DATA}
export PYTHONPATH="${REGRID_WRAPPER_DIR}/src":${PYTHONPATH}
#
#==================================================================================================#
if [[ "${CHEM_GROUP}" == "smoke" ]]; then
  source "${USHrrfs}"/chem_prep_smoke.sh
fi

if [[ "${CHEM_GROUP}" == "rwc" ]]; then
  source "${USHrrfs}"/chem_prep_rwc.sh
fi #rwc

if [[ "${CHEM_GROUP}" == "anthro" ]]; then
  source "${USHrrfs}"/chem_prep_anthro.sh
fi # anthro

if [[ "${CHEM_GROUP}" == "pollen" ]]; then
  source "${USHrrfs}"/chem_prep_pollen.sh
fi # bio/pollen

if [[ "${CHEM_GROUP}" == "GOES_AOD" ]] ; then
  source "${USHrrfs}"/chem_prep_goes_aod.sh
fi

if [[ "${CHEM_GROUP}" == "ssalt" ]] ; then
  echo "NOTHING to prepare -- exiting"
fi

if [[ "${CHEM_GROUP}" == "dust" ]]; then
  if [[ ! -s "${FIXrrfs}/chemistry/dust/fengsha_dust_inputs.${MESH_NAME}.nc" ]]; then
     source "${HOMErrfs}/workflow/tools/chem_prep_dust.sh"
     ${cpreq} "${UMBRELLA_PREP_CHEM_DATA}/dust.init.nc" "${FIXrrfs}/chemistry/dust/fengsha_dust_inputs.${MESH_NAME}.nc" 
     echo "INFO: The new dust.init.nc fix file: ${UMBRELLA_PREP_CHEM_DATA}/dust.init.nc has been copied to ${FIXrrfs}/chemistry/dust/fengsha_dust_inputs.${MESH_NAME}.nc"
  fi
fi # dust
