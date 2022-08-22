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

This is the ex-script for the task that conduct JEDI EnVar IODA tasks
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
valid_args=( \
"cycle_dir" \
"cycle_type" \
"mem_type" \
"workdir" \
"slash_ensmem_subdir" \
"comout" \
)
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
# Load modules.
#
#-----------------------------------------------------------------------
#
case $MACHINE in
#
"WCOSS_C" | "WCOSS")
#
  . /apps/lmod/lmod/init/sh
  module purge
  module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/soft/modulefiles
  module load intel/16.1.150 impi/5.1.1.109 netcdf/4.3.0 
  module list
  
  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np 1"
  ;;
#
"WCOSS_DELL_P3")
  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np ${IO_LAYOUT_Y}"
  ;;
#
"HERA")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun"
  ;;
#
"JET")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun"
  ;;
#
"ORION")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun"
  ;;
#
"ODIN")
#
  module list

  ulimit -s unlimited
  ulimit -a
  APRUN="srun -n 1"
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
set -x

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
# Get into working directory and define fix directory
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Getting into working directory for JEDI EnVAR IODA ..."

cd_vrfy ${workdir}

fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"

#
#-----------------------------------------------------------------------
#
# Prepare files and folders
#
#-----------------------------------------------------------------------
# 
# Create folders for the working path
mkdir -p GSI_diags
mkdir -p obs
mkdir -p geoval

# Define either "spinup" or "prod" cycle
if [ ${cycle_type} == "spinup" ]; then
  cycle_tag="_spinup"
else
  cycle_tag=""
fi

# 
echo "comout="$comout

# Create folders under COMOUT
mkdir -p ${comout}/jedienvar_ioda
mkdir -p ${comout}/jedienvar_ioda/anal_gsi
mkdir -p ${comout}/jedienvar_ioda/jedi_obs

# Specify the path of the GSI Analysis working folder
gsidiag_path=${cycle_dir}${slash_ensmem_subdir}/anal_conv_gsi${cycle_tag}

# Copy GSI ncdiag files to COMOUT 
cp_vrfy ${gsidiag_path}/ncdiag* ${comout}/jedienvar_ioda/anal_gsi/

# Copy only ncdiag first guess files to the workfing folder
cp_vrfy ${comout}/jedienvar_ioda/anal_gsi/*ges* ${workdir}/GSI_diags

#
#-----------------------------------------------------------------------
#
# Change the ncdiag file name from *.nc4.$DATE to *.$DATE_ensmean.nc4
#
#-----------------------------------------------------------------------
# 
cd_vrfy ${workdir}/GSI_diags
gzip -d *.gz
fl=`ls -1 ncdiag*`

for ifl in $fl
do
  leftpart01=`basename $ifl .$CDATE`
  leftpart02=`basename $leftpart01 .nc`
  flnm=${leftpart02}.${CDATE}_ensmean.nc4
  echo $flnm
  mv $ifl $flnm
done
#
#-----------------------------------------------------------------------
#
# Execute the IODA python script
#
#-----------------------------------------------------------------------
#  
cd ${workdir}

module list
ulimit -v unlimited
which python

# Specify the IODA python script
IODACDir=/scratch1/BMC/zrtrr/llin/220601_jedi/ioda-bundle_20220530/ioda-bundle/build/bin

# PYIODA library
export PYTHONPATH=/scratch1/BMC/zrtrr/llin/220501_emc_reg_wflow/dr-jedi-ioda/ioda-bundle/build/lib/python3.7/pyioda

# Running the python script
PYTHONEXE=/scratch1/NCEPDEV/da/python/hpc-stack/miniconda3/core/miniconda3/4.6.14/envs/iodaconv/bin/python
${PYTHONEXE} ${IODACDir}/proc_gsi_ncdiag.py -o $workdir/obs -g $workdir/geoval $workdir/GSI_diags || print_err_msg_exit "\
#Call to executable to run No Var Cloud Analysis returned with nonzero exit code."

# Copy IODA obs files to COMOUT
cp_vrfy ${workdir}/obs/*nc4 ${comout}/jedienvar_ioda/jedi_obs/

#
#-----------------------------------------------------------------------
#
# touch jedienvar_ioda_complete.txt to indicate competion of this task
# 
#-----------------------------------------------------------------------
#
touch jedienvar_ioda_complete.txt
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
JEDI EnVAR IODA completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

