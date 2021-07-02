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
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
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

This is the ex-script for the task that conduct non-var cloud analysis
with FV3 for the specified cycle.
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
valid_args=( "CYCLE_DIR" "WORKDIR")
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
#-----------------------------------------------------------------------
#
case $MACHINE in
#
"WCOSS_C" | "WCOSS")
#
  . /apps/lmod/lmod/init/sh
  module purge
  module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/soft/modulefiles
  module load intel/16.1.150 impi/5.1.1.109 netcdf/4.3.0 
  module list
  
  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np 1"
  ;;
#
"HERA")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun"
  ;;
#
"JET")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun"
  ;;
#
"ORION")
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
  APRUN="srun -n 1"
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
set -x
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
# Get into working directory and define fix directory
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Getting into working directory for radar tten process ..."

workdir=${WORKDIR}
cd_vrfy ${workdir}

fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"

#
#-----------------------------------------------------------------------
#
# link or copy background and grid configuration files
#
#-----------------------------------------------------------------------

cp_vrfy ${fixgriddir}/fv3_akbk                               fv3_akbk
cp_vrfy ${fixgriddir}/fv3_grid_spec                          fv3_grid_spec

bkpath=${CYCLE_DIR}/fcst_fv3lam/INPUT
if [ -w ${bkpath}/gfs_data.tile7.halo0.nc ]; then  # Use background from INPUT
  ln_vrfy -s ${bkpath}/sfc_data.tile7.halo0.nc      fv3_sfcdata
  cp_vrfy ${bkpath}/gfs_data.tile7.halo0.nc      fv3_dynvars
  cp_vrfy ${bkpath}/gfs_data.tile7.halo0.nc      fv3_tracer
else                                               # Use background from RESTART
  cp_vrfy ${bkpath}/fv_core.res.tile1.nc         fv3_dynvars
  cp_vrfy ${bkpath}/fv_tracer.res.tile1.nc       fv3_tracer
  ln_vrfy -s ${bkpath}/sfc_data.nc                  fv3_sfcdata
fi

#
#-----------------------------------------------------------------------
#
# link/copy observation files to working directory
#
#-----------------------------------------------------------------------

process_bufr_path=${CYCLE_DIR}/process_bufr

obs_files_source[0]=${process_bufr_path}/LightningInFV3LAM.dat
obs_files_target[0]=LightningInFV3LAM.dat

obs_files_source[1]=${process_bufr_path}/NASALaRC_cloud4fv3.bin
obs_files_target[1]=NASALaRC_cloud4fv3.bin

obs_files_source[2]=${process_bufr_path}/fv3_metarcloud.bin
obs_files_target[2]=fv3_metarcloud.bin

obs_number=${#obs_files_source[@]}
for (( i=0; i<${obs_number}; i++ ));
do
  obs_file=${obs_files_source[$i]}
  obs_file_t=${obs_files_target[$i]}
  if [ -r "${obs_file}" ]; then
    cp_vrfy "${obs_file}" "${obs_file_t}"
  else
    print_info_msg "$VERBOSE" "Warning: ${obs_file} does not exist!"
  fi
done

#-----------------------------------------------------------------------
#
# Build namelist 
#
#-----------------------------------------------------------------------

cat << EOF > gsiparm.anl

 &SETUP
  iyear=${YYYY},
  imonth=${MM},
  iday=${DD},
  ihour=${HH},
  iminute=00,
 /
 &RAPIDREFRESH_CLDSURF
   dfi_radar_latent_heat_time_period=20.0,
   metar_impact_radius=10.0,
   metar_impact_radius_lowCloud=4.0,
   l_pw_hgt_adjust=.true.,
   l_limit_pw_innov=.true.,
   max_innov_pct=0.1,
   l_cleanSnow_WarmTs=.true.,
   r_cleanSnow_WarmTs_threshold=5.0,
   l_conserve_thetaV=.true.,
   i_conserve_thetaV_iternum=3,
   l_cld_bld=.true.,
   l_numconc=.true.,
   cld_bld_hgt=1200.0,
   build_cloud_frac_p=0.50,
   clear_cloud_frac_p=0.10,
   iclean_hydro_withRef_allcol=1,
   i_gsdcldanal_type=6,
   i_gsdsfc_uselist=1,
   i_lightpcp=1,
   i_gsdqc=2,
   l_saturate_bkCloud=.true.,
 /
EOF



#
#-----------------------------------------------------------------------
#
# Copy the executable to the run directory.
#
#-----------------------------------------------------------------------
#
exect="fv3lam_nonvarcldana.exe"

if [ -f ${EXECDIR}/$exect ]; then
  print_info_msg "$VERBOSE" "
Copying the nonVar Cloud Analysis executable to the run directory..."
  cp_vrfy ${EXECDIR}/${exect} ${workdir}
else
  print_err_msg_exit "\
The executable specified in exect does not exist:
  exect = \"${EXECDIR}/$exect\"
Build executable and rerun."
fi
#
#
#
#-----------------------------------------------------------------------
#
# Run the non-var cloud analysis application.  
#
#-----------------------------------------------------------------------
#
$APRUN ./${exect} > stdout 2>&1 || print_err_msg_exit "\
Call to executable to run No Var Cloud Analysis returned with nonzero exit code."

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
RADAR REFL TTEN PROCESS completed successfully!!!

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

