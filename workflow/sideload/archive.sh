#!/usr/bin/env bash
# shellcheck disable=all
declare -rx PS4='+${SECONDS}s $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
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
rm -rf "${workdir}"
mkdir -p "${workdir}"
cd "${workdir}" || exit 1
ln -snf "${sideloaddir}/archive_create_filelist.py" .
end=$((10#${CDATE:8:2}))
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
fi
#
# archive com/ files to HPSS
cd "${tar_rundir}" || exit 1
destdir="${ARCHIVE_HPSSDIR}/${CDATE:0:4}/${CDATE:0:6}/${CDATE:0:8}"
hsi mkdir -p "${destdir}"
bgn2=$(printf "%02d" ${bgn})
end2=$(printf "%02d" ${end})
htar -cvf "${destdir}/com1.${CDATE:0:8}${bgn2}-${end2}.tar" -L "${workdir}/com1.filelist"
if [[ -n "${ARCHIVE_COM2_SPEC}" ]]; then
  htar -cvf "${destdir}/com2.${CDATE:0:8}${bgn2}-${end2}.tar" -L "${workdir}/com2.filelist"
fi
#
# create the file list for stmp.tar
if [[ -n "${ARCHIVE_STMP}" ]]; then
  cd "${DATAROOT}" || exit 1
  rm -rf "${workdir}/stmp.*"
  ngroup=$(( ARCHIVE_INTERVAL/ARCHIVE_STMP_INTERVAL ))
  for i in $(seq 1 ${ngroup}); do
    grp_bgn=$(( bgn+(i-1)*ARCHIVE_STMP_INTERVAL ))
    grp_end=$(( bgn+i*ARCHIVE_STMP_INTERVAL -1 ))
    grp_bgn2=$(printf "%02d" ${grp_bgn})
    grp_end2=$(printf "%02d" ${grp_end})
    for hr in $(seq ${grp_bgn} ${grp_end}); do
      hr2=$(printf "%02d" ${hr})
      if [[ "${ARCHIVE_STMP}" == *fcst* ]]; then
        find ${RUN}_fcst_${hr2}*/det/ -type f \( -name "diag*.nc" -o -name "history*.nc" -o -name "mpasout*.nc" \) >> "${workdir}/stmp.${CDATE:0:8}${grp_bgn2}-${grp_end2}"
      fi
      if [[ "${ARCHIVE_STMP}" == *mpassit* ]]; then
        find ${RUN}_mpassit_${hr2}*/det/ -type f -name "mpassit*.nc" >> "${workdir}/stmp.${CDATE:0:8}${grp_bgn2}-${grp_end2}"
      fi
    done
  done
  #
  # archive stmp/ files to HPSS
  for file in ${workdir}/stmp.*; do
    suffix=${file##*/}
    if [[ -s "${file}" ]]; then
      htar -cvf "${destdir}/${suffix}.tar" -L "${file}"
    fi
  done
fi
#
#
exit 0
