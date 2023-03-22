#!/bin/bash
set +x
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

This is the ex-script for the task that copies/fetches to a local directory 
either from disk or HPSS) the external model files from which initial or 
boundary condition files for the FV3 will be generated.
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
valid_args=( \
"ics_or_lbcs" \
"use_user_staged_extrn_files" \
"extrn_mdl_cdate" \
"extrn_mdl_lbc_spec_fhrs" \
"extrn_mdl_fns_on_disk" \
"extrn_mdl_fns_on_disk2" \
"extrn_mdl_fns_in_arcv" \
"extrn_mdl_source_dir" \
"extrn_mdl_source_dir2" \
"extrn_mdl_staging_dir" \
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
# Load modules.
#
#-----------------------------------------------------------------------
#
case $MACHINE in

  "WCOSS2")
    module load wgrib2/2.0.8
    module list
    ;;  

  "HERA")
    module load gnu/9.2.0
    module load wgrib2/3.1.0
    wgrib2=/apps/wgrib2/3.1.0/gnu/9.2.0_ncep/bin/wgrib2
    ;;  

  "JET")
    module load intel/18.0.5.274
    module load wgrib2/2.0.8
    wgrib2=/apps/wgrib2/2.0.8/intel/18.0.5.274/bin/wgrib2
    ;;  

  *)  
    print_err_msg_exit "\
Wgrib2 has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  wgrib2 = `which wgrib2` "
    ;;  

esac
#
#-----------------------------------------------------------------------
#
# Set num_files_to_copy to the number of external model files that need
# to be copied or linked to from/at a location on disk.  Then set 
# extrn_mdl_fps_on_disk to the full paths of the external model files 
# on disk.
#
#-----------------------------------------------------------------------
#
num_files_to_copy="${#extrn_mdl_fns_on_disk[@]}"
prefix="${extrn_mdl_source_dir}/"
extrn_mdl_fps_on_disk=( "${extrn_mdl_fns_on_disk[@]/#/$prefix}" )
prefix2="${extrn_mdl_source_dir2}"
extrn_mdl_fps_on_disk2=( "${extrn_mdl_fns_on_disk2[@]/#/$prefix2}" )
#
#-----------------------------------------------------------------------
#
# Loop through the list of external model files and check whether they
# all exist on disk.  The counter num_files_found_on_disk keeps track of
# the number of external model files that were actually found on disk in
# the directory specified by extrn_mdl_source_dir.
#
#-----------------------------------------------------------------------
#
num_files_found_on_disk="0"
min_age="5"  # Minimum file age, in minutes.
#
#-----------------------------------------------------------------------
#
# Set the variable (data_src) that determines the source of the external
# model files (either disk or HPSS).
#
#-----------------------------------------------------------------------
#
data_src="disk"
#
#-----------------------------------------------------------------------
#
# If the source of the external model files is "disk", copy the files
# from the source directory on disk to a staging directory.
#
#-----------------------------------------------------------------------
#
extrn_mdl_fns_on_disk_str="( "$( printf "\"%s\" " "${extrn_mdl_fns_on_disk[@]}" )")"

if [ "${RUN_ENVIR}" = "nco" ]; then

    print_info_msg "
Creating links in staging directory (extrn_mdl_staging_dir) to external 
model files on disk (extrn_mdl_fns_on_disk) in the source directory 
(extrn_mdl_source_dir):
  extrn_mdl_staging_dir = \"${extrn_mdl_staging_dir}\"
  extrn_mdl_source_dir = \"${extrn_mdl_source_dir}\"
  extrn_mdl_fns_on_disk = ${extrn_mdl_fns_on_disk_str}"

  for fps in "${extrn_mdl_fps_on_disk[@]}" ; do
    if [ -f "$fps" ]; then
      #
      # Increment the counter that keeps track of the number of external
      # model files found on disk and print out an informational message.
      #
      ln_vrfy -sf -t ${extrn_mdl_staging_dir} ${fps}
     print_info_msg "
File fps exists on disk:
  fps = \"$fps\""
    fi
  done
else
    #
    # If the external model files are user-staged, then simply link to 
    # them.  Otherwise, if they are on the system disk, copy them to the
    # staging directory.
    #
    if [ "${use_user_staged_extrn_files}" = "TRUE" ]; then
      print_info_msg "
Creating symlinks in the staging directory (extrn_mdl_staging_dir) to the
external model files on disk (extrn_mdl_fns_on_disk) in the source directory 
(extrn_mdl_source_dir):
  extrn_mdl_source_dir = \"${extrn_mdl_source_dir}\"
  extrn_mdl_fns_on_disk = ${extrn_mdl_fns_on_disk_str}
  extrn_mdl_staging_dir = \"${extrn_mdl_staging_dir}\""
      ln_vrfy -sf -t ${extrn_mdl_staging_dir} ${extrn_mdl_fps_on_disk[@]}
    else
      print_info_msg "
