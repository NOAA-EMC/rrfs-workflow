#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '

module load nco

set -x
cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1
#
# determine time steps and etc according to the mesh
#
if [[ ${MESH_NAME} == "conus12km" ]]; then
  dt=60
  substeps=2
  radt=30
elif [[ ${MESH_NAME} == "conus3km" ]]; then
  dt=20
  substeps=4
  radt=15
else
  echo "Unknown MESH_NAME, exit!"
  err_exit
fi
#
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$("${USHrrfs}/find_fcst_length.sh" "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
# 
#
YYYYMMDDHH=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y%m%d%H)
yesterday_name=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 24 hours" +%Y%m%d%H)
twodaysago_name=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 48 hours" +%Y%m%d%H)
today_name=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H) # history.2025-03-17_00.00.00.nc
today_HH=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%H)
yesterday_chem_name=/lfs5/BMC/rtwbl/rap-chem/mpas_conus3km/cycledir/stmp/${yesterday_name}/rrfs_fcst_${today_HH}_v2.1.1/det/fcst_${today_HH}/mpasout.${today_name}.00.00.nc
twodayago_chem_name=/lfs5/BMC/rtwbl/rap-chem/mpas_conus3km/cycledir/stmp/${twodaysago_name}/rrfs_fcst_${today_HH}_v2.1.1/det/fcst_${today_HH}/mpasout.${today_name}.00.00.nc

TOPDIR=/lfs5/BMC/rtwbl/rap-chem/mpas_conus3km/cycledir/stmp/${YYYYMMDDHH}/
INITFILE=/lfs5/BMC/rtwbl/rap-chem/mpas_conus3km/cycledir/stmp/${YYYYMMDDHH}/init/ctl/hrrrv5.init.nc
OROFILE=/mnt/lfs5/BMC/rtwbl/rap-chem/mpas_rt/input/grids/oro/3km_conus.ugwp_oro_data.nc

full=1

if [[ ${full} -eq 1 ]] ;then


${cpreq} ${OROFILE} .

has_rrfsa_icbcs=0
has_ungrib_icbcs=0

if [[ -r ${MPAS_RRFSA_DIR}/${YYYYMMDDHH}/init/ctl/hrrrv5.init.nc ]]; then
has_rrfsa_icbcs=1
fi

if [[ -r ${INITFILE} ]]; then
has_ungrib_icbcs=1
fi

if [[ ${has_rrfsa_icbcs} -eq 1 ]];then
  ${cpreq} ${MPAS_RRFSA_DIR}/${YYYYMMDDHH}/init/ctl/hrrrv5.init.nc mpasin.nc
else
  if [[ ${has_ungrib_icbcs} -eq 1 ]]; then
     ${cpreq} ${INITFILE} mpasin.nc
     sleep 5s
  else
     echo "No ungrib ic either, exitiing"
     exit 1
  fi
fi

if [[ ${has_ungrib_icbcs} -eq 1 ]]; then
   for ihour in $(seq 0 3 ${fcst_length})
   do
     datestr=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%Y-%m-%d_%H.00.00)  
     ${cpreq} ${TOPDIR}/lbc/ctl/hrrrv5.lbc.${datestr}.nc lbc.${datestr}.nc
     sleep 5s
# smoke fin
     ncdump -hv lbc_SMKF lbc.${datestr}.nc
     if [[ $? -eq 0 ]]; then
        ncrename -v lbc_SMKF,lbc_smoke_fine lbc.${datestr}.nc
     fi
     ncdump -hv lbc_MASSDEN lbc.${datestr}.nc
     if [[ $? -eq 0 ]];then
        ncrename -v lbc_MASSDEN,lbc_smoke_fine  lbc.${datestr}.nc
     fi
     ncdump -hv lbc_DSTF lbc.${datestr}.nc
     if [[ $? -eq 0 ]]; then 
        ncrename -v lbc_DSTF,lbc_dust_fine lbc.${datestr}.nc
     fi
     ncdump -hv lbc_DSTC lbc.${datestr}.nc
     if [[ $? -eq 0 ]]; then
        ncrename -v lbc_DSTC,lbc_dust_coarse lbc.${datestr}.nc
     fi
     ncap2 -O -s 'lbc_ch4=float(lbc_qv*0.0+1.9)' lbc.${datestr}.nc lbc.${datestr}.nc
   done
else
   if [[ ${has_rrfsa_icbcs} -eq 1 ]];then
      echo "No LBC files created, using RRFSA LBCs"
      for ihour in $(seq 0 3 ${fcst_length})
      do
        datestr=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%Y-%m-%d_%H.00.00)  
        ${cpreq} ${MPAS_RRFSA_DIR}/${YYYYMMDDHH}/fcst/ctl/hrrrv5.lbc.${datestr}.nc lbc.${datestr}.nc
        ncap2 -O -s 'lbc_ch4=float(lbc_qv*0.0+1.9)' lbc.${datestr}.nc lbc.${datestr}.nc
      done
   else
      echo "No RRFSA LBCs either, exiting"
      exit 1
   fi
fi


# Check if smoke is in the files
ncdump -hv smoke mpasin.nc
if [[ $? -eq 0 ]]; then
  echo "Smoke is in the IC/BCs" 
  has_data=1
else
  echo "Smoke not in the IC/BCs"
  has_data=0
fi

if [[ -r ${yesterday_chem_name} ]]; then
   cyclefile=${yesterday_chem_name}
elif [[ -r ${twodayago_chem_name} ]]; then
   cyclefile=${twodayago_chem_name}
else
   echo "no cycle file available"
