#!/usr/bin/env bash
# convert a number to the ungrib file naming convention: GRIBFILE.AAA
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
num=$((10#$1))
[[ "${num}" == "0" ]] && exit
num=$((10#$num-1))
letters=( {A..Z} )
pt1=$((10#$num % 26))
leftover=$((10#$num/26))
pt2=$((leftover % 26 ))
pt3=$((leftover/26))
echo "GRIBFILE.${letters[${pt3}]}${letters[${pt2}]}${letters[${pt1}]}"
