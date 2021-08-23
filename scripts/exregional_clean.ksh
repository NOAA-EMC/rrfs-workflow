#!/bin/ksh --login

#
#-----------------------------------------------------------------------
# Source the variable definitions file.
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
#
#-----------------------------------------------------------------------
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u -x; } > /dev/null 2>&1
#
#
#-----------------------------------------------------------------------
# set up currentime from CDATE 
#-----------------------------------------------------------------------
#
currentime=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')

#-----------------------------------------------------------------------
# Delete ptmp directories
#-----------------------------------------------------------------------
deletetime=$(date +%Y%m%d -d "${currentime} ${CLEAN_OLDPROD_HRS} hours ago")
echo "Deleting ptmp directories before ${deletetime}..."
cd ${COMOUT_BASEDIR}
set -A XX $(ls -d ${RUN}.20* | sort -r)
for dir in ${XX[*]};do
  onetime=$(echo $dir | cut -d'.' -f2)
  if [[ ${onetime} =~ '^[0-9]+$' ]] && [[ ${onetime} -le ${deletetime} ]]; then
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
  if [[ ${onetime} =~ '^[0-9]+$' ]] && [[ ${onetime} -le ${deletetime} ]]; then
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
  if [[ ${onetime} =~ '^[0-9]+$' ]] && [[ ${onetime} -le ${deletetime} ]]; then
    rm -f ${CYCLE_BASEDIR}/${onetime}/fcst_fv3lam/phy*nc
    rm -f ${CYCLE_BASEDIR}/${onetime}/fcst_fv3lam/dyn*nc
    rm -rf ${CYCLE_BASEDIR}/${onetime}/fcst_fv3lam/RESTART
    echo "Deleted netCDF files in ${CYCLE_BASEDIR}/${onetime}/fcst_fv3lam"
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
  if [[ ${onetime} =~ '^[0-9]+$' ]] && [[ ${onetime} -le ${deletetime} ]]; then
    rm -rf ${CYCLE_BASEDIR}/${onetime}/postprd
    echo "Deleted postprd files in ${CYCLE_BASEDIR}/${onetime}/postprd"
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
  if [[ ${filetime} =~ '^[0-9]+$' ]] && [[ ${filetime} -le ${deletetime} ]]; then
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
  if [[ ${onetime} =~ '^[0-9]+$' ]] && [[ ${onetime} -le ${deletetime} ]]; then
    rm -rf ${NWGES_BASEDIR}/${onetime}
    echo "Deleted ${NWGES_BASEDIR}/${onetime}"
  fi
done

exit 0
