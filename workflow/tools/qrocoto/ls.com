#!/bin/bash
# shellcheck disable=all
# find the log file for a given task at a given cycle
# by Guoqing Ge, 2025/07
#
if [[ ! -s exp.setup ]]; then
  echo "Run this command under the expdir where exp.setup is located"
  exit
fi
source exp.setup
if [[ $# < 2 ]]; then
  echo "$(basename $0) <YYYYMMDDHH|YYYYMMDDHHmm> <task>"
  exit
fi

RUN=rrfs

CDATE=$1
taskraw=$2
if [[ $3 == -* ]]; then
  lsopts=$3
fi

task=${taskraw%_g*}
if [[ "${task}" == *prep_chem* ]]; then
  task="prep_chem"
fi
PDY=${CDATE:0:8}
cyc=${CDATE:8:2}

comout="${COMROOT}/${NET}/${VERSION}/${RUN}.${PDY}/${cyc}/${task}/${WGF}"
if [[ ! -d "${comout}" ]]; then
  echo "not found: ${comout}"
else
  echo "ls ${comout}"
  ls "${comout}" ${lsopts} --color -F
fi
