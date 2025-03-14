#!/bin/bash
set -eux

#-----------------------------------------------------------------------
# Source the variable definitions file.
#-----------------------------------------------------------------------

#### . ${GLOBAL_VAR_DEFNS_FP}
module load prod_util

#-----------------------------------------------------------------------
# set up currentime from CDATE 
#-----------------------------------------------------------------------

CDATE=${CDATE:-${PDY}${cyc}}

#-----------------------------------------------------------------------
# Delete development data directories
# Remove this session after turn on the KEEPDATA function
#-----------------------------------------------------------------------

cd /lfs/h3/emc/lam/noscrub/ecflow/stmp/emc.lam/rrfs/ecflow_rrfs
rm -f data_clean1.sh
echo "set -x" >> data_clean1.sh
search_cyc_12=$($NDATE -12 ${CDATE} | cut -c9-10)
search_cyc_11=$($NDATE -11 ${CDATE} | cut -c9-10)
search_cyc_10=$($NDATE -10 ${CDATE} | cut -c9-10)
search_cyc_9=$($NDATE -9 ${CDATE} | cut -c9-10)
search_cyc_8=$($NDATE -8 ${CDATE} | cut -c9-10)
search_cyc_7=$($NDATE -7 ${CDATE} | cut -c9-10)
for idx_cyc in ${search_cyc_12#0} ${search_cyc_11#0} ${search_cyc_10#0} ${search_cyc_9#0} ${search_cyc_8#0} ${search_cyc_7#0}; do
  idx_cyc2d=$( printf "%02d" "${idx_cyc#0}" )
  fcst_state=$(ecflow_client --query state /nco_rrfs_dev_${idx_cyc2d}/primary/${idx_cyc2d}/rrfs/v1.0/forecast)
  if [ ${fcst_state} == "complete" ]; then
    echo "Cycle ${idx_cyc2d} is completed - proceed with cleanup"
    ls|grep "_${idx_cyc2d}\."|awk '{print "rm -rf",$1}' >> data_clean1.sh
    ls -d */ |grep "_${idx_cyc2d}_v1.0" |awk '{print "rm -rf",$1}' >> data_clean1.sh
  fi
done
[[ $(cat data_clean1.sh|wc -l) -gt 1 ]]&& sh ./data_clean1.sh

exit 0
#-----------------------------------------------------------------------
# Delete ptmp directories
#-----------------------------------------------------------------------
deletetime=$(date +%Y%m%d -d "${currentime} ${CLEAN_OLDPROD_HRS} hours ago")
echo "Deleting ptmp directories before ${deletetime}..."
cd ${COMOUT_BASEDIR}
set -A XX $(ls -d ${RUN}.20* | sort -r)
for dir in ${XX[*]};do
  onetime=$(echo $dir | cut -d'.' -f2)
  if [[ ${onetime} =~ ^[0-9]+$ ]] && [[ ${onetime} -le ${deletetime} ]]; then
    rm -rf ${COMOUT_BASEDIR}/${RUN}.${onetime}
    echo "Deleted ${COMOUT_BASEDIR}/${RUN}.${onetime}"
  fi
done

#-----------------------------------------------------------------------
# Delete stmp directories
#-----------------------------------------------------------------------
deletetime=$(date +%Y%m%d%H -d "${currentime} ${CLEAN_OLDRUN_HRS} hours ago")
echo "Deleting stmp directories before ${deletetime}..."
cd ${CYCLE_BASEDIR}
set -A XX $(ls -d 20* | sort -r)
for onetime in ${XX[*]};do
  if [[ ${onetime} =~ ^[0-9]+$ ]] && [[ ${onetime} -le ${deletetime} ]]; then
    rm -rf ${CYCLE_BASEDIR}/${onetime}
    echo "Deleted ${CYCLE_BASEDIR}/${onetime}"
  fi
done

#-----------------------------------------------------------------------
# Delete netCDF files
#-----------------------------------------------------------------------
deletetime=$(date +%Y%m%d%H -d "${currentime} ${CLEAN_OLDFCST_HRS} hours ago")
echo "Deleting netCDF files before ${deletetime}..."
cd ${CYCLE_BASEDIR}
set -A XX $(ls -d 20* | sort -r)
for onetime in ${XX[*]};do
  if [[ ${onetime} =~ ^[0-9]+$ ]] && [[ ${onetime} -le ${deletetime} ]]; then
    if [ ${nens} -gt 1 ]; then
      for ii in ${listens}
      do
        iii=`printf %4.4i $ii`
        SLASH_ENSMEM_SUBDIR=/mem${iii}
        rm -f ${CYCLE_BASEDIR}/${onetime}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/phy*nc
        rm -f ${CYCLE_BASEDIR}/${onetime}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/dyn*nc
        rm -rf ${CYCLE_BASEDIR}/${onetime}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART
        echo "Deleted netCDF files in ${CYCLE_BASEDIR}/${onetime}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam"
      done
    else
        rm -f ${CYCLE_BASEDIR}/${onetime}/fcst_fv3lam/phy*nc
        rm -f ${CYCLE_BASEDIR}/${onetime}/fcst_fv3lam/dyn*nc
        rm -f ${CYCLE_BASEDIR}/${onetime}/anal_conv_gsi/pe0*.nc4
        rm -f ${CYCLE_BASEDIR}/${onetime}/anal_conv_gsi/pe0*_setup
        rm -f ${CYCLE_BASEDIR}/${onetime}/anal_conv_gsi/obs_input.*
        rm -f ${CYCLE_BASEDIR}/${onetime}/anal_conv_gsi/diag*
        rm -f ${CYCLE_BASEDIR}/${onetime}/anal_conv_gsi_spinup/pe0*.nc4
        rm -f ${CYCLE_BASEDIR}/${onetime}/anal_conv_gsi_spinup/pe0*_setup
        rm -f ${CYCLE_BASEDIR}/${onetime}/anal_conv_gsi_spinup/obs_input.*
        rm -f ${CYCLE_BASEDIR}/${onetime}/anal_conv_gsi_spinup/diag*

        rm -rf ${CYCLE_BASEDIR}/${onetime}/fcst_fv3lam/RESTART
        echo "Deleted netCDF files in ${CYCLE_BASEDIR}/${onetime}/fcst_fv3lam"
    fi
  fi
done

#-----------------------------------------------------------------------
# Delete duplicate postprod files in stmp
#-----------------------------------------------------------------------
deletetime=$(date +%Y%m%d%H -d "${currentime} ${CLEAN_OLDSTMPPOST_HRS} hours ago")
echo "Deleting stmp postprd files before ${deletetime}..."
cd ${CYCLE_BASEDIR}
set -A XX $(ls -d 20* | sort -r)
for onetime in ${XX[*]};do
  if [[ ${onetime} =~ ^[0-9]+$ ]] && [[ ${onetime} -le ${deletetime} ]]; then
    if [ ${nens} -gt 1 ]; then
      for ii in ${listens}
      do
        iii=`printf %4.4i $ii`
        SLASH_ENSMEM_SUBDIR=/mem${iii}
        rm -rf ${CYCLE_BASEDIR}/${onetime}${SLASH_ENSMEM_SUBDIR}/postprd
        echo "Deleted postprd files in ${CYCLE_BASEDIR}/${onetime}${SLASH_ENSMEM_SUBDIR}/postprd"
      done
    else
        rm -rf ${CYCLE_BASEDIR}/${onetime}/postprd
        echo "Deleted postprd files in ${CYCLE_BASEDIR}/${onetime}/postprd"
    fi
  fi
done

#-----------------------------------------------------------------------
# Delete old log files
#-----------------------------------------------------------------------
deletetime=$(date +%Y%m%d%H -d "${currentime} ${CLEAN_OLDLOG_HRS} hours ago")
echo "Deleting log files before ${deletetime}..."

# Remove template date from last two levels
logs=$(echo ${LOGDIR} | rev | cut -f 3- -d / | rev)
cd ${logs}
pwd
set -A XX $(ls -d ${RUN}.20*/* | sort -r)
for onetime in ${XX[*]}; do
  # Remove slash and RUN from directory to get time
  filetime=${onetime/\//}
  filetime=${filetime##*.}
  # Remove cycle subdir from path
  logsdate=${onetime%%/*}
  if [[ ${filetime} =~ ^[0-9]+$ ]] && [[ ${filetime} -le ${deletetime} ]]; then
    echo "Deleting files from ${logs}/${onetime}"
    rm -rf ${onetime}
    # Remove an empty date directory
    [ "$(ls -A $logsdate)" ] || rmdir $logsdate
  fi
done

#-----------------------------------------------------------------------
# Delete nwges directories
#-----------------------------------------------------------------------
deletetime=$(date +%Y%m%d%H -d "${currentime} ${CLEAN_NWGES_HRS} hours ago")
echo "Deleting nwges directories before ${deletetime}..."
cd ${NWGES_BASEDIR}
set -A XX $(ls -d 20* | sort -r)
for onetime in ${XX[*]};do
  if [[ ${onetime} =~ ^[0-9]+$ ]] && [[ ${onetime} -le ${deletetime} ]]; then
    rm -rf ${NWGES_BASEDIR}/${onetime}
    echo "Deleted ${NWGES_BASEDIR}/${onetime}"
  fi
done

#-----------------------------------------------------------------------
exit 0
