#!/bin/bash
set -eux

#-----------------------------------------------------------------------
# Source the variable definitions file.
#-----------------------------------------------------------------------

module load prod_util

#-----------------------------------------------------------------------
# set up currentime from CDATE 
#-----------------------------------------------------------------------
export DATA=${DATA:-${DATAROOT}/${jobid}}
mkdir -p ${DATA}
cd ${DATA}
CDATE=${CDATE:-${PDY}${cyc}}

#-----------------------------------------------------------------------
# Clean up the COM
# Keep all COM for the past 12 hours then clean up all files on the 13th cycle
#   with exception of analysis and grib2 files
#-----------------------------------------------------------------------
rm -f ${DATA}/data_clean_com.sh
echo "set -x" &> ${DATA}/data_clean_com.sh
target_cleanup_pdy=$($NDATE -13 ${CDATE} | cut -c1-8)
target_cleanup_cyc=$($NDATE -13 ${CDATE} | cut -c9-10)
[[ -z ${COMrrfs} ]]&& exit 0
cd ${COMrrfs}
for wgf_run in rrfs enkfrrfs; do
  cd ${COMrrfs}/${wgf_run}.${target_cleanup_pdy}
  for directory2clean in $(ls |grep "${target_cleanup_cyc}"); do
    dir_remove=${COMrrfs}/${wgf_run}.${target_cleanup_pdy}/${directory2clean}
    echo "Check ${dir_remove} for cleanup"
    [[ ! -d ${dir_remove} ]]&& exit 0
    cd ${dir_remove}
    find . -type f|grep -v "analysis"|grep -v "grib2"|awk -v dir_remove="$dir_remove" '{print "rm -f",dir_remove"/"$1}' >> ${DATA}/data_clean_com.sh
  done
done
cd $DATA
[[ $(cat ${DATA}/data_clean_com.sh|wc -l) -gt 1 ]]&& sh ${DATA}/data_clean_com.sh

#-----------------------------------------------------------------------
# Remove the Umbrella Data for the current cycle up to the forecast step
#-----------------------------------------------------------------------

#### Temporary keep all 12Z for debug
#if [ ! ${cyc} == 19 ]; then
cd $DATAROOT
if [ ${KEEPDATA} == "YES" ]; then
  for dir_remove in rrfs_analysis_gsi rrfs_analysis_gsi_spinup rrfs_calc_ensmean rrfs_forecast_spinup rrfs_init rrfs_init_spinup; do
    [[ -d ${dir_remove}_${cyc}_v1.0 ]]&& mv ${dir_remove}_${cyc}_v1.0 ${dir_remove}_$$_${cyc}_v1.0
  done
else
  for dir_remove in rrfs_analysis_gsi rrfs_analysis_gsi_spinup rrfs_calc_ensmean rrfs_forecast_spinup rrfs_init rrfs_init_spinup; do
    [[ -d ${dir_remove}_${cyc}_v1.0 ]]&& rm -rf ${dir_remove}_${cyc}_v1.0
  done
fi
cd $DATA
#fi
#-----------------------------------------------------------------------
# Delete development data directories if KEEPDATA set to YES
# Keep DATA for development for the last 12 hours
# Remove this session after turn on the KEEPDATA function
#-----------------------------------------------------------------------

[[ ${KEEPDATA} == "NO" ]]&& exit 0
[[ -f ${DATA}/data_clean1.sh ]]&& rm -f ${DATA}/data_clean1.sh
cd $DATAROOT
echo "set -x" >> ${DATA}/data_clean1.sh
search_cyc_18=$($NDATE -18 ${CDATE} | cut -c9-10)
search_cyc_17=$($NDATE -17 ${CDATE} | cut -c9-10)
search_cyc_16=$($NDATE -16 ${CDATE} | cut -c9-10)
search_cyc_15=$($NDATE -15 ${CDATE} | cut -c9-10)
search_cyc_14=$($NDATE -14 ${CDATE} | cut -c9-10)
search_cyc_13=$($NDATE -13 ${CDATE} | cut -c9-10)
search_cyc_12=$($NDATE -12 ${CDATE} | cut -c9-10)
search_cyc_11=$($NDATE -11 ${CDATE} | cut -c9-10)
search_cyc_10=$($NDATE -10 ${CDATE} | cut -c9-10)
search_cyc_09=$($NDATE -9 ${CDATE} | cut -c9-10)
#### for idx_cyc in ${search_cyc_18#0} ${search_cyc_17#0} ${search_cyc_16#0} ${search_cyc_15#0} ${search_cyc_14#0} ${search_cyc_13#0} ${search_cyc_12#0} ${search_cyc_11#0} ${search_cyc_10#0} ${search_cyc_09#0}; do
for idx_cyc in ${search_cyc_18#0} ${search_cyc_17#0} ${search_cyc_16#0} ${search_cyc_15#0} ${search_cyc_14#0} ${search_cyc_13#0}; do
  idx_cyc2d=$( printf "%02d" "${idx_cyc#0}" )
  fcst_state=$(ecflow_client --query state /nco_rrfs_dev_${idx_cyc2d}/primary/${idx_cyc2d}/rrfs/v1.0/forecast)

  #### Temporary keep all 13Z for debug
  # if [ ${idx_cyc2d} == 19 ] || [ ${idx_cyc2d} == 12 ]; then
  #   fcst_state="reserved"
  # fi

  if [ ${fcst_state} == "complete" ]; then
    echo "Cycle ${idx_cyc2d} is completed - proceed with cleanup"
    ls|grep "_${idx_cyc2d}\."|awk -v DATAROOT="$DATAROOT" '{print "rm -rf",DATAROOT"/"$1}' >> ${DATA}/data_clean1.sh
    # Include the backup umbrella data directories
    ls -d */ |grep "_${idx_cyc2d}_v1.0" |awk -v DATAROOT="$DATAROOT" '{print "rm -rf",DATAROOT"/"$1}' >> ${DATA}/data_clean1.sh
  fi
done
[[ $(cat ${DATA}/data_clean1.sh|wc -l) -gt 1 ]]&& sh ${DATA}//data_clean1.sh
cd $DATA

exit 0
