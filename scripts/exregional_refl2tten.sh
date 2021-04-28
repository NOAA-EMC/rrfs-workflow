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
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
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

This is the ex-script for the task that generates radar reflectivity tten
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
valid_args=( "CYCLE_DIR" "WORKDIR")
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
Getting into working directory for radar tten process ..."

workdir=${WORKDIR}
cd_vrfy ${workdir}

fixdir=$FIX_GSI
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}

print_info_msg "$VERBOSE" "fixdir is $fixdir"
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"
pwd

#
#-----------------------------------------------------------------------
#
# link or copy background and grid configuration files
#
#-----------------------------------------------------------------------

cp_vrfy ${fixgriddir}/fv3_akbk                               fv3_akbk
cp_vrfy ${fixgriddir}/fv3_grid_spec                          fv3_grid_spec

bkpath=${CYCLE_DIR}/fcst_fv3lam/INPUT
if [ -w ${bkpath}/gfs_data.tile7.halo0.nc ]; then  # cold start uses background from INPUT
  ln_vrfy -s ${bkpath}/sfc_data.tile7.halo0.nc      fv3_sfcdata
  ln_vrfy -s ${bkpath}/gfs_data.tile7.halo0.nc      fv3_dynvars
  ln_vrfy -s ${bkpath}/gfs_data.tile7.halo0.nc      fv3_tracer
  print_info_msg "$VERBOSE" "radar2tten is not ready for cold start"
  exit 0
else                                               # cycle uses background from RESTART
  ln_vrfy -s ${bkpath}/fv_core.res.tile1.nc         fv3_dynvars
  ln_vrfy -s ${bkpath}/fv_tracer.res.tile1.nc       fv3_tracer
  ln_vrfy -s ${bkpath}/sfc_data.nc                  fv3_sfcdata
  cp_vrfy    ${bkpath}/phy_data.nc                  fv3_phydata
fi

#
#-----------------------------------------------------------------------
#
# link/copy observation files to working directory
#
#-----------------------------------------------------------------------
process_radarref_path=${CYCLE_DIR}/process_radarref
process_lightning_path=${CYCLE_DIR}/process_lightning

obs_file=${process_radarref_path}/RefInGSI3D.dat
if [ -r "${obs_file}" ]; then
   cp_vrfy "${obs_file}" "RefInGSI3D.dat_01"
else
   print_info_msg "$VERBOSE" "Warning: ${obs_file} does not exist!"
fi

obs_file=${process_lightning_path}/LightningInFV3LAM.dat
if [ -r "${obs_file}" ]; then
   cp_vrfy "${obs_file}" "LightningInGSI.dat_01"
else
   print_info_msg "$VERBOSE" "Warning: ${obs_file} does not exist!"
fi


#-----------------------------------------------------------------------
#
# Create links to BUFR table, which needed for generate the BUFR file
#
#-----------------------------------------------------------------------
bufr_table=${fixdir}/prepobs_prep_RAP.bufrtable

# Fixed fields
cp_vrfy $bufr_table prepobs_prep.bufrtable

#
#-----------------------------------------------------------------------
#
# Copy the executable to the run directory.
#
#-----------------------------------------------------------------------
#

exect="${EXECDIR}/ref2tten.exe"

if [ -f ${exect} ]; then
  print_info_msg "$VERBOSE" "
Copying the radar refl tten  executable to the run directory..."
  cp_vrfy ${exect} ${workdir}/ref2ttenfv3lam.exe
else
  print_err_msg_exit "\
The radar refl tten executable specified in exect does not exist:
  exect = \"$exect\"
Build radar refl tten and rerun."
fi
#
#
#
#-----------------------------------------------------------------------
#
# Run the radar to tten application.  
#
#-----------------------------------------------------------------------
#
$APRUN ./ref2ttenfv3lam.exe > stdout 2>&1 || print_err_msg_exit "\
Call to executable to run radar refl tten returned with nonzero exit code."

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
RADAR REFL TTEN PROCESS completed successfully!!!

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

