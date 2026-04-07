#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
cd "${DATA}" || exit 1
domain=${UPP_DOMAIN:-""}
#
#  cpy excutable and fix files; decide mesh
#
${cpreq} "${EXECrrfs}/upp.x" .
${cpreq} "${FIXrrfs}"/upp/* .
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
${cpreq} "postxconfig-NT_L${nlevel}.txt" postxconfig-NT.txt
FIXcrtm=${FIXrrfs}/crtm/2.4.0_upp
while read -r line; do
  ln -snf "${FIXcrtm}/${line}" .
done < crtmfiles.upp
#
#  get YYJJJHH
#
YYJJJHH=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%y%j%H)
#
# find forecst length for this cycle
#
fcst_len_hrs_cycles=${FCST_LEN_HRS_CYCLES:-"01 01"}
fcst_len_hrs_thiscyc=$( "${USHrrfs}/find_fcst_length.sh"  "${fcst_len_hrs_cycles}"  "${cyc}" )
echo "forecast length for this cycle is ${fcst_len_hrs_thiscyc}"
#
# loop through forecast history files for this group
#
read -ra fhr_all <<< "${GROUP_HOURS}"  # convert string to array
for fhr in "${fhr_all[@]}"; do
    if (( 10#${fhr} > 10#${fcst_len_hrs_thiscyc} )); then
      break
    fi
    # get forecast hour and string
    CDATEp=$( ${NDATE} "${fhr}"  "${CDATE}" )
    timestr=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H.%M.%S)
    timestr2=$(date -d "${CDATEp:0:8} ${CDATEp:8:2}" +%Y-%m-%d_%H:%M:%S)
    # decide the mpassit files
    mpassit_file=${UMBRELLA_MPASSIT_DATA}/mpassit.${timestr}.nc

    # wait for file available
    for (( j=0; j < 20; j=j+1)); do
      if [[ -s "${mpassit_file}" ]]; then
        break
      fi
      sleep 60s
    done
    # run UPP
    if [[ -s "${mpassit_file}" ]] ; then

      ln -snf "${mpassit_file}" .
# generate the namelist on the fly
cat << EOF > itag
&model_inputs
fileName='mpassit.${timestr}.nc'
fileNameFlux='mpassit.${timestr}.nc'
IOFORM='netcdfpara'
grib='grib2'
DateStr='${timestr2}'
MODELNAME='RAPR'
SUBMODELNAME='MPAS'
fileNameFlat='postxconfig-NT.txt'
/
&nampgb
numx=2
/
EOF

      # run the executable
      source prep_step
      ${MPI_RUN_CMD} ./upp.x
      # check the status copy output to COMOUT
      fhr2=$(printf %02d $((10#$fhr)) )
      postprs="POSTPRS.GrbF${fhr2}"
      postnat="POSTNAT.GrbF${fhr2}"
      posttwo="POSTTWO.GrbF${fhr2}"
      if [[ ! -s "./${postprs}" ]]; then
        echo "FATAL ERROR: failed to genereate POST grib2 files"
        err_exit
      fi

      mv itag "itag_${fhr2}"
      # Append the 2D fields onto the 3D files
      cat "${postprs}" "${posttwo}" > "${postprs}.tmp"
      mv "${postprs}.tmp"  "${postprs}"
      cat "${postnat}" "${posttwo}" > "${postnat}.two"
      mv "${postnat}.two" "${postnat}"

      # copy products to COMOUT
      fhr3=$(printf %03d $((10#$fhr)) )
      ${cpreq} "${postprs}"  "${COMOUT}/upp/${WGF}${MEMDIR}/${RUN}.t${cyc}z.prslev.f${fhr3}.${domain}grib2"
      ${cpreq} "${postnat}"  "${COMOUT}/upp/${WGF}${MEMDIR}/${RUN}.t${cyc}z.natlev.f${fhr3}.${domain}grib2"
      ${cpreq} "${posttwo}"  "${COMOUT}/upp/${WGF}${MEMDIR}/${RUN}.t${cyc}z.testbed.f${fhr3}.${domain}grib2"
      ln -snf  "${COMOUT}/upp/${WGF}${MEMDIR}/${RUN}.t${cyc}z.prslev.f${fhr3}.${domain}grib2"  "${COMOUT}/upp/${WGF}${MEMDIR}/${YYJJJHH}0000${fhr2}"
      ln -snf  "${COMOUT}/upp/${WGF}${MEMDIR}/${RUN}.t${cyc}z.prslev.f${fhr3}.${domain}grib2"  "${COMOUT}/upp/${WGF}${MEMDIR}/${PDY}.${RUN}.t${cyc}z.prslev.f${fhr3}.${domain}grib2"
      ln -snf  "${COMOUT}/upp/${WGF}${MEMDIR}/${RUN}.t${cyc}z.natlev.f${fhr3}.${domain}grib2"  "${COMOUT}/upp/${WGF}${MEMDIR}/${PDY}.${RUN}.t${cyc}z.natlev.f${fhr3}.${domain}grib2"
      ln -snf  "${COMOUT}/upp/${WGF}${MEMDIR}/${RUN}.t${cyc}z.testbed.f${fhr3}.${domain}grib2"  "${COMOUT}/upp/${WGF}${MEMDIR}/${PDY}.${RUN}.t${cyc}z.testbed.f${fhr3}.${domain}grib2"

      echo "done" > "${COMOUT}/upp/${WGF}${MEMDIR}/done.upp_${fhr2}"

    else
      echo "FATAL ERROR: cannot find mpass file at ${timestr}"
      err_exit
    fi
done
