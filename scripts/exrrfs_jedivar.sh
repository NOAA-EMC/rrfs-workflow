#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x

cpreq=${cpreq:-cpreq}
BUMPLOC=${BUMPLOC:-"conus12km-401km11levels"}

cd ${DATA}

CDATEm1=$($NDATE -1 ${CDATE})
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
#
# determine whether to begin new cycles
#
if [[ -r "${UMBRELLA_ROOT}/prep_ic/init.nc" ]]; then
  start_type='cold'
  initial_filename='init.nc'
  initial_file=${UMBRELLA_ROOT}/prep_ic/init.nc
else
  start_type='warm'
  initial_filename='mpasin.nc'
  initial_file=${UMBRELLA_ROOT}/prep_ic/mpasin.nc
fi
#
#
#
${cpreq} ${FIXrrfs}/physics/${PHYSICS_SUITE}/* .
#ln -snf VEGPARM.TBL.da VEGPARM.TBL #gge.debug temp
mkdir -p graphinfo stream_list
${cpreq} ${FIXrrfs}/graphinfo/* graphinfo/
${cpreq} ${FIXrrfs}/jedi/obsop_name_map.yaml .                  
${cpreq} ${FIXrrfs}/jedi/keptvars.yaml .              
${cpreq} ${FIXrrfs}/jedi/geovars.yaml . 
${cpreq} ${FIXrrfs}/stream_list/${PHYSICS_SUITE}/* stream_list/
#
# create data directory 
#
mkdir -p data; cd data                   
mkdir -p bumploc obs ens

#
#  bump files
#
${cpreq} ${FIXrrfs}/bumploc/${BUMPLOC}/* bumploc/
${cpreq} ${FIXrrfs}/meshes/${MESH_NAME}.static.nc static.nc

#
#  link background
#

ln -snf ${initial_file} .

#
# copy observations files
#
cp ${COMOUT}/ioda_bufr/* obs/.                           
#
#  find ensemble forecast
#
mpasout_file=mpasout.${timestr}.nc
for (( ii=0; ii<4; ii=ii+1 )); do
   CDATEp=$($NDATE -${ii} ${CDATE} )
   ensdir=${COMINrrfs}/rrfsenkf.${CDATEp:0:8}/${CDATEp:8:2}
   ensdir_m001=${ensdir}/m001/fcst
   if [[ -s ${ensdir_m001}/${mpasout_file} ]]; then
     for (( iii=1; iii<31; iii=iii+1 )); do
        memid=$(printf %03d ${iii})
        ln -s ${ensdir}/m${memid}/fcst/${mpasout_file} ens/m${memid}.${mpasout_file}
     done
   fi
done
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
if [[ "${begin}" != "YES" ]]; then
  ${cpreq} ${DATA}/data/${initial_filename} ${COMOUT}/da_jedivar/.
fi
