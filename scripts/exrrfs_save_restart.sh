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

This is the ex-script for the task that saves restart files to nwges.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Get the cycle date and hour (in formats of yyyymmdd and hh, respectively)
# from CDATE.
#
#-----------------------------------------------------------------------
#
yyyymmdd=${CDATE:0:8}
hh=${CDATE:8:2}
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
run_blending=${GESROOT}/${RUN}.${PDY}/${cyc}/${mem_num}/run_blending
run_ensinit=${GESROOT}/${RUN}.${PDY}/${cyc}/${mem_num}/run_ensinit
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

if [ ! -r ${NWGES_DIR}/INPUT/gfs_ctrl.nc ]; then
  cp $DATA/INPUT/gfs_ctrl.nc ${NWGES_DIR}/INPUT/gfs_ctrl.nc
  if_save_input=TRUE
fi

if [ -r "$DATA/RESTART/${restart_prefix}.coupler.res" ]; then
  if [ "${IO_LAYOUT_Y}" = "1" ]; then
    for file in ${filelistn}; do
      mv $DATA/RESTART/${restart_prefix}.${file} ${NWGES_DIR}/RESTART/${restart_prefix}.${file}
    done
  else
    for file in ${filelistn}; do
      for ii in ${list_iolayout}
      do
        iii=$(printf %4.4i $ii)
        mv $DATA/RESTART/${restart_prefix}.${file}.${iii} ${NWGES_DIR}/RESTART/${restart_prefix}.${file}.${iii}
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
  ncap2 -O -v -s 'flash_extent_density=ref_f3d' ${NWGES_DIR}/RESTART/${restart_prefix}.phy_data.nc ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc
  python -u ${SCRIPTSdir}/exrrfs_process_lightning.py
  ncks -A -C -v flash_extent_density ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc ${NWGES_DIR}/RESTART/${restart_prefix}.phy_data.nc
  rm ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc
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

  ncap2 -O -v -s 'flash_extent_density=ref_f3d' ${NWGES_DIR}/RESTART/${restart_prefix}.phy_data.nc ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc
  python -u ${SCRIPTSdir}/exrrfs_process_lightning.py
  ncks -A -C -v flash_extent_density ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc ${NWGES_DIR}/RESTART/${restart_prefix}.phy_data.nc
  rm ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc
fi
#
#-----------------------------------------------------------------------
#
# Back to our regularly scheduled programming 
#
#-----------------------------------------------------------------------
#
  for file in ${filelist}; do
    mv $DATA/RESTART/${restart_prefix}.${file} ${NWGES_DIR}/RESTART/${restart_prefix}.${file}
  done
  echo " ${fhr} forecast from ${yyyymmdd}${hh} is ready " #> ${NWGES_DIR}/RESTART/restart_done_f${fhr}
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

  if [ -r "$DATA/RESTART/${restart_prefix}.coupler.res" ] && ([ ${fhr} -eq ${FCST_LEN_HRS_thiscycle} ] || [ "${CYCLE_SUBTYPE}" = "ensinit" ]); then
    if [ "${IO_LAYOUT_Y}" = "1" ]; then
      for file in ${filelistn}; do
        mv $DATA/RESTART/${file} ${NWGES_DIR}/RESTART/${restart_prefix}.${file}
      done
    else
      for file in ${filelistn}; do
        for ii in ${list_iolayout}
        do
          iii=$(printf %4.4i $ii)
          mv $DATA/RESTART/${file}.${iii} ${NWGES_DIR}/RESTART/${restart_prefix}.${file}.${iii}
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
  ncap2 -O -v -s 'flash_extent_density=ref_f3d' ${NWGES_DIR}/RESTART/${restart_prefix}.phy_data.nc ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc
  time_1=`date +%s`
  python -u ${SCRIPTSdir}/exrrfs_process_lightning.py
  time_2=`date +%s`
  ncks -A -C -v flash_extent_density ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc ${NWGES_DIR}/RESTART/${restart_prefix}.phy_data.nc
  time_3=`date +%s`
  rm ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc
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
  ncap2 -O -v -s 'flash_extent_density=ref_f3d' ${NWGES_DIR}/RESTART/${restart_prefix}.phy_data.nc ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc
  time_1=`date +%s`
  python -u ${SCRIPTSdir}/exrrfs_process_lightning.py
  time_2=`date +%s`
  ncks -A -C -v flash_extent_density ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc ${NWGES_DIR}/RESTART/${restart_prefix}.phy_data.nc
  time_3=`date +%s`
  rm ${NWGES_DIR}/RESTART/${restart_prefix}.tmp.nc
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
       mv $DATA/RESTART/${file} ${NWGES_DIR}/RESTART/${restart_prefix}.${file}
    done
    echo " ${fhr} forecast from ${yyyymmdd}${hh} is ready " #> ${NWGES_DIR}/RESTART/restart_done_f${fhr}
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
    cp ${NWGES_DIR}/RESTART/${restart_prefix}.sfc_data.nc ${SURFACE_DIR}/${restart_prefix}.sfc_data.nc.${CDATE}
  else
    for ii in ${list_iolayout}
    do
      iii=$(printf %4.4i $ii)
      cp ${NWGES_DIR}/RESTART/${restart_prefix}.sfc_data.nc.${iii} ${SURFACE_DIR}/${restart_prefix}.sfc_data.nc.${CDATE}.${iii}
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
    if [ -r ${DATA}/INPUT/coupler.res ]; then  # warm start
      if [ "${IO_LAYOUT_Y}" = "1" ]; then
        for file in ${filelistn}; do
          cp $DATA/INPUT/${file} ${NWGES_DIR}/INPUT/${file}
        done
      else
        for file in ${filelistn}; do
          for ii in ${list_iolayout}
          do
            iii=$(printf %4.4i $ii)
           cp $DATA/INPUT/${file}.${iii} ${NWGES_DIR}/INPUT/${file}.${iii}
          done
        done
      fi
      for file in ${filelist}; do
        cp $DATA/INPUT/${file} ${NWGES_DIR}/INPUT/${file}
      done
    else  # cold start
      for file in ${filelistcold}; do
        cp $DATA/INPUT/${file} ${NWGES_DIR}/INPUT/${file}
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

