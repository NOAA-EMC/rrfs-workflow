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
#cdate_crnt_fhr=$( date --utc --date "${yyyymmdd} ${hh} UTC" "+%Y%m%d%H" )
#
#-----------------------------------------------------------------------
#
# Determine early exit for running blending vs 1 time step ensinit.
#
#-----------------------------------------------------------------------
#
run_blending=${NWGES_BASEDIR}/${cdate}/run_blending
run_ensinit=${NWGES_BASEDIR}/${cdate}/run_ensinit
if [[ ${CYCLE_SUBTYPE} == "ensinit" && -e $run_blending ]]; then
   echo "clean exit ensinit, blending used instead of ensinit."
   exit 0
fi
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

if [ "${CYCLE_SUBTYPE}" = "ensinit" ]; then
  restart_prefix=$( date "+%Y%m%d.%H%M%S" -d "${save_yyyy}${save_mm}${save_dd} ${save_hh} + ${DT_ATMOS} seconds" )
else
  restart_prefix=${save_yyyy}${save_mm}${save_dd}.${save_hh}0000
fi

if_save_input=FALSE

if [ ! -r ${nwges_dir}/INPUT/gfs_ctrl.nc ]; then
  cp $run_dir/INPUT/gfs_ctrl.nc ${nwges_dir}/INPUT/gfs_ctrl.nc
  if_save_input=TRUE
fi

if [ -r "$run_dir/RESTART/${restart_prefix}.coupler.res" ]; then
  if [ "${IO_LAYOUT_Y}" = "1" ]; then
    for file in ${filelistn}; do
      mv $run_dir/RESTART/${restart_prefix}.${file} ${nwges_dir}/RESTART/${restart_prefix}.${file}
    done
  else
    for file in ${filelistn}; do
      for ii in ${list_iolayout}
      do
        iii=$(printf %4.4i $ii)
        mv $run_dir/RESTART/${restart_prefix}.${file}.${iii} ${nwges_dir}/RESTART/${restart_prefix}.${file}.${iii}
      done
    done
  fi
#
#-----------------------------------------------------------------------
#
# If EnVar needs flash extent density field in control member, add it 
#
#-----------------------------------------------------------------------
#
if [[ ${DO_GLM_FED_DA} = TRUE && ${DO_ENSEMBLE} != TRUE ]]; then
  export restart_prefix=${restart_prefix} 
  export PREP_MODEL=2
  ncap2 -O -v -s 'flash_extent_density=ref_f3d' ${nwges_dir}/RESTART/${restart_prefix}.phy_data.nc ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc
  python -u ${SCRIPTSdir}/exrrfs_process_glmfed.py
  ncks -A -C -v flash_extent_density ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc ${nwges_dir}/RESTART/${restart_prefix}.phy_data.nc
  rm ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc
fi
#
#-----------------------------------------------------------------------
#
# If EnVar will need flash extent density field in ensembles, add it 
#
#-----------------------------------------------------------------------
#
if [[ ${DO_ENSEMBLE} = TRUE && ${fhr} -eq 1 && ${PREP_MODEL_FOR_FED} = TRUE ]]; then
  export restart_prefix=${restart_prefix}  
  export PREP_MODEL=2

  ncap2 -O -v -s 'flash_extent_density=ref_f3d' ${nwges_dir}/RESTART/${restart_prefix}.phy_data.nc ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc
  python -u ${SCRIPTSdir}/exrrfs_process_glmfed.py
  ncks -A -C -v flash_extent_density ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc ${nwges_dir}/RESTART/${restart_prefix}.phy_data.nc
  rm ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc
fi
#
#-----------------------------------------------------------------------
#
# Back to our regularly scheduled programming 
#
#-----------------------------------------------------------------------
#
  for file in ${filelist}; do
    mv $run_dir/RESTART/${restart_prefix}.${file} ${nwges_dir}/RESTART/${restart_prefix}.${file}
  done
  echo " ${fhr} forecast from ${yyyymmdd}${hh} is ready " #> ${nwges_dir}/RESTART/restart_done_f${fhr}
else

  FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS}
  if [ "${CYCLE_TYPE}" = "spinup" ]; then
    FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_SPINUP}
  else
    num_fhrs=( "${#FCST_LEN_HRS_CYCLES[@]}" )
    ihh=`expr ${hh} + 0`
    if [ ${num_fhrs} -gt ${ihh} ]; then
       FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_CYCLES[${ihh}]}
    fi
  fi
  print_info_msg "The forecast length for cycle (\"${hh}\") is (\"${FCST_LEN_HRS_thiscycle}\")."

  if [ -r "$run_dir/RESTART/${restart_prefix}.coupler.res" ] && ([ ${fhr} -eq ${FCST_LEN_HRS_thiscycle} ] || [ "${CYCLE_SUBTYPE}" = "ensinit" ]); then
    if [ "${IO_LAYOUT_Y}" = "1" ]; then
      for file in ${filelistn}; do
        mv $run_dir/RESTART/${file} ${nwges_dir}/RESTART/${restart_prefix}.${file}
      done
    else
      for file in ${filelistn}; do
        for ii in ${list_iolayout}
        do
          iii=$(printf %4.4i $ii)
          mv $run_dir/RESTART/${file}.${iii} ${nwges_dir}/RESTART/${restart_prefix}.${file}.${iii}
        done
      done
    fi
