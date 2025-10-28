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
if (( spinup_mode == -1 )); then
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
    ${cpreq} "${thisfile}" "${UMBRELLA_PREP_IC_DATA}/mpasout.nc"
    echo "warm start from ${thisfile}"
  else
    echo "FATAL ERROR: PREP_IC failed, cannot find warm start file: ${thisfile}"
    err_exit
  fi
else
  echo "FATAL ERROR: PREP_IC failed, start type is not defined"
  err_exit
fi

#
# do sfc cycling
#
for hr in ${SFC_UPDATE_CYCS:-"99"}; do
  shr=$(printf '%02d' $((10#$hr)) )
  var_list="smois,snow,snowh,snowc,sst,canwat,tslb,skintemp,landmask,isltyp,ivgtyp,soilt1"
  if [ "${cyc}" == "${shr}" ]; then
    NUM=3 # look back ${NUM} cycles to find mpasout files for surface cycling
    for (( ii=cyc_interval; ii<=$(( NUM*cyc_interval )); ii=ii+cyc_interval )); do
      CDATEp=$(${NDATE} -${ii} "${CDATE}" )
      PDYii=${CDATEp:0:8}
      cycii=${CDATEp:8:2}
      thisfile=${COMINrrfs}/${RUN}.${PDYii}/${cycii}/fcst/${WGF}${MEMDIR}/mpasout.${timestr}.nc
      if [[ -r ${thisfile} ]]; then
        break
      fi
    done
    if [[ -r ${thisfile} ]]; then
      ${cpreq} "${thisfile}" "${UMBRELLA_PREP_IC_DATA}/mpas_sfc.nc"
      if [[ -r "${UMBRELLA_PREP_IC_DATA}/init.nc" ]]; then
        to_file="${UMBRELLA_PREP_IC_DATA}/init.nc"
      elif [[ -r "${UMBRELLA_PREP_IC_DATA}/mpasout.nc" ]]; then
        to_file="${UMBRELLA_PREP_IC_DATA}/mpasout.nc"
      fi
      echo "surface update from ${thisfile} to ${to_file}"
      ncks -O -C -x -v ${var_list} "${to_file}"  tmp.nc
      ncks -A -v ${var_list} "${UMBRELLA_PREP_IC_DATA}/mpas_sfc.nc" tmp.nc
      mv tmp.nc "${to_file}"
    else
      echo "SFC_UPDATE failed, cannot find warm start file: ${thisfile}"
    fi
  fi
done

#
#  find the right satbias file
#
PREP_IC_TYPE=${PREP_IC_TYPE:-"no_da"}
if [[ "${PREP_IC_TYPE}" == "jedivar" ]] || [[ "${PREP_IC_TYPE}" == "getkf"  ]]; then
  if ( (( spinup_mode == 1 )) && [[ "${start_type}" == "warm" ]] ) || \
     ( (( spinup_mode == -1 )) && [[ "${prod_switch:-"no"}" == "yes" ]] ); then
    # warm start in the spinup session or prod_switch in the prod session
      spinup_str="_spinup"
  else
      spinup_str=""
  fi

  NUM=5 # look back ${NUM} cycles to find satbias files
  if [[ "${USE_THE_LATEST_SATBIAS:-"FALSE"}" == "TRUE" ]]; then # only use the latest satbias from the previous cycle
    NUM=1
  fi

  for (( ii=cyc_interval; ii<=$(( NUM*cyc_interval )); ii=ii+cyc_interval )); do
    CDATEp=$(${NDATE} -${ii} "${CDATE}" )
    PDYii=${CDATEp:0:8}
    cycii=${CDATEp:8:2}
    satbias_path=${COMINrrfs}/${RUN}.${PDYii}/${cycii}/${PREP_IC_TYPE}${spinup_str}/${WGF}
    nSatbias=$(find "${satbias_path}"/*satbias*.nc | wc -l)
    if (( nSatbias > 0 )); then
      cp "${satbias_path}"/*satbias*.nc  "${UMBRELLA_PREP_IC_DATA}"
      echo "found satbias from ${satbias_path}"
      break
    fi
  done
fi

exit 0
