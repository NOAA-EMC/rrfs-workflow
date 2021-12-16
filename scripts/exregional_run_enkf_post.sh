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
function ncvarlst_noaxis_time_new { ncks -m  ${1} | grep -E 'name.*=' | cut -f 2 -d '=' | grep -o '"*.*"' | sed 's/"//g' | sort |grep -v -i -E "axis|time" ;  }
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
valid_args=( "cycle_dir" "cycle_type" "enkfworkdir" "NWGES_DIR" "slash_ensmem_subdir" "memname")
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
#
#-----------------------------------------------------------------------
#

cd_vrfy $enkfworkdir

#
#-----------------------------------------------------------------------
#
# For each member, restore the EnKF analysis back to
# separate tracer and dynvar files
#
#-----------------------------------------------------------------------
#

if [ ${cycle_type} == "spinup" ]; then
   bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam_spinup/INPUT
else
   bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam/INPUT
fi

FileUpdated=fv3sar_tile1_${memname}_dynvartracer
    
cp_vrfy $bkpath/fv_tracer.res.tile1.nc ./${memname}_fv3_tracer
cp_vrfy $bkpath/fv_core.res.tile1.nc ./${memname}_fv3_dynvars
ncvarlst_noaxis_time_new ${memname}_fv3_tracer > nck_tracer_list.txt
ncvarlst_noaxis_time_new ${memname}_fv3_dynvars > nck_dynvar_list.txt
user_nck_dynvar_list=`cat nck_dynvar_list.txt|paste -sd "," -  | tr -d '[:space:]'`
user_nck_tracer_list=`cat nck_tracer_list.txt |paste -sd "," -  | tr -d '[:space:]'` 
      
#
#-----------------------------------------------------------------------
#
# Extract dynvars variables from the EnKF analysi, update the
# dynvar files
#
#-----------------------------------------------------------------------
#
ncks -A -v $user_nck_dynvar_list $FileUpdated  ${memname}_fv3_dynvars
mv_vrfy ${memname}_fv3_dynvars   ${bkpath}/fv_core.res.tile1.nc
#
#-----------------------------------------------------------------------
#
# Extract tracer variables from the EnKF analysi, update the
# tracer files
#
#-----------------------------------------------------------------------
#
ncks -A -v  $user_nck_tracer_list $FileUpdated  ${memname}_fv3_tracer 
ncks --no_abc -O -x -v yaxis_2  ${memname}_fv3_tracer tmp_${memname}_tracer
mv_vrfy tmp_${memname}_tracer  ${bkpath}/fv_tracer.res.tile1.nc

#
#-----------------------------------------------------------------------
# clean up temporary files
#-----------------------------------------------------------------------
#
rm -f $FileUpdated
rm -f ${memname}_fv3_tracer tmp_${memname}_tracer
rm -f fv3_${memname}_tracer
rm -f ${memname}_fv3_dynvars
rm -f fv3_${memname}_dynvars
rm -f fv3_${memname}_sfcdata  diag*ges*_${memname}

print_info_msg "
========================================================================
EnKF POST-PROCESS completed successfully for mem"${memname}"!!!

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
