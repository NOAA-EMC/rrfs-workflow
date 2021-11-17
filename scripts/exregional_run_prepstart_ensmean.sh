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
valid_args=( "cycle_type" "modelinputdir" )
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
# go to INPUT directory.
# prepare member initial conditions for 
#     warm start if BKTYPE=0
#
#-----------------------------------------------------------------------

cd_vrfy ${modelinputdir}

#
#--------------------------------------------------------------------
#
# loop through ensemble members to link all the member files
#

imem=1
while [[ $imem -le ${NUM_ENS_MEMBERS} ]];
  do
  ensmem=$( printf "%04d" $imem ) 

#
#--------------------------------------------------------------------
#
# Setup the INPUT directory for warm start cycles, which can be spin-up cycle or product cycle.
#
# First decide the source of the first guess (fg_restart_dirname) depending on cycle_type and BKTYPE:
#  1. If cycle is spinup cycle (cycle_type == spinup) or it is the product start cycle (BKTYPE==2),
#             looking for the first guess from spinup forecast (fcst_fv3lam_spinup)
#  2. Others, looking for the first guess from product forecast (fcst_fv3lam)
#
  fg_restart_dirname=fcst_fv3lam

  bkpath=${CYCLE_DIR}/mem${ensmem}/${fg_restart_dirname}/INPUT  # cycling, use background from RESTART

#   the restart file from FV3 has a name like: ${YYYYMMDD}.${HH}0000.fv_core.res.tile1.nc
#   But the restart files for the forecast length has a name like: fv_core.res.tile1.nc
#   So the defination of restart_prefix needs a "." at the end.
#

  checkfile=${bkpath}/fv_core.res.tile1.nc
  checkfile1=${bkpath}/fv_tracer.res.tile1.nc
  if [ -r "${checkfile}" ] && [ -r "${checkfile1}" ] ; then
    ln_vrfy ${bkpath}/fv_core.res.tile1.nc       fv_core.res.tile1.nc_mem${ensmem}
    ln_vrfy ${bkpath}/fv_tracer.res.tile1.nc     fv_tracer.res.tile1.nc_mem${ensmem}
    ln_vrfy ${bkpath}/sfc_data.nc                sfc_data.nc_mem${ensmem}
    ln_vrfy ${bkpath}/fv_srf_wnd.res.tile1.nc    fv_srf_wnd.res.tile1.nc_mem${ensmem}
    ln_vrfy ${bkpath}/phy_data.nc                phy_data.nc_mem${ensmem}
    if [ $imem == 1 ]; then
      ln_vrfy ${bkpath}/coupler.res                coupler.res
      ln_vrfy ${bkpath}/fv_core.res.nc             fv_core.res.nc
      ln_vrfy ${bkpath}/gfs_ctrl.nc  gfs_ctrl.nc
    fi
  else
    print_err_msg_exit "Error: cannot find background: ${checkfile}"
  fi

#-----------------------------------------------------------------------
#
# next member
  (( imem += 1 ))

 done
#
#-----------------------------------------------------------------------
#
# get ensemble mean
#
ncea fv_core.res.tile1.nc_mem* fv_core.res.tile1.nc
ncea fv_tracer.res.tile1.nc_mem* fv_tracer.res.tile1.nc
ncea sfc_data.nc_mem* sfc_data.nc
ncea fv_srf_wnd.res.tile1.nc_mem* fv_srf_wnd.res.tile1.nc
ncea phy_data.nc_mem* phy_data.nc
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Prepare start completed successfully!!!

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

