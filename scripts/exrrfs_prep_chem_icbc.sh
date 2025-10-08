#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154,SC2034
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '

module load nco

set -x
cpreq=${cpreq:-cpreq}
prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cd "${DATA}" || exit 1
# find forecst length for this cycle
#
fcst_length=${FCST_LENGTH:-1}
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$("${USHrrfs}/find_fcst_length.sh" "${fcst_len_hrs_cycles}" "${cyc}" "${fcst_length}")
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
YYYYMMDDHH=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y%m%d%H)
yesterday_name=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 24 hours" +%Y%m%d)
twodaysago_name=$(date -d "${CDATE:0:8} ${CDATE:8:2} - 48 hours" +%Y%m%d)
today_name=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H) # history.2025-03-17_00.00.00.nc
today_HH=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%H)
yesterday_chem_name=${DATAROOT}/../${yesterday_name}/rrfs_fcst_${today_HH}_${rrfs_ver}/det/fcst_${today_HH}/mpasout.${today_name}.00.00.nc
twodayago_chem_name=${DATAROOT}/../${twodaysago_name}/rrfs_fcst_${today_HH}__${rrfs_ver}/det/fcst_${today_HH}/mpasout.${today_name}.00.00.nc

if [[ -e "${UMBRELLA_PREP_IC_DATA}/init.nc" ]]; then
   CYCLETOFILE=${UMBRELLA_PREP_IC_DATA}/init.nc
elif [[ -e "${COMOUT}/ic/${WGF}${MEMDIR}/init.nc" ]]; then
   CYCLETOFILE=${COMOUT}/ic/${WGF}${MEMDIR}/init.nc
else
   echo "Cannot find init file at ${UMBRELLA_PREP_IC_DATA}/init.nc or ${COMOUT}/ic/${WGF}${MEMDIR}/init.nc, exiting"
   exit 1
fi

# First check to see if there is a cyclefile available:
if [[ -r ${yesterday_chem_name} ]]; then
   cyclefile=${yesterday_chem_name}
elif [[ -r ${twodayago_chem_name} ]]; then
   cyclefile=${twodayago_chem_name}
else
   echo "no cycle file available"
fi

has_ungrib_icbcs=0
has_rrfsa_icbcs=0


species_list=(unspc_fine unspc_coarse dust_fine dust_coarse polp_tree polp_grass polp_weed pols_all polp_all ssalt_fine ssalt_coarse ch4)
# TODO, for now, only either cycle from previous output or reinitialize
# The realtime system and retros system will be able to use smoke and dust
# from the RRFS as initial and boundary conditions
if [[ ${cyclefile} ]] ;then 
   for species in "${species_list[@]}"; do
      # Check to see if the species is in the file 
      ncdump -hv ${species} ${cyclefile}
      if [[ $? -eq 0 ]]; then
         ncks -A -v ${species} ${cyclefile} ${CYCLETOFILE}
      fi
   done
else
   for species in "${species_list[@]}"; do
      ncap2 -O -s "${species}=1.e-12*qv" ${CYCLETOFILE} ${CYCLETOFILE}
   done
fi # yesterday chem


if [[ ${has_ungrib_icbcs} -eq 1 ]]; then
   for ihour in $(seq 0 3 ${fcst_length})
   do
     datestr=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%Y-%m-%d_%H.00.00)  
     fid=${UMBRELLA_PREP_LBC_DATA}/lbc/lbc.${datestr}.nc
     sleep 5s
# smoke fin
     ncdump -hv lbc_SMKF ${fid}
     if [[ $? -eq 0 ]]; then
        ncrename -v lbc_SMKF,lbc_smoke_fine ${fid}
     fi
     ncdump -hv lbc_MASSDEN ${fid}
     if [[ $? -eq 0 ]];then
        ncrename -v lbc_MASSDEN,lbc_smoke_fine  ${fid}
     fi
     ncdump -hv lbc_DSTF ${fid}
     if [[ $? -eq 0 ]]; then 
        ncrename -v lbc_DSTF,lbc_dust_fine ${fid}
     fi
     ncdump -hv lbc_DSTC ${fid}
     if [[ $? -eq 0 ]]; then
        ncrename -v lbc_DSTC,lbc_dust_coarse ${fid}
     fi
   done
else
   if [[ ${has_rrfsa_icbcs} -eq 1 ]];then
      echo "Using realtime RRFSA LBCs"
      for ihour in $(seq 0 3 ${fcst_length})
      do
        datestr=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%Y-%m-%d_%H.00.00)  
        ${cpreq} ${MPAS_RRFSA_DIR}/${YYYYMMDDHH}/fcst/ctl/hrrrv5.lbc.${datestr}.nc lbc.${datestr}.nc
      done
   else
      echo "No RRFSA LBCs either, exiting"
      #exit 1
   fi
fi



