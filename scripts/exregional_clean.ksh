#!/bin/ksh --login

currentime=`date`

. ${GLOBAL_VAR_DEFNS_FP}

# Delete run directories
deletetime=`date +%Y%m%d%H -d "${currentime} 72 hours ago"`
echo "Deleting directories before ${deletetime}..."
cd ${CYCLE_BASEDIR}
set -A XX `ls -d 20* | sort -r`
for onetime in ${XX[*]};do
  if [[ ${onetime} -le ${deletetime} ]]; then
    rm -rf ${CYCLE_BASEDIR}/${onetime}
    echo "Deleted ${CYCLE_BASEDIR}/${onetime}"
  fi
done

# Delete netCDF files
deletetime=`date +%Y%m%d%H -d "${currentime} 24 hours ago"`
echo "Deleting netCDF files before ${deletetime}..."
cd ${CYCLE_BASEDIR}
set -A XX `ls -d 20* | sort -r`
for onetime in ${XX[*]};do
  if [[ ${onetime} -le ${deletetime} ]]; then
    rm -f ${CYCLE_BASEDIR}/${onetime}/phy*nc
    rm -f ${CYCLE_BASEDIR}/${onetime}/dyn*nc
    rm -rf ${CYCLE_BASEDIR}/${onetime}/RESTART
    rm -rf ${CYCLE_BASEDIR}/${onetime}/INPUT
    echo "Deleted netCDF files in ${CYCLE_BASEDIR}/${onetime}"
  fi
done

# Delete old log files
deletetime=`date +%Y%m%d%H -d "${currentime} 48 hours ago"`
echo "Deleting log files before ${deletetime}..."

# Remove template date from last two levels
logs=`echo ${LOGDIR} | rev | cut -f 3- -d / | rev`
cd ${logs}
pwd
set -A XX `ls -d 20*/* | sort -r`
for onetime in ${XX[*]}; do
  # Remove slash from directory to get time
  filetime=${onetime/\//}
  logsdate=${onetime%%/*}
  if [[ ${filetime} -le ${deletetime} ]]; then
    echo "Deleting files from ${logs}/${onetime}"
    rm -rf ${onetime}
    # Remove an empty date directory
    [ "$(ls -A $logsdate)" ] || rmdir $logsdate
  fi
done

exit 0
