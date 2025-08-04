#!/usr/bin/env bash
# shellcheck disable=SC2154,SC1091
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
#prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
#
# enter the run directory
#
cd "${DATA}" || exit

#start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
#timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
#
# determine whether to begin new cycles and link correct ensembles
#
if [[ -s "${UMBRELLA_PREP_IC_DATA}/mem001/init.nc" ]]; then
  echo "recentering does not work for cold start!"
  exit 0
else
  initial_file='mpasout.nc'
fi
#
# link ensemble members
#
for i in $(seq -w 001 "${ENS_SIZE}"); do
  ln -snf "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}" mpasout_mem"${i}".nc
done

#-----------------------------------------------------------------------
#
# link the control member 
#
#-----------------------------------------------------------------------
#
mpasoutfile="${UMBRELLA_PREP_CONTROL_IC_DATA}/mpasout.nc"
if [ -s "${mpasoutfile}" ] ; then
  ln -sf "${mpasoutfile}"  ./mpasout_control.nc
  ${cpreq} "${mpasoutfile}"  ./mpasout_mean.nc
else
  err_exit "Cannot find control background: ${mpasoutfile}"
fi

#
# generate the namelist.ens
#
cat << EOF > namelist.ens
&setup
  ens_size=${ENS_SIZE},
  filebase='mpasout'
  filetail(1)='.nc'
  numvar(1)=6
  varlist(1)="qv u w theta tslb q2"
  l_write_mean=.true.
  l_recenter=.true.
/
EOF

# run mpasjedi_enkf.x
export pgm="gen_ensmean_recenter.exe"
${cpreq} "${EXECrrfs}"/${pgm} .
source prep_step
${MPI_RUN_CMD} ./${pgm} log.out
# check the status
export err=$?
err_chk
#
