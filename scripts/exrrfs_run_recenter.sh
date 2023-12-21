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

This is the ex-script for the task that recenters ensemble analysis with FV3 for the
specified cycle.
========================================================================"
#
# Set environment
#
ulimit -s unlimited
ulimit -a

case $MACHINE in
#
"WCOSS2")
#
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=1
  ncores=$(( NNODES_RUN_RECENTER*PPN_RUN_RECENTER ))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_RUN_RECENTER} --cpu-bind core --depth ${OMP_NUM_THREADS}"
  ;;
#
"HERA")
  export OMP_NUM_THREADS=1
#  export OMP_STACKSIZE=300M
  APRUN="srun --export=ALL"
  ;;
#
"ORION")
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
  APRUN="srun --export=ALL"
  ;;
#
"HERCULES")
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
  APRUN="srun --export=ALL"
  ;;
#
"JET")
  APRUN="srun --export=ALL"
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
#
#--------------------------------------------------------------------
#
# loop through ensemble members to link all the member files
#
#--------------------------------------------------------------------
#
if [ "${CYCLE_TYPE}" = "spinup" ]; then
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
    if [ ${DO_ENSFCST} = "TRUE" ] ; then
      ln -sf ${bkpath}/fv_core.res.tile1.nc  ./fv3sar_tile1_mem${memberstring}_dynvar
      ln -sf ${bkpath}/fv_tracer.res.tile1.nc   ./fv3sar_tile1_mem${memberstring}_tracer
      ln -sf ${bkpath}/sfc_data.nc  ./fv3sar_tile1_mem${memberstring}_sfcvar
    else
      ln -sf ${bkpath}/bk_fv_core.res.tile1.nc  ./fv3sar_tile1_mem${memberstring}_dynvar
      ln -sf ${bkpath}/bk_fv_tracer.res.tile1.nc   ./fv3sar_tile1_mem${memberstring}_tracer
      ln -sf ${bkpath}/bk_sfc_data.nc  ./fv3sar_tile1_mem${memberstring}_sfcvar
    fi
    ln -sf ${bkpath}/fv_core.res.tile1.nc  ./rec_fv3sar_tile1_mem${memberstring}_dynvar
    ln -sf ${bkpath}/fv_tracer.res.tile1.nc   ./rec_fv3sar_tile1_mem${memberstring}_tracer
    ln -sf ${bkpath}/sfc_data.nc  ./rec_fv3sar_tile1_mem${memberstring}_sfcvar
  else
    err_exit "Cannot find background: ${dynvarfile} ${tracerfile}"
  fi

  (( imem += 1 ))
 done
#
#-----------------------------------------------------------------------
#
# Prepare the data structure for ensemble mean
#
#-----------------------------------------------------------------------
#
cp -f ./fv3sar_tile1_mem001_dynvar fv3sar_tile1_dynvar
cp -f ./fv3sar_tile1_mem001_tracer fv3sar_tile1_tracer
cp -f ./fv3sar_tile1_mem001_sfcvar fv3sar_tile1_sfcvar
#
#-----------------------------------------------------------------------
#
# link the control member 
#
#-----------------------------------------------------------------------
#
dynvarfile_control=${ctrlpath}/fcst_fv3lam/INPUT/fv_core.res.tile1.nc
tracerfile_control=${ctrlpath}/fcst_fv3lam/INPUT/fv_tracer.res.tile1.nc
dynvarfile_control_spinup=${ctrlpath}/fcst_fv3lam_spinup/INPUT/fv_core.res.tile1.nc
tracerfile_control_spinup=${ctrlpath}/fcst_fv3lam_spinup/INPUT/fv_tracer.res.tile1.nc
if [ -r "${dynvarfile_control_spinup}" ] && [ -r "${tracerfile_control_spinup}" ] && [[ ${DO_ENSFCST} != "TRUE" ]] ; then
  ln -sf ${ctrlpath}/fcst_fv3lam_spinup/INPUT/fv_core.res.tile1.nc  ./control_dynvar
  ln -sf ${ctrlpath}/fcst_fv3lam_spinup/INPUT/fv_tracer.res.tile1.nc   ./control_tracer
  ln -sf ${ctrlpath}/fcst_fv3lam_spinup/INPUT/sfc_data.nc  ./control_sfcvar
elif [ -r "${dynvarfile_control}" ] && [ -r "${tracerfile_control}" ] ; then
  ln -sf ${ctrlpath}/fcst_fv3lam/INPUT/fv_core.res.tile1.nc  ./control_dynvar
  ln -sf ${ctrlpath}/fcst_fv3lam/INPUT/fv_tracer.res.tile1.nc   ./control_tracer
  ln -sf ${ctrlpath}/fcst_fv3lam/INPUT/sfc_data.nc  ./control_sfcvar
else
  err_exit "Cannot find background: ${dynvarfile_control} or ${dynvarfile_control_spinup}"
fi
#
#-----------------------------------------------------------------------
#
# prepare the namelist.ens
#
#-----------------------------------------------------------------------
#
cat << EOF > namelist.ens
&setup
  fv3_io_layout_y=1,
  ens_size=${nens},
  filebase='fv3sar_tile1'
  filetail(1)='dynvar'
  filetail(2)='tracer'
  filetail(3)='sfcvar'
  numvar(1)=9
  numvar(2)=13
  numvar(3)=10
  varlist(1)="u v W DZ T delp phis ua va"
  varlist(2)="sphum liq_wat ice_wat rainwat snowwat graupel water_nc ice_nc rain_nc o3mr liq_aero ice_aero sgs_tke"
  varlist(3)="t2m q2m f10m tslb smois tsea tsfc tsfcl emis_ice emis_lnd"
  l_write_mean=.false.
  l_recenter=.true.
/
EOF
#
#-----------------------------------------------------------------------
#
# Run executable to recenter the ensemble
#
#-----------------------------------------------------------------------
#
echo pwd is `pwd`
export pgm="ens_mean_recenter_P2DIO.exe"

${APRUN} ${EXECdir}/$pgm < namelist.ens >>$pgmout 2>errfile
export err=$?; err_chk
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
touch ${COMOUT}/recenter_complete.txt
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
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

