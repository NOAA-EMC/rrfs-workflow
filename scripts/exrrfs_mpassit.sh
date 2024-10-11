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
#gge.debug: in operation, does UPP work on COMROOT(wait for the completion of all fcsts?)  or DATAROOT?
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

# run the MPAS model
ulimit -s unlimited
ulimit -v unlimited
ulimit -a
### temporarily solution since mpassit uses different modules files that other components
set +x # supress messy output in the module load process
module purge
module load gnu
module load intel/2023.2.0
module load impi/2023.2.0
module load pnetcdf/1.12.3
module load szip
module load hdf5parallel/1.10.5
module load netcdf-hdf5parallel/4.7.0
module use /mnt/lfs4/HFIP/hfv3gfs/nwprod/NCEPLIBS/modulefiles
module load netcdf/4.7.0
PNETCDF=/apps/pnetcdf/1.12.3/intel_2023.2.0-impi
module use "/lfs5/BMC/nrtrr/FIX_RRFS2/modulefiles"
module load "prod_util/2.1.1"
module list
set -x  
### temporarily solution since mpassit uses different modules files that other components
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
