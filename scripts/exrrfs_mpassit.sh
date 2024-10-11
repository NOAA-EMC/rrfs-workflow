#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}/${FHR}
fhr=$((10#${FHR:-0})) # remove leading zeros
CDATEp=$($NDATE ${fhr} ${CDATE} )
timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S) 

if [[ -z "${ENS_INDEX}" ]]; then
  ensindexstr=""
else
  ensindexstr="/mem${ENS_INDEX}"
fi
${cpreq} ${DATAROOT}/${NET}/${rrfs_ver}/${RUN}.${PDY}/${cyc}${ensindexstr}/fcst/history.${timestr}.nc .
${cpreq} ${DATAROOT}/${NET}/${rrfs_ver}/${RUN}.${PDY}/${cyc}${ensindexstr}/fcst/diag.${timestr}.nc .
${cpreq} ${FIXrrfs}/mpassit/${NET}/* .
# generate the namelist on the fly
if [[ "${NET}" == "conus12km" ]]; then
  nx=480
  ny=280
  dx=12000.0
  ref_lat=39.0
elif [[ "${NET}" == "conus3km" ]]; then
  nx=1601
  ny=961
  dx=3000.0
  ref_lat=38.5
fi
sed -e "s/@timestr@/${timestr}/" -e "s/@nx@/${nx}/" -e "s/@ny@/${ny}/" -e "s/@dx@/${dx}/" \
    -e "s/@ref_lat@/${ref_lat}/" ${PARMrrfs}/namelist.mpassit > namelist.mpassit

# run the executable
ulimit -s unlimited
ulimit -v unlimited
ulimit -a
source prep_step
${cpreq} ${EXECrrfs}/mpassit.x .
${MPI_RUN_CMD} ./mpassit.x namelist.mpassit
# check the status, copy output to COMOUT
if [[ -s "./mpassit.${timestr}.nc" ]]; then
  ${cpreq} ${DATA}/${FHR}/mpassit.${timestr}.nc ${COMOUT}${ensindexstr}/mpassit/
else
  echo "FATAL ERROR: failed to genereate mpassit.${timestr}.nc"
  err_exit
fi
