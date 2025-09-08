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
# 1. INTERP_METHOD             -- likely a metatask variable for each input type, determines interpolation method
# 2. EMIS_SECTOR_TO_PROCESS    -- which emission sector is this task performing? (anthro, pollen, dust)
# 3. ANTHRO_EMISINV            -- undecided, may merge for custom dataset, or leave option to combine
# 4. DATADIR_CHEM             -- location of interpolated files, ready to be used
# 5. MESH_NAME                -- name of the MPAS domain, required to know if we have weights or data intepolated to the domain 
# 6. FCST_LENGTH               -- nhours of forecast
#
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
nt=$SLURM_NTASKS
cpreq=${cpreq:-cpreq}
#
LS=/bin/ls
LN=/bin/ln
RM=/bin/rm
MKDIR=/bin/mkdir
CP=/bin/cp
MV=/bin/mv
ECHO=/bin/echo
CAT=/bin/cat
GREP=/bin/grep
CUT=`which cut`
AWK="/bin/gawk --posix"
SED=/bin/sed
DATE=/bin/date
# 
# ... Go to the main PREP directory
cd ${DATA}
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
# Set the interpolation method if none is selected
if [ -z "${INTERP_METHOD}" ]; then
   ${ECHO} "No interpolation method selected, defaulting to 'conserve'"
   export INTERP_METHOD="bilinear"
fi
#
INITFILE=/lfs5/BMC/rtwbl/rap-chem/mpas_conus3km/cycledir/stmp/${YYYY}${MM}${DD}${HH}/init/ctl/hrrrv5.init.nc
# Set the init/mesh file name and link here:\

if [[ "${MESH_NAME}" -eq "conus12km" ]]; then


if [[ -r ${UMBRELLA_PREP_IC_DATA}/init.nc ]]; then
    ln -sf ${UMBRELLA_PREP_IC_DATA}/init.nc ./${MESH_NAME}.init.nc
elif [[ -r ${UMBRELLA_PREP_IC_DATA}/hrrrv5.init.nc ]]; then
    ln -sf ${UMBRELLA_PREP_IC_DATA}/hrrrv5.init.nc ./${MESH_NAME}.init.nc
elif [[ -r  ${UMBRELLA_PREP_IC_DATA_GFS}/init.nc ]]; then
    ln -sf ${UMBRELLA_PREP_IC_DATA_GFS}/init.nc ./${MESH_NAME}.init.nc
elif [[ -r ${UMBRELLA_FCST_DATA}/fcst_${HH}/mpasin.nc ]]; then
    ln -sf ${UMBRELLA_FCST_DATA}/fcst_${HH}/mpasin.nc ./${MESH_NAME}.init.nc
else
    echo "WARNING: NO Init File available, cannot reinterpolate if files are missing, did you run the task out of order?"
    has_init=0
fi

else

if [[ -r ${UMBRELLA_PREP_IC_DATA}/init.nc ]]; then
    ln -sf ${UMBRELLA_PREP_IC_DATA}/init.nc ./${MESH_NAME}.init.nc
elif [[ -r ${UMBRELLA_PREP_IC_DATA}/hrrrv5.init.nc ]]; then
    ln -sf ${UMBRELLA_PREP_IC_DATA}/hrrrv5.init.nc ./${MESH_NAME}.init.nc
elif [[ -r ${INITFILE} ]]; then
    ln -sf ${INITFILE} ./${MESH_NAME}.init.nc
elif [[ -r ${UMBRELLA_FCST_DATA}/fcst_${HH}/mpasin.nc ]]; then
    ln -sf ${UMBRELLA_FCST_DATA}/fcst_${HH}/mpasin.nc ./${MESH_NAME}.init.nc
elif [[ -r  ${UMBRELLA_PREP_IC_DATA_GFS}/init.nc ]]; then
    ln -sf ${UMBRELLA_PREP_IC_DATA_GFS}/init.nc ./${MESH_NAME}.init.nc
