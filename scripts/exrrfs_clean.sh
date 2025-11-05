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
# Remove this session before NCO code delivery
# Clean up the COM
# Keep all COM for the past 12 hours then clean up all files on the 13th cycle
#   with exception of analysis and grib2 files
#-----------------------------------------------------------------------
[[ -f ${DATA}/data_clean_com.sh ]]&& rm -f ${DATA}/data_clean_com.sh
echo "set -x" &> ${DATA}/data_clean_com.sh
target_cleanup_pdy=$($NDATE -13 ${CDATE} | cut -c1-8)
target_cleanup_cyc=$($NDATE -13 ${CDATE} | cut -c9-10)
[[ -z ${COMrrfs} ]]&& exit 0
cd ${COMrrfs}
for wgf_run in rrfs enkfrrfs; do
  if [ -d ${COMrrfs}/${wgf_run}.${target_cleanup_pdy} ]; then
    cd ${COMrrfs}/${wgf_run}.${target_cleanup_pdy}
    for directory2clean in $(ls |grep "${target_cleanup_cyc}"); do
      dir_remove=${COMrrfs}/${wgf_run}.${target_cleanup_pdy}/${directory2clean}
      echo "Check ${dir_remove} for cleanup"
      [[ ! -d ${dir_remove} ]]&& exit 0
      cd ${dir_remove}
      find . -type f|grep -v "analysis"|grep -v "grib2"|awk -v dir_remove="$dir_remove" '{print "rm -f",dir_remove"/"$1}' >> ${DATA}/data_clean_com.sh
    done
  else
    break
  fi
done
cd $DATA
[[ $(cat ${DATA}/data_clean_com.sh|wc -l) -gt 1 ]]&& sh ${DATA}/data_clean_com.sh

#-----------------------------------------------------------------------
# Remove the Umbrella Data for the current cycle up to the forecast step
#-----------------------------------------------------------------------

cd $DATAROOT
if [ ${KEEPDATA} == "YES" ]; then
  # Keep all unique id DATA and rename the Umbrella Data directory to ensure new job will not run on the same directory
  for dir_remove in rrfs_analysis_gsi rrfs_analysis_gsi_spinup rrfs_calc_ensmean rrfs_forecast_spinup rrfs_forecast rrfs_init rrfs_init_spinup rrfs_ics rrfs_lbcops; do
    [[ -d ${dir_remove}_${cyc}_v1.0 ]]&& mv ${dir_remove}_${cyc}_v1.0 ${dir_remove}_$$_${cyc}_v1.0
  done
else
  # Delete all unique id DATA for this cycle
  [[ -f ${DATA}/cleanup_run.sh ]]&& rm -f ${DATA}/cleanup_run.sh
  echo "set -x" &> ${DATA}/cleanup_run.sh
  idx_cyc2d=${cyc}
  # Find all unique id data to remove
    find . -maxdepth 1 -type d -name "rrfs_*_${idx_cyc2d}\.*"| sed 's|^\./||'|grep "_${idx_cyc2d}\."|awk '{print "rm -rf",$1}' >> ${DATA}/cleanup_run.sh
  # Find all Umbrella Data to remove
    find . -maxdepth 1 -type d -name "rrfs_*_${idx_cyc2d}_v1\.0"| sed 's|^\./||'|awk '{print "rm -rf",$1}' >> ${DATA}/cleanup_run.sh
  cat ${DATA}/cleanup_run.sh
  chmod 755 ${DATA}/cleanup_run.sh
  [[ $(cat ${DATA}/cleanup_run.sh|wc -l) -gt 1 ]]&& ${DATA}/cleanup_run.sh &> ${DATA}/cleanup_run_$$.log
  # Double check and delete all Umbrella Data for this cycle
  for dir_remove in *_${idx_cyc2d}_v1.0; do
    [[ -d ${dir_remove} ]]&& rm -rf ${dir_remove}
  done
fi

