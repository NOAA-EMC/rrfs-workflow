#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+${SECONDS}s $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}
#
# find variables from env
# 
CDATEin=$(${NDATE} "-${OFFSET}" "${CDATE}") #CDATE for input external data
if [[ "${EXTRN_MDL_SOURCE}" == "GFS_NCO" ]]; then
  SOURCE_BASEDIR=${COMINgfs}/gfs.${CDATEin:0:8}/${CDATEin:8:2}
  FILENAME_PATTERN=gfs.t${CDATEin:8:2}z.pgrb2.0p25.f^HHH^
  FILENAME_PATTERN_B=gfs.t${CDATEin:8:2}z.pgrb2b.0p25.f^HHH^
elif [[ "${EXTRN_MDL_SOURCE}" == "GEFS_NCO" ]]; then
  SOURCE_BASEDIR=${COMINgefs}/gefs.${CDATEin:0:8}/${CDATEin:8:2}/pgrb2ap5
  FILENAME_PATTERN=gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2a.0p50.f^HHH^
  FILENAME_PATTERN_B=gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2b.0p50.f^HHH^
fi
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any

cd "${DATA}" || exit 1
${cpreq} "${FIXrrfs}/ungrib/Vtable.${prefix}" Vtable
if [[ "${DO_CHEMISTRY^^}" == "TRUE" ]] && [[ "${USE_EXTERNAL_CHEM^^}" == "TRUE" ]]; then
  ${cpreq} "${FIXrrfs}/ungrib/Vtable.${prefix}.SD" Vtable
fi
#
# convert numbers to 10-based to be robust and easier to reference
#
offset=$((10#${OFFSET:-0}))
tot_length=$((10#${LENGTH:-0}))
group_total_num=$((10#${GROUP_TOTAL_NUM:-1}))
group_index=$((10#${GROUP_INDEX:-1}))
interval=$((10#${INTERVAL:-1}))
#
# compute fhr_begin, fhr_end, and then fhr_all for a given group
#
group_fhr_len=$(( tot_length/group_total_num ))
if (( group_index==1 )); then
  fhr_begin=${offset}
else
  fhr_begin=$(( offset + (group_index-1)*group_fhr_len + interval ))
fi
fhr_end=$(( offset + group_index*group_fhr_len  ))
fhr_all=$(seq ${fhr_begin} ${interval} ${fhr_end})
#
# link all grib2 files with local file name (AAA, AAB, ...)
#
knt=0
for fhr in  ${fhr_all}; do
  knt=$(( 10#${knt} + 1 ))
  HHH=$(printf %03d $((10#$fhr)) )
  HH=$(printf %02d $((10#$fhr)) )
  GRIBFILE_LOCAL=$( "${USHrrfs}/num_to_GRIBFILE.XXX.sh"  "${knt}" )
  TARGET_FILE=${FILENAME_PATTERN/^HHH^/${HHH}}
  TARGET_FILE=${TARGET_FILE/^HH^/${HH}}
  GRIBFILE="${SOURCE_BASEDIR}/${TARGET_FILE}"
  if [[ "${REGRID_RRFS_GRIB2^^}" == "TRUE"  ]]; then
    if [[ -s "${GRIBFILE}" ]]; then
      source "${USHrrfs}"/regrid_rrfs_grib2.sh # regrid NA3km rotated-lat-lon to the 3km variation of grid 130
    else
      echo "FATAL ERROR: ${GRIBFILE} missing"
      err_exit
    fi
  elif [[ -s "${GRIBFILE}" ]]; then
    ${cpreq} "${GRIBFILE}"  "${GRIBFILE_LOCAL}"
    # if FILENAME_PATTERN_B is defined and non-empty
    if [[ -n "${FILENAME_PATTERN_B+x}" ]] && [[ -n "${FILENAME_PATTERN_B}" ]]; then
      TARGET_FILE=${FILENAME_PATTERN_B/^HHH^/${HHH}}
      TARGET_FILE=${TARGET_FILE/^HH^/${HH}}
      GRIBFILE="${SOURCE_BASEDIR}/${TARGET_FILE}"
      cat "${GRIBFILE}" >> "${GRIBFILE_LOCAL}"
    fi
  else
    # If GRIBFILE does not exist, might need to do time interpolation
    if (( INTERVAL == 1 )) && (( fhr % 3 != 0 )); then
      source "${USHrrfs}"/gefs_interpolation.sh
    else
      echo "FATAL ERROR: ${GRIBFILE} missing and not eligible for time interpolation"
      err_exit
    fi
  fi
done
#
# generate the namelist on the fly
#
CDATEbegin=$(${NDATE} $((10#${fhr_begin})) "${CDATEin}")
CDATEend=$(${NDATE} $((10#${fhr_end})) "${CDATEin}")
start_time=$(date -d "${CDATEbegin:0:8} ${CDATEbegin:8:2}" +%Y-%m-%d_%H:%M:%S) 
end_time=$(date -d "${CDATEend:0:8} ${CDATEend:8:2}" +%Y-%m-%d_%H:%M:%S) 
interval_seconds=$(( INTERVAL*3600 ))
sed -e "s/@start_time@/${start_time}/" -e "s/@end_time@/${end_time}/" \
    -e "s/@interval_seconds@/${interval_seconds}/" -e "s/@prefix@/${prefix}/" \
    "${PARMrrfs}/namelist.wps" > namelist.wps
#
# run ungrib
#
source prep_step
${cpreq} "${EXECrrfs}/ungrib.x" .
./ungrib.x
export err=$?; err_chk
#
# check the status
#
outfile="${prefix}:$(date -d "${CDATEend:0:8} ${CDATEend:8:2}" +%Y-%m-%d_%H)"
if [[ -s ${outfile} ]]; then
  mv "${prefix}":* "${UMBRELLA_UNGRIB_DATA}/"
else
  echo "FATAL ERROR: ungrib failed"
  err_exit
fi
