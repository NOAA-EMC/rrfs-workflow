#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1
cyc_interval=${CYC_INTERVAL:-1}
spinup_mode=${SPINUP_MODE:-0}
#
# decide if this cycle is cold start
#
start_type="warm"
for hr in ${COLDSTART_CYCS:-"99"}; do
  chr=$(printf '%02d' $((10#$hr)) )
  if [ "${cyc}" == "${chr}" ]; then
    start_type="cold"
    break
  fi
done
if (( SPINUP_MODE == -1 )); then
# always warm start for prod cycles parallel to spinup cycles
  start_type="warm"
  for hr in ${PRODSWITCH_CYCS:-"99"}; do
    chr=$(printf '%02d' $((10#$hr)) )
    if [ "${cyc}" == "${chr}" ]; then
      prod_switch=yes
      break
    fi
  done
fi
echo "this cycle is ${start_type} start"
#
#  find the right background file
#
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 

if [[ "${start_type}" == "cold" ]]; then
  thisfile=${COMINrrfs}/${RUN}.${PDY}/${cyc}/ic/${WGF}${MEMDIR}/init.nc
  if [[ -r ${thisfile} ]]; then
    ${cpreq} "${thisfile}" "${UMBRELLA_PREP_IC_DATA}/init.nc"
    echo "cold start from ${thisfile}"
  else
    echo "FATAL ERROR: PREP_IC failed, cannot find cold start file: ${thisfile}"
    err_exit
  fi
elif [[ "${start_type}" == "warm" ]]; then
  thisfile="undefined"
  if (( spinup_mode == 1 ));  then
    NUM=1 # only use the previous cycle mpasout.nc
    fcststr="fcst_spinup"
  else
    NUM=3
    if [[ "${prod_switch:-"no"}" == "yes" ]]; then
      fcststr="fcst_spinup"
    else
      fcststr="fcst"
    fi
  fi
  for (( ii=cyc_interval; ii<=$(( NUM*cyc_interval )); ii=ii+cyc_interval )); do
    CDATEp=$(${NDATE} -${ii} "${CDATE}" )
    PDYii=${CDATEp:0:8}
    cycii=${CDATEp:8:2}
    thisfile=${COMINrrfs}/${RUN}.${PDYii}/${cycii}/${fcststr}/${WGF}${MEMDIR}/mpasout.${timestr}.nc
    if [[ -r ${thisfile} ]]; then
      break
    fi
  done
  if [[ -r ${thisfile} ]]; then
    ${cpreq} "${thisfile}" "${UMBRELLA_PREP_IC_DATA}/mpasin.nc"
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
