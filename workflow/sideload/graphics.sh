#!/usr/bin/env bash
# shellcheck disable=all
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
date
#
pygrafdir="${HOMErrfs}/workflow/sideload/pygraf"
image_list="${pygrafdir}/image_lists/regional_mpas_subset.yml"
file_tmpl="rrfs.t${cyc}z.prslev.f0{FCST_TIME:02d}.conus.grib2"
model=${NET}
ntasks=${SLURM_CPUS_ON_NODE:-12}
grib2_dir="${COMOUT}/upp/det"
workdir="${COMOUT}/graphics"
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
  fhr2=fcst_len_hrs_thiscyc
fi
#
read -ra tiles <<< "${TILES}"
for tile in ${tiles[@]}; do
  tmpdir="${workdir}/tmp"
  python create_graphics.py maps --all_leads -d ${grib2_dir} -f ${fhr1} ${fhr2} --file_type prs --file_tmpl ${file_tmpl} -m ${model} \
      --images ${image_list} hourly -n ${ntasks} -o ${tmpdir} -s ${CDATE} --tiles ${tile}
  export err=$?; err_chk
  #
  mkdir -p "${tmpdir}/${tile}"
  dirs=(${tmpdir}/*/)
  for i in ${dirs[@]}; do
    mv ${i}/* "${tmpdir}/${tile}"
  done
done
#
# zip the files if requested and the last group

exit 0
