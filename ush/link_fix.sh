#!/bin/bash

#
#-----------------------------------------------------------------------
#
# This file defines a function that <need to complete>...
#
#-----------------------------------------------------------------------
#
function link_fix() {
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
  local scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
  local scrfunc_fn=$( basename "${scrfunc_fp}" )
  local scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Get the name of this function.
#
#-----------------------------------------------------------------------
#
  local func_name="${FUNCNAME[0]}"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names that this script/function can
# accept.  Then process the arguments provided to it (which should con-
# sist of a set of name-value pairs of the form arg1="value1", etc).
#
#-----------------------------------------------------------------------
#
  local valid_args=( \
"verbose" \
"file_group" \
"output_varname_res_in_filenames" \
  )
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
# Declare local variables.
#
#-----------------------------------------------------------------------
#
  local valid_vals_verbose \
        valid_vals_file_group \
        fns \
        fps \
        run_task \
        sfc_climo_fields \
        num_fields \
        i \
        ii \
        res_prev \
        res \
        fp_prev \
        fp \
        fn \
        relative_or_null \
        cres \
        tmp \
        fns_sfc_climo_with_halo_in_fn \
        fns_sfc_climo_no_halo_in_fn \
        target \
        symlink
#
#-----------------------------------------------------------------------
#
# Set the valid values that various input arguments can take on and then
# ensure that the values passed in are one of these valid values.
#
#-----------------------------------------------------------------------
#
  valid_vals_verbose=( "TRUE" "FALSE" )
  check_var_valid_value "verbose" "valid_vals_verbose"

  valid_vals_file_group=( "grid" "orog" "sfc_climo" )
  check_var_valid_value "file_group" "valid_vals_file_group"
#
#-----------------------------------------------------------------------
#
# Create symlinks in the FIXLAM directory pointing to the grid files.
# These symlinks are needed by the make_orog, make_sfc_climo, make_ic,
# make_lbc, and/or run_fcst tasks.
#
# Note that we check that each target file exists before attempting to 
# create symlinks.  This is because the "ln" command will create sym-
# links to non-existent targets without returning with a nonzero exit
# code.
#
#-----------------------------------------------------------------------
#
  print_info_msg "$verbose" "
Creating links in the FIXLAM directory to the grid files..."
#
#-----------------------------------------------------------------------
#
# Create globbing patterns for grid, orography, and surface climatology
# files.
#
#
# For grid files (i.e. file_group set to "grid"), symlinks are created
# in the FIXLAM directory to files (of the same names) in the GRID_DIR.
# These symlinks/files and the reason each is needed is listed below:
#
# 1) "C*.mosaic.halo${NHW}.nc"
#    This mosaic file for the wide-halo grid (i.e. the grid with a ${NHW}-
#    cell-wide halo) is needed as an input to the orography filtering 
#    executable in the orography generation task.  The filtering code
#    extracts from this mosaic file the name of the file containing the
#    grid on which it will generate filtered topography.  Note that the
#    orography generation and filtering are both performed on the wide-
#    halo grid.  The filtered orography file on the wide-halo grid is then
#    shaved down to obtain the filtered orography files with ${NH3}- and
#    ${NH4}-cell-wide halos.
#
#    The raw orography generation step in the make_orog task requires the
#    following symlinks/files:
#
#    a) C*.mosaic.halo${NHW}.nc
#       The script for the make_orog task extracts the name of the grid
#       file from this mosaic file; this name should be 
#       "C*.grid.tile${TILE_RGNL}.halo${NHW}.nc".
#
#    b) C*.grid.tile${TILE_RGNL}.halo${NHW}.nc
#       This is the 
#       The script for the make_orog task passes the name of the grid 
#       file (extracted above from the mosaic file) to the orography 
#       generation executable.  The executable then
#       reads in this grid file and generates a raw orography
#       file on the grid.  The raw orography file is initially renamed "out.oro.nc",
#       but for clarity, it is then renamed "C*.raw_orog.tile${TILE_RGNL}.halo${NHW}.nc".
#
#    c) The fixed files thirty.second.antarctic.new.bin, landcover30.fixed, 
#       and gmted2010.30sec.int.
#
#    The orography filtering step in the make_orog task requires the 
#    following symlinks/files:
#
#    a) C*.mosaic.halo${NHW}.nc
#       This is the mosaic file for the wide-halo grid.  The orography
#       filtering executable extracts from this file the name of the grid
#       file containing the wide-halo grid (which should be 
#       "${CRES}.grid.tile${TILE_RGNL}.halo${NHW}.nc").  The executable then
#       looks for this grid file IN THE DIRECTORY IN WHICH IT IS RUNNING.
#       Thus, before running the executable, the script creates a symlink in this run directory that
#       points to the location of the actual wide-halo grid file.
#
#    b) C*.raw_orog.tile${TILE_RGNL}.halo${NHW}.nc
#       This is the raw orography file on the wide-halo grid.  The script
#       for the make_orog task copies this file to a new file named 
#       "C*.filtered_orog.tile${TILE_RGNL}.halo${NHW}.nc" that will be
#       used as input to the orography filtering executable.  The executable
#       will then overwrite the contents of this file with the filtered orography.
#       Thus, the output of the orography filtering executable will be
#       the file C*.filtered_orog.tile${TILE_RGNL}.halo${NHW}.nc.
#
#    The shaving step in the make_orog task requires the following:
#
#    a) C*.filtered_orog.tile${TILE_RGNL}.halo${NHW}.nc
#       This is the filtered orography file on the wide-halo grid.
#       This gets shaved down to two different files:
#
#        i) ${CRES}.oro_data.tile${TILE_RGNL}.halo${NH0}.nc
#           This is the filtered orography file on the halo-0 grid.
#
#       ii) ${CRES}.oro_data.tile${TILE_RGNL}.halo${NH4}.nc
#           This is the filtered orography file on the halo-4 grid.
#
#       Note that the file names of the shaved files differ from that of
#       the initial unshaved file on the wide-halo grid in that the field
#       after ${CRES} is now "oro_data" (not "filtered_orog") to comply
#       with the naming convention used more generally.
#
# 2) "C*.mosaic.halo${NH4}.nc"
#    This mosaic file for the grid with a 4-cell-wide halo is needed as
#    an input to the surface climatology generation executable.  The 
#    surface climatology generation code reads from this file the number
#    of tiles (which should be 1 for a regional grid) and the tile names.
#    More importantly, using the ESMF function ESMF_GridCreateMosaic(),
#    it creates a data object of type esmf_grid; the grid information
#    in this object is obtained from the grid file specified in the mosaic
#    file, which should be "C*.grid.tile${TILE_RGNL}.halo${NH4}.nc".  The
#    dimensions specified in this grid file must match the ones specified
#    in the (filtered) orography file "C*.oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
#    that is also an input to the surface climatology generation executable.
#    If they do not, then the executable will crash with an ESMF library
#    error (something like "Arguments are incompatible").
#
#    Thus, for the make_sfc_climo task, the following symlinks/files must
#    exist:
#    a) "C*.mosaic.halo${NH4}.nc"
#    b) "C*.grid.tile${TILE_RGNL}.halo${NH4}.nc"
#    c) "C*.oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
#
# 3) 
#
#
#-----------------------------------------------------------------------
#
  case "${file_group}" in
#
  "grid")
    fns=( \
    "C*${DOT_OR_USCORE}mosaic.halo${NHW}.nc" \
    "C*${DOT_OR_USCORE}mosaic.halo${NH4}.nc" \
    "C*${DOT_OR_USCORE}mosaic.halo${NH3}.nc" \
    "C*${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NHW}.nc" \
    "C*${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH3}.nc" \
    "C*${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH4}.nc" \
        )
    if [ "${DO_NON_DA_RUN}" = "FALSE" ] && [ "${RUN_TASK_MAKE_GRID}" = "FALSE" ]; then
      grid_name=( "RRFS_CONUS_3km" "RRFS_NA_3km" )
      if [[ ${grid_name[@]} =~ "${PREDEF_GRID_NAME}" ]] ; then
        fns+=( \
        "C*${DOT_OR_USCORE}fvcom_mask.nc" \
             )
      fi
    fi
    fps=( "${fns[@]/#/${GRID_DIR}/}" )
    run_task="${RUN_TASK_MAKE_GRID}"
    ;;
