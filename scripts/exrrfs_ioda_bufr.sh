#!/bin/bash
set -x

source ${FIXrrfs}/workflow/${WGF}/workflow.conf

export FIX_GSI="${FIXrrfs}/gsi"
export FIX_JEDI="${FIXrrfs}/jedi"
export PARM_IODACONV="${PARMrrfs}/iodaconv"
# RDASApp ships the python converters and their auxiliary data in its source tree, so the
# ex-script needs the clone itself and not only the executables installed into exec/.
export RDASAPP_DIR="${RDASAPP_DIR:-${HOMErrfs}/sorc/RDASApp}"

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. $USHrrfs/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that converts the BUFR observations to
IODA format for the specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set environment
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case $MACHINE in
#
"WCOSS2")
  APRUN="mpiexec -n 1 -ppn 1"
  ;;
#
"URSA")
  APRUN="srun --export=ALL -n 1"
  ;;
#
"HERA")
  APRUN="srun --export=ALL"
  ;;
#
"JET")
  APRUN="srun --export=ALL"
  ;;
#
"ORION")
  APRUN="srun --export=ALL"
  ;;
#
"HERCULES")
  APRUN="srun --export=ALL"
  ;;
#
esac
#
#-----------------------------------------------------------------------
#
# Extract from CDATE the starting year, month, day, and hour of the
# forecast.  These are needed below for various operations.
#
#-----------------------------------------------------------------------
#
START_DATE=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
YYYYMMDDHH=${CDATE:0:10}
JJJ=$(date +%j -d "${START_DATE}")

YYYY=${YYYYMMDDHH:0:4}
MM=${YYYYMMDDHH:4:2}
DD=${YYYYMMDDHH:6:2}
HH=${YYYYMMDDHH:8:2}
YYYYMMDD=${YYYYMMDDHH:0:8}
#
#-----------------------------------------------------------------------
#
#   set observation source
#
#-----------------------------------------------------------------------
#
OBSTYPE_SOURCE=${OBSTYPE_SOURCE:-"rrfs"}
obs_source=${OBSTYPE_SOURCE}
if [[ ${HH} -eq '00' || ${HH} -eq '12' ]]; then
  obs_source=${OBSTYPE_SOURCE}_e
fi

case $MACHINE in

"WCOSS2" | "URSA")

  obsfileprefix=${obs_source}
  obspath_tmp=${COMINobsproc}/${obs_source}.${YYYYMMDD}

  ;;
"JET" | "HERA" | "ORION" | "HERCULES")

  obsfileprefix=${YYYYMMDDHH}.${obs_source}
  obspath_tmp=${COMINobsproc}

esac
#
#-----------------------------------------------------------------------
#
# Copy the BUFR files to be converted into the working directory. The
# early (_e) dumps used at 00z and 12z carry only a subset of the types,
# so each copy is optional: a type that is not there is skipped further
# down rather than failing the task.
#
#-----------------------------------------------------------------------
#
copy_obs_file() {       # copy_obs_file <dump type> <local name>
  local obs_type="$1" local_name="$2" obs_file
  obs_file=${obspath_tmp}/${obsfileprefix}.t${HH}z.${obs_type}.tm00.bufr_d
  if [ -r "${obs_file}" ]; then
    cp -p "${obs_file}" "${local_name}"
  else
    print_info_msg "WARNING: ${obs_file} does not exist; skipping ${obs_type}"
  fi
}

run_process_prepbufr=false
obs_file=${obspath_tmp}/${obsfileprefix}.t${HH}z.prepbufr.tm00
if [ -r "${obs_file}" ]; then
  print_info_msg "$VERBOSE" "Found ${obs_file}; Use it as observation "
  cp -p "${obs_file}" prepbufr
  run_process_prepbufr=true
else
  print_info_msg "WARNING: PrepBUFR file for ${YYYYMMDDHH} does not exist!"
fi

