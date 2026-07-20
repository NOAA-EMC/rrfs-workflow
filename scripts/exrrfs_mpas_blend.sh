#!/usr/bin/env bash
# shellcheck disable=SC2153,SC1091,SC2154
declare -rx PS4='+${SECONDS}s $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
cd "${DATA}"  || exit 1

cyc_interval=${CYC_INTERVAL:-1}
cyc=${CDATE:8:2}
large_scale_file=${UMBRELLA_PREP_IC_DATA}/init.nc
small_scale_file=""
timestr=$(date -d "${CDATE:0:8} ${CDATE:8:2}" +%Y-%m-%d_%H.%M.%S)

for hr in ${BLENDING_CYCS:-"99"}; do
  shr=$(printf '%02d' $((10#$hr)) )
  if [[ "${cyc}" == "${shr}" ]]; then
    # look back ${NUM} cycles to find mpasout files as small scale file
    NUM=3
    for (( ii=cyc_interval; ii<=$(( NUM*cyc_interval )); ii=ii+cyc_interval )); do
      CDATEp=$(${NDATE} -${ii} "${CDATE}" )
      PDYii=${CDATEp:0:8}
      cycii=${CDATEp:8:2}
      file_mpasout="${COMINrrfs}/${RUN}.${PDYii}/${cycii}/fcst/${WGF}${memdir}/mpasout.${timestr}.nc"
      if [[ -s "${file_mpasout}" ]]; then
        small_scale_file="${file_mpasout}"
        break
      fi
    done

    if [[ -r ${large_scale_file} ]] && [[ -r ${small_scale_file} ]] ; then
      blend_fields=blend_fields.nc
      blend_file=blend_file.nc
      blend_fix=${FIXrrfs}/mpas_blend
      blend_parm=${PARMrrfs}/mpas_blend
      grid_info_file=${blend_parm}/grid_weight

      ln -sfn "${small_scale_file}" .
      ln -sfn "${large_scale_file}" .
      ln -sfn "${grid_info_file}" .
      ln -sfn "${blend_fix}"/global*grid.nc .
      ln -sfn "${blend_fix}/${MESH_NAME}"/conus*grid.nc .
      ln -sfn "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.grid.nc" .

      small_file=$(basename "${small_scale_file}")
      large_file=$(basename "${large_scale_file}")
      grid_file=$(basename "${grid_info_file}")

      # generate the naemlist on fly
      sed -e "s/@grid_file@/${grid_file}/" -e "s/@large_file@/${large_file}/" -e "s/@small_file@/${small_file}/"  \
          -e "s/@blend_fields@/${blend_fields}/"  "${blend_parm}/namelist.mpas_blend" > input.nml

      # run the executable
      source prep_step
      ${cpreq} "${EXECrrfs}"/mpas_blending.x .
      ${MPI_RUN_CMD} ./mpas_blending.x
      export err=$?; err_chk

      # check the status, copy output to UMBRELLA_PREP_IC_DATA
      if [[ -s "./${blend_fields}" ]]; then
        ${cpreq} "${small_scale_file}" "${blend_file}"  
        ncks -A  "${blend_fields}"     "${blend_file}"
        ${cpreq} "${blend_file}"       "${large_scale_file}"
        echo "INFO: mpas blending finished successfully at ${timestr}"
      else
        echo "INFO: failed to genereate ${blend_fields}, no blending at ${timestr} "
      fi

    else  
      echo "INFO: cannot find large scale file ${large_scale_file} or  small scale file ${small_scale_file}, no blending at ${timestr}"
    fi
  fi  
done

exit 0
