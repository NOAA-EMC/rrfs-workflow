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
. $USHdir/make_grid_mosaic_file.sh
. $USHdir/link_fix.sh
. $USHdir/set_FV3nml_sfc_climo_filenames.sh
. $USHdir/set_FV3nml_stoch_params.sh
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

This is the ex-script for the task that generates grid files.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  Then
# process the arguments provided to this script/function (which should
# consist of a set of name-value pairs of the form arg1="value1", etc).
#
#-----------------------------------------------------------------------
#
valid_args=()
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
# OpenMP environment setting
#
#-----------------------------------------------------------------------
#
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=1024m
#
#-----------------------------------------------------------------------
#
# Set the machine-dependent run command.  Also, set resource limits as
# necessary.
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case $MACHINE in

  "WCOSS2")
    APRUN="time"
    ;;

  "HERA")
    APRUN="time"
    ;;

  "ORION")
    APRUN="time"
    ;;

  "JET")
    APRUN="time"
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
# Generate grid files.
#
# The following will create 7 grid files (one per tile, where the 7th
# "tile" is the grid that covers the regional domain) named
#
#   ${CRES}_grid.tileN.nc for N=1,...,7.
#
# It will also create a mosaic file named ${CRES}_mosaic.nc that con-
# tains information only about tile 7 (i.e. it does not have any infor-
# mation on how tiles 1 through 6 are connected or that tile 7 is within
# tile 6).  All these files will be placed in the directory specified by
# GRID_DIR.  Note that the file for tile 7 will include a halo of width
# NHW cells.
#
# Since tiles 1 through 6 are not needed to run the FV3-LAM model and are
# not used later on in any other preprocessing steps, it is not clear
# why they are generated.  It might be because it is not possible to di-
# rectly generate a standalone regional grid using the make_hgrid uti-
# lity/executable that grid_gen_scr calls, i.e. it might be because with
# make_hgrid, one has to either create just the 6 global tiles or create
# the 6 global tiles plus the regional (tile 7), and then for the case
# of a regional simulation (i.e. GTYPE="regional", which is always the
# case here) just not use the 6 global tiles.
#
# The grid_gen_scr script called below takes its next-to-last argument
# and passes it as an argument to the --halo flag of the make_hgrid uti-
# lity/executable.  make_hgrid then checks that a regional (or nested)
# grid of size specified by the arguments to its --istart_nest, --iend_-
# nest, --jstart_nest, and --jend_nest flags with a halo around it of
# size specified by the argument to the --halo flag does not extend be-
# yond the boundaries of the parent grid (tile 6).  In this case, since
# the values passed to the --istart_nest, ..., and --jend_nest flags al-
# ready include a halo (because these arguments are
#
#   ${ISTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG},
#   ${IEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG},
#   ${JSTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG}, and
#   ${JEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG},
#
# i.e. they include "WITH_WIDE_HALO_" in their names), it is reasonable
# to pass as the argument to --halo a zero.  However, make_hgrid re-
# quires that the argument to --halo be at least 1, so below, we pass a
# 1 as the next-to-last argument to grid_gen_scr.
#
# More information on make_hgrid:
# ------------------------------
#
# The grid_gen_scr called below in turn calls the make_hgrid executable
# as follows:
#
#   make_hgrid \
#   --grid_type gnomonic_ed \
#   --nlon 2*${RES} \
#   --grid_name C${RES}_grid \
#   --do_schmidt --stretch_factor ${STRETCH_FAC} \
#   --target_lon ${LON_CTR}
#   --target_lat ${LAT_CTR} \
#   --nest_grid --parent_tile 6 --refine_ratio ${GFDLgrid_REFINE_RATIO} \
#   --istart_nest ${ISTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
#   --jstart_nest ${JSTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
#   --iend_nest ${IEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
#   --jend_nest ${JEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
#   --halo ${NH3} \
#   --great_circle_algorithm
#
# This creates the 7 grid files ${CRES}_grid.tileN.nc for N=1,...,7.
# The 7th file ${CRES}_grid.tile7.nc represents the regional grid, and
# the extents of the arrays in that file do not seem to include a halo,
# i.e. they are based only on the values passed via the four flags
#
#   --istart_nest ${ISTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG}
#   --jstart_nest ${JSTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG}
#   --iend_nest ${IEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG}
#   --jend_nest ${JEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG}
#
# According to Rusty Benson of GFDL, the flag
#
#   --halo ${NH3}
#
# only checks to make sure that the nested or regional grid combined
# with the specified halo lies completely within the parent tile.  If
# so, make_hgrid issues a warning and exits.  Thus, the --halo flag is
# not meant to be used to add a halo region to the nested or regional
# grid whose limits are specified by the flags --istart_nest, --iend_-
# nest, --jstart_nest, and --jend_nest.
#
# Note also that make_hgrid has an --out_halo option that, according to
# the documentation, is meant to output extra halo cells around the
# nested or regional grid boundary in the file generated by make_hgrid.
# However, according to Rusty Benson of GFDL, this flag was originally
# created for a special purpose and is limited to only outputting at
# most 1 extra halo point.  Thus, it should not be used.
#
#-----------------------------------------------------------------------
#

