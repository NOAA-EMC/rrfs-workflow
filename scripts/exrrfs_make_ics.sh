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

This is the ex-script for the task that generates initial condition
(IC), surface, and zeroth hour lateral boundary condition (LBC0) files
(in NetCDF format) for the RRFS.
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
"extrn_mdl_cdate" \
"extrn_mdl_lbc_spec_fhrs" \
"extrn_mdl_fns_on_disk" \
"extrn_mdl_fns_on_disk2" \
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
# Set machine-dependent parameters.
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case "$MACHINE" in

  "WCOSS2")
    export OMP_STACKSIZE=1G
    export OMP_NUM_THREADS=${TPP_MAKE_ICS}
    export FI_OFI_RXM_SAR_LIMIT=3145728
    export FI_MR_CACHE_MAX_COUNT=0
    export MPICH_OFI_STARTUP_CONNECT=1
    ncores=$(( NNODES_MAKE_ICS*PPN_MAKE_ICS ))
    APRUN="mpiexec -n ${ncores} -ppn ${PPN_MAKE_ICS} --cpu-bind core --depth ${OMP_NUM_THREADS}"
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

if [ ! -z ${extrn_mdl_source_dir2} ]; then
  cp ${extrn_mdl_fps_on_disk[@]} ${extrn_mdl_staging_dir}/.
  more ${extrn_mdl_fps_on_disk2[@]} >>  ${extrn_mdl_staging_dir}/${extrn_mdl_fns_on_disk[@]}
else
  ln -sf -t ${extrn_mdl_staging_dir} ${extrn_mdl_fps_on_disk[@]}
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
generating initial conditions and surface fields for the RRFS forecast!!!
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
    if [ "${EXTRN_MDL_NAME_ICS}" = "RAP" ] || \
       [ "${EXTRN_MDL_NAME_ICS}" = "HRRRDAS" ] || \
       [ "${EXTRN_MDL_NAME_ICS}" = "HRRR" ]; then
      varmap_file="GSDphys_var_map.txt"
    elif [ "${EXTRN_MDL_NAME_ICS}" = "RRFS" ] || \
         [ "${EXTRN_MDL_NAME_ICS}" = "NAM" ] || \
         [ "${EXTRN_MDL_NAME_ICS}" = "FV3GFS" ] || \
         [ "${EXTRN_MDL_NAME_ICS}" = "GEFS" ] || \
         [ "${EXTRN_MDL_NAME_ICS}" = "GDASENKF" ] || \
         [ "${EXTRN_MDL_NAME_ICS}" = "GSMGFS" ]; then
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
# needed to generate the ICs.
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
# nsoill_out:
# The number of soil layers to include in the output NetCDF file.
#
# FIELD_from_climo, where FIELD = "vgtyp", "sotyp", "vgfrc", "lai", or
# "minmax_vgfrc":
# Logical variable indicating whether or not to obtain the field in
# question from climatology instead of the external model.  The field in
# question is one of vegetation type (FIELD="vgtyp"), soil type (FIELD=
# "sotyp"), vegetation fraction (FIELD="vgfrc"), leaf area index
# (FIELD="lai"), or min/max areal fractional coverage of annual green
# vegetation (FIELD="minmax_vfrr").  If FIELD_from_climo is set to
# ".true.", then the field is obtained from climatology (regardless of
# whether or not it exists in an external model file).  If it is set
# to ".false.", then the field is obtained from the external  model.
# If "false" is chosen and the external model file does not provide
# this field, then chgres_cube prints out an error message and stops.
#
# tg3_from_soil:
# Logical variable indicating whether or not to set the tg3 soil tempe-  # Needs to be verified.
# rature field to the temperature of the deepest soil layer.
#
#-----------------------------------------------------------------------
#