else
    echo "WARNING: NO Init File available, cannot reinterpolate if files are missing, did you run the task out of order?"
    has_init=0
fi



fi



#
MPAS_BASEFILE=${DATADIR_CHEM}/grids/domain_latlons/mpas_${MESH_NAME}_init.nc
#SCRIPT=${HOMErrfs}/scripts/regrid_chem_to_mpas.py
SCRIPT=${HOMErrfs}/scripts/exrrfs_regrid_chem.py
INTERP_WEIGHTS_DIR=${DATADIR_CHEM}/grids/interpolation_weights/  
#
# Set a few things for the CONDA environment
export REGRID_WRAPPER_LOG_DIR=${DATA}
regrid_wrapper_dir=/lfs5/BMC/rtwbl/rap-chem/mpas_rt/working/ben_interp/regrid-wrapper
PYTHONDIR=${regrid_wrapper_dir}/src
CONDAENV=/lfs5/BMC/rtwbl/rap-chem/miniconda/envs/regrid-wrapper
export PATH=${CONDAENV}/bin:${PATH}
export ESMFMKFILE=${CONDAENV}/lib/esmf.mk
export PYTHONPATH=${PYTHONDIR}:${PYTHONPATH}
#
#==================================================================================================
#                                 ... Wildfire ...                                             
#==================================================================================================#
if [[ "${EMIS_SECTOR_TO_PROCESS}" == "smoke" ]]; then
#
if [[ ! ${RAVE_DIR} ]]; then
RAVE_INPUTDIR=/public/data/grids/nesdis/3km_fire_emissions/ # JLS, TODO, should come from a config/namelist
else
RAVE_INPUTDIR=${RAVE_DIR}
fi
RAVE_OUTPUTDIR=${DATADIR_CHEM}/emissions/fire/processed/rave/
ECO_INPUTDIR=${DATADIR_CHEM}/aux/ecoregion/
ECO_OUTPUTDIR=${DATADIR_CHEM}/aux/ecoregion/
FMC_INPUTDIR=${DATADIR_CHEM}/aux/FMC/${YYYY}/${MM}/
FMC_OUTPUTDIR=${DATADIR_CHEM}/aux/FMC/${YYYY}/${MM}/
#
dummyRAVE=${DATADIR_CHEM}/emissions/fire/processed/rave/${MESH_NAME}_dummy_rave.nc
mkdir -p ${RAVE_OUTPUTDIR}
#
# Create a temporary directory to process the emissions so we don't mess with the raw data
#
#
srun python -u ${SCRIPT} \
               "RAVE" \
               ${DATA} \
               ${RAVE_INPUTDIR} \
               ${RAVE_OUTPUTDIR} \
               ${INTERP_WEIGHTS_DIR} \
               ${YYYY}${MM}${DD}${HH} \
               ${MESH_NAME}
mv *.log *.ESMF_LogFile logs || echo "could not move logs"
# 
for ihour in $(seq 0 ${FCST_LENGTH}); 
do
#
   if [[ ${ihour} -gt 24 ]]; then
      ihour2=$((${ihour}-24))
   else
      ihour2=${ihour}
   fi
   timestr1=`date +%Y%m%d%H -d "$previous_day + $ihour2 hours"`
   timestr2=`date +%Y-%m-%d_%H -d "$current_day + $ihour hours"`
   timestr3=`date +%Y-%m-%d_%H:00:00 -d "$current_day + $ihour hours"`
