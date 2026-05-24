#!/usr/bin/env bash
# shellcheck disable=all
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
date
#
export HOMErrfs=${HOMErrfs} #comes from the workflow at runtime
export EXECrrfs=${EXECrrfs:-${HOMErrfs}/exec}
export FIXrrfs=${FIXrrfs:-${HOMErrfs}/fix}
export PARMrrfs=${PARMrrfs:-${HOMErrfs}/parm}
export USHrrfs=${USHrrfs:-${HOMErrfs}/ush}
#
export err=$?; err_chk
exit 0
