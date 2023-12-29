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

This is the ex-script for the task that generates radar reflectivity tten
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
valid_args=( "cycle_dir" "cycle_type" "mem_type" "slash_ensmem_subdir" )
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
#
"WCOSS2")
  ncores=$(( NNODES_RUN_REF2TTEN*PPN_RUN_NONVARCLDANL))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_RUN_NONVARCLDANL}"
  ;;
#
"HERA")
  APRUN="srun --export=ALL"
  ;;
#
"JET")
  APRUN="srun --export=ALL"
  ;;
#
"ORION")
  APRUN="srun --export=ALL"
  ;;
#
"HERCULES")
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
#-----------------------------------------------------------------------
#
# Define fix directory
#
#-----------------------------------------------------------------------
#
fixdir=$FIX_GSI
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}

print_info_msg "$VERBOSE" "fixdir is $fixdir"
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"
#
#-----------------------------------------------------------------------
#
# link or copy background and grid configuration files
#
#-----------------------------------------------------------------------

if [ "${cycle_type}" = "spinup" ]; then
  cycle_tag="_spinup"
else
  cycle_tag=""
fi
if [ "${mem_type}" = "MEAN" ]; then
    bkpath=${cycle_dir}/ensmean/fcst_fv3lam${cycle_tag}/INPUT
else
    bkpath=${cycle_dir}${slash_ensmem_subdir}/fcst_fv3lam${cycle_tag}/INPUT
fi

n_iolayouty=$(($IO_LAYOUT_Y-1))
list_iolayout=$(seq 0 $n_iolayouty)

cp ${fixgriddir}/fv3_akbk  fv3_akbk
cp ${fixgriddir}/fv3_grid_spec  fv3_grid_spec

if [ -r "${bkpath}/coupler.res" ]; then # Use background from warm restart
  if [ "${IO_LAYOUT_Y}" == "1" ]; then
    ln -s ${bkpath}/fv_core.res.tile1.nc  fv3_dynvars
    ln -s ${bkpath}/fv_tracer.res.tile1.nc  fv3_tracer
    ln -s ${bkpath}/sfc_data.nc  fv3_sfcdata
    ln -s ${bkpath}/phy_data.nc  fv3_phydata
  else
    for ii in ${list_iolayout}
    do
      iii=$(printf %4.4i $ii)
      ln -s ${bkpath}/fv_core.res.tile1.nc.${iii}  fv3_dynvars.${iii}
      ln -s ${bkpath}/fv_tracer.res.tile1.nc.${iii}  fv3_tracer.${iii}
      ln -s ${bkpath}/sfc_data.nc.${iii}  fv3_sfcdata.${iii}
      ln -s ${bkpath}/phy_data.nc.${iii}  fv3_phydata.${iii}
      ln -s ${gridspec_dir}/fv3_grid_spec.${iii}  fv3_grid_spec.${iii}
    done
  fi
  BKTYPE=0
else                                   # Use background from cold start
  ln -s ${bkpath}/sfc_data.tile7.halo0.nc  fv3_sfcdata
  ln -s ${bkpath}/gfs_data.tile7.halo0.nc  fv3_dynvars
  ln -s ${bkpath}/gfs_data.tile7.halo0.nc  fv3_tracer
  print_info_msg "$VERBOSE" "radar2tten is not ready for cold start"
  BKTYPE=1
  exit 0
fi
#
#-----------------------------------------------------------------------
#
# link/copy observation files to working directory
#
#-----------------------------------------------------------------------
#
ss=0
for bigmin in ${RADARREFL_TIMELEVEL[@]}; do
  bigmin=$( printf %2.2i $bigmin )
  obs_file=${comin}/rrfs.t${HH}z.RefInGSI3D.bin.${bigmin}
  if [ "${IO_LAYOUT_Y}" == "1" ]; then
    obs_file_check=${obs_file}
  else
    obs_file_check=${obs_file}.0000
  fi
  ((ss+=1))
  num=$( printf %2.2i ${ss} )
  if [ -r "${obs_file_check}" ]; then
     if [ "${IO_LAYOUT_Y}" == "1" ]; then
       cp "${obs_file}" "RefInGSI3D.dat_${num}"
     else
       for ii in ${list_iolayout}
       do
         iii=$(printf %4.4i $ii)
         cp "${obs_file}.${iii}" "RefInGSI3D.dat.${iii}_${num}"
       done
     fi
  else
     print_info_msg "$VERBOSE" "WARNING: ${obs_file} does not exist!"
  fi
done

obs_file=${COMIN}/rrfs.t${HH}z.LightningInFV3LAM.bin
if [ -r "${obs_file}" ]; then
   cp "${obs_file}" "LightningInGSI.dat_01"
else
   print_info_msg "$VERBOSE" "WARNING: ${obs_file} does not exist!"
fi
#
#-----------------------------------------------------------------------
#
# Create links to BUFR table, which needed for generate the BUFR file
#
#-----------------------------------------------------------------------
#
bufr_table=${fixdir}/prepobs_prep_RAP.bufrtable

# Fixed fields
cp $bufr_table prepobs_prep.bufrtable
#
#-----------------------------------------------------------------------
#
# Build namelist and run executable 
#
#   fv3_io_layout_y : subdomain of restart files
#
#-----------------------------------------------------------------------
#
if [ ${BKTYPE} -eq 1 ]; then
  n_iolayouty=1
else
  n_iolayouty=$(($IO_LAYOUT_Y))
fi

cat << EOF > namelist.ref2tten
   &setup
    dfi_radar_latent_heat_time_period=15.0,
    convection_refl_threshold=28.0,
    l_tten_for_convection_only=.true.,
    l_convection_suppress=.false.,
    fv3_io_layout_y=${n_iolayouty},
    timelevel=${ss},
   /
EOF
#
#-----------------------------------------------------------------------
#
# Run the radar to tten application.  
#
#-----------------------------------------------------------------------
#
export pgm="ref2tten.exe"
. prep_step

$APRUN ${EXECdir}/$pgm >>$pgmout 2>errfile
export err=$?; err_chk
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
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

