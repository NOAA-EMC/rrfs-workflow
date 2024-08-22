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

This is the ex-script for the task that generates lateral boundary con-
dition (LBC) files (in NetCDF format) for all LBC update hours (except
hour zero).
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
"use_user_staged_extrn_files" \
"extrn_mdl_name" \
"extrn_mdl_cdate" \
"extrn_mdl_lbc_spec_fhrs" \
"extrn_mdl_fns_on_disk" \
"extrn_mdl_fns_on_disk2" \
"extrn_mdl_source_dir" \
"extrn_mdl_source_dir2" \
"extrn_mdl_staging_dir" \
"bcgrp" \
"bcgrpnum" \
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
# Set machine-dependent parameters.
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case "$MACHINE" in

  "WCOSS2")
    export OMP_STACKSIZE=1G
    export OMP_NUM_THREADS=${TPP_MAKE_LBCS}
    ncores=$(( NNODES_MAKE_LBCS*PPN_MAKE_LBCS ))
    APRUN="mpiexec -n ${ncores} -ppn ${PPN_MAKE_LBCS} --cpu-bind core --depth ${OMP_NUM_THREADS}"
    ;;

  "HERA")
    APRUN="srun --export=ALL"
    ;;

  "ORION")
    APRUN="srun --export=ALL"
    ;;

  "HERCULES")
    APRUN="srun --export=ALL"
    ;;

  "JET")
    APRUN="srun --export=ALL"
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
# If the location extrn_mdl_source_dir is a user-specified directory
# (i.e. if use_user_staged_extrn_files is set to "TRUE"), then if/when we
# encounter the first file that does not exist, we exit the script with
# an error message.  If extrn_mdl_source_dir is a system directory (i.e.
# if use_user_staged_extrn_files is not set to "TRUE"), then if/when we
# encounter the first file that does not exist or exists but is younger
# than a certain age, we break out of the loop.  The age cutoff is to
# ensure that files are not still being written to.
#
#-----------------------------------------------------------------------
#
num_files_found_on_disk="0"
min_age="5"  # Minimum file age, in minutes.

for fp in "${extrn_mdl_fps_on_disk[@]}"; do
  #
  # If the external model file exists, then...
  #
  if [ -f "$fp" ]; then
    #
    # Increment the counter that keeps track of the number of external
    # model files found on disk and print out an informational message.
    #
    num_files_found_on_disk=$(( num_files_found_on_disk+1 ))
    print_info_msg "
File fp exists on disk:
  fp = \"$fp\""
    #
    # If we are NOT searching for user-staged external model files, then
    # we also check that the current file is at least min_age minutes old.
    #
    if [ "${use_user_staged_extrn_files}" != "TRUE" ]; then

      if [ $( find "$fp" -mmin +${min_age} ) ]; then
        print_info_msg "
File fp is older than the minimum required age of min_age minutes:
  fp = \"$fp\"
  min_age = ${min_age} minutes"

      else
        print_info_msg "
File fp is NOT older than the minumum required age of min_age minutes:
  fp = \"$fp\"
  min_age = ${min_age} minutes
Not checking presence and age of remaining external model files on disk."
        break
      fi
    fi
  #
  # If the external model file does not exist, then...
  #
  else
    #
    # If an external model file is not found and we are searching for it
    # in a user-specified directory, print out an error message and exit.
    #
    if [ "${use_user_staged_extrn_files}" = "TRUE" ]; then
      err_exit "\
File fp does NOT exist on disk:
  fp = \"$fp\"
Please ensure that the directory specified by extrn_mdl_source_dir exists
and that all the files specified in the array extrn_mdl_fns_on_disk exist
within it:
  extrn_mdl_source_dir = \"${extrn_mdl_source_dir}\"
  extrn_mdl_fns_on_disk = ( $( printf "\"%s\" " "${extrn_mdl_fns_on_disk[@]}" ))"
    #
    # If an external model file is not found and we are searching for it
    # in a system directory, give up on the system directory.
    #
    else
      print_info_msg "
File fp does NOT exist on disk:
  fp = \"$fp\"
Not checking presence and age of remaining external model files on disk."
      break

    fi
  fi
done
#
#-----------------------------------------------------------------------
#
# Copy the files from the source directory on disk to a staging directory.
#
#-----------------------------------------------------------------------
#
extrn_mdl_fns_on_disk_str="( "$( printf "\"%s\" " "${extrn_mdl_fns_on_disk[@]}" )")"

