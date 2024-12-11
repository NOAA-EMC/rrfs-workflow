#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}
#
#  find cycle time
#
YYYYMMDDHH=${CDATE}
YYYYMMDD=${CDATE:0:8}
HH=${CDATE:8:2}
#
# 
#
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
if [[ -z "${ENS_INDEX}" ]]; then
  IFS=' ' read -r -a array <<< "${PROD_BGN_AT_HRS}"
  ensindexstr=""
  lbc_interval=${LBC_INTERVAL:-3}
else
  IFS=' ' read -r -a array <<< "${ENS_PROD_BGN_AT_HRS}"
  ensindexstr="/mem${ENS_INDEX}"
  lbc_interval=${ENS_LBC_INTERVAL:-3}
fi
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$(${USHrrfs}/find_fcst_length.sh "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"

#
# find cycle that has boundary files 
#

CDATElbcend=$($NDATE $((10#${fcst_len_hrs_thiscyc})) ${CDATE})
string_time=$(date -d "${CDATElbcend:0:8} ${CDATElbcend:8:2}" +%Y-%m-%d_%H.%M.%S)
last_bdyfile="lbc.${string_time}.nc"
n=0
while [[ $n -le 12 ]]; do
  CDATElbc=$($NDATE -$((10#${n})) ${CDATE})
  YYYYMMDDlbc=${CDATElbc:0:8}
  HHlbc=${CDATElbc:8:2}
  checkfile=${COMINrrfs}/${RUN}.${YYYYMMDDlbc}/${HHlbc}${ensindexstr}/lbc/${last_bdyfile}
  if [ -r "${checkfile}" ];then
     echo "Found ${checkfile}; Use it as boundary for forecast "
     break
  else
     n=$((n + 1))
  fi
done

#
# find bdy sequence and copy them to umbrella space
#

fhr_all=$(seq 0 $((10#${lbc_interval})) $((10#${fcst_len_hrs_thiscyc} )) )

if [ -r "${checkfile}" ]; then
  for fhr in  ${fhr_all}; do
    CDATElbc=$($NDATE ${fhr} ${CDATE})
    string_time=$(date -d "${CDATElbc:0:8} ${CDATElbc:8:2}" +%Y-%m-%d_%H.%M.%S)
    ${cpreq} ${COMINrrfs}/${RUN}.${YYYYMMDDlbc}/${HHlbc}${ensindexstr}/lbc/lbc.${string_time}.nc ${UMBRELLA_DATA}/prep_lbc/.
  done
else
  echo "Cannot find boundary file: ${checkfile}"
  err_exit
fi