copy_obs_file satwnd  satwndbufr
copy_obs_file gsrcsr  abibufr
copy_obs_file atms    atmsbufr
copy_obs_file crisf4  crisfsbufr
copy_obs_file 1bamua  1bamsuabufr
copy_obs_file esamua  esamsuabufr
copy_obs_file nexrad  l2rwbufr
#
#-----------------------------------------------------------------------
#
# Modify yaml template and run bufr2ioda (prepbufr)
#
#-----------------------------------------------------------------------
#
export LD_LIBRARY_PATH="${RDASAPP_DIR}/build/lib64:${LD_LIBRARY_PATH}"

export pgm="bufr2ioda.x"
. prep_step

yaml_list=(
"prepbufr_adpsfc.yaml"
#"prepbufr_adpupa.yaml"  # use python
"prepbufr_aircar.yaml"
"prepbufr_aircft.yaml"
"prepbufr_ascatw.yaml"
"prepbufr_msonet.yaml"
"prepbufr_proflr.yaml"
"prepbufr_rassda.yaml"
"prepbufr_sfcshp.yaml"
"prepbufr_vadwnd.yaml"
)

formatted_time=$(date -d"${YYYYMMDD} ${HH}" '+%Y-%m-%dT%H:%M:%SZ')

for yamlfile in "${yaml_list[@]}"; do
  message_type=$(basename "$yamlfile" .yaml | awk -F'_' '{print $NF}')

  cpreq -p ${PARM_IODACONV}/${yamlfile} .
  sed -i "s/@referenceTime@/${formatted_time}/" "${yamlfile}"

  cpreq -p ${FIX_JEDI}/ioda_empty.nc ioda_${message_type}.nc

  if [[ ${run_process_prepbufr} == true ]]; then
    ${EXECrrfs}/$pgm ${yamlfile} >> $pgmout 2>errfile
    export err=$?
    if [ $err -ne 0 ]; then
      if grep -qF "No valid BUFR subsets were found" errfile; then
        echo "WARNING: ${message_type}: no valid BUFR subsets in input. Skipping this type." >> "${pgmout}"
        export err=0
      fi
    fi
    err_chk
    mv errfile errfile_${message_type}
  fi
done
#
#-----------------------------------------------------------------------
#
# run the python bufr2ioda tools
#
#-----------------------------------------------------------------------
#
export PYTHONUNBUFFERED=1

# pyioda libraries
shopt -s nullglob
dirs=("$RDASAPP_DIR"/build/lib/python3.*)
PYIODALIB=${dirs[0]}
WXFLOWLIB=${RDASAPP_DIR}/sorc/wxflow/src
export PYTHONPATH="${WXFLOWLIB}:${PYIODALIB}:${PYIODALIB}/site-packages:${PYTHONPATH}"

satwnd_list=(
"ahi"
"avhrr"
"goes"
"leogeo"
"modis"
"seviri"
"viirs"
)
for sensor in "${satwnd_list[@]}"; do
  cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_satwnd_amv_${sensor}.json .
  cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_satwnd_amv_${sensor}.py .
done

cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_adpupa_prepbufr.json .
cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_adpupa_prepbufr.py .
cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_gsrcsr.json .
cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_gsrcsr.py .
cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_amsua.py .

# generate a JSON w CDATE from the template and convert to IODA
cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/python/gen_bufr2ioda_json.py .

# ADPUPA (surface pressure)
if [[ ${run_process_prepbufr} == true ]]; then
  export pgm="bufr2ioda_adpupa_prepbufr.py"
  cpreq -p ${FIX_JEDI}/ioda_empty.nc ioda_adpupa.nc
  ./gen_bufr2ioda_json.py -t bufr2ioda_adpupa_prepbufr.json -o bufr2ioda_adpupa_prepbufr_0.json
  ./bufr2ioda_adpupa_prepbufr.py -c bufr2ioda_adpupa_prepbufr_0.json >> $pgmout
  export err=$?; err_chk
fi