print_info_msg "
Creating links in staging directory (extrn_mdl_staging_dir) to external
model files on disk (extrn_mdl_fns_on_disk) in the source directory
(extrn_mdl_source_dir):
extrn_mdl_staging_dir = \"${extrn_mdl_staging_dir}\"
extrn_mdl_source_dir = \"${extrn_mdl_source_dir}\"
extrn_mdl_fns_on_disk = ${extrn_mdl_fns_on_disk_str}"

if [ ${extrn_mdl_name} != GEFS ] ; then
  ln -sf -t ${extrn_mdl_staging_dir} ${extrn_mdl_fps_on_disk[@]}
elif [ ${extrn_mdl_name} = GEFS ] ; then
# Get GEFS files and do time interpolation using wgrib2
  length=${#extrn_mdl_fps_on_disk[@]}

  for (( j=0; j<length; j++ ));
  do
    fps=${extrn_mdl_fps_on_disk[$j]}
    fps2=${extrn_mdl_fps_on_disk2[$j]}
    fps_name=${extrn_mdl_fns_on_disk[$j]}
    if [ -f "$fps" ]; then
      #
      # Increment the counter that keeps track of the number of external
      # model files found on disk and print out an informational message.
      #
      cp ${fps} ${extrn_mdl_staging_dir}/${fps_name}
      if [ -f "$fps2" ]; then
        cat ${fps2} >>  ${extrn_mdl_staging_dir}/${fps_name}
      fi

      print_info_msg "
File fps exists on disk:
  fps = \"$fps\""
    fi
  done

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

      wgrib2 ${extrn_mdl_staging_dir}/$in1 -rpn sto_1 -import_grib ${extrn_mdl_staging_dir}/$in2 -rpn sto_2 -set_grib_type same \
    -if ":$a:" \
       -rpn "rcl_1:$b1:*:rcl_2:$c1:*:+" -set_ftime "$d1" -set_scaling same same -grib_out ${extrn_mdl_staging_dir}/$file

print_info_msg "
========================================================================
Done interpolating the GEFS lbcs files for hour \"${fcsthr}\"
========================================================================"
    fi
  done
fi

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of retrieving model files.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Successfully copied or linked to external model files on disk needed for
generating lateral boundary conditions for the RRFS forecast!!!
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set values of several external-model-associated variables.
#
#-----------------------------------------------------------------------
#
eval EXTRN_MDL_CDATE=${extrn_mdl_cdate}
extrn_mdl_fns_str="( "$( printf "\"%s\" " "${extrn_mdl_fns_on_disk[@]}" )")"
eval EXTRN_MDL_FNS=${extrn_mdl_fns_str}
extrn_mdl_lbc_spec_fhrs_str="( "$( printf "\"%s\" " "${extrn_mdl_lbc_spec_fhrs[@]}" )")"
eval EXTRN_MDL_LBC_SPEC_FHRS=${extrn_mdl_lbc_spec_fhrs_str}
#
#-----------------------------------------------------------------------
#
# Set physics-suite-dependent variable mapping table needed in the FORTRAN
# namelist file that the chgres_cube executable will read in.
#
#-----------------------------------------------------------------------
#
varmap_file=""

case "${CCPP_PHYS_SUITE}" in
#
  "FV3_GFS_v16" | \
  "FV3_GFS_v15p2" )
    varmap_file="GFSphys_var_map.txt"
    ;;
#
  "FV3_RRFS_v1beta" | \
  "FV3_GFS_v15_thompson_mynn_lam3km" | \
  "FV3_HRRR" | \
  "FV3_HRRR_gf" | \
  "FV3_HRRR_gf_nogwd" | \
  "FV3_RAP" | \
  "RRFS_sas" | \
  "RRFS_sas_nogwd" )
    if [ "${EXTRN_MDL_NAME_LBCS}" = "RAP" ] || \
       [ "${EXTRN_MDL_NAME_LBCS}" = "HRRR" ]; then
      varmap_file="GSDphys_var_map.txt"
    elif [ "${EXTRN_MDL_NAME_LBCS}" = "RRFS" ] || \
         [ "${EXTRN_MDL_NAME_LBCS}" = "NAM" ] || \
         [ "${EXTRN_MDL_NAME_LBCS}" = "FV3GFS" ] || \
         [ "${EXTRN_MDL_NAME_LBCS}" = "GEFS" ] || \
         [ "${EXTRN_MDL_NAME_LBCS}" = "GDASENKF" ] || \
         [ "${EXTRN_MDL_NAME_LBCS}" = "GSMGFS" ]; then
      varmap_file="GFSphys_var_map.txt"
    fi
    ;;