#
#-----------------------------------------------------------------------
#
# If EnVar needs flash extent density field in control member, add it 
#
#-----------------------------------------------------------------------
#
if [[ ${DO_GLM_FED_DA} = TRUE && ${DO_ENSEMBLE} != TRUE ]]; then
  export restart_prefix=${restart_prefix} 
  export PREP_MODEL=2
  time_0=`date +%s`
  ncap2 -O -v -s 'flash_extent_density=ref_f3d' ${nwges_dir}/RESTART/${restart_prefix}.phy_data.nc ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc
  time_1=`date +%s`
  python -u ${SCRIPTSdir}/exrrfs_process_glmfed.py
  time_2=`date +%s`
  ncks -A -C -v flash_extent_density ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc ${nwges_dir}/RESTART/${restart_prefix}.phy_data.nc
  time_3=`date +%s`
  rm ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc
  time_4=`date +%s`
  echo ncaps2 execution time was `expr $time_1 - $time_0` s.
  echo python execution time was `expr $time_2 - $time_1` s.
  echo ncks execution time was `expr $time_3 - $time_2` s.
  echo rm execution time was `expr $time_4 - $time_3` s.
fi
#
#-----------------------------------------------------------------------
#
# If EnVar will need flash extent density field in ensembles, add it 
#
#-----------------------------------------------------------------------
#
if [[ ${DO_ENSEMBLE} = TRUE && ${fhr} -eq 1 && ${PREP_MODEL_FOR_FED} = TRUE ]]; then
  export restart_prefix=${restart_prefix}  
  export PREP_MODEL=2

  time_0=`date +%s`
  ncap2 -O -v -s 'flash_extent_density=ref_f3d' ${nwges_dir}/RESTART/${restart_prefix}.phy_data.nc ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc
  time_1=`date +%s`
  python -u ${SCRIPTSdir}/exrrfs_process_glmfed.py
  time_2=`date +%s`
  ncks -A -C -v flash_extent_density ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc ${nwges_dir}/RESTART/${restart_prefix}.phy_data.nc
  time_3=`date +%s`
  rm ${nwges_dir}/RESTART/${restart_prefix}.tmp.nc
  time_4=`date +%s`
  echo ncaps2 execution time was `expr $time_1 - $time_0` s.
  echo python execution time was `expr $time_2 - $time_1` s.
  echo ncks execution time was `expr $time_3 - $time_2` s.
  echo rm execution time was `expr $time_4 - $time_3` s.
fi
#
#-----------------------------------------------------------------------
#
# Back to our regularly scheduled programming 
#
#-----------------------------------------------------------------------
#
    for file in ${filelist}; do
       mv $run_dir/RESTART/${file} ${nwges_dir}/RESTART/${restart_prefix}.${file}
    done
    echo " ${fhr} forecast from ${yyyymmdd}${hh} is ready " #> ${nwges_dir}/RESTART/restart_done_f${fhr}
  else
    echo "This forecast hour does not need to save restart: ${yyyymmdd}${hh}f${fhr}"
  fi
fi
#
#-----------------------------------------------------------------------
# save surface data
#-----------------------------------------------------------------------
#
if [ "${CYCLE_TYPE}" = "prod" ] && [ "${CYCLE_SUBTYPE}" = "control" ]; then
  if [ "${IO_LAYOUT_Y}" = "1" ]; then
    cp ${nwges_dir}/RESTART/${restart_prefix}.sfc_data.nc ${SURFACE_DIR}/${restart_prefix}.sfc_data.nc.${cdate}
  else
    for ii in ${list_iolayout}
    do
      iii=$(printf %4.4i $ii)
      cp ${nwges_dir}/RESTART/${restart_prefix}.sfc_data.nc.${iii} ${SURFACE_DIR}/${restart_prefix}.sfc_data.nc.${cdate}.${iii}
    done
  fi
fi
#
#-----------------------------------------------------------------------
# save input
#-----------------------------------------------------------------------
#
if [ "${if_save_input}" = TRUE ]; then
  if [ "${DO_SAVE_INPUT}" = TRUE ]; then
    if [ -r ${run_dir}/INPUT/coupler.res ]; then  # warm start
      if [ "${IO_LAYOUT_Y}" = "1" ]; then
        for file in ${filelistn}; do
          cp $run_dir/INPUT/${file} ${nwges_dir}/INPUT/${file}
        done
      else
        for file in ${filelistn}; do
          for ii in ${list_iolayout}
          do
            iii=$(printf %4.4i $ii)
           cp $run_dir/INPUT/${file}.${iii} ${nwges_dir}/INPUT/${file}.${iii}
          done
        done
      fi
      for file in ${filelist}; do
        cp $run_dir/INPUT/${file} ${nwges_dir}/INPUT/${file}
      done
    else  # cold start
      for file in ${filelistcold}; do
        cp $run_dir/INPUT/${file} ${nwges_dir}/INPUT/${file}
      done
    fi
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