# SATWND
if [[ -f satwndbufr ]]; then
  for sensor in "${satwnd_list[@]}"; do
    export pgm="bufr2ioda_satwnd_amv_${sensor}.py"
    ./gen_bufr2ioda_json.py -t bufr2ioda_satwnd_amv_${sensor}.json -o bufr2ioda_satwnd_amv_${sensor}_0.json
    ./bufr2ioda_satwnd_amv_${sensor}.py -c bufr2ioda_satwnd_amv_${sensor}_0.json >> $pgmout
    export err=$?; err_chk
  done
fi

# Satellite Radiance

#1 ABI GSRCSR
# --------------------------------------------------
# run  bufr2netcdf tool for abi csr bufr obs
# --------------------------------------------------
if [[ -f abibufr ]]; then
  export pgm="bufr2ioda_gsrcsr.py"
  ./gen_bufr2ioda_json.py -t bufr2ioda_gsrcsr.json -o bufr2ioda_gsrcsr_0.json
  ./bufr2ioda_gsrcsr.py -c bufr2ioda_gsrcsr_0.json >> $pgmout
  export err=$?; err_chk
fi

#2 ATMS
# --------------------------------------------------
# run  bufr2netcdf tool for atms bufr obs
# --------------------------------------------------
cpreq "${FIX_JEDI}/atms_beamwidth.txt" .
cpreq "${PARM_IODACONV}/bufr_atms_mapping.yaml" .
input_file="atmsbufr"
output_file="ioda_atms_{splits/satId}.nc"
yaml="bufr_atms_mapping.yaml"
if [[ -f "$input_file" ]]; then
  export pgm="bufr2netcdf.x"
  ${EXECrrfs}/bufr2netcdf.x "$input_file" "$yaml" "$output_file"
  export err=$?; err_chk
else
  echo "Input file $input_file does not exist."
fi

#3 AMSUA
# --------------------------------------------------
# run  bufr2netcdf tool for amsua bufr obs
# --------------------------------------------------
cpreq "${PARM_IODACONV}/bufr_1bamua_mapping.yaml" .
cpreq "${PARM_IODACONV}/bufr_esamua_mapping.yaml" .
ln -snf "${RDASAPP_DIR}/rrfs-test/IODA/python/aux" .
yaml_1b="bufr_1bamua_mapping.yaml"
yaml_es="bufr_esamua_mapping.yaml"
input_1b="1bamsuabufr"
input_es="esamsuabufr"
output_file="ioda_amsua_{splits/satId}.nc"
if [[ -f "$input_1b" && -f "$input_es" ]]; then
  export pgm="bufr2ioda_amsua.py"
  python bufr2ioda_amsua.py $input_1b $input_es $yaml_es $yaml_1b $output_file
  export err=$?; err_chk
else
  echo "Input files $input_1b and/or $input_es do not exist."
fi

#4 CRIS
# --------------------------------------------------
# run  bufr2netcdf tool for cris-fsr bufr obs
# --------------------------------------------------
cpreq "${PARM_IODACONV}/bufr2netcdf_cris-fsr.yaml" .
input_file="crisfsbufr"
output_file="ioda_crisf4_{splits/satId}.nc"
yaml="bufr2netcdf_cris-fsr.yaml"

if [[ -f "$input_file" ]]; then
  export pgm="bufr2netcdf.x"
  ${EXECrrfs}/bufr2netcdf.x "$input_file" "$yaml" "$output_file"
  export err=$?; err_chk
else
  echo "Input file $input_file does not exist."
fi
#
#-----------------------------------------------------------------------
#
# Run l2rw super-ob bufr2ioda tool
#
#-----------------------------------------------------------------------
#
grid_file="fv3_grid_spec"
cpreq -p "${FIX_GSI}/${PREDEF_GRID_NAME}/${grid_file}" .

