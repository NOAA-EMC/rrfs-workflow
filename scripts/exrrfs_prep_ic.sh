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

# Populate the list for the ensemble members, or deterministic member
if (( "${ENS_SIZE:-0}" > 2 )); then
  mapfile -t mem_list < <(printf "%03d\n" $(seq 1 "$ENS_SIZE"))
else
  mem_list=("000") # if determinitic
fi

for index in "${mem_list[@]}"; do # loop through all the members
  # Determine path
  if (( 10#${index} == 0 )); then
    memdir=""
    umbrella_prep_ic_mem="${UMBRELLA_PREP_IC_DATA}"
    export CMDFILE="${DATA}/script_prep_ic_0.sh"
  else
    memdir="/mem${index}"
    umbrella_prep_ic_mem="${UMBRELLA_PREP_IC_DATA}${memdir}"
    mkdir -p "${umbrella_prep_ic_mem}"
    pid=$((10#${index}-1))
    export CMDFILE="${DATA}/script_prep_ic_${pid}.sh"
  fi

  if [[ "${start_type}" == "cold" ]]; then
    thisfile=${COMINrrfs}/${RUN}.${PDY}/${cyc}/ic/${WGF}${memdir}/init.nc
    if [[ -r ${thisfile} ]]; then
      echo "${cpreq} ${thisfile} ${umbrella_prep_ic_mem}/init.nc" >> "$CMDFILE"
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
      thisfile=${COMINrrfs}/${RUN}.${PDYii}/${cycii}/${fcststr}/${WGF}${memdir}/mpasout.${timestr}.nc
      if [[ -r ${thisfile} ]]; then
        break
      fi
    done
    if [[ -r ${thisfile} ]]; then
      echo "${cpreq} ${thisfile} ${umbrella_prep_ic_mem}/mpasout.nc"  >> "$CMDFILE"
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
        thisfile_mpasout=${COMINsfc}/${RUN}.${PDYii}/${cycii}/fcst/${WGF}${memdir}/mpasout.${timestr}.nc
        if [[ -r ${thisfile_mpasout} ]]; then
          thisfile=${thisfile_mpasout}
          break
        fi
      done
      # if no mpasout files, use init.nc (from another run)
      if [[ ! -r ${thisfile_mpasout} ]] && [[ "${COMINsfc}" != "${COMINrrfs}" ]] ; then
        PDYii=${CDATE:0:8}
        cycii=${CDATE:8:2}
        thisfile_init=${COMINsfc}/${RUN}.${PDYii}/${cycii}/ic/${WGF}${memdir}/init.nc
        if [[ -r ${thisfile_init} ]]; then
          var_list="smois,snow,snowh,snowc,sst,canwat,tslb,skintemp,landmask,isltyp,ivgtyp"
          thisfile=${thisfile_init}
        fi
      fi
      #
      if [[ -r ${thisfile} ]]; then
        echo "${cpreq}" "${thisfile}" "${umbrella_prep_ic_mem}/mpas_sfc.nc" >> "$CMDFILE"
        if [[ -r "${umbrella_prep_ic_mem}/init.nc" ]]; then
          to_file="${umbrella_prep_ic_mem}/init.nc"
        elif [[ -r "${umbrella_prep_ic_mem}/mpasout.nc" ]]; then
          to_file="${umbrella_prep_ic_mem}/mpasout.nc"
        fi
        echo "surface update from ${thisfile} to ${to_file}"
        echo " ncks -O -C -x -v ${var_list} \"${to_file}\"  tmp.nc ; \
               ncks -A -v ${var_list} \"${umbrella_prep_ic_mem}/mpas_sfc.nc\" tmp.nc ; \
               mv tmp.nc \"${to_file}\" " >>  "$CMDFILE"
      else
        echo "SFC_UPDATE failed, cannot find source file for sfc state: ${thisfile}"
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
        echo "cp ${satbias_path}/*satbias*.nc  ${umbrella_prep_ic_mem}" >> "$CMDFILE"
        echo "found satbias from ${satbias_path}"
        break
      fi
    done
  fi

done # done for all the members

#
# parallel run the serial tasks
#
${cpreq} "${EXECrrfs}"/rank_run.x .
${MPI_RUN_CMD} ./rank_run.x "${DATA}/script_prep_ic_*.sh"

# Check for errors
export err=$?
if (( err != 0 )); then
  echo "prep_ic failed with error code ${err}"
  err_exit
else
  echo "prep_ic completed successfully"
fi

exit 0
