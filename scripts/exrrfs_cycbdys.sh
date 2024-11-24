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
# find bdy sequence and copy them to umbrella space
#
fhr_all=$(seq 0 $((10#${lbc_interval})) $((10#${fcst_len_hrs_thiscyc} )) )

knt=0
for fhr in  ${fhr_all}; do
  CDATElbc=$($NDATE ${fhr} ${CDATE})
  string_time=$(date -d "${CDATElbc:0:8} ${CDATElbc:8:2}" +%Y-%m-%d_%H.%M.%S)
  ${cpreq} ${COMINrrfs}/${RUN}.${YYYYMMDD}/${HH}${ensindexstr}/lbc/lbc.${string_time}.nc ${UMBRELLA_DATA}/cycbdys/.
done

#CDATElbc=${CDATE}
#${cpreq} ${COMINrrfs}/${RUN}.${CDATElbc:0:8}/${CDATElbc:8:2}${ensindexstr}/lbc/lbc*.nc ${UMBRELLA_DATA}/cycbdys/.

