#!/usr/bin/env bash
# FIX_RRFS2 only contains conus3km, conus12km, na12km meshes
# this script faciliates linking other meshes, such as fwx1.25km, south3.5km, eu12km, etc
#
# shellcheck disable=all
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
HOMErrfs="${run_dir}/../../"

# gaeac6
meshdir="/gpfs/f6/arfs-gsl/world-shared/FIX_MESHES"
if [[ -d "${meshdir}" ]]; then
  ln -snf "${meshdir}"/*km "${HOMErrfs}/fix"
fi

# ursa
meshdir="/scratch3/BMC/wrfruc/FIX_MESHES"
if [[ -d "${meshdir}" ]]; then
  ln -snf "${meshdir}"/*km "${HOMErrfs}/fix"
fi

# orion/hercules
meshdir="/work/noaa/zrtrr/FIX_MESHES"
if [[ -d "${meshdir}" ]]; then
  ln -snf "${meshdir}"/*km "${HOMErrfs}/fix"
fi
