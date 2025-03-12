#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHrrfs/source_util_funcs.sh
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

This is the ex-script for the task that runs the applications after
analysis with RRFS for the specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Configuration Parameters
#
#-----------------------------------------------------------------------
#
if [[ ! -v OB_TYPE ]]; then
  OB_TYPE="conv"
fi
export OB_TYPE=${OB_TYPE}

#
#-----------------------------------------------------------------------
#
# Set environment
#
#-----------------------------------------------------------------------
#
ulimit -a

case $MACHINE in

"WCOSS2")
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=1
  ncores=$(( NNODES_UPDATE_LBC_SOIL*PPN_UPDATE_LBC_SOIL))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_UPDATE_LBC_SOIL} --cpu-bind core --depth ${OMP_NUM_THREADS}"
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

bkpath=${FORECAST_INPUT_PRODUCT}

# decide background type
if [ -r "${bkpath}/coupler.res" ]; then
  BKTYPE=0              # warm start
else
  BKTYPE=1              # cold start
fi
#
#-----------------------------------------------------------------------
#
# adjust soil T/Q based on analysis increment
#
#-----------------------------------------------------------------------
#

if [[ ${BKTYPE} -eq 0 ]] && [[ ${OB_TYPE} =~ "conv" ]] && [[ "${DO_SOIL_ADJUST}" = "TRUE" ]]; then  # warm start
#### I do not know which netcdf files specifically are modified by adjust_soiltq, so let's copy all of them into the working directory for now
  ln -s ${bkpath}/*.nc .
  ln -snf ${fixgriddir}/fv3_grid_spec                fv3_grid_spec

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

  $APRUN ${EXECrrfs}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
  mv errfile errfile_adjust_soiltq

##### Copy modified netcdf files back to COMOUT for future jobs
####  cpreq *.nc ${bkpath}

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
  cpreq ${bkpath}/gfs_bndy.tile7.000.nc ${bkpath}/gfs_bndy.tile7.000.nc_before_update
  ln -s ${bkpath}/gfs_bndy.tile7.000.nc .

cat << EOF > namelist.updatebc
 &setup
  fv3_io_layout_y=${IO_LAYOUT_Y},
  bdy_update_type=1,
  grid_type_fv3_regional=2,
 /
EOF

  export pgm="update_bc.exe"
  . prep_step

  $APRUN ${EXECrrfs}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
  mv errfile errfile_update_bc

##### Copy modified boundary condition file back to COMOUT for future jobs
####  cpreq gfs_bndy.tile7.000.nc ${bkpath}

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
Update LBC soil completed successfully!!!

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