# GSK comments about chgres:
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
nsoill_out=""
geogrid_file_input_grid="\"\""
vgtyp_from_climo=""
sotyp_from_climo=""
vgfrc_from_climo=""
minmax_vgfrc_from_climo=""
lai_from_climo=""
tg3_from_soil=""
convert_nst=""
#
#-----------------------------------------------------------------------
#
# If the external model is not one that uses the RUC land surface model
# (LSM) -- which currently includes all valid external models except the
# HRRR, the RAP, and the RRFS -- then we set the number of soil levels 
# to include in the output NetCDF file that chgres_cube generates 
# (nsoill_out; this is a variable in the namelist that chgres_cube reads
# in) to 4.  This is because FV3 can handle this regardless of the LSM
# that it is using (which is specified in the suite definition file, or
# SDF), as follows.  
# If the SDF does not use the RUC LSM (i.e. it uses the Noah or Noah MP 
# LSM), then it will expect to see 4 soil layers; and if the SDF uses 
# the RUC LSM, then the RUC LSM itself has the capability to regrid from 
# 4 soil layers to the 9 layers that it uses.
#
# On the other hand, if the external model is one that uses the RUC LSM
# (currently meaning that it is either the HRRR, the RAP, or the RRFS),
# then what we set nsoill_out to depends on whether the RUC or the 
# Noah/Noah MP LSM is used in the SDF.  If the SDF uses RUC, then both
# the external model and FV3 use RUC (which expects 9 soil levels), so 
# we simply set nsoill_out to 9.  In this case, chgres_cube does not 
# need to do any regridding of soil levels (because the number of levels
# in is the same as the number out).  If the SDF uses the Noah or Noah 
# MP LSM, then the output from chgres_cube must contain 4 soil levels
# because that is what these LSMs expect, and the code in FV3 does not 
# have the capability to regrid from the 9 levels in the external model
# to the 4 levels expected by Noah/Noah MP.  In this case, chgres_cube
# does the regridding from 9 to 4 levels.
#
# In summary, we can set nsoill_out to 4 unless the external model is
# the HRRR, RAP, or RRFS AND the forecast model is using the RUC LSM.
#
#-----------------------------------------------------------------------
#
nsoill_out="4"
if [ "${EXTRN_MDL_NAME_ICS}" = "HRRR" -o \
     "${EXTRN_MDL_NAME_ICS}" = "HRRRDAS" -o \
     "${EXTRN_MDL_NAME_ICS}" = "RAP" -o \
     "${EXTRN_MDL_NAME_ICS}" = "RRFS" ] && \
   [ "${SDF_USES_RUC_LSM}" = "TRUE" ]; then
  nsoill_out="9"
fi
#
#-----------------------------------------------------------------------
#
# If the external model for ICs is one that does not provide the aerosol
# fields needed by Thompson microphysics (currently only the HRRR and 
# RAP provide aerosol data) and if the physics suite uses Thompson 
# microphysics, set the variable thomp_mp_climo_file in the chgres_cube 
# namelist to the full path of the file containing aerosol climatology 
# data.  In this case, this file will be used to generate approximate 
# aerosol fields in the ICs that Thompson MP can use.  Otherwise, set
# thomp_mp_climo_file to a null string.
#
#-----------------------------------------------------------------------
#
thomp_mp_climo_file=""
if [ "${EXTRN_MDL_NAME_ICS}" != "HRRR" -a \
     "${EXTRN_MDL_NAME_ICS}" != "HRRRDAS" -a \
     "${EXTRN_MDL_NAME_ICS}" != "RAP" ] && \
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
case "${EXTRN_MDL_NAME_ICS}" in

"GSMGFS")
  external_model="GSMGFS"
  fn_atm="${EXTRN_MDL_FNS[0]}"
  fn_sfc="${EXTRN_MDL_FNS[1]}"
  input_type="gfs_gaussian_nemsio" # For spectral GFS Gaussian grid in nemsio format.
  convert_nst=False
  tracers_input="[\"spfh\",\"clwmr\",\"o3mr\"]"
  tracers="[\"sphum\",\"liq_wat\",\"o3mr\"]"
  vgtyp_from_climo=True
  sotyp_from_climo=True
  vgfrc_from_climo=True
  minmax_vgfrc_from_climo=True
  lai_from_climo=True
  tg3_from_soil=False
  ;;

