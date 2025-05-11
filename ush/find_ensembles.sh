#!/usr/bin/env bash
# copy ioda observation files from com/ to the run directory
#
# shellcheck disable=SC2154,SC2153
if [[ "${HYB_WGT_ENS}" != "0" ]] && [[ "${HYB_WGT_ENS}" != "0.0" ]]; then # using ensembles
  if [[ "${HYB_ENS_TYPE}" == "1"  ]]; then # rrfsens
    echo "use rrfs ensembles"
    mpasout_file=mpasout.${timestr}.nc
    for (( ii=0; ii<4; ii=ii+1 )); do
       CDATEp=$(${NDATE} "-${ii}" "${CDATE}" )
       if [[ "${HYB_ENS_PATH}" == "" ]]; then
         ensdir=${COMINrrfs}/rrfs.${CDATEp:0:8}/${CDATEp:8:2}
       else
         ensdir=${HYB_ENS_PATH}/rrfs.${CDATEp:0:8}/${CDATEp:8:2}
       fi
       ensdir_m001=${ensdir}/fcst/enkf/mem001
       if [[ -s "${ensdir_m001}/${mpasout_file}" ]]; then
         for (( iii=1; iii<31; iii=iii+1 )); do
            memid=$(printf %03d "${iii}")
            ln -s "${ensdir}/fcst/enkf/mem${memid}/${mpasout_file}" "ens/mem${memid}.nc"
         done
       fi
    done
  elif [[ "${HYB_ENS_TYPE}" == "2"  ]]; then # interpolated GDAS/GEFFS
    echo "use interpolated GDAS/GEFS ensembles"
    init_file=init.nc
    for (( ii=0; ii<7; ii=ii+1 )); do
       CDATEp=$(${NDATE} "-${ii}" "${CDATE}" )
       if [[ "${HYB_ENS_PATH}" == "" ]]; then
         ensdir=${COMINrrfs}/rrfs.${CDATEp:0:8}/${CDATEp:8:2}
       else
         ensdir=${HYB_ENS_PATH}/rrfs.${CDATEp:0:8}/${CDATEp:8:2}
       fi
       ensdir_m001=${ensdir}/ic/enkf/mem001
       if [[ -s "${ensdir_m001}/${init_file}" ]]; then
         for (( iii=1; iii<31; iii=iii+1 )); do
            memid=$(printf %03d "${iii}")
            ln -s "${ensdir}/ic/enkf/mem${memid}/${init_file}" "ens/mem${memid}.nc"
         done
       fi
    done

  elif [[ "${HYB_ENS_TYPE}" == "0"  ]]; then # rrfsens->GDAS->3DVAR
    echo "determine the ensemble type on the fly"
    echo "==== to be implemented ===="
  fi
fi