#-----------------------------------------------------------------------
# Remove this session before NCO code delivery
# Delete post and prdgen data directories for current cyc if KEEPDATA set to YES
# Remove this session after turn on the KEEPDATA function
#-----------------------------------------------------------------------
cd $DATAROOT
if [ ${KEEPDATA} == "YES" ]; then
  [[ -f ${DATA}/post_prdgen_data_clean1.sh ]]&& rm -f ${DATA}/post_prdgen_data_clean1.sh
  echo "set -x" &> ${DATA}/post_prdgen_data_clean1.sh
  idx_cyc2d=${cyc}
  # Remove post
  [[ -d rrfs_post_${idx_cyc2d}_v1.0 ]]&& rm -rf rrfs_post_${idx_cyc2d}_v1.0
  find . -maxdepth 1 -type d -name "rrfs_*_post_*"| sed 's|^\./||'|grep "_${idx_cyc2d}\."|awk '{print "rm -rf",$1}' >> ${DATA}/post_prdgen_data_clean1.sh
  # Remove prdgen
  find . -maxdepth 1 -type d -name "rrfs_*_prdgen_*"| sed 's|^\./||'|grep "_${idx_cyc2d}\."|awk '{print "rm -rf",$1}' >> ${DATA}/post_prdgen_data_clean1.sh
  cat ${DATA}/post_prdgen_data_clean1.sh
  chmod 755 ${DATA}/post_prdgen_data_clean1.sh
  [[ $(cat ${DATA}/post_prdgen_data_clean1.sh|wc -l) -gt 1 ]]&& ${DATA}/post_prdgen_data_clean1.sh &> ${DATA}/post_prdgen_data_clean1_run_$$.log
fi

[[ ${KEEPDATA} == "NO" ]]&& exit 0

#-----------------------------------------------------------------------
# Remove this session before NCO code delivery
# Remove old DATA in development mode under KEEPDATA=YES
# Remove all DATA older then 8 cycles
# Proceed with remove when the forecast job for target cycle is completed
#-----------------------------------------------------------------------
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
for idx_cyc in ${search_cyc_18#0} ${search_cyc_17#0} ${search_cyc_16#0} ${search_cyc_15#0} ${search_cyc_14#0} ${search_cyc_13#0} ${search_cyc_12#0} ${search_cyc_11#0} ${search_cyc_10#0} ${search_cyc_09#0}; do
  idx_cyc2d=$( printf "%02d" "${idx_cyc#0}" )
  [[ ${idx_cyc} -lt 6 ]]&& cyc_idx=00
  [[ ${idx_cyc} -ge 6 ]]&& cyc_idx=06
  [[ ${idx_cyc} -ge 12 ]]&& cyc_idx=12
  [[ ${idx_cyc} -ge 18 ]]&& cyc_idx=18
  fcst_state=$(ecflow_client --query state /rrfs_dev/primary/${cyc_idx}/rrfs/v1.0/${idx_cyc2d}/forecast)

  # Temporary keep all 13Z for debug
  # if [ ${idx_cyc2d} == 19 ] || [ ${idx_cyc2d} == 12 ]; then
  #   fcst_state="reserved"
  # fi

  if [ ${fcst_state} == "complete" ]; then
    echo "Cycle ${idx_cyc2d} is completed - proceed with cleanup"
    find . -maxdepth 1 -type d -name "rrfs_*_${idx_cyc2d}\.*"| sed 's|^\./||'|awk '{print "rm -rf",$1}' >> ${DATA}/data_clean1.sh
    # Include the backup umbrella data directories
    find . -maxdepth 1 -type d -name "rrfs_*_${idx_cyc2d}_v1\.0"| sed 's|^\./||'|awk '{print "rm -rf",$1}' >> ${DATA}/data_clean1.sh
  fi
done
chmod 755 ${DATA}/data_clean1.sh
[[ $(cat ${DATA}/data_clean1.sh|wc -l) -gt 1 ]]&& ${DATA}/data_clean1.sh
cd $DATA

exit 0
