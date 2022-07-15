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
"fhr" \
"cycle_type" \
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

save_time=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${fhr} hours" "+%Y%m%d%H" )
save_yyyy=${save_time:0:4}
save_mm=${save_time:4:2}
save_dd=${save_time:6:2}
save_hh=${save_time:8:2}


# 
#-----------------------------------------------------------------------
#
# Let save the restart files if needed before run post.
# This part will copy or move restart files matching the forecast hour
# this post will process to the nwges directory. The nwges is used to 
# stage the restart files for a long time. 
#-----------------------------------------------------------------------
#
filelist="fv_core.res.nc coupler.res"
filelistn="fv_core.res.tile1.nc fv_srf_wnd.res.tile1.nc fv_tracer.res.tile1.nc phy_data.nc sfc_data.nc"
filelistcold="gfs_data.tile7.halo0.nc sfc_data.tile7.halo0.nc"
n_iolayouty=$(($IO_LAYOUT_Y-1))
list_iolayout=$(seq 0 $n_iolayouty)

restart_prefix=${save_yyyy}${save_mm}${save_dd}.${save_hh}0000
if [ ! -r ${nwges_dir}/INPUT/gfs_ctrl.nc ]; then
  cp_vrfy $run_dir/INPUT/gfs_ctrl.nc ${nwges_dir}/INPUT/gfs_ctrl.nc
  if [ -r ${run_dir}/INPUT/coupler.res ]; then  # warm start
    if [ "${IO_LAYOUT_Y}" == "1" ]; then
      for file in ${filelistn}; do
        cp_vrfy $run_dir/INPUT/${file} ${nwges_dir}/INPUT/${file}
      done
    else
      for file in ${filelistn}; do
        for ii in ${list_iolayout}
        do
          iii=$(printf %4.4i $ii)
         cp_vrfy $run_dir/INPUT/${file}.${iii} ${nwges_dir}/INPUT/${file}.${iii}
        done
      done
    fi
    for file in ${filelist}; do
      cp_vrfy $run_dir/INPUT/${file} ${nwges_dir}/INPUT/${file}
    done
  else  # cold start
    for file in ${filelistcold}; do
      cp_vrfy $run_dir/INPUT/${file} ${nwges_dir}/INPUT/${file}
    done
  fi
fi
if [ -r "$run_dir/RESTART/${restart_prefix}.coupler.res" ]; then
  if [ "${IO_LAYOUT_Y}" == "1" ]; then
    for file in ${filelistn}; do
      mv_vrfy $run_dir/RESTART/${restart_prefix}.${file} ${nwges_dir}/RESTART/${restart_prefix}.${file}
    done
  else
    for file in ${filelistn}; do
      for ii in ${list_iolayout}
      do
        iii=$(printf %4.4i $ii)
        mv_vrfy $run_dir/RESTART/${restart_prefix}.${file}.${iii} ${nwges_dir}/RESTART/${restart_prefix}.${file}.${iii}
      done
    done
  fi
  for file in ${filelist}; do
    mv_vrfy $run_dir/RESTART/${restart_prefix}.${file} ${nwges_dir}/RESTART/${restart_prefix}.${file}
  done
  echo " ${fhr} forecast from ${yyyymmdd}${hh} is ready " #> ${nwges_dir}/RESTART/restart_done_f${fhr}
else

  FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS}
  if [ ${cycle_type} == "spinup" ]; then
    FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_SPINUP}
  else
    num_fhrs=( "${#FCST_LEN_HRS_CYCLES[@]}" )
    ihh=`expr ${hh} + 0`
    if [ ${num_fhrs} -gt ${ihh} ]; then
       FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_CYCLES[${ihh}]}
    fi
  fi
  print_info_msg "$VERBOSE" " The forecast length for cycle (\"${hh}\") is
                 ( \"${FCST_LEN_HRS_thiscycle}\") "

  if [ -r "$run_dir/RESTART/coupler.res" ] && [ ${fhr} -eq ${FCST_LEN_HRS_thiscycle} ] ; then
    if [ "${IO_LAYOUT_Y}" == "1" ]; then
      for file in ${filelistn}; do
        mv_vrfy $run_dir/RESTART/${file} ${nwges_dir}/RESTART/${restart_prefix}.${file}
      done
    else
      for file in ${filelistn}; do
        for ii in ${list_iolayout}
        do
          iii=$(printf %4.4i $ii)
          mv_vrfy $run_dir/RESTART/${file}.${iii} ${nwges_dir}/RESTART/${restart_prefix}.${file}.${iii}
        done
      done
    fi
    for file in ${filelist}; do
       mv_vrfy $run_dir/RESTART/${file} ${nwges_dir}/RESTART/${restart_prefix}.${file}
    done
    echo " ${fhr} forecast from ${yyyymmdd}${hh} is ready " #> ${nwges_dir}/RESTART/restart_done_f${fhr}
  else
    echo "This forecast hour does not need to save restart: ${yyyymmdd}${hh}f${fhr}"
  fi
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
save restart for forecast hour $fhr completed successfully.

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