#
  *)
  err_exit "\
The variable \"varmap_file\" has not yet been specified for this physics
suite (CCPP_PHYS_SUITE):
  CCPP_PHYS_SUITE = \"${CCPP_PHYS_SUITE}\""
  ;;
#
esac
#
#-----------------------------------------------------------------------
#
# Set external-model-dependent variables that are needed in the FORTRAN
# namelist file that the chgres_cube executable will read in.  These are de-
# scribed below.  Note that for a given external model, usually only a
# subset of these all variables are set (since some may be irrelevant).
#
# external_model:
# Name of the external model from which we are obtaining the fields
# needed to generate the LBCs.
#
# fn_atm_nemsio:
# Name (not including path) of the nemsio file generated by the external
# model that contains the atmospheric fields.
#
# fn_sfc_nemsio:
# Name (not including path) of the nemsio file generated by the external
# model that contains the surface fields.
#
# input_type:
# The "type" of input being provided to chgres_cube.  This contains a combi-
# nation of information on the external model, external model file for-
# mat, and maybe other parameters.  For clarity, it would be best to
# eliminate this variable in chgres_cube and replace with with 2 or 3 others
# (e.g. extrn_mdl, extrn_mdl_file_format, etc).
#
# tracers_input:
# List of atmospheric tracers to read in from the external model file
# containing these tracers.
#
# tracers:
# Names to use in the output NetCDF file for the atmospheric tracers
# specified in tracers_input.  With the possible exception of GSD phys-
# ics, the elements of this array should have a one-to-one correspond-
# ence with the elements in tracers_input, e.g. if the third element of
# tracers_input is the name of the O3 mixing ratio, then the third ele-
# ment of tracers should be the name to use for the O3 mixing ratio in
# the output file.  For GSD physics, three additional tracers -- ice,
# rain, and water number concentrations -- may be specified at the end
# of tracers, and these will be calculated by chgres_cube.
#
#-----------------------------------------------------------------------
#

# GSK comments about chgres_cube:
#
# The following are the three atmsopheric tracers that are in the atmo-
# spheric analysis (atmanl) nemsio file for CDATE=2017100700:
#
#   "spfh","o3mr","clwmr"
#
# Note also that these are hardcoded in the code (file input_data.F90,
# subroutine read_input_atm_gfs_spectral_file), so that subroutine will
# break if tracers_input(:) is not specified as above.
#
# Note that there are other fields too ["hgt" (surface height (togography?)),
# pres (surface pressure), ugrd, vgrd, and tmp (temperature)] in the atmanl file, but those
# are not considered tracers (they're categorized as dynamics variables,
# I guess).
#
# Another note:  The way things are set up now, tracers_input(:) and
# tracers(:) are assumed to have the same number of elements (just the
# atmospheric tracer names in the input and output files may be differ-
# ent).  There needs to be a check for this in the chgres_cube code!!
# If there was a varmap table that specifies how to handle missing
# fields, that would solve this problem.
#
# Also, it seems like the order of tracers in tracers_input(:) and
# tracers(:) must match, e.g. if ozone mixing ratio is 3rd in
# tracers_input(:), it must also be 3rd in tracers(:).  How can this be checked?
#
# NOTE: Really should use a varmap table for GFS, just like we do for
# RAP/HRRR.
#

# A non-prognostic variable that appears in the field_table for GSD physics
# is cld_amt.  Why is that in the field_table at all (since it is a non-
# prognostic field), and how should we handle it here??

# I guess this works for FV3GFS but not for the spectral GFS since these
# variables won't exist in the spectral GFS atmanl files.
#  tracers_input="\"sphum\",\"liq_wat\",\"ice_wat\",\"rainwat\",\"snowwat\",\"graupel\",\"o3mr\""
#
# Not sure if tracers(:) should include "cld_amt" since that is also in
# the field_table for CDATE=2017100700 but is a non-prognostic variable.

