#!/usr/bin/env bash
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
PURGE_PATTERN=${PURGE_PATTERN:-${DATAROOT}/${RUN}_*_${cyc}_${rrfs_ver}/${WGF}*}
for mydir in ${PURGE_PATTERN}; do
  rm -rf "${mydir}"
done
#
date
echo "JOB purge_stmp HAS COMPLETED NORMALLY!"
exit 0
