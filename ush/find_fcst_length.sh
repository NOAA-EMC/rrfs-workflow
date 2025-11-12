#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
#
#  $1=${fcst_len_hrs_cycles}
#  $2=${cyc}
#
set -x
read -ra array <<< "$1"
cyc=$2
num_fhrs=${#array[@]}
if (( num_fhrs == 24 )); then
  icyc=$((10#${cyc}))
  if (( icyc < num_fhrs )); then
    thiscyc=${array[$icyc]}
    fcst_len_hrs_thiscyc=$((10#${thiscyc}))
  else
    echo "cannot find forecast length from FCST_LEN_HRS_CYCLES, use a default value of 1h" >&2
    fcst_len_hrs_thiscyc=1 # if fcst_len_hrs_cycles is not set correctly, use 1 as the default value
  fi
else
  fcst_len_hrs_thiscyc=1
fi
echo "${fcst_len_hrs_thiscyc}"
