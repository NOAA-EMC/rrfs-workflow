#
#-----------------------------------------------------------------------
#
# This file defines a function that, for an ensemble-enabled experiment 
# (i.e. for an experiment for which the workflow configuration variable 
# DO_ENSEMBLE has been set to "TRUE"), creates new namelist files with
# unique stochastic "seed" parameters, using a base namelist file in the 
# ${EXPTDIR} directory. These new namelist files are stored within each
# member directory housed within each cycle directory in ${EXPTDIR}.
# Files of any two ensemble members differ only in their stochastic "seed" 
# parameter values.  These namelist files are generated when this file is
# called as part of the RUN_FCST_TN task. 
#
#-----------------------------------------------------------------------
#
function set_FV3nml_stoch_params() {
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
# Specify the set of valid argument names for this script/function.  Then
# process the arguments provided to this script/function (which should
# consist of a set of name-value pairs of the form arg1="value1", etc).
#
#-----------------------------------------------------------------------
#
  local valid_args=( \
     "cdate" \
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
  local i \
        ensmem_num \
        fv3_nml_ens_fp \
        iseed_shum \
        iseed_skeb \
        iseed_sppt \
        iseed_spp \
        settings
#
#-----------------------------------------------------------------------
#
# For a given cycle and member, generate a namelist file with unique 
# seed values.
#
#-----------------------------------------------------------------------
#
  fv3_nml_ensmem_fp_base="${CYCLE_DIR}${slash_ensmem_subdir}/fcst_fv3lam/input.nml_base"
  fv3_nml_ensmem_fp="${CYCLE_DIR}${slash_ensmem_subdir}/fcst_fv3lam/input.nml"
  ensmem_num=${ENSMEM_INDX}

  iseed_shum=$(( cdate*1000 + ensmem_num*10 + 2 ))
  iseed_skeb=$(( cdate*1000 + ensmem_num*10 + 3 ))
  iseed_sppt=$(( cdate*1000 + ensmem_num*10 + 1 ))
  iseed_spp=$(( cdate*1000 + ensmem_num*10 + 4 ))

if [[ "${ENSMEM_INDX}" = "1" && ${DO_ENSCONTROL} == "TRUE" ]]; then

    settings="\
'nam_stochy': {
    'iseed_shum': ${iseed_shum},
    'iseed_skeb': ${iseed_skeb},
    'iseed_sppt': ${iseed_sppt},  
    'sppt': -999.0
  }
'gfs_physics_nml': {
    'do_sppt': false
  }
'nam_spperts': {
    'iseed_spp': ${iseed_spp},
  }"

else

  settings="\
'nam_stochy': {
    'iseed_shum': ${iseed_shum},
    'iseed_skeb': ${iseed_skeb},
    'iseed_sppt': ${iseed_sppt},
   }
'nam_spperts': {
    'iseed_spp': ${iseed_spp},
   }"

fi

  $USHDIR/set_namelist.py -q \
                          -n ${fv3_nml_ensmem_fp_base} \
                          -u "$settings" \
                          -o ${fv3_nml_ensmem_fp} || \
    print_err_msg_exit "\
Call to python script set_namelist.py to set the variables in the FV3
namelist file that specify the paths to the surface climatology files
failed.  Parameters passed to this script are:
  Full path to base namelist file:
    FV3_NML_BASE_ENS_FP = \"${fv3_nml_ensmem_fp_base}\"
  Full path to output namelist file:
    fv3_nml_ensmem_fp = \"${fv3_nml_ensmem_fp}\"
  Namelist settings specified on command line (these have highest precedence):
    settings =
$settings"

#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
  { restore_shell_opts; } > /dev/null 2>&1

}

