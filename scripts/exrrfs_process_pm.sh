#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh
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

This is the ex-script for the task that runs PM (cloud, metar, lightning, 
pm) preprocess for the specified cycle.
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
valid_args=( "CYCLE_DIR" )
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
"HERCULES")
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
# Define fix directory
#
#-----------------------------------------------------------------------
#
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"
#
#-----------------------------------------------------------------------
#
# copy bufr table
#
#-----------------------------------------------------------------------
#
BUFR_TABLE=${FIX_GSI}/pm.bufrtable
cp $BUFR_TABLE .
#
#-----------------------------------------------------------------------
#
# check PM CSV files from current cycle to previous 3 hours, 
# if one file found, get Station ID, Latitude, Longitude, Elevation, 
# PM25_AQI, PM25_Measured, PM25, PM25_Unit, PM10,PM10_Unit
#
#-----------------------------------------------------------------------
#
run_pm=false
AQObs=HourlyAQObs
obs_file=${AQObs}.dat
pm_dat=pm.dat
pm_bufr=pm.bufr

n=0
checkfile=${OBSPATH_PM}/${AQObs}_${YYYYMMDD}${HH}.dat
while [[ $n -le 2 ]] ; do
  if [ -r "${checkfile}" ] ; then
    print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as observation "
    break
  else
    n=$((n + 1))
    YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${n} hours ago" )
    checkfile=${OBSPATH_PM}/${AQObs}_${YYYYMMDDHHmInterv}.dat
    print_info_msg "$VERBOSE" "Trying this file: ${checkfile}"
  fi
done

pm_cnt=0
if [ -r "${checkfile}" ]; then
   cp ${checkfile} ${obs_file}
   grep 'UG/M3' ${obs_file} | awk '-F",' '{ printf "%-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %s\n", $1, $5, $6,$7,$17,$21,$27,$28,$33,$34}' > ${pm_dat}
   pm_cnt=`wc  -l < ${pm_dat}`
   run_pm=true
else
   print_info_msg "$VERBOSE" "Warning: ${obs_file} does not exist!"
fi
#
#-----------------------------------------------------------------------
#
# Build namelist and run executable for pm
#
#   analysis_time : process obs used for this analysis date (YYYYMMDDHH)
#   infile      : PM ASCII  file name
#   outfile     : PM BUFR file name
#   cnt         : count of PM observation
#
#-----------------------------------------------------------------------
#
cat << EOF > namelist.pm
 &setup
  analysis_time = "${YYYYMMDDHH}",
  infile="${pm_dat}",
  outfile="${pm_bufr}",
  cnt=${pm_cnt},
 /
EOF
#
#-----------------------------------------------------------------------
#
# Run the process for NASA LaRc cloud  bufr file 
#
#-----------------------------------------------------------------------
#
export pgm="process_pm.exe"
. prep_step

if [[ "$run_pm" == true ]]; then
  $APRUN ${EXECdir}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
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
PM PROCESS completed successfully!!!

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

