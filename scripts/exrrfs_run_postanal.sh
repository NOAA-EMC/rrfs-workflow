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
valid_args=( "cycle_dir" "gsi_type" "mem_type" "analworkdir" \
             "slash_ensmem_subdir" \
             "satbias_dir" "ob_type" )
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

"WCOSS2")
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=1
  ncores=$(( NNODES_RUN_POSTANAL*PPN_RUN_POSTANAL))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_RUN_POSTANAL} --cpu-bind core --depth ${OMP_NUM_THREADS}"
  ;;

"HERA")
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=300M
  APRUN="srun --export=ALL"
  ;;

"ORION")
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
  APRUN="srun --export=ALL"
  ;;

"HERCULES")
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
  APRUN="srun --export=ALL"
  ;;

"JET")
  export OMP_NUM_THREADS=2
  export OMP_STACKSIZE=1024M
  APRUN="srun --export=ALL"
  ;;

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
# Define fix and background path
#
#-----------------------------------------------------------------------
#
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
if [ "${CYCLE_TYPE}" = "spinup" ]; then
  if [ "${mem_type}" = "MEAN" ]; then
    bkpath=${cycle_dir}/ensmean/fcst_fv3lam_spinup/INPUT
  else
    bkpath=${cycle_dir}${slash_ensmem_subdir}/fcst_fv3lam_spinup/INPUT
  fi
else
  if [ "${mem_type}" = "MEAN" ]; then
    bkpath=${cycle_dir}/ensmean/fcst_fv3lam/INPUT
  else
    bkpath=${cycle_dir}${slash_ensmem_subdir}/fcst_fv3lam/INPUT
  fi
fi
# decide background type
if [ -r "${bkpath}/coupler.res" ]; then
  BKTYPE=0              # warm start
else
  BKTYPE=1              # cold start
fi
#
#-----------------------------------------------------------------------
#
# Update smoke and dust from aerosol data assimilation 
#
#-----------------------------------------------------------------------
#
if [ "${CYCLE_TYPE}" = "spinup" ]; then
  analworkname="_gsi_spinup"
else
  analworkname="_gsi"
fi

if [[ ${BKTYPE} -eq 0 ]] && [[ "${DO_PM_DA}" = "TRUE" ]]; then  # warm start
  analworkdir_aero="${cycle_dir}/anal_AERO_${analworkname}"
  # Assume the GSI analysis files are in current dir
  if [ "${IO_LAYOUT_Y}" = "1" ]; then
    ln -snf ${analworkdir_aero}/fv3_tracer  fv3_tracer_sdp
    ncrename -v smoke,smoke_ori -v dust,dust_ori  fv3_tracer
    ncks -A  -v smoke,dust        fv3_tracer_sdp  fv3_tracer
  else
    for ii in ${list_iolayout}
    do
      iii=`printf %4.4i $ii`
      ln -snf ${analworkdir_aero}/fv3_tracer.${iii} fv3_tracer_sdp.${iii}
      ncrename -v smoke,smoke_ori -v dust,dust_ori  fv3_tracer.${iii}
      ncks -A  -v smoke,dust fv3_tracer_sdp.${iii}  fv3_tracer.${iii}
    done
  fi
fi
#
#-----------------------------------------------------------------------
#
# adjust soil T/Q based on analysis increment
#
#-----------------------------------------------------------------------
#
if [[ ${BKTYPE} -eq 0 ]] && [[ ${ob_type} =~ "conv" ]] && [[ "${DO_SOIL_ADJUST}" = "TRUE" ]]; then  # warm start
  cd ${bkpath}
  if [ "${IO_LAYOUT_Y}" = "1" ]; then
    ln -snf ${fixgriddir}/fv3_grid_spec                fv3_grid_spec
  else
    for ii in ${list_iolayout}
    do
      iii=`printf %4.4i $ii`
      ln  -snf ${gridspec_dir}/fv3_grid_spec.${iii}    fv3_grid_spec.${iii}
    done
  fi

cat << EOF > namelist.soiltq
 &setup
  fv3_io_layout_y=${IO_LAYOUT_Y},
  iyear=${YYYY},
  imonth=${MM},
  iday=${DD},
  ihour=${HH},
  iminute=0,
 /
EOF

  export pgm="adjust_soiltq.exe"
  . prep_step

  $APRUN ${EXECdir}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
  mv errfile errfile_adjust_soiltq
fi
#
#-----------------------------------------------------------------------
#
# update boundary condition absed on analysis results.
# This will generate a new boundary file at 0-hour
#
#-----------------------------------------------------------------------
#
if [ ${BKTYPE} -eq 0 ] && [ "${DO_UPDATE_BC}" = "TRUE" ]; then  # warm start
  cd ${bkpath}

cat << EOF > namelist.updatebc
 &setup
  fv3_io_layout_y=${IO_LAYOUT_Y},
  bdy_update_type=1,
  grid_type_fv3_regional=2,
 /
EOF

  cp gfs_bndy.tile7.000.nc gfs_bndy.tile7.000.nc_before_update

  export pgm="update_bc.exe"
  . prep_step

  $APRUN ${EXECdir}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
  mv errfile errfile_update_bc
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
post analysis completed successfully!!!

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

