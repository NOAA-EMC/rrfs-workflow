#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2153
fhr_0=$(( 10#${fhr} % 3 ))
fhr_m=$(( 10#${fhr} - fhr_0 ))
fhr_p=$(( 10#${fhr} - fhr_0 + 3 ))
HHH_M=$(printf %03d $((10#$fhr_m)) )
HHH_P=$(printf %03d $((10#$fhr_p)) )
NAME_FILE_M=${FILENAME_PATTERN/^HHH^/${HHH_M}}
NAME_FILE_P=${FILENAME_PATTERN/^HHH^/${HHH_P}}
GRIBFILE_M="${SOURCE_BASEDIR}/${NAME_FILE_M}"
GRIBFILE_P="${SOURCE_BASEDIR}/${NAME_FILE_P}"
echo "Deriving ${GRIBFILE} based on ${GRIBFILE_M} and ${GRIBFILE_P}"
# Get interpolation weights
vtime=$(date +%Y%m%d%H -d "${CDATEin:0:8} ${CDATEin:8:2} +${fhr_m} hours" )
fhr_0=$(( 10#${fhr} % 3 ))
c=$( echo "${fhr_0}/3" | bc -l )
c1=$( printf "%.5f\n" "$c" )
b1=$( echo "1-${c1}" | bc -l )
# Get time settings for interpolation
a="vt=${vtime}"
d1="${fhr} hour forecast"
# Now use wgrib2 to interpolate
wgrib2 "${GRIBFILE_M}" -rpn sto_1 -import_grib "${GRIBFILE_P}" -rpn sto_2 -set_grib_type same \
  -if ":$a:" \
  -rpn "rcl_1:$b1:*:rcl_2:$c1:*:+" -set_ftime "$d1" -set_scaling same same -grib_out "${GRIBFILE_LOCAL}"
if [ -n "${FILENAME_PATTERN_B+x}" ] && [ -n "${FILENAME_PATTERN_B}" ]; then
  NAME_FILE_M=${FILENAME_PATTERN_B/^HHH^/${HHH_M}}
  NAME_FILE_P=${FILENAME_PATTERN_B/^HHH^/${HHH_P}}
  GRIBFILE_M="${SOURCE_BASEDIR}/${NAME_FILE_M}"
  GRIBFILE_P="${SOURCE_BASEDIR}/${NAME_FILE_P}"
  wgrib2 "${GRIBFILE_M}" -rpn sto_1 -import_grib "${GRIBFILE_P}" -rpn sto_2 -set_grib_type same \
    -if ":$a:" \
    -rpn "rcl_1:$b1:*:rcl_2:$c1:*:+" -set_ftime "$d1" -set_scaling same same -grib_out "${GRIBFILE_LOCAL}_b"
  cat "${GRIBFILE_LOCAL}_b" >> "${GRIBFILE_LOCAL}"
  rm "${GRIBFILE_LOCAL}_b"
fi
