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

This is the ex-script for the task that calculates ensemble mean with FV3 for the
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
valid_args=( "cycle_type" "comout" "ensmeandir" )
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
"WCOSS2")
#
  module list
  ulimit -s unlimited
  ulimit -a
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=1
  ncores=$(( NNODES_RUN_RECENTER*PPN_RUN_RECENTER ))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_RUN_RECENTER} --cpu-bind core --depth ${OMP_NUM_THREADS}"
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

cd_vrfy ${ensmeandir}

#
#--------------------------------------------------------------------
#
# loop through ensemble members to link all the member files
#

if [ ${cycle_type} == "spinup" ]; then
  fg_restart_dirname=fcst_fv3lam_spinup
else
  fg_restart_dirname=fcst_fv3lam
fi

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
    ln -sf ${bkpath}/sfc_data.nc  ./fv3sar_tile1_mem${memberstring}_sfcvar
    if [ $imem -eq 1 ]; then
# Prepare the data structure for ensemble mean
      cp_vrfy -f ${bkpath}/fv_core.res.tile1.nc  fv3sar_tile1_dynvar
      cp_vrfy -f ${bkpath}/fv_tracer.res.tile1.nc  fv3sar_tile1_tracer
      cp_vrfy -f ${bkpath}/sfc_data.nc  fv3sar_tile1_sfcvar
# Prepare other needed files for GSI observer run
      cp_vrfy -f ${bkpath}/coupler.res coupler.res
      ln_vrfy -snf ${bkpath}/fv_core.res.nc fv_core.res.nc
      ln_vrfy -snf ${bkpath}/fv_srf_wnd.res.tile1.nc fv_srf_wnd.res.tile1.nc
      ln_vrfy -snf ${bkpath}/phy_data.nc phy_data.nc
    fi
  else
    print_err_msg_exit "Error: cannot find background: ${dynvarfile} ${tracerfile}"
  fi
  (( imem += 1 ))
 done

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
  varlist(3)="t2m q2m f10m tslb smois tsea tsfc tsfcl alnsf alnwf alvsf alvwf emis_ice emis_lnd"
  l_write_mean=.true.
  l_recenter=.false.
  beta=1,
/
EOF

#
#-----------------------------------------------------------------------
#
# Run executable to calculate the ensemble mean
#

echo pwd is `pwd`
#ENSMEAN_EXEC=${EXECDIR}/gen_ensmean_recenter.exe
ENSMEAN_EXEC=${EXECDIR}/ens_mean_recenter_P2DIO.exe

if [ -f ${ENSMEAN_EXEC} ]; then 
  print_info_msg "$VERBOSE" "
Copying the ensemble mean executable to the run directory..."
  cp_vrfy ${ENSMEAN_EXEC} ${ensmeandir}/.
else
  print_err_msg_exit "\
The ensemble mean executable specified in ENSMEAN_EXEC does not exist:
  ENSMEAN_EXEC = \"${ENSMEAN_EXEC}\"
Build ENSMEAN_EXEC and rerun." 
fi

${APRUN} ${ENSMEAN_EXEC}  < namelist.ens > stdout_ensmean 2>&1 || print_err_msg_exit "\
Call to executable to calculate ensemble ensmean returned with nonzero exit code."

cp stdout_ensmean ${comout}/stdout.t${HH}z.ensmean
#
#-----------------------------------------------------------------------
#
# Link the ensemble mean files as GSI recognizable names
#
ln -s fv3sar_tile1_dynvar fv_core.res.tile1.nc
ln -s fv3sar_tile1_tracer fv_tracer.res.tile1.nc
ln -s fv3sar_tile1_sfcvar sfc_data.nc
#
#-----------------------------------------------------------------------
#
# Fix checksum for the files after calculating ensemble mean 
#
#-----------------------------------------------------------------------
#
for files in fv3sar_tile1_dynvar  fv3sar_tile1_sfcvar  fv3sar_tile1_tracer  ; do
  ncatted -a checksum,,d,,  $files
done

#
#-----------------------------------------------------------------------
#
# touch a file to show completion of the task
#
touch ${comout}/calc_ensmean_complete.txt
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

