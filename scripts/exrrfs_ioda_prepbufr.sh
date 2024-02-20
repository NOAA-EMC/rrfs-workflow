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

This is the ex-script for the task that runs ioda converter (prepbufr) 
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
# copy template yaml files
#
#-----------------------------------------------------------------------
#
cp ${PARM_IODACONV}/*.yaml .
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
# Modify yaml template and run the process
# for converting prepbufr file 
#
#-----------------------------------------------------------------------
#
formatted_time=$(date -d"${YYYYMMDDHH:0:8} ${YYYYMMDDHH:8:2}" '+%Y-%m-%dT%H:%M:%SZ')

for yamlfile in *.yaml; do
  message_type=$(echo "$yamlfile" | cut -d'_' -f4 | sed 's/\..*//')

  if grep -q "referenceTime" ${yamlfile}; then
    sed -i "s/referenceTime:.*/referenceTime: ${formatted_time}/" ${yamlfile}
  fi

  if [[ ${run_process_prepbufr} ]]; then
    $APRUN ${EXECdir}/$pgm ${yamlfile} >> $pgmout 2>errfile
    export err=$?; err_chk
    mv errfile errfile_${message_type}
  fi
done
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

