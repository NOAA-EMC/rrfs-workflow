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
workdir=${COMOUT}/archive/${WGF}
sideloaddir=${HOMErrfs}/workflow/sideload
tar_rundir=${COMOUT}/..   # COMOUT contains cyc, we run htar/tar under ${RUN}.${PDY}
#
# create the file list for com1.tar (and com2.tar if requested)
mkdir -p "${workdir}"
cd "${workdir}" || exit 1
ln -snf "${sideloaddir}/archive_create_filelist.py" .
end=${CDATE:8:2}
bgn=$(( end +1 -ARCHIVE_INTERVAL ))
for hr in $(seq ${bgn} ${end}); do
  hr2=$(printf "%02d" ${hr})
  if [[ -n "${ARCHIVE_COM1_SPEC}" ]]; then
    ./archive_create_filelist.py "${tar_rundir}/${hr2}" "${ARCHIVE_COM1_SPEC}" "${hr2}" "com1.${hr2}"
  fi
  if [[ -n "${ARCHIVE_COM2_SPEC}" ]]; then
    ./archive_create_filelist.py "${tar_rundir}/${hr2}" "${ARCHIVE_COM2_SPEC}" "${hr2}" "com2.${hr2}"
  fi
done
cat com1.* > com1.filelist
if [[ -n "${ARCHIVE_COM2_SPEC}" ]]; then
  cat com2.* > com2.filelist
  htar -cvf "${ARCHIVE_HPSSDIR}/com2.${CDATE:0:8}{bgn}-{end}.tar" -L com2.filelist
fi
#
# archive com/ files to HPSS
cd "${tar_rundir}" || exit 1
destdir="${ARCHIVE_HPSSDIR}/${CDATE:0:4}/${CDATE:0:6}/${CDATE:0:8}"
hsi mkdir -p "${destdir}"
bgn=$(printf "%02d" ${bgn})
end=$(printf "%02d" ${end})
htar -cvf "${destdir}/com1.${CDATE:0:8}${bgn}-${end}.tar" -L "${workdir}/com1.filelist"
if [[ -n "${ARCHIVE_COM2_SPEC}" ]]; then
  htar -cvf "${destdir}/com2.${CDATE:0:8}${bgn}-${end}.tar" -L "${workdir}com2.filelist"
fi
#
#
export err=$?; err_chk
exit 0