#
   EMISFILE=${UMBRELLA_PREP_CHEM_DATA}/smoke.init.retro.${timestr2}.00.00.nc
   EMISFILE2="${RAVE_OUTPUTDIR}/${MESH_NAME}-RAVE-${timestr1}.nc"
   if [[ -r ${EMISFILE2} ]]; then
      ncrename -v PM25,e_bb_in_smoke_fine -v FRP_MEAN,frp_in -v FRE,fre_in ${EMISFILE2}
      ncrename -v SO2,e_bb_in_so2 -v NH3,e_bb_in_nh3 ${EMISFILE2}
      ncrename -v CH4,e_bb_in_ch4 ${EMISFILE2}
      ncrename -v PM10,e_bb_in_smoke_coarse ${EMISFILE2}
      ln -sf ${EMISFILE2} ${EMISFILE}
   else
      cp ${dummyRAVE} ${EMISFILE}
   fi
   ncks -O -6 ${EMISFILE} ${EMISFILE}
   ncks -A -v xtime ${DATA}/${MESH_NAME}.init.nc ${EMISFILE}
   ncap2 -O -s xtime=\"${timestr3}\" ${EMISFILE} ${EMISFILE}  
#
done
#
#
# Concatenate for ebb2
ncrcat ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.retro.*.00.00.nc ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc
#
# Calculate previous 24 hour average HWP
#
# TODO
#
# Emissions to be calculated inside of model
if [[ ! -r "${ECO_OUTPUTDIR}/ecoregions_${MESH_NAME}_mpas.nc" ]]; then
   echo "Regridding ECO_REGION"
   ln -s ${ECO_INPUTFILE} ${DATA}/
   srun python -u ${SCRIPT}   \
                   "ECOREGION" \
                   ${DATA} \
                   ${ECO_INPUTDIR} \
                   ${ECO_OUTPUTDIR} \
                   ${INTERP_WEIGHTS_DIR} \
                   ${YYYY}${MM}${DD}${HH} \
                   ${MESH_NAME}

fi
ncks -A -v ecoregion_ID ${ECO_OUTPUTDIR}/ecoregions_${MESH_NAME}_mpas.nc ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc
ncap2 -O -s 'hwp_prev24=0.0*frp_in+30.' -s 'totprcp_prev24=0.0*frp_in+0.1' ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc
ncrename -v frp_in,frp_prev24 -v fre_in,fre_prev24 ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc
# 

