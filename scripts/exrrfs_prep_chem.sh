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
# 1. EMIS_SECTOR_TO_PROCESS    -- which emission sector is this task performing? (anthro, pollen, dust)
# 2. ANTHRO_EMISINV            -- undecided, may merge for custom dataset, or leave option to combine
# 3. DATADIR_CHEM             -- location of interpolated files, ready to be used
# 4. MESH_NAME                -- name of the MPAS domain, required to know if we have weights or data intepolated to the domain 
# 5. FCST_LENGTH               -- nhours of forecast
#
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
nt=${SLURM_NTASKS}
cpreq=${cpreq:-cpreq}
cd "${DATA}" || exit 1
#
# ... Set some date variables
#
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S)
YYYY=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y)
MM=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%m)
DD=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%d)
HH=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%H)
DOW=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%u)  # 1-7, Monday-Sunday
#
YYYY_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${FCST_LENGTH} hours" +%Y)
MM_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${FCST_LENGTH} hours" +%m)
DD_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${FCST_LENGTH} hours" +%d)
HH_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${FCST_LENGTH} hours" +%H)
DOW_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${FCST_LENGTH} hours " +%A)  # 1-7, Monday-Sunday
#
YYYYp=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 1 day" +%Y)
MMp=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 1 day" +%m)
DDp=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 1 day" +%d)
HHp=$(date -d "${CDATE:0:8} ${CDATE:8:2}- 1 day" +%H)
#
current_day=`${DATE} -d "${YYYY}${MM}${DD}"`
current_hh=`${DATE} -d ${HH} +"%H"`
#
prev_hh=`${DATE} -d "$current_hh -24 hour" +"%H"`
previous_day=`${DATE} '+%C%y%m%d' -d "$current_day-1 days"`
previous_day="${previous_day} ${prev_hh}"
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
MOY_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${FCST_LENGTH} hours" +%B)  # full month name (e.g., January)
DOY=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%j)  # Julian day 
#
if [[ "${DOY}" -ne 0 ]]; then
  DOY_m1=$((${DOY}-1))
else
  DOY_m1=0
fi
#
DOY_END=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${FCST_LENGTH} hours" +%j)  # Julian day 
#
# Set the init/mesh file name and link here:\
if [[ ${keepdata} == "YES" ]]; then
   if [[ -r ${UMBRELLA_PREP_IC_DATA}/init.nc ]]; then
       ln -sf ${UMBRELLA_PREP_IC_DATA}/init.nc ./${MESH_NAME}.init.nc
       INIT_FILE=./${MESH_NAME}.init.nc
   else
       echo "WARNING: NO Init File available, cannot reinterpolate if files are missing, did you run the task out of order?"
       has_init=0
   fi
else
   if [[ -r ${COMOUT}/ic/${WGF}${MEMDIR}/init.nc  ]]; then
       ln -sf  ${COMOUT}/ic/${WGF}${MEMDIR}/init.nc ./${MESH_NAME}.init.nc
       INIT_FILE=./${MESH_NAME}.init.nc
   else
       echo "WARNING: NO Init File available, cannot reinterpolate if files are missing, did you run the task out of order?"
       has_init=0
   fi
fi

#
SCRIPT=${HOMErrfs}/scripts/exrrfs_regrid_chem.py
VINTERP_SCRIPT=${HOMErrfs}/scripts/exrrfs_vinterp_chem.py
INTERP_WEIGHTS_DIR=${DATADIR_CHEM}/grids/interpolation_weights/  
#
# Set a few things for the CONDA environment
export REGRID_WRAPPER_LOG_DIR=${DATA}
regrid_wrapper_dir=${REGRID_WRAPPER_DIR} #/lfs5/BMC/rtwbl/rap-chem/mpas_rt/working/ben_interp/regrid-wrapper/
PYTHONDIR=${regrid_wrapper_dir}/src
regrid_conda_env=${REGRID_CONDA_ENV}  #CONDAENV=/lfs5/BMC/rtwbl/rap-chem/miniconda/envs/regrid-wrapper
export PATH=${regrid_conda_env}/bin:${PATH}
export ESMFMKFILE=${regrid_conda_env}/lib/esmf.mk
export PYTHONPATH=${PYTHONDIR}:${PYTHONPATH}
#
#==================================================================================================
#                                 ... Wildfire ...                                             
#==================================================================================================#
if [[ "${EMIS_SECTOR_TO_PROCESS}" == "smoke" ]]; then
  source "USHrrfs"/prep_smoke.sh
fi

if [[ "${EMIS_SECTOR_TO_PROCESS}" == "rwc" ]]; then
  source "USHrrfs"/prep_rwc.sh
fi #rwc

if [[ "${EMIS_SECTOR_TO_PROCESS}" == "anthro" ]]; then
  source "USHrrfs"/prep_anthro.sh
fi # anthro

if [[ "${EMIS_SECTOR_TO_PROCESS}" == "pollen" ]]; then
  source "USHrrfs"/prep_pollen.sh
fi # bio/pollen

if [[ "${EMIS_SECTOR_TO_PROCESS}" == "dust" ]]; then
  source "${USHrrfs}/prep_dust.sh"
fi # dust
