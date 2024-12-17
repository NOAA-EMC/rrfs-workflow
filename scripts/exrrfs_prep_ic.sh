#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S) 
IFS=' ' read -r -a array <<< "${PROD_BGN_AT_HRS}"
lbc_interval=${LBC_INTERVAL:-3}
# determine whether to begin new cycles
begin="NO"
begin="YES"
#for hr in "${array[@]}"; do
#  if [[ "${cyc}" == "$(printf '%02d' ${hr})" ]]; then
#    begin="YES"; break
#  fi
#done
if [[ "${begin}" == "YES" ]]; then
  ${cpreq} ${COMINrrfs}/rrfs.${PDY}/${cyc}${MEMDIR}/ic/init.nc ${UMBRELLA_DATA}${MEMDIR}/prep_ic/.
  do_restart='false'
else
  ${cpreq} ${COMINrrfs}/rrfs.${PDY}/${cyc}${MEMDIR}/da/restart.${timestr}.nc ${UMBRELLA_DATA}${MEMDIR}/prep_ic/.
  do_restart='true'
fi
