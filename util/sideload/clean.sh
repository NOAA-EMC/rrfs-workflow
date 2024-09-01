#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
date
#
# for debugging
#EXPDIR=/home/role.rtrr/RRFS/1.0.1/conus12km
#
export task_id=${task_id:-'clean'}
# source the config cascade
source ${EXPDIR}/exp.setup
source ${EXPDIR}/config/config.base
source ${EXPDIR}/config/config.${MACHINE}
source ${EXPDIR}/config/config.${task_id}
rrfs_ver=${VERSION}
RUN=rrfs

# for debugging
#CDATE=2024072000
#CLEAN_HRS_IC=6 #gge.debug
#CLEAN_HRS_LBC=12 #gge.debug
#CLEAN_HRS_DA=6 #gge.debug
#CLEAN_HRS_FCST=6 #gge.debug
#CLEAN_HRS_FCST_HISTORY=3 #gge.debug
#CLEAN_HRS_FCST_RESTART=3 #gge.debug
#CLEAN_HRS_FCST_DIAG=3 #gge.debug
#CLEAN_HRS_LOG=6 #gge.debug

delete_data() {
  local CLEAN_HRS=$1
  local basedir=$2
  local task_id=$3
  cd ${basedir}
  local deletetime=$(date +%Y%m%d%H -d "${CDATE:0:8} ${CDAE:8:2} ${CLEAN_HRS} hours ago")
  for dir in  $(ls -d ${RUN}*/* | sort -r); do
    local myPDY=${dir:5:8}
    local HH=${dir:14:2}
    local dirtime=${myPDY}${HH}
    if [[ ${dirtime} =~ ^[0-9]+$  ]] && [[ ${dirtime} -le ${deletetime} ]]; then
      rm -rf ${RUN}.${myPDY}/${HH}/${task_id}
      echo "Cleaned ${basedir}/${RUN}.${myPDY}/${HH}/${task_id}"
    fi
  done
}

# clean ic
delete_data ${CLEAN_HRS_IC} ${COMROOT}/${NET}/${rrfs_ver} 'ic'
delete_data ${CLEAN_HRS_IC} ${DATAROOT}/${NET}/${rrfs_ver} 'ic'

# clean lbc
delete_data ${CLEAN_HRS_LBC} ${COMROOT}/${NET}/${rrfs_ver} 'lbc'
delete_data ${CLEAN_HRS_LBC} ${DATAROOT}/${NET}/${rrfs_ver} 'lbc'

# clean DA
delete_data ${CLEAN_HRS_DA} ${COMROOT}/${NET}/${rrfs_ver} 'da'
delete_data ${CLEAN_HRS_DA} ${DATAROOT}/${NET}/${rrfs_ver} 'da'

# clean fcst  (files other than history, diag and restart may stay longer)
delete_data ${CLEAN_HRS_FCST} ${COMROOT}/${NET}/${rrfs_ver} 'fcst'
delete_data ${CLEAN_HRS_FCST} ${DATAROOT}/${NET}/${rrfs_ver} 'fcst'

# clean fcst history, diag, restart
delete_data ${CLEAN_HRS_FCST_HISTORY} ${COMROOT}/${NET}/${rrfs_ver} 'fcst/history.*'
delete_data ${CLEAN_HRS_FCST_DIAG} ${COMROOT}/${NET}/${rrfs_ver} 'fcst/restart.*'
delete_data ${CLEAN_HRS_FCST_RESTART} ${COMROOT}/${NET}/${rrfs_ver} 'fcst/diag.*'

# clean log files
delete_data ${CLEAN_HRS_LOG} ${COMROOT}/${NET}/${rrfs_ver}/logs ''
#
exit 0
