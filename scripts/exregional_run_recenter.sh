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
valid_args=( "cycle_type" "recenterdir" )
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
    cp_vrfy ${bkpath}/fv_core.res.tile1.nc  ./fv3sar_tile1_mem${memberstring}_dynvar
    cp_vrfy ${bkpath}/fv_tracer.res.tile1.nc   ./fv3sar_tile1_mem${memberstring}_tracer
    cp_vrfy ${bkpath}/sfc_data.nc  ./fv3sar_tile1_mem${memberstring}_sfcvar
    ln -sf ${bkpath}/fv_core.res.tile1.nc  ./rec_fv3sar_tile1_mem${memberstring}_dynvar
    ln -sf ${bkpath}/fv_tracer.res.tile1.nc   ./rec_fv3sar_tile1_mem${memberstring}_tracer
    ln -sf ${bkpath}/sfc_data.nc  ./rec_fv3sar_tile1_mem${memberstring}_sfcvar
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
cp_vrfy -f ./fv3sar_tile1_mem001_sfcvar fv3sar_tile1_sfcvar

#
#-----------------------------------------------------------------------
#
# link the control member 
#
dynvarfile_control=${ENSCTRL_CYCLE_DIR}/fcst_fv3lam/INPUT/fv_core.res.tile1.nc
tracerfile_control=${ENSCTRL_CYCLE_DIR}/fcst_fv3lam/INPUT/fv_tracer.res.tile1.nc
dynvarfile_control_spinup=${ENSCTRL_CYCLE_DIR}/fcst_fv3lam_spinup/INPUT/fv_core.res.tile1.nc
tracerfile_control_spinup=${ENSCTRL_CYCLE_DIR}/fcst_fv3lam_spinup/INPUT/fv_tracer.res.tile1.nc
if [ -r "${dynvarfile_control}" ] && [ -r "${tracerfile_control}" ] ; then
  ln -sf ${ENSCTRL_CYCLE_DIR}/fcst_fv3lam/INPUT/fv_core.res.tile1.nc  ./control_dynvar
  ln -sf ${ENSCTRL_CYCLE_DIR}/fcst_fv3lam/INPUT/fv_tracer.res.tile1.nc   ./control_tracer
  ln -sf ${ENSCTRL_CYCLE_DIR}/fcst_fv3lam/INPUT/sfc_data.nc  ./control_sfcvar
elif [ -r "${dynvarfile_control_spinup}" ] && [ -r "${tracerfile_control_spinup}" ] ; then
  ln -sf ${ENSCTRL_CYCLE_DIR}/fcst_fv3lam_spinup/INPUT/fv_core.res.tile1.nc  ./control_dynvar
  ln -sf ${ENSCTRL_CYCLE_DIR}/fcst_fv3lam_spinup/INPUT/fv_tracer.res.tile1.nc   ./control_tracer
  ln -sf ${ENSCTRL_CYCLE_DIR}/fcst_fv3lam_spinup/INPUT/sfc_data.nc  ./control_sfcvar
else
  print_err_msg_exit "Error: cannot find background: ${dynvarfile_control} or ${dynvarfile_control_spinup}"
fi

#
#-----------------------------------------------------------------------
#
# prepare the namelist.ens
#
cat << EOF > namelist.ens
&setup
  fv3_io_layout_y=1,
  ens_size=${nens},
  filebase='fv3sar_tile1'
  filetail(1)='dynvar'
  filetail(2)='tracer'
  filetail(3)='sfcvar'
  numvar(1)=7
  numvar(2)=13
  numvar(3)=14
  varlist(1)="u v W DZ T delp phis"
  varlist(2)="sphum liq_wat ice_wat rainwat snowwat graupel water_nc ice_nc rain_nc o3mr liq_aero ice_aero sgs_tke"
  varlist(3)="t2m q2m f10m tsea smois tsea tsfc tsfcl alnsf alnwf alvsf alvwf emis_ice emis_lnd"
  l_write_mean=.false.
  l_recenter=.true.
/
EOF

#
#-----------------------------------------------------------------------
#
# Run executable to recenter the ensemble
#

echo pwd is `pwd`
ENSMEAN_EXEC=${EXECDIR}/gen_ensmean_recenter.exe

if [ -f ${ENSMEAN_EXEC} ]; then 
  print_info_msg "$VERBOSE" "
Copying the ensemble mean executable to the run directory..."
  cp_vrfy ${ENSMEAN_EXEC} ${recenterdir}/.
else
  print_err_msg_exit "\
The ensemble mean executable specified in ENSMEAN_EXEC does not exist:
  ENSMEAN_EXEC = \"${ENSMEAN_EXEC}\"
Build ENSMEAN_EXEC and rerun." 
fi

${APRUN} ${ENSMEAN_EXEC}  < namelist.ens > stdout_recenter 2>&1 || print_err_msg_exit "\
Call to executable to run ensemble recenter returned with nonzero exit code."

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
# touch a file to show completion of the task
#
touch recenter_complete.txt
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