external_model=""
fn_atm=""
fn_sfc=""
fn_grib2=""
input_type=""
tracers_input="\"\""
tracers="\"\""
#
#-----------------------------------------------------------------------
#
# If the external model for LBCs is one that does not provide the aerosol
# fields needed by Thompson microphysics (currently only the HRRR and
# RAP provide aerosol data) and if the physics suite uses Thompson
# microphysics, set the variable thomp_mp_climo_file in the chgres_cube
# namelist to the full path of the file containing aerosol climatology
# data.  In this case, this file will be used to generate approximate
# aerosol fields in the LBCs that Thompson MP can use.  Otherwise, set
# thomp_mp_climo_file to a null string.
#
#-----------------------------------------------------------------------
#
thomp_mp_climo_file=""
if [ "${EXTRN_MDL_NAME_LBCS}" != "HRRR" -a \
     "${EXTRN_MDL_NAME_LBCS}" != "RAP" ] && \
   [ "${SDF_USES_THOMPSON_MP}" = "TRUE" ]; then
  thomp_mp_climo_file="${THOMPSON_MP_CLIMO_FP}"
fi
#
#-----------------------------------------------------------------------
#
# Set other chgres_cube namelist variables depending on the external
# model used.
#
#-----------------------------------------------------------------------
#
case "${EXTRN_MDL_NAME_LBCS}" in

"GSMGFS")
  external_model="GSMGFS"
  input_type="gfs_gaussian_nemsio" # For spectral GFS Gaussian grid in nemsio format.
  tracers_input="[\"spfh\",\"clwmr\",\"o3mr\"]"
  tracers="[\"sphum\",\"liq_wat\",\"o3mr\"]"
  ;;

"FV3GFS")
  if [ "${FV3GFS_FILE_FMT_LBCS}" = "nemsio" ]; then
    external_model="FV3GFS"
    input_type="gaussian_nemsio"     # For FV3-GFS Gaussian grid in nemsio format.
    tracers_input="[\"spfh\",\"clwmr\",\"o3mr\",\"icmr\",\"rwmr\",\"snmr\",\"grle\"]"
    tracers="[\"sphum\",\"liq_wat\",\"o3mr\",\"ice_wat\",\"rainwat\",\"snowwat\",\"graupel\"]"
  elif [ "${FV3GFS_FILE_FMT_LBCS}" = "grib2" ]; then
    external_model="GFS"
    fn_grib2="${EXTRN_MDL_FNS[0]}"
    input_type="grib2"
  elif [ "${FV3GFS_FILE_FMT_ICS}" = "netcdf" ]; then
    tracers_input="[\"spfh\",\"clwmr\",\"o3mr\",\"icmr\",\"rwmr\",\"snmr\",\"grle\"]"
    tracers="[\"sphum\",\"liq_wat\",\"o3mr\",\"ice_wat\",\"rainwat\",\"snowwat\",\"graupel\"]"
    external_model="FV3GFS"
    input_type="gaussian_netcdf"
  fi
  ;;

"GDASENKF")
  tracers_input="[\"spfh\",\"clwmr\",\"o3mr\",\"icmr\",\"rwmr\",\"snmr\",\"grle\"]"
  tracers="[\"sphum\",\"liq_wat\",\"o3mr\",\"ice_wat\",\"rainwat\",\"snowwat\",\"graupel\"]"
  external_model="GFS"
  input_type="gaussian_netcdf"
  fn_atm="${EXTRN_MDL_FNS[0]}"
  fn_sfc="${EXTRN_MDL_FNS[1]}"
  ;;

"GEFS")
  external_model="GFS"
  fn_grib2="${EXTRN_MDL_FNS[0]}"
  input_type="grib2"
  ;;

"RAP")
  external_model="RAP"
  input_type="grib2"
  ;;

"HRRR")
  external_model="HRRR"
  input_type="grib2"
;;

"NAM")
  external_model="NAM"
  input_type="grib2"
  ;;

"RRFS")
  external_model="NAM"
  input_type="grib2"
  ;;

*)
  err_exit "\
External-model-dependent namelist variables have not yet been specified
for this external LBC model (EXTRN_MDL_NAME_LBCS):
  EXTRN_MDL_NAME_LBCS = \"${EXTRN_MDL_NAME_LBCS}\""
  ;;

