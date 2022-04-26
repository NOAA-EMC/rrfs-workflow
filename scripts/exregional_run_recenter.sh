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

This is the ex-script for the task that recenters ensemble analysis with FV3 for the
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
valid_args=( "cycle_type" "recenterdir" "controldir" )
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
  module load nco/4.9.3
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
JJJ=$(date +%j -d "${START_DATE}")

YYYY=${YYYYMMDDHH:0:4}
MM=${YYYYMMDDHH:4:2}
DD=${YYYYMMDDHH:6:2}
HH=${YYYYMMDDHH:8:2}
YYYYMMDD=${YYYYMMDDHH:0:8}

cd_vrfy ${recenterdir}

#
#--------------------------------------------------------------------
#
# loop through ensemble members to link all the member files
#

fg_restart_dirname=fcst_fv3lam

imem=1
for imem in  $(seq 1 $nens)
  do
  ensmem=$( printf "%04d" $imem ) 
  memberstring=$( printf "%03d" $imem )

  bkpath=${CYCLE_DIR}/mem${ensmem}/${fg_restart_dirname}/INPUT  # cycling, use background from RESTART

  dynvarfile=${bkpath}/fv_core.res.tile1.nc
  tracerfile=${bkpath}/fv_tracer.res.tile1.nc
  if [ -r "${dynvarfile}" ] && [ -r "${tracerfile}" ] ; then
    ln -sf ${bkpath}/fv_core.res.tile1.nc  ./fv3sar_tile1_mem${memberstring}_dynvar
    ln -sf ${bkpath}/fv_tracer.res.tile1.nc   ./fv3sar_tile1_mem${memberstring}_tracer
    ln -sf ${bkpath}/phy_data.nc  ./fv3sar_tile1_mem${memberstring}_phyvar
  else
    print_err_msg_exit "Error: cannot find background: ${dynvarfile} ${tracerfile}"
  fi

  (( imem += 1 ))
 done
#
#-----------------------------------------------------------------------
#
# Prepare the data structure for ensemble mean
#
cp_vrfy -f ./fv3sar_tile1_mem001_dynvar fv3sar_tile1_dynvar
cp_vrfy -f ./fv3sar_tile1_mem001_tracer fv3sar_tile1_tracer
cp_vrfy -f ./fv3sar_tile1_mem001_phyvar fv3sar_tile1_phyvar

#
#-----------------------------------------------------------------------
#
# Run executable to get ensemble mean
#

echo pwd is `pwd`
ENSMEAN_EXEC=${EXECDIR}/gen_be_ensmean.x

if [ -f ${ENSMEAN_EXEC} ]; then 
  print_info_msg "$VERBOSE" "
Copying the ensemble mean executable to the run directory..."
  cp_vrfy ${ENSMEAN_EXEC} ${recenterdir}/gen_be_ensmean.x
else
  print_err_msg_exit "\
The ensemble mean executable specified in ENSMEAN_EXEC does not exist:
  ENSMEAN_EXEC = \"${ENSMEAN_EXEC}\"
Build ENSMEAN_EXEC and rerun." 
fi

# get ensemble mean of dynvar
ftail=dynvar
for varname in u v W DZ T delp phis ; do
${APRUN} ${ENSMEAN_EXEC}  ./  fv3sar_tile1 ${nens} ${varname} ${ftail} 1>stdout.ensmean.${ftail}_${varname} 2>stderr.ensmean.${ftail}_${varname} || print_err_msg_exit "\
Call to executable to run ensemble mean returned with nonzero exit code."
done


# get ensemble mean of tracer
ftail=tracer
for varname in sphum liq_wat ice_wat rainwat snowwat graupel water_nc ice_nc rain_nc o3mr liq_aero ice_aero sgs_tke ; do
${APRUN} ${ENSMEAN_EXEC}  ./  fv3sar_tile1 ${nens} ${varname} ${ftail} 1>stdout.ensmean.${ftail}_${varname} 2>stderr.ensmean.${ftail}_${varname} || print_err_msg_exit "\
Call to executable to run ensemble mean returned with nonzero exit code."
done

