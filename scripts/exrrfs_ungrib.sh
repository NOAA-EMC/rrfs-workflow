#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}
#
# find prefix from source
# 
prefixin=${EXTRN_MDL_SOURCE}
offset=${OFFSET}
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

CDATEin=$($NDATE -${offset} ${CDATE}) #CDATE for input external data

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
# link all grib2 files with local file name (AAA, AAB, ...)
#
fhr_all=$(seq $((10#${OFFSET})) $((10#${INTERVAL})) $(( 10#${OFFSET} + 10#${LENGTH})) )
knt=0
for fhr in  ${fhr_all}; do

  knt=$(( 10#${knt} + 1 ))
  HHH=$(printf %03d ${fhr})
  GRIBFILE_LOCAL=$(${USHrrfs}/num_to_GRIBFILE.XXX.sh ${knt})
  if [[ "${prefixin}" == "GFS" ]] || [[ "${prefixin}" == "GEFS" ]]; then
    NAME_FILE=$(echo "${NAME_PATTERNa}" | sed "s/fHHH/f${HHH}/g")
    GRIBFILE="${COMIN}/${NAME_FILE}"
    ${cpreq} ${GRIBFILE} ${GRIBFILE_LOCAL}
    NAME_FILE=$(echo "${NAME_PATTERNb}" | sed "s/fHHH/f${HHH}/g")
    GRIBFILE="${COMIN}/${NAME_FILE}"
    cat ${GRIBFILE} >> ${GRIBFILE_LOCAL}
  else
    NAME_FILE=$(echo "${NAME_PATTERN}" | sed "s/\${HHH}/${HHH}/g")
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
CDATEout=$($NDATE $(( 10#${OFFSET} + 10#${LENGTH})) ${CDATEin})
start_time=$(date -d "${CDATEin:0:8} ${CDATEin:8:2}" +%Y-%m-%d_%H:%M:%S) 
end_time=$(date -d "${CDATEout:0:8} ${CDATEout:8:2}" +%Y-%m-%d_%H:%M:%S) 
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
outfile="${prefix}:$(date -d "${CDATEout:0:8} ${CDATEout:8:2}" +%Y-%m-%d_%H)"
if [[ -s ${outfile} ]]; then
  if [[ -z "${ENS_INDEX}" ]]; then
    mv ${prefix}:* ${umbrella_data}/ungrib_${TYPE}/
    if [[ "${TYPE}" == "lbc" ]] && [[ ! -d ${umbrella_data}/ungrib_ic  ]]; then
    # lbc tasks need init.nc, don't know why it is so but we have to leave with this for a while
    # link ungrib_lbc to ungrib_ic so that ic tasks can run and generate init.nc
      ln -snf ${umbrella_data}/ungrib_lbc ${umbrella_data}/ungrib_ic
    fi
  else
    mv ${prefix}:* ${umbrella_data}/mem${ENS_INDEX}/ungrib_${TYPE}/
  fi
else
  echo "FATAL ERROR: ungrib failed"
  err_exit
fi