esac
#
#-----------------------------------------------------------------------
#
# Loop through the LBC update times and run chgres_cube for each such time to
# obtain an LBC file for each that can be used as input to the FV3-LAM.
#
#-----------------------------------------------------------------------
#
num_fhrs="${#EXTRN_MDL_LBC_SPEC_FHRS[@]}"
bcgrp10=${bcgrp#0}
bcgrpnum10=${bcgrpnum#0}
for (( ii=0; ii<${num_fhrs}; ii=ii+bcgrpnum10 )); do
  i=$(( ii + bcgrp10 ))
  if [ ${i} -lt ${num_fhrs} ]; then
    echo " group ${bcgrp10} processes member ${i}"
#
# Get the forecast hour of the external model.
#
  fhr="${EXTRN_MDL_LBC_SPEC_FHRS[$i]}"
#
# Set external model output file name and file type/format.  Note that
# these are now inputs into chgres_cube.
#
  fn_atm=""
  fn_grib2=""

  case "${EXTRN_MDL_NAME_LBCS}" in
  "GSMGFS")
    fn_atm="${EXTRN_MDL_FNS[$i]}"
    ;;
  "FV3GFS")
    if [ "${FV3GFS_FILE_FMT_LBCS}" = "nemsio" ]; then
      fn_atm="${EXTRN_MDL_FNS[$i]}"
    elif [ "${FV3GFS_FILE_FMT_LBCS}" = "grib2" ]; then
      fn_grib2="${EXTRN_MDL_FNS[$i]}"
    elif [ "${FV3GFS_FILE_FMT_LBCS}" = "netcdf" ]; then
      fn_atm="${EXTRN_MDL_FNS[$i]}"
    fi
    ;;
  "GDASENKF")
    fn_atm="${EXTRN_MDL_FNS[0][$i]}"
    fn_sfc="${EXTRN_MDL_FNS[1][$i]}"
    ;;
  "GEFS")
    fn_grib2="${EXTRN_MDL_FNS[$i]}"
    ;;
  "RAP")
    fn_grib2="${EXTRN_MDL_FNS[$i]}"
    ;;
  "HRRR")
    fn_grib2="${EXTRN_MDL_FNS[$i]}"
    ;;
  "NAM")
    fn_grib2="${EXTRN_MDL_FNS[$i]}"
    ;;
  "RRFS")
    fn_grib2="${EXTRN_MDL_FNS[$i]}"
    ;;
  *)
    err_exit "\
The external model output file name to use in the chgres_cube FORTRAN name-
list file has not specified for this external LBC model (EXTRN_MDL_NAME_LBCS):
  EXTRN_MDL_NAME_LBCS = \"${EXTRN_MDL_NAME_LBCS}\""
    ;;
  esac
#
# Get the starting date (year, month, and day together), month, day, and
# hour of the the external model forecast.  Then add the forecast hour
# to it to get a date and time corresponding to the current forecast time.
#
  yyyymmdd="${EXTRN_MDL_CDATE:0:8}"
  mm="${EXTRN_MDL_CDATE:4:2}"
  dd="${EXTRN_MDL_CDATE:6:2}"
  hh="${EXTRN_MDL_CDATE:8:2}"

  cdate_crnt_fhr=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${fhr} hours" "+%Y%m%d%H" )
#
# Get the month, day, and hour corresponding to the current forecast time
# of the the external model.
#
  mm="${cdate_crnt_fhr:4:2}"
  dd="${cdate_crnt_fhr:6:2}"
  hh="${cdate_crnt_fhr:8:2}"
#
# Build the FORTRAN namelist file that chgres_cube will read in.
#

#
# Create a multiline variable that consists of a yaml-compliant string
# specifying the values that the namelist variables need to be set to
# (one namelist variable per line, plus a header and footer).  Below,
# this variable will be passed to a python script that will create the
# namelist file.
#
# IMPORTANT:
# If we want a namelist variable to be removed from the namelist file,
# in the "settings" variable below, we need to set its value to the
# string "null".  This is equivalent to setting its value to
#    !!python/none
# in the base namelist file specified by FV3_NML_BASE_SUITE_FP or the
# suite-specific yaml settings file specified by FV3_NML_YAML_CONFIG_FP.
#
# It turns out that setting the variable to an empty string also works
# to remove it from the namelist!  Which is better to use??
#
  settings="
