#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}
if [[ -z "${ENS_INDEX}" ]]; then
  if [[ "${TYPE}" == "IC" ]] || [[ "${TYPE}" == "ic" ]]; then
    prefix=${IC_PREFIX:-IC_PREFIX_not_defined}
    offset=${IC_OFFSET:-3}
  else #lbc
    prefix=${LBC_PREFIX:-LBC_PREFIX_not_defined}
    offset=${LBC_OFFSET:-6}
  fi
else # ensrrfs
  if [[ "${TYPE}" == "IC" ]] || [[ "${TYPE}" == "ic" ]]; then
    prefix=${ENS_IC_PREFIX:-ENS_IC_PREFIX_not_defined}
    offset=${ENS_IC_OFFSET:-39}
  else #lbc
    prefix=${ENS_LBC_PREFIX:-ENS_LBC_PREFIX_not_defined}
    offset=${ENS_LBC_OFFSET:-39}
  fi
fi
CDATEin=$($NDATE -${offset} ${CDATE}) #CDATE for input external data
FHRin=$(( 10#${FHR}+10#${offset} )) #FHR for input external data

cd ${DATA}
${cpreq} ${FIXrrfs}/ungrib/Vtable.${prefix} Vtable
#
if [[ "${prefix}" == "GFS" ]]; then
  fstr=$(printf %03d ${FHRin})
  filea=${COMINgfs}/gfs.${CDATEin:0:8}/${CDATEin:8:2}/gfs.t${CDATEin:8:2}z.pgrb2.0p25.f${fstr}
  fileb=${COMINgfs}/gfs.${CDATEin:0:8}/${CDATEin:8:2}/gfs.t${CDATEin:8:2}z.pgrb2b.0p25.f${fstr}
  ls -lth ${filea} ${fileb}
  cat ${filea} ${fileb} > GRIBFILE.AAA

elif [[ "${prefix}" == "GEFS" ]]; then
  fstr=$(printf %03d ${FHRin})
  filea=${COMINgefs}/gefs.${CDATEin:0:8}/${CDATEin:8:2}/pgrb2ap5/gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2a.0p50.f${fstr}
  fileb=${COMINgefs}/gefs.${CDATEin:0:8}/${CDATEin:8:2}/pgrb2bp5/gep${ENS_INDEX:1}.t${CDATEin:8:2}z.pgrb2b.0p50.f${fstr}
  ls -lth ${filea} ${fileb}
  cat ${filea} ${fileb} > GRIBFILE.AAA

elif [[ "${prefix}" == "RAP" ]]; then
  fstr=$(printf %02d ${FHRin})
  GRIBFILE=${COMINrap}/rap.${CDATEin:0:8}/rap.t${CDATEin:8:2}z.wrfnatf${fstr}.grib2
  ${cpreq} ${GRIBFILE} GRIBFILE.AAA

elif [[ "${prefix}" == "RRFS" ]]; then
  fstr=$(printf %02d ${FHRin})
  GRIBFILE=${COMINrrfs1}/rrfs_a.${CDATEin:0:8}/${CDATEin:8:2}/rrfs.t${CDATEin:8:2}z.natlve.f${fstr}.grib2
  ${cpreq} ${GRIBFILE} GRIBFILE.AAA

else
  echo "ungrib PREFIX=${prefix} not supported"
  err_exit
fi
#
# generate the namelist on the fly
CDATEout=$($NDATE ${FHR} ${CDATE})
start_time=$(date -d "${CDATEout:0:8} ${CDATEout:8:2}" +%Y-%m-%d_%H:%M:%S) 
end_time=${start_time}
interval_seconds=3600
if [[ "${NET}" == "conus3km"   ]]; then
  dx=3; dy=3
else
  dx=12; dy=12
fi
sed -e "s/@start_time@/${start_time}/" -e "s/@end_time@/${end_time}/" \
    -e "s/@interval_seconds@/${interval_seconds}/" -e "s/@prefix@/${prefix}/" \
    -e "s/@dx@/${dx}/" -e "s/@dy@/${dy}/" ${PARMrrfs}/rrfs/namelist.wps > namelist.wps

# run ungrib
source prep_step
${cpreq} ${EXECrrfs}/ungrib.x .
./ungrib.x
# check the status
outfile="${prefix}:$(date -d "${CDATEout:0:8} ${CDATEout:8:2}" +%Y-%m-%d_%H)"
if [[ -s ${outfile} ]]; then
  if [[ -z "${ENS_INDEX}" ]]; then
    ${cpreq} ${DATA}/${outfile} ${COMOUT}/${task_id}_${TYPE}/
    if [[ "${TYPE}" == "lbc" ]] && [[ ! -d ${COMOUT}/${task_id}_ic  ]]; then
    # lbc tasks need init.nc, don't know why it is so but we have to leave with this for a while
    # link ungrib_lbc to ungrib_ic so that ic tasks can run and generate init.nc
      ln -snf ${COMOUT}/${task_id}_lbc ${COMOUT}/${task_id}_ic
    fi
  else
    ${cpreq} ${DATA}/${outfile} ${COMOUT}/mem${ENS_INDEX}/${task_id}_${TYPE}/
  fi
else
  echo "FATAR ERROR: ungrib failed"
  err_exit
fi
