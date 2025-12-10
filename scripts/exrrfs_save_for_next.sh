#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1
mpasout_interval=${MPASOUT_INTERVAL:-1}
cyc_interval=${CYC_INTERVAL:-1}
#
CDATEp=$( ${NDATE}  "${cyc_interval}"  "${CDATE}" )
timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
mpasout_file=${UMBRELLA_FCST_DATA}/mpasout.${timestr}.nc
#
# save to com
if [[ "${mpasout_interval,,}" != "none"  ]]; then
  mpasout_path=$(realpath "${mpasout_file}")
  ${cpreq} "${mpasout_path}" "${COMOUT}/fcst/${WGF}${MEMDIR}/."
fi
exit 0
