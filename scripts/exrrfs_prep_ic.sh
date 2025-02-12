#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}
cyc_interval=${CYC_INTERVAL:-1}
#
# decide if this cycle is cold start
#
start_type="warm"
cyc_hrs_coldstart=${CYCL_HRS_COLDSTART:-"99"}
array=(${cyc_hrs_coldstart})
for hr in "${array[@]}"; do
  chr=$(printf '%02d' ${hr})
  if [ "${cyc}" == "${chr}" ]; then
    start_type="cold"
  fi
done
echo "this cycle is ${start_type} start"
#
#  find the right background file
#
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 

if [[ "${start_type}" == "cold" ]]; then
  thisfile=${COMINrrfs}/${RUN}${WGF}.${PDY}/${cyc}${MEMDIR}/ic/init.nc
  if [[ -r ${thisfile} ]]; then
    ${cpreq} ${thisfile} ${UMBRELLA_PREP_IC_DATA}/init.nc
    echo "cold start from ${thisfile}"
  else
    echo "FATAL ERROR: PREP_IC failed, cannot find cold start file: ${thisfile}"
    err_exit
  fi
elif [[ "${start_type}" == "warm" ]]; then
  thisfile="undefined"
  for (( ii=${cyc_interval}; ii<=$(( 3*${cyc_interval} )); ii=ii+${cyc_interval} )); do
    CDATEp=$($NDATE -${ii} ${CDATE} )
    PDYii=${CDATEp:0:8}
    cycii=${CDATEp:8:2}
    thisfile=${COMINrrfs}/${RUN}${WGF}.${PDYii}/${cycii}${MEMDIR}/fcst/mpasout.${timestr}.nc
    if [[ -r ${thisfile} ]]; then
      break
    fi
  done
  if [[ -r ${thisfile} ]]; then
    ${cpreq} ${thisfile} ${UMBRELLA_PREP_IC_DATA}/mpasin.nc
    echo "warm start from ${thisfile}"
  else
    echo "FATAL ERROR: PREP_IC failed, cannot find warm start file: ${thisfile}"
    err_exit
  fi
else
  echo "FATAL ERROR: PREP_IC failed, start type is not defined"
  err_exit
fi
exit 0
