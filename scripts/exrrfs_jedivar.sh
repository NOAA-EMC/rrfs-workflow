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
  do_DAcycling='false'
  initial_file=${UMBRELLA_ROOT}/prep_ic/init.nc
else
  start_type='warm'
  do_DAcycling='true'
  initial_file=${UMBRELLA_ROOT}/prep_ic/mpasin.nc
fi
#
ln -snf ${FIXrrfs}/physics/${PHYSICS_SUITE}/* .
ln -snf ${FIXrrfs}/meshes/${MESH_NAME}.ugwp_oro_data.nc ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < ${zeta_levels})
ln -snf ${FIXrrfs}/meshes/${MESH_NAME}.invariant.nc_L${nlevel} ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf ${FIXrrfs}/graphinfo/* graphinfo/
ln -snf ${FIXrrfs}/stream_list/${PHYSICS_SUITE}/* stream_list/
${cpreq} ${FIXrrfs}/jedi/obsop_name_map.yaml .                  
${cpreq} ${FIXrrfs}/jedi/keptvars.yaml .              
${cpreq} ${FIXrrfs}/jedi/geovars.yaml . 
#
# create data directory 
#
mkdir -p data; cd data                   
mkdir -p bumploc obs ens static_bec
#
#  bump files and static BEC files
#
ln -snf ${FIXrrfs}/bumploc/${BUMPLOC}/* bumploc/
ln -snf ${FIXrrfs}/static_bec/${MESH_NAME}_L${nlevel}/stddev.nc static_bec/stddev.nc
ln -snf ${FIXrrfs}/static_bec/${MESH_NAME}_L${nlevel}/nicas_${NTASKS} static_bec/nicas
ln -snf ${FIXrrfs}/static_bec/${MESH_NAME}_L${nlevel}/vbal_${NTASKS} static_bec/vbal
#
# copy observations files
#
cp ${COMOUT}/ioda_bufr/* obs/.
#
#  find ensemble forecasts based on HYB_OPT
#    0: no_ensemble BEC; 1. online rrfs ensembles; 2. offline rrfs ensembles; 3. online GDAS ensembles
#
if [[ "HYB_OPT" == 1  ]]; then
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
fi
#
#  link background
#
cd ${DATA}
ln -snf ${initial_file} mpasin.nc
#
# generate namelist, streams, and jedivar.yaml on the fly
run_duration=1:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="true" #true
if [[ "${MESH_NAME}" == "conus12km" ]]; then
  dt=60
  substeps=2
  disp=12000.0
  radt=30
  pio_num_iotasks=1
  pio_stride=40
elif [[ "${MESH_NAME}" == "conus3km" ]]; then
  dt=20
  substeps=4
  disp=3000.0
  radt=15
  pio_num_iotasks=40
  pio_stride=20
else
  echo "Unknown MESH_NAME, exit!"
  err_exit
fi
file_content=$(< ${PARMrrfs}/${physics_suite}/namelist.atmosphere) # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere
${cpreq} ${PARMrrfs}/streams.atmosphere.da streams.atmosphere
analysisDate=""${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z""
beginDate=""${CDATEm1:0:4}-${CDATEm1:4:2}-${CDATEm1:6:2}T${CDATEm1:8:2}:00:00Z""
sed -e "s/@analysisDate@/${analysisDate}/" -e "s/@beginDate@/${beginDate}/" \
    ${PARMrrfs}/jedivar.yaml > jedivar.yaml

if [[ ${start_type} == "cold" ]]; then
  exit 0 #gge.tmp.debug need more time to figure out cold start DA
fi
# run mpasjedi_variational.x
export OOPS_TRACE=1
export OMP_NUM_THREADS=1
ulimit -s unlimited
ulimit -v unlimited
ulimit -a

source prep_step
${cpreq} ${EXECrrfs}/mpasjedi_variational.x .
${MPI_RUN_CMD} ./mpasjedi_variational.x jedivar.yaml log.out
# check the status
export err=$?
err_chk
#
# the input/output file are linked from the umbrella directory, so no need to copy