"FV3GFS")
  if [ "${FV3GFS_FILE_FMT_ICS}" = "nemsio" ]; then
    external_model="FV3GFS"
    tracers_input="[\"spfh\",\"clwmr\",\"o3mr\",\"icmr\",\"rwmr\",\"snmr\",\"grle\"]"
    tracers="[\"sphum\",\"liq_wat\",\"o3mr\",\"ice_wat\",\"rainwat\",\"snowwat\",\"graupel\"]"
    fn_atm="${EXTRN_MDL_FNS[0]}"
    fn_sfc="${EXTRN_MDL_FNS[1]}"
    input_type="gaussian_nemsio"     # For FV3-GFS Gaussian grid in nemsio format.
    convert_nst=True
  elif [ "${FV3GFS_FILE_FMT_ICS}" = "grib2" ]; then
    external_model="GFS"
    fn_grib2="${EXTRN_MDL_FNS[0]}"
    input_type="grib2"
    convert_nst=False
    if [ "$MACHINE" = "WCOSS2" ]; then
      if [ "${DO_RETRO}" = "TRUE" ]; then
        fn_atm="${EXTRN_MDL_FNS[0]}"
      else
        fn_atm="${EXTRN_MDL_FNS[0]}"
        fn_sfc="${EXTRN_MDL_FNS[1]}"
      fi
    fi
  elif [ "${FV3GFS_FILE_FMT_ICS}" = "netcdf" ]; then
    tracers_input="[\"spfh\",\"clwmr\",\"o3mr\",\"icmr\",\"rwmr\",\"snmr\",\"grle\"]"
    tracers="[\"sphum\",\"liq_wat\",\"o3mr\",\"ice_wat\",\"rainwat\",\"snowwat\",\"graupel\"]"
    external_model="FV3GFS"
    input_type="gaussian_netcdf"
    convert_nst=False
    fn_atm="${EXTRN_MDL_FNS[0]}"
    fn_sfc="${EXTRN_MDL_FNS[1]}"
  fi
  vgtyp_from_climo=True
  sotyp_from_climo=True
  vgfrc_from_climo=True
  minmax_vgfrc_from_climo=True
  lai_from_climo=True
  tg3_from_soil=True
  ;;

"GDASENKF")
  tracers_input="[\"spfh\",\"clwmr\",\"o3mr\",\"icmr\",\"rwmr\",\"snmr\",\"grle\"]"
  tracers="[\"sphum\",\"liq_wat\",\"o3mr\",\"ice_wat\",\"rainwat\",\"snowwat\",\"graupel\"]"
  external_model="GFS"
  input_type="gaussian_netcdf"
  convert_nst=False
  fn_atm="${EXTRN_MDL_FNS[0]}"
  fn_sfc="${EXTRN_MDL_FNS[1]}"
  vgtyp_from_climo=True
  sotyp_from_climo=True
  vgfrc_from_climo=True
  minmax_vgfrc_from_climo=True
  lai_from_climo=True
  tg3_from_soil=True
  ;;

"GEFS")
  external_model="GFS"
  fn_grib2="${EXTRN_MDL_FNS[0]}"
  input_type="grib2"
  convert_nst=False
  vgtyp_from_climo=True
  sotyp_from_climo=True
  vgfrc_from_climo=True
  minmax_vgfrc_from_climo=True
  lai_from_climo=True
  tg3_from_soil=False
  ;;

"HRRR")
  external_model="HRRR"
  fn_grib2="${EXTRN_MDL_FNS[0]}"
  input_type="grib2"
#
# Path to the HRRRX geogrid file.
#
  geogrid_file_input_grid="${FIXgsm}/geo_em.d01.nc_HRRRX"