Copying external model files on disk (extrn_mdl_fns_on_disk) from source
directory (extrn_mdl_source_dir) to staging directory (extrn_mdl_staging_dir):
  extrn_mdl_source_dir = \"${extrn_mdl_source_dir}\"
  extrn_mdl_fns_on_disk = ${extrn_mdl_fns_on_disk_str}
  extrn_mdl_staging_dir = \"${extrn_mdl_staging_dir}\""
      cp_vrfy ${extrn_mdl_fps_on_disk[@]} ${extrn_mdl_staging_dir}
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
Successfully copied or linked to external model files on disk needed for
generating lateral boundary conditions for the FV3 forecast!!!
Now move to time interpolation!!!
========================================================================"
#
#-----------------------------------------------------------------------
#
# Create a variable definitions file (a shell script) and save in it the
# values of several external-model-associated variables generated in this 
# script that will be needed by downstream workflow tasks.
#
#-----------------------------------------------------------------------
#
extrn_mdl_var_defns_fn="${EXTRN_MDL_LBCS_VAR_DEFNS_FN}"
extrn_mdl_var_defns_fp="${extrn_mdl_staging_dir}/${extrn_mdl_var_defns_fn}"
check_for_preexist_dir_file "${extrn_mdl_var_defns_fp}" "delete"

if [ "${data_src}" = "disk" ]; then
  extrn_mdl_fns_str="( "$( printf "\"%s\" " "${extrn_mdl_fns_on_disk[@]}" )")"
fi

#
#-----------------------------------------------------------------------
#

yyyymmdd=${extrn_mdl_cdate:0:8}
hh=${extrn_mdl_cdate:8:2}

echo extrn_mdl_cdate=${extrn_mdl_cdate}
echo " yyyymmddhh= ${yyyymmdd} ${hh} "

for files in "${extrn_mdl_fps_on_disk[@]}"; do
  file=$( basename "$files" )
  echo " Checking for $file "
  if [[ -f ${extrn_mdl_staging_dir}/$file ]]; then
    echo "Found ${extrn_mdl_staging_dir}/$file "
  else
    fcsthr=$( echo $file | awk '{print substr($0, length($0)-2)}' | sed 's/^0*//'  )

print_info_msg "
========================================================================

Missing $files for forecast hour $fcsthr ! 
Need to do time interpolation!

========================================================================"

    fcsthr_0=$(( fcsthr % 3 ))
    echo fcsthr_0=${fcsthr_0}
    fcsthr_m=$(( fcsthr - fcsthr_0 )) 
    echo fcsthr_m=${fcsthr_m}
    fcsthr_p=$(( fcsthr - fcsthr_0 + 3 )) 
    echo fcsthr_p=${fcsthr_p}
    fhrm=$( printf "%03d" ${fcsthr_m} )
    echo fhrm=${fhrm}
    fhrp=$( printf "%03d" ${fcsthr_p} )
    echo fhrp=${fhrp}
    in1=$( echo $file | sed 's/...$/'${fhrm}'/g' ) 
    echo in1=${in1}
    in2=$( echo $file | sed 's/...$/'${fhrp}'/g' ) 
    echo in2=${in2}
    vtime=$( date +%Y%m%d%H -d "${yyyymmdd} ${hh} +${fcsthr_m} hours" )
    echo vtime = $vtime
    a="vt=${vtime}"
    d1="${fcsthr} hour forecast"
    echo $d1
    c=$( expr ${fcsthr_0}/3 | bc -l )
    c1=$( printf "%.5f\n"  $c )
    b1=$( expr 1-$c1 | bc -l )
    echo " b1,c1= $b1 $c1 "

print_info_msg "
========================================================================
Deriving ${extrn_mdl_staging_dir}/$file 
based on
${extrn_mdl_staging_dir}/$in1 
and  
${extrn_mdl_staging_dir}/$in2
========================================================================"

    $wgrib2 ${extrn_mdl_staging_dir}/$in1 -rpn sto_1 -import_grib ${extrn_mdl_staging_dir}/$in2 -rpn sto_2 -set_grib_type same \
  -if ":$a:" \
     -rpn "rcl_1:$b1:*:rcl_2:$c1:*:+" -set_ftime "$d1" -set_scaling same same -grib_out ${extrn_mdl_staging_dir}/$file 
     
print_info_msg "
========================================================================
Done interpolating the GEFS lbcs files for hour \"${fcsthr}\"
========================================================================"

  fi

done

settings="\
DATA_SRC=\"${data_src}\"
EXTRN_MDL_CDATE=\"${extrn_mdl_cdate}\"
EXTRN_MDL_STAGING_DIR=\"${extrn_mdl_staging_dir}\"
EXTRN_MDL_FNS=${extrn_mdl_fns_str}"
#
# If the external model files obtained above were for generating LBCS (as
# opposed to ICs), then add to the external model variable definitions 
# file the array variable EXTRN_MDL_LBC_SPEC_FHRS containing the forecast 
# hours at which the lateral boundary conditions are specified.
#
extrn_mdl_lbc_spec_fhrs_str="( "$( printf "\"%s\" " "${extrn_mdl_lbc_spec_fhrs[@]}" )")"
settings="$settings
EXTRN_MDL_LBC_SPEC_FHRS=${extrn_mdl_lbc_spec_fhrs_str}"

{ cat << EOM >> ${extrn_mdl_var_defns_fp}
$settings
EOM
} || print_err_msg_exit "\
Heredoc (cat) command to create a variable definitions file associated
with the external model from which to generate ${ics_or_lbcs} returned with a 
nonzero status.  The full path to this variable definitions file is:
  extrn_mdl_var_defns_fp = \"${extrn_mdl_var_defns_fp}\""
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

