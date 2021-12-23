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

function ncvarlst_noaxis_time { ncks --trd -m ${1} | grep -E ': type' | cut -f 1 -d ' ' | sed 's/://' | sort |grep -v -i -E "axis|time" ;  }
function ncvarlst_noaxis_time_new { ncks -m  ${1} | grep -E 'float' | cut -d "(" -f 1 | cut -c 10- ;  }
export  HDF5_USE_FILE_LOCKING=FALSE #clt to avoild recenter's error "NetCDF: HDF error"
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

This is the ex-script for the task that runs EnKF analysis with FV3 for the
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
valid_args=( "cycle_dir" "cycle_type" "enkfworkdir" "NWGES_DIR" )
process_args valid_args "$@"

cycle_type=${cycle_type:-prod}

case $MACHINE in
#
"WCOSS_C" | "WCOSS")
#
  module load NCO/4.7.0
  module list
  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np ${PE_MEMBER01}"
  ;;
#
"WCOSS_DELL_P3")
#
  module load NCO/4.7.0
  module list
  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np ${PE_MEMBER01}"
  ;;
#
"THEIA")
#
  ulimit -s unlimited
  ulimit -a
  np=${SLURM_NTASKS}
  APRUN="mpirun -np ${np}"
  ;;
#
"HERA")
  module load nco/4.9.3
  ulimit -s unlimited
  ulimit -v unlimited
  ulimit -a
  export OMP_NUM_THREADS=1
#  export OMP_STACKSIZE=300M
  APRUN="srun"
  ;;
#
"ORION")
  ulimit -s unlimited
  ulimit -a
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
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
  APRUN="srun -n ${PE_MEMBER01}"
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

vlddate=$CDATE

#
#-----------------------------------------------------------------------
#
# Go to working directory.
# Define fix path
#
#-----------------------------------------------------------------------
#

cd_vrfy $enkfworkdir
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}

#
#-----------------------------------------------------------------------
#
# Loop through the members, copy over the background and
#  observer output (diag*ges*) files to the running directory
#
#-----------------------------------------------------------------------
#
 cp_vrfy ${fixgriddir}/fv3_coupler.res    coupler.res
 cp_vrfy ${fixgriddir}/fv3_akbk           fv3sar_tile1_akbk.nc
 cp_vrfy ${fixgriddir}/fv3_grid_spec      fv3sar_tile1_grid_spec.nc

#
#-----------------------------------------------------------------------
#
# Get nlons (NX_RES) and nlats (NY_RES) from  fv3_grid_spec
#
#-----------------------------------------------------------------------
#
 for imem in  $(seq 1 $nens) ensmean; do

     if [ ${imem} == "ensmean" ]; then
        memchar="ensmean"
        memcharv0="ensmean"
     else
        memchar="mem"$(printf %04i $imem)
        memcharv0="mem"$(printf %03i $imem)
     fi
     slash_ensmem_subdir=$memchar
     if [ ${cycle_type} == "spinup" ]; then
        bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam_spinup/INPUT
        observer_nwges_dir="${NWGES_DIR}/${slash_ensmem_subdir}/observer_gsi_spinup"
     else
        bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam/INPUT
        observer_nwges_dir="${NWGES_DIR}/${slash_ensmem_subdir}/observer_gsi"
     fi

     cp_vrfy   ${bkpath}/fv_core.res.tile1.nc         fv3_${memcharv0}_dynvars
     cp_vrfy   ${bkpath}/fv_tracer.res.tile1.nc       fv3_${memcharv0}_tracer
     cp_vrfy   ${bkpath}/sfc_data.nc                  fv3_${memcharv0}_sfcdata

#
#-----------------------------------------------------------------------
#
# get the variable list from the tracer and dynvar files
#
#-----------------------------------------------------------------------
#
     if [ $imem == 1 ];then   
         ncvarlst_noaxis_time_new fv3_${memcharv0}_tracer > nck_tracer_list.txt
         ncvarlst_noaxis_time_new fv3_${memcharv0}_dynvars > nck_dynvar_list.txt
     fi
     user_nck_dynvar_list=`cat nck_dynvar_list.txt|paste -sd "," -  | tr -d '[:space:]'`
     user_nck_tracer_list=`cat nck_tracer_list.txt |paste -sd "," -  | tr -d '[:space:]'` 
#   This file contains horizontal grid information
     ncrename -d yaxis_1,yaxis_2 -v yaxis_1,yaxis_2 fv3_${memcharv0}_tracer
#
#-----------------------------------------------------------------------
#
# Copy tracer variables from tracer file to dynvars file, and
# get a combined dynvartracer background
#
#-----------------------------------------------------------------------
#
     ncks -A -v $user_nck_tracer_list fv3_${memcharv0}_tracer fv3_${memcharv0}_dynvars
     mv fv3_${memcharv0}_dynvars fv3sar_tile1_${memcharv0}_dynvartracer
#
#-----------------------------------------------------------------------
#
# Copy observer outputs (diag*ges*) to the working directory
#
#-----------------------------------------------------------------------
#
     for diagfile0 in `ls  ${observer_nwges_dir}/diag*ges*`; do
         diagfile=$(basename  $diagfile0)
         cp_vrfy  $diagfile0  ${diagfile}_$memcharv0
     done

 done

#
#----------------------------------------------------------------------
#

print_info_msg "
========================================================================
EnKF PRE-PROCESS completed successfully!!!

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