'config': {
 'fix_dir_target_grid': ${FIXLAM},
 'mosaic_file_target_grid': ${FIXLAM}/${CRES}${DOT_OR_USCORE}mosaic.halo$((10#${NH4})).nc,
 'orog_dir_target_grid': ${FIXLAM},
 'orog_files_target_grid': ${CRES}${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo$((10#${NH4})).nc,
 'vcoord_file_target_grid': ${FIXam}/${VCOORD_FILE},
 'varmap_file': ${UFS_UTILS_DIR}/parm/varmap_tables/${varmap_file},
 'data_dir_input_grid': ${extrn_mdl_staging_dir},
 'atm_files_input_grid': ${fn_atm},
 'grib2_file_input_grid': \"${fn_grib2}\",
 'cycle_mon': $((10#${mm})),
 'cycle_day': $((10#${dd})),
 'cycle_hour': $((10#${hh})),
 'convert_atm': True,
 'regional': 2,
 'halo_bndy': $((10#${NH4})),
 'halo_blend': $((10#${HALO_BLEND})),
 'input_type': ${input_type},
 'external_model': ${external_model},
 'tracers_input': ${tracers_input},
 'tracers': ${tracers},
 'thomp_mp_climo_file': ${thomp_mp_climo_file},
}
"
#
# Call the python script to create the namelist file.
#
  nml_fn="fort.41"
  ${USHdir}/set_namelist.py -q -u "$settings" -o ${nml_fn} || \
    err_exit "\
Call to python script set_namelist.py to set the variables in the namelist
file read in by the ${exec_fn} executable failed.  Parameters passed to
this script are:
  Name of output namelist file:
    nml_fn = \"${nml_fn}\"
  Namelist settings specified on command line (these have highest precedence):
    settings =
$settings"
#
#-----------------------------------------------------------------------
#
# Subset RRFS North America grib2 file for fire weather grid.
# +/- 10 degrees latitude/longitude around center lat/lon point.
#
#-----------------------------------------------------------------------
#
  if [ ${PREDEF_GRID_NAME} = "RRFS_FIREWX_1.5km" ]; then
    sp_lon=$(echo "$LON_CTR + 360" | bc -l)
    sp_lat=$(echo "(90 - $LAT_CTR) * -1" | bc -l)
    gridspecs="rot-ll:${sp_lon}:${sp_lat}:0 -10:801:0.025 -10:801:0.025"
    lbc_spec_fhrs=( "${EXTRN_MDL_LBC_SPEC_FHRS[$i]}" ) 
    fcst_hhh=$(( ${lbc_spec_fhrs} - ${EXTRN_MDL_LBCS_OFFSET_HRS} ))
    fcst_hhh_FV3LAM=`printf %3.3i $fcst_hhh`
    fn_grib2_subset=rrfs.t${hh}z.prslev.f${fcst_hhh_FV3LAM}.subset.grib2

    wgrib2 ${extrn_mdl_staging_dir}/${fn_grib2} -set_grib_type c3b \
      -new_grid_winds grid -new_grid ${gridspecs} ${extrn_mdl_staging_dir}/${fn_grib2_subset}
    mv ${extrn_mdl_staging_dir}/${fn_grib2_subset} ${extrn_mdl_staging_dir}/${fn_grib2}
  fi
#
#-----------------------------------------------------------------------
#
# Run chgres_cube.
#
#-----------------------------------------------------------------------
#
  export pgm="chgres_cube"
  . prep_step

  ${APRUN} ${EXECdir}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
#
# Move LBCs file for the current lateral boundary update time to the LBCs
# work directory.  Note that we rename the file by including in its name
# the forecast hour of the FV3-LAM (which is not necessarily the same as
# that of the external model since their start times may be offset).
#
  lbc_spec_fhrs=( "${EXTRN_MDL_LBC_SPEC_FHRS[$i]}" ) 
  fcst_hhh=$(( ${lbc_spec_fhrs} - ${EXTRN_MDL_LBCS_OFFSET_HRS} ))
  fcst_hhh_FV3LAM=`printf %3.3i $fcst_hhh`
  mv gfs.bndy.nc ${lbcs_dir}/gfs_bndy.tile7.${fcst_hhh_FV3LAM}.nc
# copy results to nwges for longe time disk storage.
  cp ${lbcs_dir}/gfs_bndy.tile7.${fcst_hhh_FV3LAM}.nc ${lbcs_nwges_dir}/.

  fi
done
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Lateral boundary condition (LBC) files (in NetCDF format) generated suc-
cessfully for all LBC update hours (except hour zero)!!!

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
