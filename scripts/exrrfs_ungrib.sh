#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}
#
# find variables from env
# 
prefixin=${EXTRN_MDL_SOURCE}
#
# wildcard match GFS
#
if [[ ${prefixin} == *"GFS"* ]]; then
  prefix="GFS"
elif [[ ${prefixin} == *"GEFS"* ]]; then
  prefix="GEFS"
else
  prefix=${prefixin}
fi

CDATEin=$($NDATE -${OFFSET} ${CDATE}) #CDATE for input external data

cd ${DATA}
${cpreq} ${FIXrrfs}/ungrib/Vtable.${prefix} Vtable
#
if [[ "${prefixin}" == "GFS" ]]; then
  COMIN=${COMINgfs}/gfs.${CDATEin:0:8}/${CDATEin:8:2}
  NAME_PATTERNa=gfs.t${CDATEin:8:2}z.pgrb2.0p25.fHHH
  NAME_PATTERNb=gfs.t${CDATEin:8:2}z.pgrb2b.0p25.fHHH

elif [[ "${prefixin}" == "GEFS" ]]; then
  COMIN=${COMINgefs}/gefs.${CDATEin:0:8}/${CDATEin:8:2}/pgrb2ap5
  NAME_PATTERNa=gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2a.0p50.fHHH
  NAME_PATTERNb=gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2b.0p50.fHHH

else
  echo "ungrib PREFIX=${prefix} from xml"
fi
#
# find start and end time
#
fhr_chunk=$(( (10#${LENGTH}/10#${INTERVAL} + 1)/10#${GROUP_NUM}*10#${INTERVAL} ))
fhr_begin=$((10#${OFFSET} + (10#${GROUP_INDEX} - 1 )*10#${fhr_chunk} ))
if [[ 10#${GROUP_INDEX} -eq 10#${GROUP_NUM} ]]; then
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
  HHH=$(printf %03d ${fhr})
  GRIBFILE_LOCAL=$(${USHrrfs}/num_to_GRIBFILE.XXX.sh ${knt})
  if [[ "${prefixin}" == "GFS" ]] || [[ "${prefixin}" == "GEFS" ]]; then
    NAME_FILE=${NAME_PATTERNa/fHHH/f${HHH}}
    GRIBFILE="${COMIN}/${NAME_FILE}"
    ${cpreq} ${GRIBFILE} ${GRIBFILE_LOCAL}
    NAME_FILE=${NAME_PATTERNb/fHHH/f${HHH}}
    GRIBFILE="${COMIN}/${NAME_FILE}"
    cat ${GRIBFILE} >> ${GRIBFILE_LOCAL}
  else
    NAME_FILE=${NAME_PATTERN/fHHH/${HHH}}
    GRIBFILE="${COMIN}/${NAME_FILE}"
    ${cpreq} ${GRIBFILE} ${GRIBFILE_LOCAL}
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
CDATEbegin=$($NDATE $((10#${fhr_begin})) ${CDATEin})
CDATEend=$($NDATE $((10#${fhr_end})) ${CDATEin})
start_time=$(date -d "${CDATEbegin:0:8} ${CDATEbegin:8:2}" +%Y-%m-%d_%H:%M:%S) 
end_time=$(date -d "${CDATEend:0:8} ${CDATEend:8:2}" +%Y-%m-%d_%H:%M:%S) 
interval_seconds=$(( ${INTERVAL}*3600 ))
sed -e "s/@start_time@/${start_time}/" -e "s/@end_time@/${end_time}/" \
    -e "s/@interval_seconds@/${interval_seconds}/" -e "s/@prefix@/${prefix}/" \
    -e "s/@dx@/${dx}/" -e "s/@dy@/${dy}/" ${PARMrrfs}/namelist.wps > namelist.wps
#
# run ungrib
#
source prep_step
${cpreq} ${EXECrrfs}/ungrib.x .
./ungrib.x
export err=$?; err_chk
#
# check the status
#
outfile="${prefix}:$(date -d "${CDATEend:0:8} ${CDATEend:8:2}" +%Y-%m-%d_%H)"
if [[ -s ${outfile} ]]; then
  if [[ -z "${ENS_INDEX}" ]]; then
    mv ${prefix}:* ${UMBRELLA_DATA}/ungrib_${TYPE}/
    if [[ "${TYPE}" == "lbc" ]] && [[ ! -d ${UMBRELLA_DATA}/ungrib_ic  ]]; then
    # lbc tasks need init.nc, don't know why it is so but we have to leave with this for a while
    # link ungrib_lbc to ungrib_ic so that ic tasks can run and generate init.nc
      ln -snf ${UMBRELLA_DATA}/ungrib_lbc ${UMBRELLA_DATA}/ungrib_ic
    fi
  else
    mv ${prefix}:* ${UMBRELLA_DATA}/mem${ENS_INDEX}/ungrib_${TYPE}/
  fi
else
  echo "FATAL ERROR: ungrib failed"
  err_exit
fi
