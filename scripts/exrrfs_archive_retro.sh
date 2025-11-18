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
echo "ARCHIVE RETRO.... EXITING!!!"
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

This is the ex-script for the task that runs a analysis with FV3 for the
specified cycle.
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
valid_args=( "cycle_dir" )
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
ulimit -v unlimited
ulimit -a
export OOPS_TRACE=0
export LD_LIBRARY_PATH="${RDASAPP_DIR}/build/lib64:${LD_LIBRARY_PATH}"

case $MACHINE in
#
"WCOSS2")
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=${TPP_RUN_ARCHIVE_RETRO}
  ncores=$(( NNODES_RUN_ARCHIVE_RETRO*PPN_RUN_ARCHIVE_RETRO))
  APRUN="mpirun -n ${NNODES_RUN_ARCHIVE_RETRO} -ppn ${PPN_RUN_ARCHIVE_RETRO} --cpu-bind core --depth 1"
  APRUN=""
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
#
#-----------------------------------------------------------------------
#
# Archive data for MATS verification to HPSS.
#
#-----------------------------------------------------------------------
#
hsi "mkdir -p $ARCHIVEDIR/rrfs.${PDY}"
cd "${COMOUT_BASEDIR}/rrfs.${PDY}"
htar -cvf "${ARCHIVEDIR}/rrfs.${PDY}/${cyc}.tar" "${cyc}"
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

