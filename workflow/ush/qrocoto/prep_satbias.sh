#!/usr/bin/env bash
#
# This script is to help users to prepare intial satbias files 
#
# shellcheck disable=1091,2154
RUN="rrfs"

if (( $# < 1 )); then
  echo "Usage: $0 YYYYMMDDHH [satbias_path]"
  echo "satbias_path is optional"
  echo "If satbias_path is missing, \$FIXrrfs/fix/satbias_init will be used"
  exit
fi

source ./exp.setup
PDY=${1:0:8}
cyc=${1:8:2}
if ${DO_ENSEMBLE:-false}; then
  dest_path=${COMROOT}/${NET}/${VERSION}/${RUN}.${PDY}/${cyc}/getkf_solver/${WGF}
else
  dest_path=${COMROOT}/${NET}/${VERSION}/${RUN}.${PDY}/${cyc}/jedivar/${WGF}
fi
mkdir -p "${dest_path}"

satbias_path=$2
if [[ -z "${satbias_path}" ]]; then
  satbias_path=${HOMErrfs}/fix/satbias_init
fi

echo "copy satbias files from ${HOMErrfs}/fix/satbias_init"
cp "${satbias_path}"/*satbias*.nc  "${dest_path}"
touch "${dest_path}/satbias_jumpstart"  # this file will jump start the very first cycle of a retro
echo "to ${dest_path}"
