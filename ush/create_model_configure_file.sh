#
#-----------------------------------------------------------------------
#
# This file defines a function that creates a model configuration file
# in the specified run directory.
#
#-----------------------------------------------------------------------
#
function create_model_configure_file() {
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
  local valid_args=(
cdate \
cycle_type \
cycle_subtype \
run_dir \
nthreads \
restart_hrs \
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
  local yyyy \
        mm \
        dd \
        hh \
        dot_quilting_dot \
        dot_print_esmf_dot \
        settings \
        model_config_fp
#
#-----------------------------------------------------------------------
#
# Create a model configuration file in the specified run directory.
#
#-----------------------------------------------------------------------
#
  print_info_msg "$VERBOSE" "
Creating a model configuration file (\"${MODEL_CONFIG_FN}\") in the specified
run directory (run_dir):
  run_dir = \"${run_dir}\""
#
# Extract from cdate the starting year, month, day, and hour of the forecast.
#
  yyyy=${cdate:0:4}
  mm=${cdate:4:2}
  dd=${cdate:6:2}
  hh=${cdate:8:2}
#
# Set parameters in the model configure file.
#
  dot_quilting_dot="."${QUILTING,,}"."
  dot_print_esmf_dot="."${PRINT_ESMF,,}"."
  dot_write_dopost_dot="."${WRITE_DOPOST,,}"."
#
# decide the forecast length for this cycle
#
  if [ -z "${FCST_LEN_HRS_CYCLES}" ]; then
    FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS}
  else
    num_fhrs=( "${#FCST_LEN_HRS_CYCLES[@]}" )
    ihh=`expr ${hh} + 0`
    if [ ${num_fhrs} -gt ${ihh} ]; then
      FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_CYCLES[${ihh}]}
    else
      FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS}
    fi
  fi
  print_info_msg "$VERBOSE" " The forecast length for cycle (\"${hh}\") is
                 ( \"${FCST_LEN_HRS_thiscycle}\") "

  if [ ${cycle_type} = "spinup" ]; then
    FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_SPINUP}
    if [ "${cycle_subtype}" == "ensinit" ]; then
      for cyc_start in "${CYCL_HRS_SPINSTART[@]}"; do
        if [ ${hh} -eq ${cyc_start} ]; then 
        FCST_LEN_HRS_thiscycle=$( expr ${DT_ATMOS}/3600 | bc -l )
        FCST_LEN_HRS_thiscycle=$( printf "%.5f\n" ${FCST_LEN_HRS_thiscycle} )
        NSOUT=1
        RESTART_INTERVAL=0
        print_info_msg "DT_ATMOS ${DT_ATMOS} FCST_LEN_HRS_thiscycle ${FCST_LEN_HRS_thiscycle} \
        NSOUT $NSOUT \
        RESTART_INTERVAL ${RESTART_INTERVAL} " 
        fi
      done
    fi
  fi

#
#-----------------------------------------------------------------------
#
# Create a multiline variable that consists of a yaml-compliant string
# specifying the values that the jinja variables in the template 
# model_configure file should be set to.
#
#-----------------------------------------------------------------------
#
  settings="\
  'start_year': $yyyy
  'start_month': $mm
  'start_day': $dd
  'start_hour': $hh
  'nhours_fcst': ${FCST_LEN_HRS_thiscycle}
  'fhrot': ${FHROT}
  'dt_atmos': ${DT_ATMOS}
  'restart_interval': ${restart_hrs}
  'write_dopost': ${dot_write_dopost_dot}
  'quilting': ${dot_quilting_dot}
  'output_grid': ${WRTCMP_output_grid}
  'nsout': ${NSOUT}
  'output_fh': ${OUTPUT_FH}"
#
# If the write-component is to be used, then specify a set of computational
# parameters and a set of grid parameters.  The latter depends on the type
# (coordinate system) of the grid that the write-component will be using.
#
  if [ "$QUILTING" = "TRUE" ]; then

    settings="${settings}
  'write_groups': ${WRTCMP_write_groups}
  'write_tasks_per_group': ${WRTCMP_write_tasks_per_group}
  'cen_lon': ${WRTCMP_cen_lon}
  'cen_lat': ${WRTCMP_cen_lat}
  'lon1': ${WRTCMP_lon_lwr_left}
  'lat1': ${WRTCMP_lat_lwr_left}"

    if [ "${WRTCMP_output_grid}" = "lambert_conformal" ]; then

      settings="${settings}
  'stdlat1': ${WRTCMP_stdlat1}
  'stdlat2': ${WRTCMP_stdlat2}
  'nx': ${WRTCMP_nx}
  'ny': ${WRTCMP_ny}
  'dx': ${WRTCMP_dx}
  'dy': ${WRTCMP_dy}
  'lon2': \"\"
  'lat2': \"\"
  'dlon': \"\"
  'dlat': \"\""

    elif [ "${WRTCMP_output_grid}" = "regional_latlon" ] || \
         [ "${WRTCMP_output_grid}" = "rotated_latlon" ]; then

      settings="${settings}
  'lon2': ${WRTCMP_lon_upr_rght}
  'lat2': ${WRTCMP_lat_upr_rght}
  'dlon': ${WRTCMP_dlon}
  'dlat': ${WRTCMP_dlat}
  'stdlat1': \"\"
  'stdlat2': \"\"
  'nx': \"\"
  'ny': \"\"
  'dx': \"\"
  'dy': \"\""

    fi

  fi

  print_info_msg $VERBOSE "
The variable \"settings\" specifying values to be used in the \"${MODEL_CONFIG_FN}\"
file has been set as follows:
#-----------------------------------------------------------------------
settings =
$settings"
#
#-----------------------------------------------------------------------
#
# Call a python script to generate the experiment's actual MODEL_CONFIG_FN
# file from the template file.
#
#-----------------------------------------------------------------------
#
  model_config_fp="${run_dir}/${MODEL_CONFIG_FN}"
  $USHdir/fill_jinja_template.py -q \
                                 -u "${settings}" \
                                 -t ${MODEL_CONFIG_TMPL_FP} \
                                 -o ${model_config_fp} || \
  print_err_msg_exit "\
Call to python script fill_jinja_template.py to create a \"${MODEL_CONFIG_FN}\"
file from a jinja2 template failed.  Parameters passed to this script are:
  Full path to template rocoto XML file:
    MODEL_CONFIG_TMPL_FP = \"${MODEL_CONFIG_TMPL_FP}\"
  Full path to output rocoto XML file:
    model_config_fp = \"${model_config_fp}\"
  Namelist settings specified on command line:
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