# Note that vgfrc, shdmin/shdmax (minmax_vgfrc), and lai fields are only available in HRRRX
# files after mid-July 2019, and only so long as the record order didn't change afterward
  vgtyp_from_climo=False
  sotyp_from_climo=False
  vgfrc_from_climo=False
  minmax_vgfrc_from_climo=False
  lai_from_climo=False
  tg3_from_soil=True
  convert_nst=False
  ;;

"HRRRDAS")
  external_model="HRRR"
  fn_grib2="${EXTRN_MDL_FNS[0]}"
  input_type="grib2"
#
# Path to the HRRRX geogrid file.
#
  geogrid_file_input_grid="${FIXgsm}/hrrrdas_geo_em.d02.nc"
# Note that vgfrc, shdmin/shdmax (minmax_vgfrc), and lai fields are only available in HRRRX
# files after mid-July 2019, and only so long as the record order didn't change afterward
  vgtyp_from_climo=False
  sotyp_from_climo=False
  vgfrc_from_climo=False
  minmax_vgfrc_from_climo=False
  lai_from_climo=False
  tg3_from_soil=True
  convert_nst=False
  ;;

"RAP")
  external_model="RAP"
  fn_grib2="${EXTRN_MDL_FNS[0]}"
  input_type="grib2"
#
# Path to the RAPX geogrid file.
#
  geogrid_file_input_grid="${FIXgsm}/geo_em.d01.nc_RAPX"
  vgtyp_from_climo=False
  sotyp_from_climo=False
  vgfrc_from_climo=False
  minmax_vgfrc_from_climo=False
  lai_from_climo=False
  tg3_from_soil=True
  convert_nst=False
  ;;

"NAM")
  external_model="NAM"
  fn_grib2="${EXTRN_MDL_FNS[0]}"
  input_type="grib2"
  vgtyp_from_climo=True
  sotyp_from_climo=True
  vgfrc_from_climo=True
  minmax_vgfrc_from_climo=True
  lai_from_climo=True
  tg3_from_soil=False
  convert_nst=False
  ;;

"RRFS")
  external_model="NAM"
  fn_grib2="${EXTRN_MDL_FNS[0]}"
  input_type="grib2"
  vgtyp_from_climo=False
  sotyp_from_climo=False
  vgfrc_from_climo=False
  minmax_vgfrc_from_climo=True
  lai_from_climo=True
  tg3_from_soil=False
  convert_nst=False
  ;;

*)
  err_exit "\
External-model-dependent namelist variables have not yet been specified
for this external IC model (EXTRN_MDL_NAME_ICS):
  EXTRN_MDL_NAME_ICS = \"${EXTRN_MDL_NAME_ICS}\""
  ;;

esac
#
#-----------------------------------------------------------------------
#
# Get the starting month, day, and hour of the the external model forecast.
#
#-----------------------------------------------------------------------
#
yyyymmdd="${EXTRN_MDL_CDATE:0:8}"
mm="${EXTRN_MDL_CDATE:4:2}"
dd="${EXTRN_MDL_CDATE:6:2}"
hh="${EXTRN_MDL_CDATE:8:2}"

