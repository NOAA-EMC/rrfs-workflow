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
PURGE_PATTERN=${PURGE_PATTERN:-${DATAROOT}/${RUN}_*_${cyc}_${rrfs_ver}/${WGF}*}
for file in ${PURGE_PATTERN}; do
  ls ${file}
done
#
date
echo "JOB ${jobid:-} HAS COMPLETED NORMALLY!"
exit 0
