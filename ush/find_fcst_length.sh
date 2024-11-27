#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
#
#  $1=${fcst_len_hrs_cycles}
#  $2=${cyc}
#  $3=${fcst_length}
#
set -x
array=($1)
cyc=$2
fcst_length=$3
num_fhrs=${#array[@]}
if (( $num_fhrs == 24 )); then
  icyc=$((10#${cyc}))
  if (( $icyc < $num_fhrs )); then
    thiscyc=${array[$icyc]}
    fcst_len_hrs_thiscyc=$((10#${thiscyc}))
  else
    echo "cannot find forecast length"
    fcst_len_hrs_thiscyc=${fcst_length}
  fi
else
  fcst_len_hrs_thiscyc=${fcst_length}
fi
echo ${fcst_len_hrs_thiscyc}