n_fmc=`ls ${FMC_INPUTDIR}/fmc_${YYYY}${MM}${DD}* | wc -l`
if [[ ${n_fmc} -gt 0 ]]; then
  echo "Have at least some soil moisture information, will interpolate"
     ln -s ${FMC_INPUTDIR}/* ${DATA}/
     srun python -u ${SCRIPT}   \
                     "FMC" \
                     ${DATA} \
                     ${FMC_INPUTDIR} \
                     ${FMC_OUTPUTDIR} \
                     ${INTERP_WEIGHTS_DIR} \
                     ${YYYY}${MM}${DD}${HH} \
                     ${MESH_NAME}
  # Average for ebb2
  ncrcat ${FMC_OUTPUTDIR}/fmc*${MESH_NAME}*nc ${UMBRELLA_PREP_CHEM_DATA}/fmc.init.nc
  ncks -A -v 10h_dead_fuel_moisture_content ${UMBRELLA_PREP_CHEM_DATA}/fmc.init.nc ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc
  ncrename -v 10h_dead_fuel_moisture_content,fmc_prev24 ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc
else
  ncap2 -O -s 'fmc_prev24=0*frp_prev24+0.2' ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc
fi

# Cut out only the first 24 hours
ncks -O -d Time,0,23 ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc ${UMBRELLA_PREP_CHEM_DATA}/smoke.init.nc
 
fi



#
#==================================================================================================
#                                 ... Anthropogenic ...                                             
#==================================================================================================
#
# --- Are we adding anthropogenic sectors?
if [[ "${EMIS_SECTOR_TO_PROCESS}" == "rwc" ]]; then
#
# --- Set the file expression and lat/lon dimension names
#
   INPUTDIR=${DATADIR_CHEM}/emissions/anthro/raw/NEMO/RWC/total/
   OUTPUTDIR=${DATADIR_CHEM}/emissions/anthro/processed/NEMO/RWC/total/
   NARR_INPUTDIR=${DATADIR_CHEM}/aux/narr_reanalysis_t2m/
   NARR_OUTPUTDIR=${DATADIR_CHEM}/aux/narr_reanalysis_t2m/
   #
   ${MKDIR} -p ${OUTPUTDIR}
   # 
   EMISFILE_RWC_PROCESSED=${OUTPUTDIR}/NEMO_RWC_ANNUAL_TOTAL_${MESH_NAME}.nc
   #
   if [[ ! -r ${EMISFILE_RWC_PROCESSED} ]]; then
      srun python -u ${SCRIPT} \
                       "NEMO" \
                       ${DATA} \
                       ${INPUTDIR} \
                       ${OUTPUTDIR} \
                       ${INTERP_WEIGHTS_DIR} \
                       ${YYYY}${MM}${DD}${HH} \
                       ${MESH_NAME}

      # Convert to how we want it
      ncap2 -O -s 'RWC_annual_sum=PEC+POC+PMOTHR' ${EMISFILE_RWC_PROCESSED} ${EMISFILE_RWC_PROCESSED}
      ncap2 -O -s 'RWC_annual_sum_smoke_fine=PEC+POC' ${EMISFILE_RWC_PROCESSED}  ${EMISFILE_RWC_PROCESSED}
      ncap2 -O -s 'RWC_annual_sum_smoke_coarse=0*RWC_annual_sum_smoke_fine' ${EMISFILE_RWC_PROCESSED}  ${EMISFILE_RWC_PROCESSED}
      ncrename -v PMOTHR,RWC_annual_sum_unspc_fine ${EMISFILE_RWC_PROCESSED}
      ncrename -v PMC,RWC_annual_sum_unspc_coarse ${EMISFILE_RWC_PROCESSED}
   fi

   # Regrid the summed minimum temperature equation:
   EMISFILE_DENOM_PROCESSED=${NARR_OUTPUTDIR}/NEMO_RWC_DENOMINATOR_2017_${MESH_NAME}.nc
   #
   if [[ ! -r ${EMISFILE_DENOM_PROCESSED} ]] ; then
        
        srun python -u ${SCRIPT} \
            "NARR" \
            ${DATA} \
            ${NARR_INPUTDIR} \
            ${NARR_OUTPUTDIR} \
            ${INTERP_WEIGHTS_DIR} \
            ${YYYY}${MM}${DD}${HH} \
            ${MESH_NAME}
   
   #
   ncks -A -v RWC_annual_sum,RWC_annual_sum_smoke_fine,RWC_annual_sum_smoke_coarse,RWC_annual_sum_unspc_fine,RWC_annual_sum_unspc_coarse ${EMISFILE_RWC_PROCESSED} ${EMISFILE_DENOM_PROCESSED}
   timestr=`date +%Y-%m-%d_%H:00:00 -d "$current_day"`
   ncap2 -O -s xtime=\"${timestr3}\"  ${EMISFILE_DENOM_PROCESSED}  ${EMISFILE_DENOM_PROCESSED}  
   ncks -O -6 ${EMISFILE_DENOM_PROCESSED} ${EMISFILE_DENOM_PROCESSED}
   #
   LINKEDEMISFILE=${UMBRELLA_PREP_CHEM_DATA}/rwc.init.nc
   #
   ${LN} -sf ${EMISFILE_DENOM_PROCESSED} ${LINKEDEMISFILE}   

   else
   ${LN} -sf ${EMISFILE_DENOM_PROCESSED} ${LINKEDEMISFILE}
   fi
fi


if [[ "${EMIS_SECTOR_TO_PROCESS}" == "anthro" ]]; then
#
# --- Set the file expression and lat/lon dimension names
#
   ANTHROEMIS_STATICDIR=${DATADIR_CHEM}/emissions/anthro/raw/${ANTHRO_EMISINV}/
   #
   GRA2PES_VERSION=total_plus_methane_final_7-15-2025
   #
   ANTHROEMIS_INPUTDIR=${DATADIR_CHEM}/emissions/anthro/raw/${ANTHRO_EMISINV}/${GRA2PES_VERSION}/2023${MM}/${DOW_STRING}/
   ANTHROEMIS_OUTPUTDIR=${DATADIR_CHEM}/emissions/anthro/processed/${ANTHRO_EMISINV}/${MOY}/${DOW_STRING}/
   ${MKDIR} -p ${ANTHROEMIS_OUTPUTDIR}
   
    #
    EMISFILE_BASE_RAW1=${DATADIR_CHEM}/emissions/anthro/raw/${ANTHRO_EMISINV}/${GRA2PES_VERSION}/2023${MM}/${DOW_STRING}/GRA2PESv1.0_total_2023${MM}_${DOW_STRING}_00to11Z.nc
    EMISFILE_BASE_RAW2=${DATADIR_CHEM}/emissions/anthro/raw/${ANTHRO_EMISINV}/${GRA2PES_VERSION}/2023${MM}/${DOW_STRING}/GRA2PESv1.0_total_2023${MM}_${DOW_STRING}_12to23Z.nc
    INPUT_GRID=${DATADIR_CHEM}/grids/domain_latlons/GRA2PESv1.0_CONUS4km_grid_info.nc

    #
    EMISFILE1=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}_${MESH_NAME}_00to11Z.nc
    EMISFILE2=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}_${MESH_NAME}_12to23Z.nc
    #
    if [[ -r ${EMISFILE_BASE_RAW1} ]] && [[ -r ${EMISFILE_BASE_RAW2} ]]; then
       echo "Checking to make sure we have corner coords"
       ncdump -hv XLAT_C ${EMISFILE_BASE_RAW1}
       if [[ $? -ne 0 ]]; then
         echo ".. we don't, cutting in from ${INPUT_GRID}"
         ncks -A -v XLAT_C,XLAT_M,XLONG_C,XLONG_M ${INPUT_GRID} ${EMISFILE_BASE_RAW1}
         ncks -A -v XLAT_C,XLAT_M,XLONG_C,XLONG_M ${INPUT_GRID} ${EMISFILE_BASE_RAW2}
       else
         echo "...we do!"
       fi
       ${ECHO} "Found base emission files: ${EMISFILE_BASE_RAW1} and ${EMISFILE_BASE_RAW2}, will interpolate"
       # -- Start the regridding process
          mpirun -np ${nt} python -u ${SCRIPT}   \
                     "GRA2PES" \
                     ${DATA} \
                     ${ANTHROEMIS_INPUTDIR} \
                     ${ANTHROEMIS_OUTPUTDIR} \
                     ${INTERP_WEIGHTS_DIR} \
                     ${YYYY}${MM}${DD}${HH} \
                     ${MESH_NAME}
  
          if [[ ! -r ${EMISFILE1} ]] || [[ ! -r ${EMISFILE2} ]]; then
             ${ECHO} "ERROR: Did not interpolate ${ANTHRO_EMISINV}"
             exit 1
          else
             ncpdq -O -a Time,nCells,nkemit ${EMISFILE1} ${EMISFILE1}
             ncpdq -O -a Time,nCells,nkemit ${EMISFILE2} ${EMISFILE2}
             ncks -O --mk_rec_dmn Time ${EMISFILE1} ${EMISFILE1}
             ncks -O --mk_rec_dmn Time ${EMISFILE2} ${EMISFILE2}
             ncks -O -6  ${EMISFILE1} ${EMISFILE1}
             ncks -O -6  ${EMISFILE2} ${EMISFILE2}
             for ihour in $(seq 0 ${FCST_LENGTH}) 
             do
                 YYYY_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%Y)
                 MM_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%m)
                 DD_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%d)
                 HH_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%H)
                 MOY_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%B)
                 DOW_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%A)
                 LINKEDEMISFILE=${UMBRELLA_PREP_CHEM_DATA}/anthro.init.${YYYY_EMIS}-${MM_EMIS}-${DD_EMIS}_${HH_EMIS}.00.00.nc
                 if [ "${HH_EMIS}" -gt 11 ]; then
                    offset=12
                    EMISFILE=${EMISFILE1}
                 else
                    offset=0
                    EMISFILE=${EMISFILE2}
                 fi
                 t_ix=$((10#$HH_EMIS-${offset}))
                 #
                 EMISFILE_FINAL=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}_${MESH_NAME}_${HH_EMIS}Z.nc
                 # Reorder
                 if [[ -r ${EMISFILE_FINAL} ]]; then
                    ${LN} -sf ${EMISFILE_FINAL} ${LINKEDEMISFILE}
                 else
                    ${ECHO} "Reordering dimensions -- cell x level x time -- >  Time x Cell x Level "
                    ncks -d Time,${t_ix},${t_ix} ${EMISFILE} ${EMISFILE_FINAL}
                    ${ECHO} "Created file #${ihour}/${FCST_LENGTH} at ${EMISFILE_FINAL}"
                    ncrename -v PM25-PRI,e_ant_in_unspc_fine -v PM10-PRI,e_ant_in_unspc_coarse ${EMISFILE_FINAL}
                    ncrename -v HC01,e_ant_in_ch4 ${EMISFILE_FINAL}
                  # TODO, other species
                    ncap2 -O -s 'e_ant_in_smoke_fine=0.0*e_ant_in_unspc_fine' ${EMISFILE_FINAL} ${EMISFILE_FINAL}
                    ncap2 -O -s 'e_ant_in_smoke_coarse=0.0*e_ant_in_unspc_fine' ${EMISFILE_FINAL} ${EMISFILE_FINAL}
                    ncap2 -O -s 'e_ant_in_dust_fine=0.0*e_ant_in_unspc_fine' ${EMISFILE_FINAL} ${EMISFILE_FINAL}
                    ncap2 -O -s 'e_ant_in_dust_coarse=0.0*e_ant_in_unspc_fine' ${EMISFILE_FINAL} ${EMISFILE_FINAL}
                    ${LN} -sf ${EMISFILE_FINAL} ${LINKEDEMISFILE}
                 fi
             done
          fi # Did inerp succeed?
    fi # Do the emission files exist
fi # anthro?

#==================================================================================================
#                                 ... Biogenic/Pollen ...                                             
#==================================================================================================
# --- Are we adding pollen or other biogenics?
if [[ "${EMIS_SECTOR_TO_PROCESS}" == "pollen" ]]; then
#
EMISINPUTDIR=${DATADIR_CHEM}/emissions/pollen/raw/${YYYY}
EMISOUTPUTDIR=${DATADIR_CHEM}/emissions/pollen/processed/${YYYY}
${MKDIR} -p ${EMISOUTPUTDIR}
#
# --- Do we have emissions regridded to our domain?
# --- If we already have the emissions, link them..
#
   EMISFILE=${EMISOUTPUTDIR}/pollen_ef_${MESH_NAME}_${YYYY}_${DOY}.nc
   LINKEDEMISFILE=${UMBRELLA_PREP_CHEM_DATA}/bio.init.nc
   if [ ! -r ${EMISFILE} ]; then
      ${ECHO} "No pollen input file regridded to this specific day and mesh: ${EMISFILE}, will look for a file to interpoloate"
   else
      ${LN} -sf ${EMISFILE} ${LINKEDEMISFILE}
      ${ECHO} "Linked pollen file ${EMISFILE}, exiting"
      exit 0
   fi
#
# -- Look for the base emission file
#
   EMISFILE_BASE=${EMISINPUTDIR}/pollen_obs_${YYYY}_BELD6_ef_T_${DOY}.nc
   if [[ -r ${EMISFILE_BASE} ]];then
      ${ECHO} "Found base emission file: ${EMISFILE_BASE}"
   else
      ${ECHO} "Cannot regrid, no base emission file: ${EMISFILE_BASE}"
      exit 1
   fi
   srun python -u ${SCRIPT}   \
              "PECM" \
              ${DATA} \
              ${EMISINPUTDIR} \
              ${EMISOUTPUTDIR} \
              ${INTERP_WEIGHTS_DIR} \
              ${YYYY}${MM}${DD}${HH} \
              ${MESH_NAME}
   if [ ! -r ${EMISFILE} ]; then
      ${ECHO} "Regrid failed, check the logs"
      exit 1
   else
      ncrename -v GRA_POLL,e_bio_in_polp_grass -v RAG_POLL,e_bio_in_polp_weed -v TREE_POLL,e_bio_in_polp_tree ${EMISFILE}
      ncks -O -6 ${EMISFILE} ${EMISFILE}
      ncks -A -v  ${DATA}/${MESH_NAME}.init.nc ${EMISFILE}
      ${LN} -sf ${EMISFILE} ${LINKEDEMISFILE}
      ${ECHO} "Linked pollen file ${EMISFILE}, exiting"
      exit 0
   fi
fi # bio/pollen

#==================================================================================================
#                                 ... Dust ...                                             
#==================================================================================================
# --- Are we adding pollen or other biogenics?
if [[ "${EMIS_SECTOR_TO_PROCESS}" == "dust" ]]; then

   LINKEDEMISFILE=${UMBRELLA_PREP_CHEM_DATA}/dust.init.nc

   DUST_INPUTDIR=${DATADIR_CHEM}/dust/raw/
   DUST_OUTPUTDIR=${DATADIR_CHEM}/dust/processed/

   DUST_OUTFILE=${DATADIR_CHEM}/dust/processed/fengsha_dust_inputs.${MESH_NAME}.nc

   if [[ ! -r ${DUST_OUTFILE} ]]; then
      ${ECHO} "Interpolated dust file: ${DUST_OUTFILE} does not exist, will attempt to create"
      srun python -u ${SCRIPT}   \
                 "FENGSHA_1" \
                 ${DATA} \
                 ${DUST_INPUTDIR} \
                 ${DUST_OUTPUTDIR} \
                 ${INTERP_WEIGHTS_DIR} \
                 ${YYYY}${MM}${DD}${HH} \
                 ${MESH_NAME}
      OUTFILE_1=${DUST_OUTPUTDIR}/FENGSHA_2022_NESDIS_inputs_${MESH_NAME}_v3.2.nc

      srun python -u ${SCRIPT}   \
                 "FENGSHA_2" \
                 ${DATA} \
                 ${DUST_INPUTDIR} \
                 ${DUST_OUTPUTDIR} \
                 ${INTERP_WEIGHTS_DIR} \
                 ${YYYY}${MM}${DD}${HH} \
                 ${MESH_NAME}
      OUTFILE_2=${DUST_OUTPUTDIR}/LAI_GVF_PC_DRAG_CLIMATOLOGY_2024v1.0.${MESH_NAME}.nc
      #ncks -A -v feff ${OUTFILE_2} ${OUTFILE_1}
      #cp ${OUTFILE_1} ${DUST_OUTFILE}
      #ncrename -d Time,nMonths ${DUST_OUTFILE}
      #ncrename -v sep,sep_in -v sandfrac,sandfrac_in -v clayfrac,clayfrac_in -v uthres,uthres_in -v uthres_sg,uthres_sg_in -v feff,feff_m_in -v albedo_drag,albedo_drag_m_in ${DUST_OUTFILE}
      #ncks -O -6 ${DUST_OUTFILE} ${DUST_OUTFILE}
      #ln -sf ${DUST_OUTFILE} ${LINKEDEMISFILE}
   else
      echo "Dust file exists, linking"
      ln -sf ${DUST_OUTFILE} ${LINKEDEMISFILE}
   fi

fi # dust



exit 0
