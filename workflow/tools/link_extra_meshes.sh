#!/usr/bin/env bash
#
# shellcheck disable=all
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
HOMErrfs="${run_dir}/../../"

# ar3.5km at gaeac6
meshdir="/gpfs/f6/arfs-gsl/world-shared/extra_meshes/ar3.5km"
if [[ -d ${meshdir} ]]; then
  ln -snf "${meshdir}" "${HOMErrfs}/fix"
fi

# global-15-3km at gaeac6
meshdir="/gpfs/f6/arfs-gsl/world-shared/extra_meshes/global-15-3km"
if [[ -d ${meshdir} ]]; then
  ln -snf "${meshdir}" "${HOMErrfs}/fix"
fi

# south3.5km at gaeac6
meshdir="/gpfs/f6/arfs-gsl/world-shared/extra_meshes/south3.5km"
if [[ -d ${meshdir} ]]; then
  ln -snf "${meshdir}" "${HOMErrfs}/fix"
fi

# ea5km at gaeac6
meshdir="/gpfs/f6/arfs-gsl/world-shared/extra_meshes/ea5km"
if [[ -d ${meshdir} ]]; then
  ln -snf "${meshdir}" "${HOMErrfs}/fix"
fi
