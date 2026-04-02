#!/usr/bin/env bash
# interplate RRFS NA3km grib2 files to the variation 130 grid at 3km
#
# shellcheck disable=SC2154,SC2153,SC2086

echo "${knt}"
wgrib2 -s -d 1 ${GRIBFILE} -GRIB ${GRIBFILE_LOCAL}
i=2
while [[ ${i} -le 330 ]] ;
do
	wgrib2 -s -d ${i} ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
	i=$((i + 1))
done
knt=$(( 10#${knt} + 1 ))
GRIBFILE_LOCAL=$( "${USHrrfs}/num_to_GRIBFILE.XXX.sh"  "${knt}" )
echo "${knt}"
wgrib2 -s -d 331 ${GRIBFILE} -GRIB ${GRIBFILE_LOCAL}
i=332
while [[ ${i} -le 660 ]] ;
do
	wgrib2 -s -d ${i} ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
	i=$((i + 1))
done
knt=$(( 10#${knt} + 1 ))
GRIBFILE_LOCAL=$( "${USHrrfs}/num_to_GRIBFILE.XXX.sh"  "${knt}" )
echo "${knt}"
wgrib2 -s -d 661 ${GRIBFILE} -GRIB ${GRIBFILE_LOCAL}
i=662
while [[ ${i} -le 990 ]] ;
do
	wgrib2 -s -d ${i} ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
	i=$((i + 1))
done
knt=$(( 10#${knt} + 1 ))
GRIBFILE_LOCAL=$( "${USHrrfs}/num_to_GRIBFILE.XXX.sh"  "${knt}" )
echo "${knt}"
wgrib2 -s -d 991 ${GRIBFILE} -GRIB ${GRIBFILE_LOCAL}
i=992
while [[ ${i} -le 1320 ]] ;
do
	wgrib2 -s -d ${i} ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
	i=$((i + 1))
done
knt=$(( 10#${knt} + 1 ))
GRIBFILE_LOCAL=$( "${USHrrfs}/num_to_GRIBFILE.XXX.sh"  "${knt}" )
echo "${knt}"
wgrib2 -s -d 1321 ${GRIBFILE} -GRIB ${GRIBFILE_LOCAL}
i=1322
while [[ ${i} -le 1430 ]] ;
do
	wgrib2 -s -d ${i} ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
	i=$((i + 1))
done
knt=$(( 10#${knt} + 1 ))
GRIBFILE_LOCAL=$( "${USHrrfs}/num_to_GRIBFILE.XXX.sh"  "${knt}" )
echo "${knt}"
wgrib2 -s -match_fs 'TMP:2 m' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'SPFH:2 m' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'RH:2 m' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'UGRD:10 m' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'VGRD:10 m' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'PRES:surface' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'MSLET' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'WEASD' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'SNOD' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'TMP:surface' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'CNWAT' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'TSOIL' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'SOILW' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'ICEC' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'LAND' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'HGT:surface' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'VEG:surface' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'VEGMIN' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
wgrib2 -s -match_fs 'VEGMAX' ${GRIBFILE} -append -GRIB ${GRIBFILE_LOCAL}