#
#-----------------------------------------------------------------------
#
# Generate grid file.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Starting grid file generation..."
#
# Generate a GFDLgrid-type of grid.
#
if [ "${GRID_GEN_METHOD}" = "GFDLgrid" ]; then
#
# Set local variables needed in the call to the executable that generates
# a GFDLgrid-type grid.
#
  nx_t6sg=$(( 2*GFDLgrid_RES ))
  grid_name="${GRID_GEN_METHOD}"
#
# Call the executable that generates the grid file.  Note that this call
# will generate a file not only the regional grid (tile 7) but also files
# for the 6 global tiles.  However, after this call we will only need the
# regional grid file.
#
  export pgm="make_hgrid"
  . prep_step

  $APRUN ${EXECdir}/${pgm} \
    --grid_type gnomonic_ed \
    --nlon ${nx_t6sg} \
    --grid_name ${grid_name} \
    --do_schmidt \
    --stretch_factor ${STRETCH_FAC} \
    --target_lon ${LON_CTR} \
    --target_lat ${LAT_CTR} \
    --nest_grid \
    --parent_tile 6 \
    --refine_ratio ${GFDLgrid_REFINE_RATIO} \
    --istart_nest ${ISTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
    --jstart_nest ${JSTART_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
    --iend_nest ${IEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
    --jend_nest ${JEND_OF_RGNL_DOM_WITH_WIDE_HALO_ON_T6SG} \
    --halo 1 \
    --great_circle_algorithm >>$pgmout 2>${tmpdir}/errfile
  export err=$?; err_chk

#
# Set the name of the regional grid file generated by the above call.
#
  grid_fn="${grid_name}.tile${TILE_RGNL}.nc"
#
# Generate a ESGgrid-type of grid.
#
elif [ "${GRID_GEN_METHOD}" = "ESGgrid" ]; then
#
# Create the namelist file read in by the ESGgrid-type grid generation
# code in the temporary subdirectory.
#
  rgnl_grid_nml_fp="$tmpdir/${RGNL_GRID_NML_FN}"
#
# Create a multiline variable that consists of a yaml-compliant string
# specifying the values that the namelist variables need to be set to
# (one namelist variable per line, plus a header and footer).  Below,
# this variable will be passed to a python script that will create the
# namelist file.
#
  settings="
'regional_grid_nml': {
    'plon': ${LON_CTR},
    'plat': ${LAT_CTR},
    'delx': ${DEL_ANGLE_X_SG},
    'dely': ${DEL_ANGLE_Y_SG},
    'lx': ${NEG_NX_OF_DOM_WITH_WIDE_HALO},
    'ly': ${NEG_NY_OF_DOM_WITH_WIDE_HALO},
    'pazi': ${PAZI},
 }
"
#
# Call the python script to create the namelist file.
#
  ${USHdir}/set_namelist.py -q -u "$settings" -o ${rgnl_grid_nml_fp}
  export err=$?
  if [ $err -ne 0 ]; then
    err_exit "\
Call to python script set_namelist.py to set the variables in the
regional_esg_grid namelist file failed.  Parameters passed to this script
are:
  Full path to output namelist file:
    rgnl_grid_nml_fp = \"${rgn_grid_nml_fp}\"
  Namelist settings specified on command line (these have highest precedence):
    settings =
$settings"
  fi
#
# Call the executable that generates the grid file.
#
  export pgm="regional_esg_grid"
  . prep_step

  $APRUN ${EXECdir}/$pgm ${rgnl_grid_nml_fp} >>$pgmout 2>${tmpdir}/errfile
  export err=$?; err_chk

#
# Set the name of the regional grid file generated by the above call.
# This must be the same name as in the regional_esg_grid code.
#
  grid_fn="regional_grid.nc"

fi
#
# Set the full path to the grid file generated above.  Then change location
# to the original directory.
#
grid_fp="$tmpdir/${grid_fn}"

cd -

print_info_msg "$VERBOSE" "
Grid file generation completed successfully."
#
#-----------------------------------------------------------------------
#
# Calculate the regional grid's global uniform cubed-sphere grid equivalent
# resolution.
#
#-----------------------------------------------------------------------
#
export pgm="global_equiv_resol"
$APRUN ${EXECdir}/$pgm "${grid_fp}" >>$pgmout 2>>${tmpdir}/errfile
export err=$?; err_chk

# Make the following (reading of res_equiv) a function in another file
# so that it can be used both here and in the exrrfs_make_orog.sh
# script.
res_equiv=$( ncdump -h "${grid_fp}" | \
             grep -o ":RES_equiv = [0-9]\+" | grep -o "[0-9]" )
export err=$?
if [ $err -ne 0 ]; then
  err_exit "\
Attempt to extract the equivalent global uniform cubed-sphere grid reso-
lution from the grid file (grid_fp) failed:
  grid_fp = \"${grid_fp}\""
fi
res_equiv=${res_equiv//$'\n'/}
#
#-----------------------------------------------------------------------
#
# Set the string CRES that will be comprise the start of the grid file
# name (and other file names later in other tasks/scripts).  Then set its
# value in the variable definitions file.
#
#-----------------------------------------------------------------------
#
if [ "${GRID_GEN_METHOD}" = "GFDLgrid" ]; then
  if [ "${GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES}" = "TRUE" ]; then
    CRES="C${GFDLgrid_RES}"
  else
    CRES="C${res_equiv}"
  fi
elif [ "${GRID_GEN_METHOD}" = "ESGgrid" ]; then
  CRES="C${res_equiv}"
fi
set_file_param "${GLOBAL_VAR_DEFNS_FP}" "CRES" "\"$CRES\""
#
#-----------------------------------------------------------------------
#
# Move the grid file from the temporary directory to GRID_DIR.  In the
# process, rename it such that its name includes CRES and the halo width.
#
#-----------------------------------------------------------------------
#
grid_fp_orig="${grid_fp}"
grid_fn="${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NHW}.nc"
grid_fp="${GRID_DIR}/${grid_fn}"
mv "${grid_fp_orig}" "${grid_fp}"
#
#-----------------------------------------------------------------------
#
# If there are pre-existing orography or climatology files that we will
# be using (i.e. if RUN_TASK_MAKE_OROG or RUN_TASK_MAKE_SURF_CLIMO is set
# to "FALSE", in which case RES_IN_FIXLAM_FILENAMES will not be set to a
# null string), check that the grid resolution contained in the variable
# CRES set above matches the resolution appearing in the names of the
# preexisting orography and/or surface climatology files.
#
#-----------------------------------------------------------------------
#
if [ ! -z "${RES_IN_FIXLAM_FILENAMES}" ]; then
  res="${CRES:1}"
  if [ "$res" -ne "${RES_IN_FIXLAM_FILENAMES}" ]; then
    err_exit "\
The resolution (res) calculated for the grid does not match the resolution
(RES_IN_FIXLAM_FILENAMES) appearing in the names of the orography and/or
surface climatology files:
  res = \"$res\"
  RES_IN_FIXLAM_FILENAMES = \"${RES_IN_FIXLAM_FILENAMES}\""
  fi
fi
#
#-----------------------------------------------------------------------
#
# Partially "shave" the halo from the grid file having a wide halo to
# generate two new grid files -- one with a 3-grid-wide halo and another
# with a 4-cell-wide halo.  These are needed as inputs by the forecast
# model as well as by the code (chgres_cube) that generates the lateral
# boundary condition files.
#
#-----------------------------------------------------------------------
#
# Set the full path to the "unshaved" grid file, i.e. the one with a wide
# halo.  This is the input grid file for generating both the grid file
# with a 3-cell-wide halo and the one with a 4-cell-wide halo.
#
unshaved_fp="${grid_fp}"
#
# We perform the work in tmpdir, so change location to that directory.
# Once it is complete, we will move the resultant file from tmpdir to
# GRID_DIR.
#
cd "$tmpdir"
#
# Create an input namelist file for the shave executable to generate a
# grid file with a 3-cell-wide halo from the one with a wide halo.  Then
# call the shave executable.  Finally, move the resultant file to the
# GRID_DIR directory.
#
print_info_msg "$VERBOSE" "
\"Shaving\" grid file with wide halo to obtain grid file with ${NH3}-cell-wide
halo..."

nml_fn="input.shave.grid.halo${NH3}"
shaved_fp="${tmpdir}/${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH3}.nc"
printf "%s %s %s %s %s\n" \
  $NX $NY ${NH3} \"${unshaved_fp}\" \"${shaved_fp}\" \
  > ${nml_fn}

export pgm="shave"
$APRUN ${EXECdir}/$pgm < ${nml_fn} >>$pgmout 2>>${tmpdir}/errfile
export err=$?; err_chk

mv ${shaved_fp} ${GRID_DIR}
#
# Create an input namelist file for the shave executable to generate a
# grid file with a 4-cell-wide halo from the one with a wide halo.  Then
# call the shave executable.  Finally, move the resultant file to the
# GRID_DIR directory.
#
print_info_msg "$VERBOSE" "
\"Shaving\" grid file with wide halo to obtain grid file with ${NH4}-cell-wide
halo..."

nml_fn="input.shave.grid.halo${NH4}"
shaved_fp="${tmpdir}/${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH4}.nc"
printf "%s %s %s %s %s\n" \
  $NX $NY ${NH4} \"${unshaved_fp}\" \"${shaved_fp}\" \
  > ${nml_fn}

$APRUN ${EXECdir}/$pgm < ${nml_fn} >>$pgmout 2>>${tmpdir}/errfile
export err=$?; err_chk

mv ${shaved_fp} ${GRID_DIR}
#
# Create an input namelist file for the shave executable to generate a
# grid file without halo from the one with a wide halo. Then call the shave 
# executable.  Finally, move the resultant file to the GRID_DIR directory.
#
print_info_msg "$VERBOSE" "
\"Shaving\" grid file with wide halo to obtain grid file without halo..."

nml_fn="input.shave.grid.halo0"
shaved_fp="${tmpdir}/${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo0.nc"
printf "%s %s %s %s %s\n" \
  $NX $NY "0" \"${unshaved_fp}\" \"${shaved_fp}\" \
  > ${nml_fn}

$APRUN ${EXECdir}/$pgm < ${nml_fn} >>$pgmout 2>>${tmpdir}/errfile
export err=$?; err_chk

mv ${shaved_fp} ${GRID_DIR}
#
# Change location to the original directory.
#
cd -
#
#-----------------------------------------------------------------------
#
# Create the grid mosaic file for the grid with a NHW-cell-wide halo.
#
#-----------------------------------------------------------------------
#
make_grid_mosaic_file \
  grid_dir="${GRID_DIR}" \
  grid_fn="${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NHW}.nc" \
  mosaic_fn="${CRES}${DOT_OR_USCORE}mosaic.halo${NHW}.nc"
export err=$?
if [ $err -ne 0 ]; then
  err_exit "\
Call to function to generate the mosaic file for a grid with a ${NHW}-cell-wide
halo failed."
fi
#
#-----------------------------------------------------------------------
#
# Create the grid mosaic file for the grid with a NH3-cell-wide halo.
#
#-----------------------------------------------------------------------
#
make_grid_mosaic_file \
  grid_dir="${GRID_DIR}" \
  grid_fn="${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH3}.nc" \
  mosaic_fn="${CRES}${DOT_OR_USCORE}mosaic.halo${NH3}.nc"
export err=$?
if [ $err -ne 0 ]; then
  err_exit "\
Call to function to generate the mosaic file for a grid with a ${NH3}-cell-wide
halo failed."
fi
#
#-----------------------------------------------------------------------
#
# Create the grid mosaic file for the grid with a NH4-cell-wide halo.
#
#-----------------------------------------------------------------------
#
make_grid_mosaic_file \
  grid_dir="${GRID_DIR}" \
  grid_fn="${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH4}.nc" \
  mosaic_fn="${CRES}${DOT_OR_USCORE}mosaic.halo${NH4}.nc"
export err=$?
if [ $err -ne 0 ]; then
  err_exit "\
Call to function to generate the mosaic file for a grid with a ${NH4}-cell-wide
halo failed."
fi
#
#-----------------------------------------------------------------------
#
# Create the grid mosaic file for the grid without halo.
#
#-----------------------------------------------------------------------
#
make_grid_mosaic_file \
  grid_dir="${GRID_DIR}" \
  grid_fn="${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo0.nc" \
  mosaic_fn="${CRES}${DOT_OR_USCORE}mosaic.halo0.nc"
export err=$?
if [ $err -ne 0 ]; then
  err_exit "\
Call to function to generate the mosaic file for a grid without halo
failed."
fi
#
#-----------------------------------------------------------------------
#
# Create symlinks in the FIXLAM directory to the grid and mosaic files
# generated above in the GRID_DIR directory.
#
#-----------------------------------------------------------------------
#
link_fix \
  verbose="$VERBOSE" \
  file_group="grid"
export err=$?
if [ $err -ne 0 ]; then
  err_exit "Call to function to create symlinks to grid and mosaic files failed."
fi
#
#-----------------------------------------------------------------------
#
# Call a function (set_FV3nml_sfc_climo_filenames) to set the values of
# those variables in the forecast model's namelist file that specify the
# paths to the surface climatology files.  These files will either already
# be avaialable in a user-specified directory (SFC_CLIMO_DIR) or will be
# generated by the MAKE_SFC_CLIMO_TN task.  They (or symlinks to them)
# will be placed (or wll already exist) in the FIXLAM directory.
#
# Also, if running ensemble forecasts, call a function (set_FV3nml_stoch_params)
# to create a new FV3 namelist file for each ensemble member that contains
# a unique set of stochastic parameters (i.e. relative to the namelist
# files of the other members).
#
# Note that unless RUN_TASK_MAKE_GRID is set to "FALSE", the call to
# set_FV3nml_sfc_climo_filenames has to be performed here instead of
# earlier during experiment generation because the surface climatology
# file names depend on the grid resolution variable CRES, and that may
# not be available until the above steps in this script have been performed.
#
# Similarly, unless RUN_TASK_MAKE_GRID is set to "FALSE", the call to
# set_FV3nml_stoch_params must be performed here because it uses the
# namelist file generated by the call to set_FV3nml_sfc_climo_filenames
# as a starting point (base) and modifies it to add the stochastic
# parameters.  Thus, the changes made by set_FV3nml_sfc_climo_filenames
# must already be in the base namelist file.
#
#-----------------------------------------------------------------------
#
set_FV3nml_sfc_climo_filenames
export err=$?
if [ $err -ne 0 ]; then
  err_exit "\
Call to function to set surface climatology file names in the FV3 namelist
file failed."
fi

if [ "${DO_ENSEMBLE}" = TRUE ]; then
  set_FV3nml_stoch_params
  export err=$?
  if [ $err -ne 0 ]; then
    err_exit "\
Call to function to set stochastic parameters in the FV3 namelist files
for the various ensemble members failed."
  fi
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
Grid files with various halo widths generated successfully!!!

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