if [[ -f l2rwbufr ]]; then
  pgm="rdas_nexrad_superob.x"
  input_bufr="l2rwbufr"
  namelist="nexrad_superob.nml"

  cpreq "${EXECrrfs}/${pgm}" .
  cpreq "${RDASAPP_DIR}/rrfs-test/IODA/radar_renameStnID.py" .
  cpreq "${RDASAPP_DIR}/rrfs-test/IODA/${namelist}" .

  sed -i "s/@CYCLETIME@/${YYYYMMDDHH}/" "${namelist}"

  "./${pgm}" "${input_bufr}" "${grid_file}" "ioda_nexrad_unfixed.nc" "${namelist}" >> "${pgmout}"
  export err=$?
  err_chk
  mv errfile errfile_radialVelocity

  export pgm="radar_renameStnID.py"
  python radar_renameStnID.py --input "ioda_nexrad_unfixed.nc" --output "ioda_nexrad.nc"
  export err=$?; err_chk
  rm -f "ioda_nexrad_unfixed.nc"
fi
#
#-----------------------------------------------------------------------
#
# Run the IODA offline tools
#
#-----------------------------------------------------------------------
#
is_empty_ioda() {
    local f="$1"
    # Robust check: look at Location dimension
    local loc
    loc=$(ncdump -h "$f" 2>/dev/null | awk '/Location =/ {print $3}' | tr -d ';')
    if [ -z "$loc" ]; then
        return 0
    fi
    if [ "$loc" -le 1 ]; then
        return 0  # empty
    fi
    return 1  # not empty
}

cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/offline_domain_check.py .
cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/offline_domain_check_satrad.py .
cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/offline_ioda_patch.py .
cpreq "${RDASAPP_DIR}"/rrfs-test/IODA/offline_vad_thinning.py .

# offline domain check & patch
for ioda_file in ioda*.nc; do
  # skip empty files
  if is_empty_ioda "$ioda_file"; then
    echo "Skipping domain check & patch: $ioda_file is empty"
    continue
  fi
  if [[ "${ioda_file}" == *abi* && "${ioda_file}" != *satwnd* ]]; then
    echo " ${ioda_file} ioda file detected: running offline_domain_check_satrad.py"
    export pgm="offline_domain_check_satrad.py"
    ./offline_domain_check_satrad.py -o "${ioda_file}" -g "${grid_file}" -s 0.005 >> $pgmout
    export err=$?; err_chk
    base_name=$(basename "$ioda_file" .nc)
    mv  "${base_name}_dc.nc" "${base_name}.nc"
  elif [[ "${ioda_file}" == *atms* || "${ioda_file}" == *cris* || "${ioda_file}" == *amsua* ]]; then
    echo " ${ioda_file} ioda file detected: temporarily skipping offline domain check"
  else
    export pgm="offline_domain_check.py"
    ./offline_domain_check.py -o "${ioda_file}" -g "${grid_file}" -s 0.005
    export err=$?; err_chk
    base_name=$(basename "$ioda_file" .nc)
    mv  "${base_name}_dc.nc" "${base_name}.nc"
    export pgm="offline_ioda_patch.py"
    if [[ "${ioda_file}" == *nexrad* ]]; then
      echo "Skipping ioda_patch for ${ioda_file}"
    elif [[ "${ioda_file}" == *adpupa* ]]; then
      ./offline_ioda_patch.py -o "${ioda_file}" --patch-timeoffset >> $pgmout
    else
      ./offline_ioda_patch.py -o "${ioda_file}" >> $pgmout
    fi
    export err=$?; err_chk
    base_name=$(basename "$ioda_file" .nc)
    mv  "${base_name}_llp.nc" "${base_name}.nc"
  fi
done

# vadwnd thinning & superobbing
if [[ -f ioda_vadwnd.nc ]]; then
  export pgm="offline_vad_thinning.py"
  ./offline_vad_thinning.py -i ioda_vadwnd.nc -o ioda_vadwnd_thinned.nc >> $pgmout
  export err=$?; err_chk
  mv ioda_vadwnd_thinned.nc ioda_vadwnd.nc
fi

#
#-----------------------------------------------------------------------
#
# Move ioda files to COMOUT
#
#-----------------------------------------------------------------------
#
ioda_files=(ioda_*.nc)
if [ ${#ioda_files[@]} -gt 0 ]; then
  cp "${ioda_files[@]}" ${COMOUT_ANALYSIS}/.
else
  print_info_msg "WARNING: no IODA files were produced for ${CDATE}"
fi
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
IODA BUFR PROCESS completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
