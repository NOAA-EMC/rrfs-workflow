#
#-----------------------------------------------------------------------
#
# This file defines a function that, for an ensemble-enabled experiment 
# (i.e. for an experiment for which the workflow configuration variable 
# DO_ENSEMBLE has been set to "TRUE"), creates new namelist files with
# unique stochastic "seed" parameters, using a base namelist file in the 
# ${EXPTDIR} directory as a template. These new namelist files are stored 
# within each member directory housed within each cycle directory. Files 
# of any two ensemble members differ only in their stochastic "seed" 
# parameter values.  These namelist files are generated when this file is
# called as part of the RUN_FCST_TN task.  
#
#-----------------------------------------------------------------------
#
function set_FV3nml_ens_stoch_seeds() {
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
        iseed_lsm_spp \
        num_iseed_spp \
        num_iseed_lsm_spp \
        settings
#
#-----------------------------------------------------------------------
#
# For a given cycle and member, generate a namelist file with unique
# seed values.
#
#-----------------------------------------------------------------------
#
  ensmem_name="mem${ENSMEM_INDX}"

  fv3_nml_ensmem_fp_base="${run_dir}/input.nml_base"
  fv3_nml_ensmem_fp="${run_dir}/input.nml"

  ensmem_num=$((10#${ENSMEM_INDX}))

  settings="\
'nam_stochy': {"

  if [ ${DO_SPPT} = TRUE ]; then
  
  iseed_sppt=$(( cdate*1000 + ensmem_num*10 + 1 ))
    settings="$settings
  'iseed_sppt': ${iseed_sppt},"
  
  fi

  if [ ${DO_SHUM} = TRUE ]; then

  iseed_shum=$(( cdate*1000 + ensmem_num*10 + 2 ))
    settings="$settings
  'iseed_shum': ${iseed_shum},"

  fi

  if [ ${DO_SKEB} = TRUE ]; then

  iseed_skeb=$(( cdate*1000 + ensmem_num*10 + 3 ))
    settings="$settings
  'iseed_skeb': ${iseed_skeb},"
  
  fi
  settings="$settings
    }"

  settings="$settings
'nam_sppperts': {"

  if [ ${DO_SPP} = TRUE ]; then

    if [ ${DO_ENSFCST_MULPHY} = TRUE ]; then
      if [ $((ENSMEM_INDX)) = 1 ] || [ $((ENSMEM_INDX)) = 5 ]; then
          ISEED_SPP=(4 5 6 7)
      elif [ $((ENSMEM_INDX)) = 2 ] || [ $((ENSMEM_INDX)) = 3 ]; then
          ISEED_SPP=(4 5 6 7 8)
      else
          ISEED_SPP=(4 5 6)
      fi
    fi

  num_iseed_spp=${#ISEED_SPP[@]}
  for (( i=0; i<${num_iseed_spp}; i++ )); do
    iseed_spp[$i]=$(( cdate*1000 + ensmem_num*10 + ${ISEED_SPP[$i]} ))
  done

    settings="$settings
  'iseed_spp': [ $( printf "%s, " "${iseed_spp[@]}" ) ],"
  
  fi

  settings="$settings
    }"

  settings="$settings
'nam_sfcperts': {"

  if [ ${DO_LSM_SPP} = TRUE ]; then

  iseed_lsm_spp=$(( cdate*1000 + ensmem_num*10 + 9))
 
    settings="$settings
  'iseed_lndp': [ $( printf "%s, " "${iseed_lsm_spp[@]}" ) ],"
 
  fi

  settings="$settings
    }"

  $USHdir/set_namelist.py -q \
                          -n ${fv3_nml_ensmem_fp_base} \
                          -u "$settings" \
                          -o ${fv3_nml_ensmem_fp} || \
    print_err_msg_exit "\
Call to python script set_namelist.py to set the variables in the FV3
namelist file that specify the paths to the surface climatology files
failed.  Parameters passed to this script are:
  Full path to base namelist file:
    FV3_NML_FP = \"${FV3_NML_FP}\"
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
