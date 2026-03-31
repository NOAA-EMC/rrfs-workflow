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
pygrafdir="${HOMErrfs}/workflow/sideload/pygraf"
image_list="${pygrafdir}/image_lists/regional_mpas_subset.yml"
file_tmpl="rrfs.t${cyc}z.prslev.f0{FCST_TIME:02d}.conus.grib2"
model=${NET}
ntasks=${SLURM_CPUS_ON_NODE:-12}
grib2_dir="${COMOUT}/upp/det"
workdir="${COMOUT}/graphics/g${GROUP_INDEX}"
rm -rf "${workdir}"
mkdir -p "${workdir}"
cd "${pygrafdir}" || exit 1
#
# find forecst length for this cycle
#
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$( "${USHrrfs}/find_fcst_length.sh"  "${fcst_len_hrs_cycles}"  "${cyc}" )
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
read -ra fhr_all <<< "${GROUP_HOURS}"  # convert string to array
fhr1=${fhr_all[0]}
fhr2=${fhr_all[${#fhr_all[@]}-1]}
if (( fcst_len_hrs_thiscyc <= fhr2 )); then 
  fhr2=${fcst_len_hrs_thiscyc}
fi
#
# generate the graphics under workdir and then move to graphics/{tile}
#
read -ra tiles <<< "${TILES}"
for tile in ${tiles[@]}; do
  python create_graphics.py maps --all_leads -d ${grib2_dir} -f ${fhr1} ${fhr2} --file_type prs --file_tmpl ${file_tmpl} -m ${model} \
      --images ${image_list} hourly -n ${ntasks} -o ${workdir} -s ${CDATE} --tiles ${tile}
  export err=$?; err_chk
  #
  mkdir -p "${COMOUT}/graphics/${tile}"
  dirs=(${workdir}/*/)
  for i in ${dirs[@]}; do
    mv ${i}/* "${COMOUT}/graphics/${tile}"
  done
done
#
# zip the graphics if requested and it is the last group
if [[ "${GRAPHICS_ZIP^^}" == "TRUE" ]] && [[ "${LAST_GROUP^^}" == "TRUE"   ]]; then
  mkdir -p "${COMOUT}/nclprd"
  for tile in ${tiles[@]}; do
    cd "${COMOUT}/graphics/${tile}"
    zip files.zip *.png
    mkdir -p "${COMOUT}/nclprd/${tile}"
    mv files.zip "${COMOUT}/nclprd/${tile}"
    rm -rf "${COMOUT}/graphics/${tile}"
  done
fi

export err=$?; err_chk
exit 0
