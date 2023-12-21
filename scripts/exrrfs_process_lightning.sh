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

This is the ex-script for the task that runs lightning preprocess
with FV3 for the specified cycle.
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
fixdir=$FIX_GSI
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}

print_info_msg "$VERBOSE" "fixdir is $fixdir"
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"
#
#-----------------------------------------------------------------------
#
# link or copy background and grid files
#
#-----------------------------------------------------------------------
#
cp ${fixgriddir}/fv3_grid_spec  fv3sar_grid_spec.nc
#
#-----------------------------------------------------------------------
#
# Link to the NLDN data
#
#-----------------------------------------------------------------------
#
run_lightning=false
filenum=0
LIGHTNING_FILE=${LIGHTNING_ROOT}/vaisala/netcdf
for n in 00 05 ; do
  filename=${LIGHTNING_FILE}/${YYJJJHH}${n}0005r
  if [ -r ${filename} ]; then
  ((filenum += 1 ))
    ln -sf ${filename} ./NLDN_lightning_${filenum}
  else
   echo " ${filename} does not exist"
  fi
done
for n in 55 50 45 40 35 ; do
  filename=${LIGHTNING_FILE}/${PREYYJJJHH}${n}0005r
  if [ -r ${filename} ]; then
  ((filenum += 1 ))
    ln -sf ${filename} ./NLDN_lightning_${filenum}
    run_lightning=true
  else
   echo " ${filename} does not exist"
  fi
done

echo "found GLD360 files: ${filenum}"
#
#-----------------------------------------------------------------------
#
# copy bufr table from fix directory
#
#-----------------------------------------------------------------------
#
BUFR_TABLE=${fixdir}/prepobs_prep_RAP.bufrtable

cp $BUFR_TABLE prepobs_prep.bufrtable
#
#-----------------------------------------------------------------------
#
# Build namelist and run executable
#
#   analysis_time : process obs used for this analysis date (YYYYMMDDHH)
#   NLDN_filenum  : number of NLDN lighting observation files 
#   IfAlaska      : logic to decide if to process Alaska lightning obs
#   bkversion     : grid type (background will be used in the analysis)
#                   = 0 for ARW  (default)
#                   = 1 for FV3LAM
#-----------------------------------------------------------------------
#
cat << EOF > namelist.lightning
 &setup
  analysis_time = ${YYYYMMDDHH},
  NLDN_filenum  = ${filenum},
  grid_type = "${PREDEF_GRID_NAME}",
  obs_type = "nldn_nc"
 /

EOF
#
#-----------------------------------------------------------------------
#
# Run the lightning (nc) process
#
#-----------------------------------------------------------------------
#
export pgm="process_Lightning.exe"
. prep_step

if [[ "$run_lightning" == true ]]; then
  $APRUN ${EXECdir}/$pgm < namelist.lightning >>$pgmout 2>errfile
  export err=$?; err_chk

  cp LightningInFV3LAM.dat ${COMOUT}/rrfs.t${HH}z.LightningInFV3LAM_NLDN.bin
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
LIGHTNING PROCESS completed successfully!!!

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