fi
if [[ ${cyclefile} ]] ;then 
   ncks -A -v unspc_fine,unspc_coarse,smoke_fine,smoke_coarse,dust_fine,dust_coarse,polp_tree,polp_grass,polp_weed,pols_all ${cyclefile} mpasin.nc
   ncks -A -v ssalt_fine,ssalt_coarse ${cyclefile} mpasin.nc
   ncdump -hv ch4 ${cyclefile}
   if [[ $? -eq 0 ]]; then
      echo "Methane is in the last cycle's output" 
      ncks -A -v ch4 ${cyclefile} mpasin.nc
      #ncap2 -O -s 'ch4=float(0.0*qv+1.9)' mpasin.nc mpasin.nc
   else
      echo "Methane not in the last cycle's output, initializing to 1.9 ppm"
      ncap2 -O -s 'ch4=float(0.0*qv+1.9)' mpasin.nc mpasin.nc
   fi

else
   if [[ ${has_ungrib_icbcs} -eq 1 ]]; then
# smoke
      ncdump -hv SMKF  ${INITFILE}
      if [[ $? -eq 0 ]]; then
         ncks -A -v SMKF ${INITFILE}  mpasin.nc
         ncrename -v SMKF,smoke_fine mpasin.nc
      fi
# fine dust
      ncdump -hv DSTF  ${INITFILE}
      if [[ $? -eq 0 ]]; then
         ncks -A -v DSTF ${INITFILE}  mpasin.nc
         ncrename -v DSTF,dust_fine mpasin.nc
      fi
# fine dust
      ncdump -hv DSTC  ${INITFILE}
      if [[ $? -eq 0 ]]; then
         ncks -A -v DSTC ${INITFILE}  mpasin.nc
         ncrename -v DSTC,dust_coarse mpasin.nc
      fi
   else
      ncap2 -O -s 'ch4=1.e-12*qv+1.9' -s 'smoke_fine=1.e-12*qv' -s 'smoke_coarse=1.e-12*qv' -s 'dust_fine=1.e-12*qv' -s 'dust_coarse=1.e-12*qv' -s 'dust_fine=1.e-12*qv' -s 'dust_coarse=1.e-12*qv' -s 'unspc_fine=1.e-12*qv' -s 'unspc_coarse=1.e-12*qv' -s 'ssalt_fine=1.e-12*qv' -s 'ssalt_coarse=1.e-12*qv' -s 'polp_tree=1.e-12*qv' -s 'polp_grass=1.e-12*qv' -s 'polp_weed=1.e-12*qv' -s 'pols_all=1.e-12*qv' mpasin.nc mpasin.nc
   fi # init file
fi # yesterday chem

fi

#ncap2 -O -s 'ch4=1.e-12*qv+1.9' mpasin.nc mpasin.nc

ln -snf "${FIXrrfs}/physics/${PHYSICS_SUITE}"/* .
ln -snf "${FIXrrfs}/meshes/${MESH_NAME}.ugwp_oro_data.nc" ./ugwp_oro_data.nc
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
ln -snf "${FIXrrfs}/meshes/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix}" ./invariant.nc
mkdir -p graphinfo stream_list
ln -snf "${FIXrrfs}"/graphinfo/* graphinfo/
ln -snf "${FIXrrfs}/stream_list/${PHYSICS_SUITE}"/* stream_list/

# generate the namelist on the fly
# do_restart already defined in the above
start_time=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H:%M:%S) 
run_duration=${fcst_len_hrs_thiscyc:-1}:00:00
physics_suite=${PHYSICS_SUITE:-'mesoscale_reference'}
jedi_da="true" #true

if [[ "${MESH_NAME}" == "conus12km" ]]; then
  pio_num_iotasks=1
  pio_stride=40
elif [[ "${MESH_NAME}" == "conus3km" ]]; then
  pio_num_iotasks=40
  pio_stride=20
fi
file_content=$(< "${PARMrrfs}/${physics_suite}/namelist.atmosphere") # read in all content
eval "echo \"${file_content}\"" > namelist.atmosphere

# generate the streams file on the fly using sed as this file contains "filename_template='lbc.$Y-$M-$D_$h.$m.$s.nc'"
lbc_interval=${LBC_INTERVAL:-3}
restart_interval=${RESTART_INTERVAL:-99}
history_interval=${HISTORY_INTERVAL:-1}
diag_interval=${HISTORY_INTERVAL:-1}
sed -e "s/@restart_interval@/${restart_interval}/" -e "s/@history_interval@/${history_interval}/" \
    -e "s/@diag_interval@/${diag_interval}/" -e "s/@lbc_interval@/${lbc_interval}/" \
    "${PARMrrfs}"/streams.atmosphere  > streams.atmosphere
#
# prelink the forecast output files to umbrella
history_all=$(seq 0 $((10#${history_interval})) $((10#${fcst_len_hrs_thiscyc} )) )
for fhr in ${history_all}; do
  CDATEp=$( ${NDATE} "${fhr}" "${CDATE}" )
  timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
  if [[ "${DO_SPINUP:-FALSE}" != "TRUE" ]];  then
    ln -snf "${DATA}/history.${timestr}.nc" "${UMBRELLA_FCST_DATA}"
    ln -snf "${DATA}/diag.${timestr}.nc" "${UMBRELLA_FCST_DATA}"
    ln -snf "${DATA}/mpasout.${timestr}.nc" "${UMBRELLA_FCST_DATA}"
    ln -snf "${DATA}/log.atmosphere.0000.out" "${UMBRELLA_FCST_DATA}"
  fi
done

