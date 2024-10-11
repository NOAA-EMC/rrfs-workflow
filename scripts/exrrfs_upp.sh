#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}/${FHR}
fhr=${FHR:1:2} # remove leading zeros
CDATEp=$($NDATE ${fhr} ${CDATE} )
timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)

if [[ -z "${ENS_INDEX}" ]]; then
  ensindexstr=""
else
  ensindexstr="/mem${ENS_INDEX}"
fi
${cpreq} ${COMINrrfs}/${RUN}.${PDY}/${cyc}${ensindexstr}/mpassit/mpassit.${timestr}.nc .
${cpreq} ${FIXrrfs}/upp/* .
FIXcrtm=${FIXrrfs}/crtm/2.4.0
while read line; do
  ln -snf ${FIXcrtm}/${line} .
done < crtmfiles.upp
# generate the namelist on the fly
cat << EOF > itag
&model_inputs
fileName='mpassit.${timestr}.nc'
fileNameFlux='mpassit.${timestr}.nc'
IOFORM='netcdfpara'
grib='grib2'
DateStr='${timestr}'
MODELNAME='RAPR'
fileNameFlat='postxconfig-NT.txt'
/
&nampgb
numx=2
/
EOF

# run the executable
ulimit -s unlimited
ulimit -v unlimited
ulimit -a
source prep_step
${cpreq} ${EXECrrfs}/upp.x .
${MPI_RUN_CMD} ./upp.x
# check the status copy output to COMOUT
wrfprs="WRFPRS.GrbF${fhr}"
wrfnat="WRFNAT.GrbF${fhr}"
wrftwo="WRFTWO.GrbF${fhr}"
if [[ ! -s "./${wrfprs}" ]]; then
  echo "FATAL ERROR: failed to genereate WRF grib2 files"
  export err=99
  err_exit
fi

### generate final grib2 products # this part needs more work
#WGRIB2=/apps/wgrib2/2.0.8/intel/18.0.5.274/bin/wgrib2
#HRRR_DIR="/public/data/grib/hrrr_wrfprs/7/0/83/0_1905141_30" #COMINhrrr
#YYJJJHH=$(date -d "${CDATE:0:8} ${CDATE:8:2}:00" +%y%j%H)
## copy selected fields from netcdf to grib2, using HRRR grib2 as a template
#${WGRIB2} ${HRRR_DIR}/${YYJJJHH}0000${fhr} -match ":TSOIL:" -set_grib_type simple -grib_out TSOIL_template.grib2
#${WGRIB2} ${HRRR_DIR}/${YYJJJHH}0000${fhr} -match ":SOILW:" -set_grib_type simple -grib_out SOILW_template.grib2
#${WGRIB2} ${HRRR_DIR}/${YYJJJHH}0000${fhr} -match ":VGTYP:" -set_grib_type simple -grib_out VGTYP.grib2
#PY=/contrib/miniconda3/4.5.12/envs/avid_verify/bin/python
#SCRIPTS="/lfs5/BMC/nrtrr/FIX_RRFS2/exec"
#${PY} ${SCRIPTS}/netcdf_to_grib.py mpassit.${timestr}.nc TSLB TSOIL_template.grib2 TSOIL.grib2
#${PY} ${SCRIPTS}/netcdf_to_grib.py mpassit.${timestr}.nc SMOIS SOILW_template.grib2 SOILW.grib2
#cat ${wrftwo} TSOIL.grib2 SOILW.grib2 VGTYP.grib2 > ${wrftwo}.tmp
#mv ${wrftwo}.tmp ${wrftwo}

# Append the 2D fields onto the 3D files
cat ${wrfprs} ${wrftwo} > ${wrfprs}.tmp
mv ${wrfprs}.tmp ${wrfprs}
cat ${wrfnat} ${wrftwo} > ${wrfnat}.two
mv ${wrfnat}.two ${wrfnat}

# copy products to COMOUT
${cpreq} ${wrfprs} ${COMOUT}${ensindexstr}/${RUN}_prs_${CDATE}_f${fhr}.grib2
${cpreq} ${wrfnat} ${COMOUT}${ensindexstr}/${RUN}_nat_${CDATE}_f${fhr}.grib2
${cpreq} ${wrftwo} ${COMOUT}${ensindexstr}/${RUN}_two_${CDATE}_f${fhr}.grib2
${cpreq} ${wrfprs} ${COMOUT}${ensindexstr}/${YYJJJHH}0000${fhr}
