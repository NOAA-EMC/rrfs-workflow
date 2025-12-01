#!/usr/bin/env bash
# shellcheck disable=SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
date
#
#-----------------------------------------------------------------------
# Specify Execution Areas
#-----------------------------------------------------------------------
#
export HOMErrfs=${HOMErrfs} #comes from the workflow at runtime
export EXECrrfs=${EXECrrfs:-${HOMErrfs}/exec}
export FIXrrfs=${FIXrrfs:-${HOMErrfs}/fix}
export PARMrrfs=${PARMrrfs:-${HOMErrfs}/parm}
export USHrrfs=${USHrrfs:-${HOMErrfs}/ush}
#
# prepare to remove all UMBRELLA directories for current ${cyc}
# in rare situations, one can pass in a predefined search pattern to achieve customized purge
#
cd "${DATAROOT}" || exit 1

PURGE_PATTERN="${RUN}_*_${cyc}_${rrfs_ver}/${WGF}*"
#
# remove any leading / to make sure any `rm -rf` operations will be done under ${DATAROOT}
#
while [[ "${PURGE_PATTERN}" == /* ]]; do
  PURGE_PATTERN="${PURGE_PATTERN#/}"
done
#
for mydir in ${PURGE_PATTERN}; do
  if [[ -d "${mydir}" ]]; then
    rm -rf "${mydir}"
  fi
done
#
date
echo "JOB purge_stmp HAS COMPLETED NORMALLY!"
exit 0
