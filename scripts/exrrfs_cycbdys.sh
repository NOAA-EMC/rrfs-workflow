#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}
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
# determine whether to begin new cycles
begin="NO"
begin="YES"
#for hr in "${array[@]}"; do
#  if [[ "${cyc}" == "$(printf '%02d' ${hr})" ]]; then
#    begin="YES"; break
#  fi
#done

#offset=$((10#${cyc}%6))
#CDATElbc=$($NDATE -${offset} ${CDATE})
CDATElbc=${CDATE}
${cpreq} ${COMINrrfs}/${RUN}.${CDATElbc:0:8}/${CDATElbc:8:2}${ensindexstr}/lbc/lbc*.nc ${UMBRELLA_DATA}/cycbdys/.

