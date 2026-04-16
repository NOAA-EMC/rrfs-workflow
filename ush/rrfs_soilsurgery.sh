#! /bin/bash

#   
#-----------------------------------------------------------------------
#
# conduct surface surgery to transfer RAP/HRRR surface fields into RRFS.
#   
# This surgery only needs to be done once to give RRFS a good start of the surface.
# Please consult Ming or Tanya first before turning on this surgery.
#     
#-----------------------------------------------------------------------
#     
if [ ${SFC_CYC} -eq 3 ] ; then
      
   do_lake_surgery=".false."
   if [ "${USE_CLM}" = "TRUE" ]; then
     do_lake_surgery=".true."
   fi
   raphrrr_com=${COMROOT}
   rapfile='missing'
   hrrrfile='missing'
   hrrr_akfile='missing'
   current_cdate=${YYYYMMDD}${HH}
   new_cdate=$($NDATE -1 ${current_cdate})
   new_pdy=$(echo ${new_cdate}| cut -c1-8)
   new_cyc=$(echo ${new_cdate}| cut -c9-10)
   if [ -r ${COMINrap}/nwges/rapges/rap_${new_cdate}f001 ]; then
     cpreq -p ${COMINrap}/nwges/rapges/rap_${new_cdate}f001 sfc_rap
          rapfile='sfc_rap'
   fi
   if [ -r ${COMINhrrr}/nwges/hrrrges_sfc/conus/hrrr_${new_cdate}f001 ]; then
     cpreq -p ${COMINhrrr}/nwges/hrrrges_sfc/conus/hrrr_${new_cdate}f001 sfc_hrrr
     hrrrfile='sfc_hrrr'
   fi

   export pgm="rrfs_util_use_raphrrr_sfc.exe"
   ln -sf ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec  fv3_grid_spec
   for file in ${rapfile} ${hrrrfile} ${hrrr_akfile}
   do
     if [ "${file}" = "missing" ]; then
       continue
     else
       if [ "${file}" = "${rapfile}" ]; then

cat << EOF > use_raphrrr_sfc.namelist
&setup
rapfile=${rapfile}
hrrrfile='missing'
hrrr_akfile='missing'
rrfsfile='sfc_data.nc'
do_lake_surgery=${do_lake_surgery}
update_snow=true
/
EOF
         cpreq use_raphrrr_sfc.namelist use_raphrrr_sfc.namelist_rap

       elif [ "${file}" = "${hrrrfile}" ]; then

cat << EOF > use_raphrrr_sfc.namelist
&setup
rapfile='missing'
hrrrfile=${hrrrfile}
hrrr_akfile='missing'
rrfsfile='sfc_data.nc'
do_lake_surgery=${do_lake_surgery}
update_snow=false
/
EOF
         cpreq use_raphrrr_sfc.namelist use_raphrrr_sfc.namelist_hrrr

       elif [ "${file}" = "${hrrr_akfile}" ]; then

cat << EOF > use_raphrrr_sfc.namelist
&setup
rapfile='missing'
hrrrfile='missing'
hrrr_akfile=${hrrr_akfile}
rrfsfile='sfc_data.nc'
do_lake_surgery=${do_lake_surgery}
update_snow=false
/
EOF

         cpreq use_raphrrr_sfc.namelist use_raphrrr_sfc.namelist_hrrrak
       fi
     fi
     cpreq sfc_data.nc sfc_data.nc_read
     . prep_step
     ${APRUN} ${EXECrrfs}/$pgm >>$pgmout 2>errfile
     export err=$?; err_chk
     mv errfile errfile_sfc_surgery.${file}
   done
      echo "${YYYYMMDDHH}(${CYCLE_TYPE}): run surface surgery"
fi