#
  "orog")
    fns=( \
    "C*${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo${NH0}.nc" \
    "C*${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo${NH4}.nc" \
        )
    suites=( "FV3_HRRR" "FV3_RAP" "FV3_HRRR_gf" "FV3_GFS_v15_thompson_mynn_lam3km" )
    if [[ ${suites[@]} =~ "${CCPP_PHYS_SUITE}" ]] ; then
      fns+=( \
      "C*${DOT_OR_USCORE}oro_data_ss.tile${TILE_RGNL}.halo${NH0}.nc" \
      "C*${DOT_OR_USCORE}oro_data_ls.tile${TILE_RGNL}.halo${NH0}.nc" \
           )
    fi
    fps=( "${fns[@]/#/${OROG_DIR}/}" )
    run_task="${RUN_TASK_MAKE_OROG}"
    ;;
#
# The following list of symlinks (which have the same names as their
# target files) need to be created made in order for the make_ics and
# make_lbcs tasks (i.e. tasks involving chgres_cube) to work.
#
  "sfc_climo")
    num_fields=${#SFC_CLIMO_FIELDS[@]}
    fns=()
    for (( i=0; i<${num_fields}; i++ )); do
      ii=$((2*i))
      fns[$ii]="C*.${SFC_CLIMO_FIELDS[$i]}.tile${TILE_RGNL}.halo${NH0}.nc"
      fns[$ii+1]="C*.${SFC_CLIMO_FIELDS[$i]}.tile${TILE_RGNL}.halo${NH4}.nc"
    done
    fps=( "${fns[@]/#/${SFC_CLIMO_DIR}/}" )
    run_task="${RUN_TASK_MAKE_SFC_CLIMO}"
    ;;
#
  esac
#
#-----------------------------------------------------------------------
#
# Find all files matching the globbing patterns and make sure that they
# all have the same resolution (an integer) in their names.
#
#-----------------------------------------------------------------------
#
  i=0
  res_prev=""
  res=""
  fp_prev=""

  for fp in ${fps[@]}; do

    fn=$( basename $fp )
  
    res=$( printf "%s" $fn | sed -n -r -e "s/^C([0-9]*).*/\1/p" )
    if [ -z $res ]; then
      print_err_msg_exit "\
The resolution could not be extracted from the current file's name.  The
full path to the file (fp) is:
  fp = \"${fp}\"
This may be because fp contains the * globbing character, which would
imply that no files were found that match the globbing pattern specified
in fp."
    fi

    if [ $i -gt 0 ] && [ ${res} != ${res_prev} ]; then
      print_err_msg_exit "\
The resolutions (as obtained from the file names) of the previous and 
current file (fp_prev and fp, respectively) are different:
  fp_prev = \"${fp_prev}\"
  fp      = \"${fp}\"
Please ensure that all files have the same resolution."
    fi

    i=$((i+1))
    fp_prev="$fp"
    res_prev=${res}

  done
#
#-----------------------------------------------------------------------
#
# If the output variable name is not set to a null string, set it.  This
# variable is just the resolution extracted from the file names in the 
# specified file group.  Note that if the output variable name is not
# specified in the call to this function, the process_args function will
# set it to a null string, in which case no output variable will be set.
#
#-----------------------------------------------------------------------
#
  if [ ! -z "${output_varname_res_in_filenames}" ]; then
    eval ${output_varname_res_in_filenames}="$res"
  fi
#
#-----------------------------------------------------------------------
#
# Replace the * globbing character in the set of globbing patterns with 
# the resolution.  This will result in a set of (full paths to) specific
# files.
#
#-----------------------------------------------------------------------
#
  fps=( "${fps[@]/\*/$res}" )
#
#-----------------------------------------------------------------------
#
# In creating the various symlinks below, it is convenient to work in 
# the FIXLAM directory.  We will change directory back to the original
# later below.
#
#-----------------------------------------------------------------------
#
  cd "$FIXLAM"
#
#-----------------------------------------------------------------------
#
# Use the set of full file paths generated above as the link targets to 
# create symlinks to these files in the FIXLAM directory.
#
#-----------------------------------------------------------------------
#
  relative_or_null=""
  if [ "${run_task}" = "TRUE" ] && [ "${MACHINE}" != "WCOSS_CRAY" ] ; then
    relative_or_null="--relative"
  fi

  for fp in "${fps[@]}"; do
    if [ -f "$fp" ]; then
      ln -sf ${relative_or_null} $fp .
    else
      print_err_msg_exit "\
Cannot create symlink because target file (fp) does not exist:
  fp = \"${fp}\""
    fi
  done
#
#-----------------------------------------------------------------------
#
# Set the C-resolution based on the resolution appearing in the file 
# names.
#
#-----------------------------------------------------------------------
#
  cres="C$res"
#
#-----------------------------------------------------------------------
#
# If considering grid files, create a symlink to the halo4 grid file
# that does not contain the halo size in its name.  This is needed by 
# the tasks that generate the initial and lateral boundary condition 
# files.
#
#-----------------------------------------------------------------------
#
  if [ "${file_group}" = "grid" ]; then

    target="${cres}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH4}.nc"
    symlink="${cres}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.nc"
    if [ -f "${target}" ]; then
      ln -sf $target $symlink
    else
      print_err_msg_exit "\
Cannot create symlink because the target file (target) in the directory 
specified by FIXLAM does not exist:
  FIXLAM = \"${FIXLAM}\"
  target = \"${target}\""
    fi
#
# The surface climatology file generation code looks for a grid file 
# having a name of the form "C${GFDLgrid_RES}_grid.tile7.halo4.nc" (i.e.
# the resolution used in this file is that of the number of grid points
# per horizontal direction per tile, just like in the global model).  
# Thus, if we are running this code, if the grid is of GFDLgrid type, and
# if we are not using GFDLgrid_RES in filenames (i.e. we are using the 
# equivalent global uniform grid resolution instead), then create a link
# whose name uses the GFDLgrid_RES that points to the link whose name uses
# the equivalent global uniform resolution.
#
    if [ "${RUN_TASK_MAKE_SFC_CLIMO}" = "TRUE" ] && \
       [ "${GRID_GEN_METHOD}" = "GFDLgrid" ] && \
       [ "${GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES}" = "FALSE" ]; then

      target="${cres}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH4}.nc"
      symlink="C${GFDLgrid_RES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.nc"
      if [ -f "${target}" ]; then
        ln -sf $target $symlink
      else
        print_err_msg_exit "\
Cannot create symlink because the target file (target) in the directory 
specified by FIXLAM does not exist:
  FIXLAM = \"${FIXLAM}\"
  target = \"${target}\""
      fi

    fi

  fi
#
#-----------------------------------------------------------------------
#
# If considering surface climatology files, create symlinks to the sur-
# face climatology files that do not contain the halo size in their 
# names.  These are needed by the task that generates the initial condi-
# tion files.
#
#-----------------------------------------------------------------------
#
  if [ "${file_group}" = "sfc_climo" ]; then

    tmp=( "${SFC_CLIMO_FIELDS[@]/#/${cres}.}" )
    fns_sfc_climo_with_halo_in_fn=( "${tmp[@]/%/.tile${TILE_RGNL}.halo${NH4}.nc}" )
    fns_sfc_climo_no_halo_in_fn=( "${tmp[@]/%/.tile${TILE_RGNL}.nc}" )

    for (( i=0; i<${num_fields}; i++ )); do
      target="${fns_sfc_climo_with_halo_in_fn[$i]}"
      symlink="${fns_sfc_climo_no_halo_in_fn[$i]}"
      if [ -f "$target" ]; then
        ln -sf $target $symlink
      else
        print_err_msg_exit "\
Cannot create symlink because target file (target) does not exist:
  target = \"${target}\""
      fi
    done
#
# In order to be able to specify the surface climatology file names in 
# the forecast model's namelist file, in the FIXLAM directory a symlink
# must be created for each surface climatology field that has "tile1" in
# its name (and no "halo") and which points to the corresponding "tile7.halo0" 
# file.
#
    tmp=( "${SFC_CLIMO_FIELDS[@]/#/${cres}.}" )
    fns_sfc_climo_tile7_halo0_in_fn=( "${tmp[@]/%/.tile${TILE_RGNL}.halo${NH0}.nc}" )
    fns_sfc_climo_tile1_no_halo_in_fn=( "${tmp[@]/%/.tile1.nc}" )

    for (( i=0; i<${num_fields}; i++ )); do
      target="${fns_sfc_climo_tile7_halo0_in_fn[$i]}"
      symlink="${fns_sfc_climo_tile1_no_halo_in_fn[$i]}"
      if [ -f "$target" ]; then
        ln -sf $target $symlink
      else
        print_err_msg_exit "\
Cannot create symlink because target file (target) does not exist:
  target = \"${target}\""
      fi
    done

  fi
#
#-----------------------------------------------------------------------
#
# Change directory back to original one.
#
#-----------------------------------------------------------------------
#
  cd -
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the start of this script/function.
#
#-----------------------------------------------------------------------
#
  { restore_shell_opts; } > /dev/null 2>&1

}