fhr="${EXTRN_MDL_ICS_OFFSET_HRS}"
cdate_crnt_fhr=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${fhr} hours" "+%Y%m%d%H" )
#
# Get the month, day, and hour corresponding to the current forecast time
# of the the external model.
#
mm="${cdate_crnt_fhr:4:2}"
dd="${cdate_crnt_fhr:6:2}"
hh="${cdate_crnt_fhr:8:2}"
#
#-----------------------------------------------------------------------
#
# Build the FORTRAN namelist file that chgres_cube will read in.
#
#-----------------------------------------------------------------------
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
 'sfc_files_input_grid': ${fn_sfc},
 'grib2_file_input_grid': \"${fn_grib2}\",
 'cycle_mon': $((10#${mm})),
 'cycle_day': $((10#${dd})),
 'cycle_hour': $((10#${hh})),
 'convert_atm': True,
 'convert_sfc': True,
 'convert_nst': ${convert_nst},
 'regional': 1,
 'halo_bndy': $((10#${NH4})),
 'halo_blend': $((10#${HALO_BLEND})),
 'input_type': ${input_type},
 'external_model': ${external_model},
 'tracers_input': ${tracers_input},
 'tracers': ${tracers},
 'nsoill_out': $((10#${nsoill_out})),
 'geogrid_file_input_grid': ${geogrid_file_input_grid},
 'vgtyp_from_climo': ${vgtyp_from_climo},
 'sotyp_from_climo': ${sotyp_from_climo},
 'vgfrc_from_climo': ${vgfrc_from_climo},
 'minmax_vgfrc_from_climo': ${minmax_vgfrc_from_climo},
 'lai_from_climo': ${lai_from_climo},
 'tg3_from_soil': ${tg3_from_soil},
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
  fn_grib2_subset=rrfs.t${hh}z.prslev.f000.subset.grib2

  wgrib2 ${extrn_mdl_staging_dir}/${fn_grib2} -set_grib_type c3b -new_grid_winds grid \
    -new_grid ${gridspecs} ${extrn_mdl_staging_dir}/${fn_grib2_subset}
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
#-----------------------------------------------------------------------
#
# Run large-scale blending
#
#-----------------------------------------------------------------------
# NOTES:
# * The large-scale blending is broken down into 4 major parts
#   1) chgres_winds: This part rotates the coldstart winds from chgres to the model D-grid.
#                    It is based on atmos_cubed_sphere/tools/external_ic.F90#L433, and it
#                    is equivalent to the fv3jedi tool called ColdStartWinds.
#   2) remap_dwinds: This part vertically remaps the D-grid winds.
#                    It is based on atmos_cubed_sphere/tools/external_ic.F90#L3485, and it
#                    is part of the fv3jedi tool called VertRemap.
#   3) remap_scalar: This part vertically remaps all other variables.
#                    It is based on atmos_cubed_sphere/tools/external_ic.F90#L2942, and it
#                    is the other part of the fv3jedi tool called VertRemap.
#   4) raymond:      This is the actual blending code which uses the raymond filter. The
#                    raymond filter is a sixth-order tangent low-pass implicit filter
#                    and can be controlled via the cutoff length scale (Lx).
#
# * Currently blended fields: u, v, t, dpres, and sphum
#     -) Blending only works with GDASENKF (netcdf)
#
# * Two RRFS EnKF member files are needed: fv_core and fv_tracer.
#     -) fv_core contains u, v, t, and dpres
#     -) fv_tracer contains sphum
#
# * Before we can do any blending, the coldstart files from chgres need to be
#   processed. This includes rotating the winds and vertically remapping all the
#   variables. The cold start file has u_w, v_w, u_s, and v_s which correspond
#   to the D-grid staggering.
#     -) u_s is the D-grid south face tangential wind component (m/s)
#     -) v_s is the D-grid south face normal wind component (m/s)
#     -) u_w is the D-grid west  face normal wind component (m/s)
#     -) v_w is the D-grid west  face tangential wind component (m/s)
#     -) https://github.com/NOAA-GFDL/GFDL_atmos_cubed_sphere/blob/bdeee64e860c5091da2d169b1f4307ad466eca2c/tools/external_ic.F90
#     -) https://dtcenter.org/sites/default/files/events/2020/20201105-1300p-fv3-gfdl-1.pdf
#

# Check for 1h RRFS EnKF files, if at least one missing then use 1tstep initialization
if [[ $DO_ENS_BLENDING == "TRUE" && $EXTRN_MDL_NAME_ICS = "GDASENKF" ]]; then

  echo "Pre-Blending Starting."
  ulimit -s unlimited
  #Add the size of the variables declared as private and multiply by the OMP_NUMTHREADS
  export OMP_STACKSIZE=600M #8*[3951*{65+67+66}]*96/1048576 = 600804864/1048576 = 573 MB
  export OMP_NUM_THREADS=$NCORES_PER_NODE
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export FI_MR_CACHE_MAX_COUNT=0
  export MPICH_OFI_STARTUP_CONNECT=1

  case "$MACHINE" in

    "WCOSS2")
       if [[ $NCORES_PER_NODE -gt 96 ]]; then
          export OMP_NUM_THREADS="96"
       fi
      ;;

    "HERA")
       if [[ $NCORES_PER_NODE -gt 80 ]]; then
          export OMP_NUM_THREADS="80"
       fi
      ;;

    "ORION")
       if [[ $NCORES_PER_NODE -gt 80 ]]; then
          export OMP_NUM_THREADS="80"
       fi
      ;;

    "HERCULES")
       if [[ $NCORES_PER_NODE -gt 80 ]]; then
          export OMP_NUM_THREADS="80"
       fi
      ;;

    "JET")
       if [[ $NCORES_PER_NODE -gt 80 ]]; then
          export OMP_NUM_THREADS="80"
       fi
      ;;

  esac

  # F2Py shared object files to PYTHONPATH
  export PYTHONPATH=$PYTHONPATH:$LIB64dir

  # Required FIX files
  cp $FIXLAM/${CRES}_grid.tile7.nc .
  cp $FIXLAM/${CRES}_oro_data.tile7.halo0.nc .
  cp $FIX_GSI/$PREDEF_GRID_NAME/fv3_akbk fv_core.res.nc

  # Shortcut the file names
  warm=./fv_core.res.tile1.nc
  cold=./out.atm.tile7.nc
  grid=./${CRES}_grid.tile7.nc
  akbk=./fv_core.res.nc
  akbkcold=./gfs_ctrl.nc
  orog=./${CRES}_oro_data.tile7.halo0.nc
  bndy=./gfs.bndy.nc

  # Run convert coldstart files to fv3 restart (rotate winds and remap).
  python ${USHdir}/chgres_cold2fv3.py $cold $grid $akbk $akbkcold $orog

fi
#
#-----------------------------------------------------------------------
#
# Move initial condition, surface, control, and 0-th hour lateral bound-
# ary files to ICs_BCs directory. Only do this if blending is off or on-
# ly for the first DA cycle if blending is on inorder to coldstart the
# system.
#-----------------------------------------------------------------------
#
if [[ $DO_ENS_BLENDING = "FALSE" ]]; then
  mv out.atm.tile${TILE_RGNL}.nc \
        ${ics_dir}/gfs_data.tile${TILE_RGNL}.halo${NH0}.nc

  mv out.sfc.tile${TILE_RGNL}.nc \
        ${ics_dir}/sfc_data.tile${TILE_RGNL}.halo${NH0}.nc

  mv gfs_ctrl.nc ${ics_dir}

  mv gfs.bndy.nc ${ics_dir}/gfs_bndy.tile${TILE_RGNL}.000.nc
fi
#
#-----------------------------------------------------------------------
#
# copy results to nwges for longe time disk storage.
#
#-----------------------------------------------------------------------
#
if [ $DO_ENS_BLENDING = "FALSE" ]; then
cp ${ics_dir}/*.nc ${ics_nwges_dir}/.
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
Initial condition, surface, and zeroth hour lateral boundary condition
files (in NetCDF format) for FV3 generated successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
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
extrn_mdl_var_defns_fn="${EXTRN_MDL_ICS_VAR_DEFNS_FN}"
extrn_mdl_var_defns_fp="${extrn_mdl_staging_dir}/${extrn_mdl_var_defns_fn}"
check_for_preexist_dir_file "${extrn_mdl_var_defns_fp}" "delete"

settings="EXTRN_MDL_CDATE=${extrn_mdl_cdate}"

{ cat << EOM >> ${extrn_mdl_var_defns_fp}
$settings
EOM
}
export err=$?
if [ $err -ne 0 ]; then
  err_exit "\
Heredoc (cat) command to create a variable definitions file associated
with the external model from which to generate ${ics_or_lbcs} returned with a
nonzero status.  The full path to this variable definitions file is:
  extrn_mdl_var_defns_fp = \"${extrn_mdl_var_defns_fp}\""
fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1