#
#-----------------------------------------------------------------------
#
# Link all members to be recentered
#

imem=1
for imem in  $(seq 1 $nens)
  do
  ensmem=$( printf "%04d" $imem ) 
  memberstring=$( printf "%03d" $imem )

  bkpath=${CYCLE_DIR}/mem${ensmem}/${fg_restart_dirname}/INPUT  # cycling, use background from RESTART

  dynvarfile=${bkpath}/fv_core.res.tile1.nc
  tracerfile=${bkpath}/fv_tracer.res.tile1.nc
  if [ -r "${dynvarfile}" ] && [ -r "${tracerfile}" ] ; then
    ln -sf ${bkpath}/fv_core.res.tile1.nc  ./rec_fv3sar_tile1_mem${memberstring}_dynvar
    ln -sf ${bkpath}/fv_tracer.res.tile1.nc   ./rec_fv3sar_tile1_mem${memberstring}_tracer
    ln -sf ${bkpath}/phy_data.nc  ./rec_fv3sar_tile1_mem${memberstring}_phyvar
  else
    print_err_msg_exit "Error: cannot find background: ${dynvarfile} ${tracerfile} "
  fi

  (( imem += 1 ))
 done
#
#-----------------------------------------------------------------------
#
# link the control member 
#

dynvarfile_control=${controldir}/fv_core.res.tile1.nc
tracerfile_control=${controldir}/fv_tracer.res.tile1.nc
if [ -r "${dynvarfile_control}" ] && [ -r "${tracerfile_control}" ] ; then
  ln -sf ${controldir}/fv_core.res.tile1.nc  ./control_dynvar
  ln -sf ${controldir}/fv_tracer.res.tile1.nc   ./control_tracer
  ln -sf ${controldir}/phy_data.nc  ./control_phyvar
else
  print_err_msg_exit "Error: cannot find background: ${dynvarfile_control}"
fi

#
#-----------------------------------------------------------------------
#
# recenter the ensemble 
#
echo pwd is `pwd`
RECENTER_EXEC=${EXECDIR}/gen_be_ensmeanrecenter.x

if [ -f ${RECENTER_EXEC} ]; then 
  print_info_msg "$VERBOSE" "
Copying the ensemble recenter executable to the run directory..."
  cp_vrfy ${RECENTER_EXEC} ${recenterdir}/gen_be_ensmeanrecenter.x
else
  print_err_msg_exit "\
The EnKF recentering executable specified in RECENTER_EXEC does not exist:
  RECENTER_EXEC = \"${RECENTER_EXEC}\"
Build RECENTER_EXEC and rerun." 
fi

#
#-----------------------------------------------------------------------
#
# Run the EnKF Recentering for all the variables/files
#
#-----------------------------------------------------------------------
#
ftail=dynvar 
for varname in u v W DZ T delp phis ; do
${APRUN} ${RECENTER_EXEC}  ./ rec_fv3sar_tile1 fv3sar_tile1 control ${nens} ${varname} ${ftail} 1>stdout.rec.${ftail}_${varname} 2>stderr.rec.${ftail}_${varname} || print_err_msg_exit "\
Call to executable to run EnKF Recenter returned with nonzero exit code."
done

ftail=tracer
for varname in sphum liq_wat ice_wat rainwat snowwat graupel water_nc ice_nc rain_nc o3mr liq_aero ice_aero sgs_tke ; do
${APRUN} ${RECENTER_EXEC}  ./ rec_fv3sar_tile1 fv3sar_tile1 control ${nens} ${varname} ${ftail} 1>stdout.rec.${ftail}_${varname} 2>stderr.rec.${ftail}_${varname} || print_err_msg_exit "\
Call to executable to run EnKF Recenter returned with nonzero exit code."
done

#
#-----------------------------------------------------------------------
#
# Fix checksum for the files after recentering
#
#-----------------------------------------------------------------------
#
for files in $(ls rec_fv3sar_tile1_mem*)  ; do
 ncatted -a checksum,,d,,  $files
done

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

