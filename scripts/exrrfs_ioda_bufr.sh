#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHdir/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u -x; } > /dev/null 2>&1
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

This is the ex-script for the task that runs ioda converter
preprocess for the specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.
# Then process the arguments provided to this script/function (which
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( "CYCLE_DIR" "comout")
process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script.  Note that these will be printed out only if VERBOSE is set to
# TRUE.
#
#-----------------------------------------------------------------------
#
print_input_args valid_args
#
#-----------------------------------------------------------------------
#
# Set environment.
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
"HERA")
  APRUN="srun"
  ;;
  #
"GAEA")
  APRUN="srun"
  ;;
#
"JET")
  APRUN="srun"
  ;;
#
"ORION")
  APRUN="srun"
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
YYYYMMDDHH=$(date +%Y%m%d%H -d "${START_DATE}")
JJJ=$(date +%j -d "${START_DATE}")

YYYY=${YYYYMMDDHH:0:4}
MM=${YYYYMMDDHH:4:2}
DD=${YYYYMMDDHH:6:2}
HH=${YYYYMMDDHH:8:2}
YYYYMMDD=${YYYYMMDDHH:0:8}

YYJJJHH=$(date +"%y%j%H" -d "${START_DATE}")
PREYYJJJHH=$(date +"%y%j%H" -d "${START_DATE} 1 hours ago")
#
#-----------------------------------------------------------------------
#
# link the executable file
#
#-----------------------------------------------------------------------
#
export pgm="bufr2ioda.x"
. prep_step
#
#
#-----------------------------------------------------------------------
#
# check the existence of the PrepBUFR file for the current cycle,
# if the file is present, convert the data into ioda format for
# aircraft, ascatw, gpsipw, mesonet, profiler, rassda,
# satwnd, surface, upperair subsets.
#
#-----------------------------------------------------------------------
#
run_process_prepbufr=false
obs_file=prepbufr
checkfile=${OBSPATH}/${YYYYMMDDHH}.rap.t${HH}z.prepbufr.tm00
if [ -r "${checkfile}" ]; then
  print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as observation "
  cp -p ${checkfile} ${obs_file}
  run_process_prepbufr=true
else
  print_info_msg "$VERBOSE" "Warning: PrepBUFR file for ${YYYYMMDDHH} does not exist!"
fi
#
#-----------------------------------------------------------------------
#
# Copy all bufr files to be converted to ioda format
#
#-----------------------------------------------------------------------
#
cp ${OBSPATH}/${YYYYMMDDHH}.rap.t${HH}z.satwnd.tm00.bufr_d satwndbufr
#
#-----------------------------------------------------------------------
#
# Modify yaml template and run bufr2ioda (prepbufr)
#
#-----------------------------------------------------------------------
#
#export LD_LIBRARY_PATH="${RDASAPP_DIR}/build/lib64:${LD_LIBRARY_PATH}"

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


formatted_time=$(date -d"${YYYYMMDDHH:0:8} ${YYYYMMDDHH:8:2}" '+%Y-%m-%dT%H:%M:%SZ')

for yamlfile in "${yaml_list[@]}"; do
  message_type=$(basename "$yamlfile" .yaml | awk -F'_' '{print $NF}')

  cp -p ${PARM_IODACONV}/${yamlfile} .
  sed -i "s/@referenceTime@/${formatted_time}/" "${yamlfile}"

  cp -p ${FIX_JEDI}/ioda_empty.nc  ioda_${message_type}.nc

  if [[ ${run_process_prepbufr} ]]; then
    ${EXECdir}/bin/$pgm ${yamlfile} >> $pgmout 2>errfile
    export err=$?; err_chk
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
#export PYTHONUNBUFFERED=1
#export PYIODALIB="$RDASAPP_DIR/build/lib/python3.*"
#export PYTHONPATH="${PYTHONPATH}:$RDASAPP_DIR/build/lib/python3.*:$RDASAPP_DIR/sorc/wxflow/src"
#export PYTHONPATH="$PYIODALIB:$RDASAPP_DIR/sorc/wxflow/src:${PYTHONPATH}"

