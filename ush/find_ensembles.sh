#!/usr/bin/env bash
# find ensemble forecasts based on user settings
#
# shellcheck disable=SC2154,SC2153
if [[ "${HYB_WGT_ENS}" != "0" ]] && [[ "${HYB_WGT_ENS}" != "0.0" ]]; then # using ensembles
  mpasout_file=mpasout.${timestr}.nc
  enshrs=$(( 10#${ENS_BEC_LOOK_BACK_HRS} + 1 ))
  ens_size=$(( 10#${ENS_SIZE} ))
  base_dir="${HYB_ENS_PATH:-$COMINrrfs}"

  for (( ii=0; ii<enshrs; ii=ii+1 )); do
     CDATEp=$(${NDATE} "-${ii}" "${CDATE}" )
     ensdir="${base_dir}/rrfs.${CDATEp:0:8}/${CDATEp:8:2}"
     mpasout_m001="${ensdir}/fcst/enkf/mem001/${mpasout_file}"
     init_m001="${ensdir}/ic/enkf/mem001/init.nc"

     found_data=false # Track if we linked anything

     if [[ "${HYB_ENS_TYPE}" == "1" &&  -s "${mpasout_m001}" ]]; then # rrfsens
         echo "use rrfs ensembles"
         for (( iii=1; iii<=ens_size; iii=iii+1 )); do
            memid=$(printf %03d "${iii}")
            ln -s "${ensdir}/fcst/enkf/mem${memid}/${mpasout_file}" "ens/mem${memid}.nc"
         done
         found_data=true
     elif [[ "${HYB_ENS_TYPE}" == "2" &&  -s "${init_m001}"  ]]; then # interpolated GDAS/GEFFS
         echo "use interpolated GDAS/GEFS ensembles"
         for (( iii=1; iii<=ens_size; iii=iii+1 )); do
            memid=$(printf %03d "${iii}")
            ln -s "${ensdir}/ic/enkf/mem${memid}/init.nc" "ens/mem${memid}.nc"
         done
         found_data=true
     elif [[ "${HYB_ENS_TYPE}" == "0"  ]]; then # rrfsens->GDAS->3DVAR
       echo "determine the ensemble type on the fly"
       if [[ -s "${mpasout_m001}" ]]; then
         echo "use rrfs ensembles"
         for (( iii=1; iii<=ens_size; iii=iii+1 )); do
            memid=$(printf %03d "${iii}")
            ln -s "${ensdir}/fcst/enkf/mem${memid}/${mpasout_file}" "ens/mem${memid}.nc"
         done
         found_data=true
       elif [[ -s "${init_m001}" ]]; then
         echo "use interpolated GDAS/GEFS ensembles"
         for (( iii=1; iii<=ens_size; iii=iii+1 )); do
            memid=$(printf %03d "${iii}")
            ln -s "${ensdir}/ic/enkf/mem${memid}/init.nc" "ens/mem${memid}.nc"
         done
         found_data=true
       fi
     fi
# Break if we actually found and linked files
     if [[ "${found_data}" == "true" ]]; then break; fi
  done

# Check if we failed to find data after checking all enshrs
  if [[ "${found_data}" == "false" ]]; then
    echo "No ensemble files found within the ${enshrs} hour look-back window."
  fi

fi
