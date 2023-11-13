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
# Source other necessary files.
#
#-----------------------------------------------------------------------
#
. $USHdir/link_fix.sh
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

This is the ex-script for the task that generates surface fields from
climatology.
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
valid_args=( "workdir" )
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
# OpenMP environment settings.
#
#-----------------------------------------------------------------------
#
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=1024m
nprocs=$(( NNODES_MAKE_SFC_CLIMO * PPN_MAKE_SFC_CLIMO ))
#
#-----------------------------------------------------------------------
#
# Change location to the temporary directory.
#
#-----------------------------------------------------------------------
#
cd $workdir
#
#-----------------------------------------------------------------------
#
# Create the namelist that the sfc_climo_gen code will read in.
#
# Question: Should this instead be created from a template file?
#
#-----------------------------------------------------------------------
#
if [ "${PREDEF_GRID_NAME}" = "RRFS_FIREWX_1.5km" ]; then
  input_substrate_temperature_file="${SFC_CLIMO_INPUT_DIR}/substrate_temperature.gfs.0.5.nc"
  input_soil_type_file="${SFC_CLIMO_INPUT_DIR}/soil_type.bnu.v2.30s.nc"
  input_vegetation_type_file="${SFC_CLIMO_INPUT_DIR}/vegetation_type.viirs.v2.igbp.30s.nc"
  vegsoilt_frac=.true.
else
  input_substrate_temperature_file="${SFC_CLIMO_INPUT_DIR}/substrate_temperature.2.6x1.5.nc"
  input_soil_type_file="${SFC_CLIMO_INPUT_DIR}/soil_type.statsgo.0.05.nc"
  input_vegetation_type_file="${SFC_CLIMO_INPUT_DIR}/vegetation_type.igbp.0.05.nc"
  vegsoilt_frac=.false.
fi

cat << EOF > ./fort.41
&config
input_facsf_file="${SFC_CLIMO_INPUT_DIR}/facsf.1.0.nc"
input_substrate_temperature_file="${input_substrate_temperature_file}"
input_maximum_snow_albedo_file="${SFC_CLIMO_INPUT_DIR}/maximum_snow_albedo.0.05.nc"
input_snowfree_albedo_file="${SFC_CLIMO_INPUT_DIR}/snowfree_albedo.4comp.0.05.nc"
input_slope_type_file="${SFC_CLIMO_INPUT_DIR}/slope_type.1.0.nc"
input_soil_type_file="${input_soil_type_file}"
input_vegetation_type_file="${input_vegetation_type_file}"
input_vegetation_greenness_file="${SFC_CLIMO_INPUT_DIR}/vegetation_greenness.0.144.nc"
mosaic_file_mdl="${FIXLAM}/${CRES}${DOT_OR_USCORE}mosaic.halo${NH4}.nc"
orog_dir_mdl="${FIXLAM}"
orog_files_mdl="${CRES}${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
halo=${NH4}
maximum_snow_albedo_method="bilinear"
snowfree_albedo_method="bilinear"
vegetation_greenness_method="bilinear"
fract_vegsoil_type=${vegsoilt_frac}
/
EOF
#
#-----------------------------------------------------------------------
#
# Set the machine-dependent run command.
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case $MACHINE in

  "WCOSS2")
    APRUN="mpiexec -n ${nprocs}"
    ;;

  "HERA")
    APRUN="srun --export=ALL"
    ;;

  "ORION")
    APRUN="srun --export=ALL"
    ;;

  "JET")
    APRUN="srun --export=ALL"
    ;;

  *)
    err_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN = \"$APRUN\""
    ;;

esac
#
#-----------------------------------------------------------------------
#
# Generate the surface climatology files.
#
#-----------------------------------------------------------------------
#
# Set the name and path to the executable and make sure that it exists.
#
exec_fn="sfc_climo_gen"
exec_fp="$EXECdir/${exec_fn}"
if [ ! -f "${exec_fp}" ]; then
  err_exit "\
The executable (exec_fp) for generating the surface climatology files
does not exist:
  exec_fp = \"${exec_fp}\"
Please ensure that you've built this executable."
fi

$APRUN ${exec_fp}
export err=$?; err_chk
#
#-----------------------------------------------------------------------
#
# Move output files out of the temporary directory.
#
#-----------------------------------------------------------------------
#
case "$GTYPE" in

#
# Consider, global, stetched, and nested grids.
#
"global" | "stretch" | "nested")
#
# Move all files ending with ".nc" to the SFC_CLIMO_DIR directory.
# In the process, rename them so that the file names start with the C-
# resolution (followed by an underscore).
#
  for fn in *.nc; do
    if [[ -f $fn ]]; then
      mv $fn ${SFC_CLIMO_DIR}/${CRES}_${fn}
    fi
  done
  ;;

#
# Consider regional grids.
#
"regional")
#
# Move all files ending with ".halo.nc" (which are the files for a grid
# that includes the specified non-zero-width halo) to the WORKDIR_SFC_-
# CLIMO directory.  In the process, rename them so that the file names
# start with the C-resolution (followed by a dot) and contain the (non-
# zero) halo width (in units of number of grid cells).
#
  for fn in *.halo.nc; do
    if [ -f $fn ]; then
      bn="${fn%.halo.nc}"
      mv $fn ${SFC_CLIMO_DIR}/${CRES}.${bn}.halo${NH4}.nc
    fi
  done
#
# Move all remaining files ending with ".nc" (which are the files for a
# grid that doesn't include a halo) to the SFC_CLIMO_DIR directory.
# In the process, rename them so that the file names start with the C-
# resolution (followed by a dot) and contain the string "halo0" to indi-
# cate that the grids in these files do not contain a halo.
#
  for fn in *.nc; do
    if [ -f $fn ]; then
      bn="${fn%.nc}"
      mv $fn ${SFC_CLIMO_DIR}/${CRES}.${bn}.halo${NH0}.nc
    fi
  done
  ;;

esac
#
#-----------------------------------------------------------------------
#
# Can these be moved to stage_static if this script is called before
# stage_static.sh????
# These have been moved.  Can delete the following after testing.
#
#-----------------------------------------------------------------------
#
link_fix \
  verbose="$VERBOSE" \
  file_group="sfc_climo"
export err=$?
if [ $err -ne 0 ]; then
  err_exit "\
Call to function to create links to surface climatology files failed."
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
All surface climatology files generated successfully!!!

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
