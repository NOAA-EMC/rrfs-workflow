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

This is the ex-script for the task that runs the post-processor (UPP) on
the output files corresponding to a specified forecast hour.
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
"cdate" \
"run_dir" \
"nwges_dir" \
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
# Get the cycle date and hour (in formats of yyyymmdd and hh, respectively)
# from cdate.
#
#-----------------------------------------------------------------------
#
yyyymmdd=${cdate:0:8}
hh=${cdate:8:2}
cyc=$hh
# 
#-----------------------------------------------------------------------
#
# Let's save the DA analysis files if needed before run fcst.
# This will copy the data assimilation analysis files from $run_dir/INPUT/
# to ${nwges_dir}/DA_OUTPUT/, 
# this is to prepare for ensemble free forecast after the ensemble data assimilation
#
#-----------------------------------------------------------------------
#
filelist="fv_core.res.nc coupler.res"
filelistn="fv_core.res.tile1.nc fv_srf_wnd.res.tile1.nc fv_tracer.res.tile1.nc phy_data.nc sfc_data.nc"
filelistcold="gfs_data.tile7.halo0.nc sfc_data.tile7.halo0.nc"
n_iolayouty=$(($IO_LAYOUT_Y-1))
list_iolayout=$(seq 0 $n_iolayouty)

if [ ! -r ${nwges_dir}/DA_OUTPUT/gfs_ctrl.nc ]; then
  cp $run_dir/INPUT/gfs_ctrl.nc ${nwges_dir}/DA_OUTPUT/gfs_ctrl.nc
fi
if [ -r ${run_dir}/INPUT/coupler.res ]; then  # warm start
    if [ "${IO_LAYOUT_Y}" = "1" ]; then
      for file in ${filelistn}; do
        cp $run_dir/INPUT/${file} ${nwges_dir}/DA_OUTPUT/${file}
      done
    else
      for file in ${filelistn}; do
        for ii in ${list_iolayout}
        do
          iii=$(printf %4.4i $ii)
         cp $run_dir/INPUT/${file}.${iii} ${nwges_dir}/DA_OUTPUT/${file}.${iii}
        done
      done
    fi
    for file in ${filelist}; do
      cp $run_dir/INPUT/${file} ${nwges_dir}/DA_OUTPUT/${file}
    done
else  # cold start
    print_info_msg "$VERBOSE" "\
The DA analysis does not exist, no files to save to DA_OUTPUT."
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
save DA analysis completed successfully.

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

