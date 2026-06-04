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
pygrafdir="${HOMErrfs}/workflow/sideload/pygraf"
image_list="${pygrafdir}/image_lists/regional_mpas_subset.yml"
file_tmpl="rrfs.t${cyc}z.prslev.f0{FCST_TIME:02d}.conus.grib2"
model=${NET}
ntasks=${NTASKS:-12}
grib2_dir="${COMOUT}/upp/det"
workdir="${COMOUT}/graphics/${WGF}"
zipdir="${COMOUT}/nclprd"
rm -rf "${workdir}"
mkdir -p "${workdir}"
cd "${pygrafdir}" || exit 1
#
# find forecst length for this cycle
#
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$( "${USHrrfs}/find_fcst_length.sh"  "${fcst_len_hrs_cycles}"  "${cyc}" )
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
fhr1=0
fhr2=${fcst_len_hrs_thiscyc}
wait_minutes=${WAIT_MINUTES:-180}
tile=${TILE:-'full'}
#
# generate the graphics
#
if [[ "${GRAPHICS_ZIP^^}" == "TRUE" ]]; then
  mkdir -p "${zipdir}"
  python create_graphics.py maps --all_leads -d ${grib2_dir} -f ${fhr1} ${fhr2} --file_type prs --file_tmpl ${file_tmpl} -m ${model} \
      --images ${image_list} hourly -n ${ntasks} -o ${workdir} -s ${CDATE} --tiles ${tile} -z ${zipdir} -w ${wait_minutes}
else
  python create_graphics.py maps --all_leads -d ${grib2_dir} -f ${fhr1} ${fhr2} --file_type prs --file_tmpl ${file_tmpl} -m ${model} \
      --images ${image_list} hourly -n ${ntasks} -o ${workdir} -s ${CDATE} --tiles ${tile} -w ${wait_minutes}
fi
export err=$?; err_chk
exit 0