# pyioda libraries
shopt -s nullglob
dirs=("$RDASAPP_DIR"/build/lib/python3.*)
PYIODALIB=${dirs[0]}
WXFLOWLIB=${RDASAPP_DIR}/sorc/wxflow/src
export PYTHONPATH="${WXFLOWLIB}:${PYIODALIB}:${PYTHONPATH}"

cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_adpupa_prepbufr.json .
cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_adpupa_prepbufr.py .
cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_satwnd_amv_goes.json .
cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_satwnd_amv_goes.py .
#cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_ztd.py .
#cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda.json .
#cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_gsrcsr.json .
#cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/bufr2ioda_gsrcsr.py .
#cp "${USHdir}"/run_bufr2ioda_gsrcsr.sh .

# generate a JSON w CDATE from the template and convert to IODA
cp "${RDASAPP_DIR}"/rrfs-test/IODA/python/gen_bufr2ioda_json.py .

# ADPUPA (surface pressure)
cp -p ${FIX_JEDI}/ioda_empty.nc ioda_adpupa.nc
./gen_bufr2ioda_json.py -t bufr2ioda_adpupa_prepbufr.json -o bufr2ioda_adpupa_prepbufr_0.json
./bufr2ioda_adpupa_prepbufr.py -c bufr2ioda_adpupa_prepbufr_0.json >> $pgmout

# SATWND
./gen_bufr2ioda_json.py -t bufr2ioda_satwnd_amv_goes.json -o bufr2ioda_satwnd_amv_goes_0.json
./bufr2ioda_satwnd_amv_goes.py -c bufr2ioda_satwnd_amv_goes_0.json >> $pgmout
#
#-----------------------------------------------------------------------
#
# Run the IODA offline tools
#
#-----------------------------------------------------------------------
#
cp "${RDASAPP_DIR}"/rrfs-test/IODA/offline_domain_check.py .
cp "${RDASAPP_DIR}"/rrfs-test/IODA/offline_domain_check_satrad.py .
cp "${RDASAPP_DIR}"/rrfs-test/IODA/offline_ioda_patch.py .
cp "${RDASAPP_DIR}"/rrfs-test/IODA/offline_vad_thinning.py .

# offline domain check & patch
for ioda_file in ioda*nc; do
  grid_file="${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec"
  if [[ "${ioda_file}" == *abi* ]]; then
    echo " ${ioda_file} ioda file detected: running offline_domain_check_satrad.py"
    ./offline_domain_check_satrad.py -o "${ioda_file}" -g "${grid_file}" -f -s 0.005 >> $pgmout
    base_name=$(basename "$ioda_file" .nc)
    mv  "${base_name}_dc.nc" "${base_name}.nc"
  elif [[ "${ioda_file}" == *atms* || "${ioda_file}" == *cris* ]]; then
    echo " ${ioda_file} ioda file detected: temporarily skipping offline domain check"
  else
    ./offline_domain_check.py -o "${ioda_file}" -g "${grid_file}" -s 0.005
    base_name=$(basename "$ioda_file" .nc)
    mv  "${base_name}_dc.nc" "${base_name}.nc"
    ./offline_ioda_patch.py -o "${ioda_file}" >> $pgmout
    base_name=$(basename "$ioda_file" .nc)
    mv  "${base_name}_llp.nc" "${base_name}.nc"
  fi
done

# vadwnd thinning & superobbing
./offline_vad_thinning.py -i ioda_vadwnd.nc -o ioda_vadwnd_thinned.nc >> $pgmout
mv ioda_vadwnd_thinned.nc ioda_vadwnd.nc
#
#-----------------------------------------------------------------------
#
# Move ioda files to COMOUT
#
#-----------------------------------------------------------------------
#
cp ioda_*.nc $COMOUT/.
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
PREPBUFR PROCESS completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

