#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}
prefix='GFS'
BUMPLOC=${BUMPLOC:-"conus12km-401km11levels"}

cd ${DATA}
CDATEm1=$($NDATE -1 ${CDATE})
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
# determine whether to begin new cycles
IFS=' ' read -r -a array <<< "${PROD_BGN_AT_HRS}"
begin="NO"
for hr in "${array[@]}"; do
  if [[ "${cyc}" == "$(printf '%02d' ${hr})" ]]; then
    begin="YES"; break
  fi
done
#
${cpreq} ${FIXrrfs}/physics/${PHYSICS_SUITE}/* .
ln -snf VEGPARM.TBL.da VEGPARM.TBL #gge.debug temp
mkdir -p graphinfo stream_list
${cpreq} ${FIXrrfs}/graphinfo/* graphinfo/
${cpreq} ${FIXrrfs}/jedi/obsop_name_map.yaml .                  
${cpreq} ${FIXrrfs}/jedi/keptvars.yaml .              
${cpreq} ${FIXrrfs}/jedi/geovars.yaml . 
${cpreq} ${FIXrrfs}/stream_list/${PHYSICS_SUITE}/* stream_list/
mkdir -p data; cd data                   
mkdir -p bumploc obs ens
${cpreq} ${FIXrrfs}/bumploc/${BUMPLOC} bumploc/
${cpreq} ${FIXrrfs}/meshes/${NET}.static.nc static.nc
if [[ "${begin}" == "YES" ]]; then
  # mpasjedi cannot run on init.nc due to the miss of pressure values
  : #do nothing
else
  cpfs ${DATAROOT}/${NET}/${rrfs_ver}/${RUN}.${CDATEm1:0:8}/${CDATEm1:8:2}/fcst/restart.${timestr}.nc .
fi
#${cpreq} ${COMINioda}/..../obs/* obs/                            
#${cpreq} ${COMINgdas}/..../ens/* ens/
#
# generate the namelist on the fly
# namelist.atmosphere and streams.atmosphere
#sed -e "s/@restart_interval@/${restart_interval}/" -e "s/@history_interval@/${history_interval}/" \
#    -e "s/@diag_interval@/${diag_interval}/" -e "s/@lbc_interval@/${lbc_interval}/" \
#    ${PARMrrfs}/streams.atmosphere_fcst > streams.atmosphere

# run mpasjedi_variational.x
export OOPS_TRACE=1
export OMP_NUM_THREADS=1
ulimit -s unlimited
ulimit -v unlimited
ulimit -a

source prep_step
${cpreq} ${EXECrrfs}/mpasjedi_variational.x .
#${MPI_RUN_CMD} ./mpasjedi_variational.x  ./$inputfile    log.out
# check the status
export err=$?
err_chk

# copy output to COMOUT
if [[ "${begin}" == "YES" ]]; then
  : # do nothing on init.nc for now
else
  ${cpreq} ${DATA}/data/restart.${timestr}.nc ${COMOUT}/da/
fi
