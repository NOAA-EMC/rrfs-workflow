#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}
#
# find variables from env
# 
CDATEin=$(${NDATE} "-${OFFSET}" "${CDATE}") #CDATE for input external data
if [[ "${EXTRN_MDL_SOURCE}" == "GFS_NCO" ]]; then
  SOURCE_BASEDIR=${COMINgfs}/gfs.${CDATEin:0:8}/${CDATEin:8:2}
  NAME_PATTERN=gfs.t${CDATEin:8:2}z.pgrb2.0p25.fHHH
  NAME_PATTERN_B=gfs.t${CDATEin:8:2}z.pgrb2b.0p25.fHHH
elif [[ "${EXTRN_MDL_SOURCE}" == "GEFS_NCO" ]]; then
  SOURCE_BASEDIR=${COMINgefs}/gefs.${CDATEin:0:8}/${CDATEin:8:2}/pgrb2ap5
  NAME_PATTERN=gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2a.0p50.fHHH
  NAME_PATTERN_B=gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2b.0p50.fHHH
fi
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any

cd "${DATA}" || exit 1
${cpreq} "${FIXrrfs}/ungrib/Vtable.${prefix}" Vtable
#
# find start and end time
#
# fhr_chunk=$(( (10#${LENGTH}/10#${INTERVAL} + 1)/10#${GROUP_TOTAL_NUM}*10#${INTERVAL} ))
fhr_chunk=$(( (10#${LENGTH}/10#${INTERVAL} + 1) * 10#${INTERVAL} / 10#${GROUP_TOTAL_NUM} ))
fhr_begin=$((10#${OFFSET} + (10#${GROUP_INDEX} - 1 )*10#${fhr_chunk} ))
if (( GROUP_INDEX == GROUP_TOTAL_NUM )); then
  fhr_end=$(( 10#${OFFSET} + 10#${LENGTH}))
else
  fhr_end=$((10#${OFFSET} + (10#${GROUP_INDEX})*10#${fhr_chunk} - 10#${INTERVAL} ))
fi
#
# link all grib2 files with local file name (AAA, AAB, ...)
#
fhr_all=$(seq $((10#${fhr_begin})) $((10#${INTERVAL})) $((10#${fhr_end} )) )
knt=0
for fhr in  ${fhr_all}; do
  knt=$(( 10#${knt} + 1 ))
  HHH=$(printf %03d $((10#$fhr)) )
  GRIBFILE_LOCAL=$( "${USHrrfs}/num_to_GRIBFILE.XXX.sh"  "${knt}" )
  NAME_FILE=${NAME_PATTERN/fHHH/${HHH}}
  GRIBFILE="${SOURCE_BASEDIR}/${NAME_FILE}"
  if [[ -s "${GRIBFILE}" ]]; then 
    ${cpreq} "${GRIBFILE}"  "${GRIBFILE_LOCAL}"
    # if NAME_PATTERN_B is defined and non-empty
    if [ -n "${NAME_PATTERN_B+x}" ] && [ -n "${NAME_PATTERN_B}" ]; then
      NAME_FILE=${NAME_PATTERN_B/fHHH/${HHH}}
      GRIBFILE="${SOURCE_BASEDIR}/${NAME_FILE}"
      cat "${GRIBFILE}" >> "${GRIBFILE_LOCAL}"
    fi
  else
    # If GRIBFILE does not exist, might need to do time interpolation
    if [[ ${INTERVAL} -eq 1 ]] && (( fhr % 3 != 0 )); then
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
if [[ "${MESH_NAME}" == *"3km"*   ]]; then
  dx=3; dy=3
else
  dx=12; dy=12
fi
CDATEbegin=$(${NDATE} $((10#${fhr_begin})) "${CDATEin}")
CDATEend=$(${NDATE} $((10#${fhr_end})) "${CDATEin}")
start_time=$(date -d "${CDATEbegin:0:8} ${CDATEbegin:8:2}" +%Y-%m-%d_%H:%M:%S) 
end_time=$(date -d "${CDATEend:0:8} ${CDATEend:8:2}" +%Y-%m-%d_%H:%M:%S) 
interval_seconds=$(( INTERVAL*3600 ))
sed -e "s/@start_time@/${start_time}/" -e "s/@end_time@/${end_time}/" \
    -e "s/@interval_seconds@/${interval_seconds}/" -e "s/@prefix@/${prefix}/" \
    -e "s/@dx@/${dx}/" -e "s/@dy@/${dy}/" "${PARMrrfs}/namelist.wps" > namelist.wps
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
