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
# This file defines a function that is used to obtain information (e.g.
# output file names, system and mass store file and/or directory names)
# for a specified external model, analysis or forecast, and cycle date.
# See the usage statement below for this function should be called and
# the definitions of the input parameters.
# 
#-----------------------------------------------------------------------
#
function get_extrn_mdl_file_dir_info() {
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
    "extrn_mdl_name" \
    "anl_or_fcst" \
    "retro_or_realtime" \
    "cdate_FV3LAM" \
    "lbs_spec_intvl_hrs" \
    "boundary_len_hrs" \
    "time_offset_hrs" \
    "extrn_mdl_date_julian" \
    "varname_extrn_mdl_memhead" \
    "varname_extrn_mdl_cdate" \
    "varname_extrn_mdl_lbc_spec_fhrs" \
    "varname_extrn_mdl_fns_on_disk" \
    "varname_extrn_mdl_fns_on_disk2" \
    "varname_extrn_mdl_sysdir" \
    "varname_extrn_mdl_sysdir2" \
  )
  process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script/function.  Note that these will be printed out only if VERBOSE
# is set to TRUE.
#
#-----------------------------------------------------------------------
#
  print_input_args valid_args
#
#-----------------------------------------------------------------------
#
# Check arguments.
#
#-----------------------------------------------------------------------
#
if [ 0 = 1 ]; then

  if [ "$#" -ne "14" ]; then

    print_err_msg_exit "
Incorrect number of arguments specified:

  Function name:  \"${func_name}\"
  Number of arguments specified:  $#

Usage:

  ${func_name} \
    extrn_mdl_name \
    anl_or_fcst \
    retro_or_realtime \
    cdate_FV3LAM \
    lbs_spec_intvl_hrs \
    boundary_len_hrs \
    time_offset_hrs \
    extrn_mdl_date_julian \
    varname_extrn_mdl_cdate \
    varname_extrn_mdl_lbc_spec_fhrs \
    varname_extrn_mdl_fns \
    varname_extrn_mdl_sysdir

where the arguments are defined as follows:
 
  extrn_mdl_name:
  Name of the external model, i.e. the name of the model providing the
  fields from which files containing initial conditions, surface fields, 
  and/or lateral boundary conditions for the FV3-LAM will be generated.

  anl_or_fcst:
  Flag that specifies whether the external model files we are interested
  in obtaining are analysis or forecast files.

  cdate_FV3LAM:
  The cycle date and time (hours only) for which we want to obtain file
  and directory information.  This has the form YYYYMMDDHH, where YYYY
  is the four-digit starting year of the cycle, MM is the two-digit
  month, DD is the two-digit day of the month, and HH is the two-digit
  hour of day.

  time_offset_hrs:
  The number of hours by which to shift back in time the start time of
  the external model forecast from the specified cycle start time of the
  FV3-LAM (cdate_FV3LAM).  When getting directory and file information on
  external model analysis files, this is normally set to 0.  When get-
  ting directory and file information on external model forecast files,
  this may be set to a nonzero value to obtain information for an exter-
  nal model run that started time_offset_hrs hours before cdate_FV3LAM
  (instead of exactly at cdate_FV3LAM).  Note that in this case, the
  forecast hours (relative to the external model run's start time) at
  which the lateral boundary conditions will be updated must be shifted
  forward by time_offset_hrs hours relative to those for the FV3-LAM in
  order to make up for the backward-in-time shift in the starting time
  of the external model.

  varname_extrn_mdl_cdate:
  Name of the global variable that will contain the starting date and
  hour of the external model run.

  varname_extrn_mdl_lbc_spec_fhrs:
  Name of the global variable that will contain the forecast hours (re-
  lative to the starting time of the external model run, which is earli-
  er than that of the FV3-LAM by time_offset_hrs hours) at which lateral
  boundary condition (LBC) output files are obtained from the external
  model (and will be used to update the LBCs of the FV3-LAM).

  varname_extrn_mdl_fns:
  Name of the global variable that will contain the names of the exter-
  nal model output files.

  varname_extrn_mdl_sysdir:
  Name of the global variable that will contain the system directory in
  which the externaml model output files may be stored.
"

  fi
fi
#
#-----------------------------------------------------------------------
#
# Declare additional local variables.
#
#-----------------------------------------------------------------------
#
local yyyy mm dd hh mn yyyymmdd \
      lbc_spec_fhrs i num_fhrs \
      yy ddd fcst_hhh fcst_hh fcst_mn \
      prefix suffix fns fns_on_disk fns_on_disk2 \
      sysbasedir sysdir sysdir2
#
#-----------------------------------------------------------------------
#
# Check input variables for valid values.
#
#-----------------------------------------------------------------------
#
anl_or_fcst="${anl_or_fcst^^}"
valid_vals_anl_or_fcst=( "ANL" "FCST" )
check_var_valid_value "anl_or_fcst" "valid_vals_anl_or_fcst"
#
#-----------------------------------------------------------------------
#
# Extract from cdate_FV3LAM the starting year, month, day, and hour of 
# the FV3-LAM cycle.  Then subtract the temporal offset specified in 
# time_offset_hrs (assumed to be given in units of hours) from cdate_FV3LAM
# to obtain the starting date and time of the external model, express the 
# result in YYYYMMDDHH format, and save it in cdate.  This is the starting 
# time of the external model forecast.
#
#-----------------------------------------------------------------------
#
yyyy=${cdate_FV3LAM:0:4}
mm=${cdate_FV3LAM:4:2}
dd=${cdate_FV3LAM:6:2}
hh=${cdate_FV3LAM:8:2}
yyyymmdd=${cdate_FV3LAM:0:8}

cdate=$( date --utc --date "${yyyymmdd} ${hh} UTC - ${time_offset_hrs} hours" "+%Y%m%d%H" )
#
#-----------------------------------------------------------------------
#
# Extract from cdate the starting year, month, day, and hour of the external 
# model forecast.  Also, set the starting minute to "00" and get the date
# without the time-of-day.  These are needed below in setting various 
# directory and file names.
#
#-----------------------------------------------------------------------
#
yyyy=${cdate:0:4}
mm=${cdate:4:2}
dd=${cdate:6:2}
hh=${cdate:8:2}
mn="00"
yyyymmdd=${cdate:0:8}
#
#-----------------------------------------------------------------------
#
# Initialize lbc_spec_fhrs to an empty array.  Then, if considering a
# forecast, reset lbc_spec_fhrs to the array of forecast hours at which 
# the lateral boundary conditions (LBCs) are to be updated, starting with 
# the 2nd such time (i.e. the one having array index 1).  We do not include 
# the first hour (hour 0) because at this initial time, the LBCs are 
# obtained from the analysis fields provided by the external model (as 
# opposed to a forecast field).
#
#-----------------------------------------------------------------------
#
lbc_spec_fhrs=( "" )
if [ "${anl_or_fcst}" = "ANL" ]; then
  ic_spec_fhrs=$(( 0 + time_offset_hrs ))
elif [ "${anl_or_fcst}" = "FCST" ]; then
  # offset is to go back to a previous cycle (for example 3-h) and 
  # use the forecast (3-h) from that cycle valid at this cycle. 
  # Here calculates the forecast and it is adding.
  if [ "${boundary_len_hrs}" = "0" ]; then
    boundary_len_hrs=${FCST_LEN_HRS}
  fi
  if [ "${DO_NON_DA_RUN}" = "TRUE" ]; then
    lbc_spec_fcst_hrs=($( seq ${lbs_spec_intvl_hrs} ${lbs_spec_intvl_hrs} ${boundary_len_hrs} ))
  else
    lbc_spec_fcst_hrs=($( seq 0 ${lbs_spec_intvl_hrs} ${boundary_len_hrs} ))
  fi
  lbc_spec_fhrs=( "${lbc_spec_fcst_hrs[@]}" )
  #
  # Add the temporal offset specified in time_offset_hrs (assumed to be in 
  # units of hours) to the the array of LBC update forecast hours to make
  # up for shifting the starting hour back in time.  After this addition,
  # lbc_spec_fhrs will contain the LBC update forecast hours relative to
  # the start time of the external model run.
  #
  num_fhrs=${#lbc_spec_fhrs[@]}
  for (( i=0; i<=$((num_fhrs-1)); i++ )); do
    lbc_spec_fhrs[$i]=$(( ${lbc_spec_fhrs[$i]} + time_offset_hrs ))
  done
fi
#
#-----------------------------------------------------------------------
#
# Set additional parameters needed in forming the names of the external
# model files only under certain circumstances.
#
#-----------------------------------------------------------------------
#
# Get the Julian day-of-year of the starting date and time of the 
# external model forecast.
#
ddd=$( date --utc --date "${yyyy}-${mm}-${dd} ${hh}:${mn} UTC" "+%j" )
#
# Get the last two digits of the year of the starting date and time of 
# the external model forecast.
#
yy=${yyyy:2:4}
#
#-----------------------------------------------------------------------
#
# Set the external model output file names that must be obtained (from 
# disk if available, otherwise from HPSS).
#
#-----------------------------------------------------------------------
#
if [ "${anl_or_fcst}" = "ANL" ]; then
  fv3gfs_file_fmt="${FV3GFS_FILE_FMT_ICS}"
  gefs_file_fmt="grib2"
elif [ "${anl_or_fcst}" = "FCST" ]; then
  fv3gfs_file_fmt="${FV3GFS_FILE_FMT_LBCS}"
  gefs_file_fmt="grib2"
fi

fns_on_disk2=( "" )

case "${anl_or_fcst}" in
#
#-----------------------------------------------------------------------
#
# Consider analysis files (possibly including surface files).
#
#-----------------------------------------------------------------------
#
  "ANL")

    fcst_hh=$( printf "%02d" "${ic_spec_fhrs}" )
    fcst_mn="00"

    case "${extrn_mdl_name}" in

    "GSMGFS")
      fns=( "atm" "sfc" )
      prefix="gfs.t${hh}z."
      fns=( "${fns[@]/#/$prefix}" )
      suffix="anl.nemsio"
      fns_on_disk=( "${fns[@]/%/$suffix}" )
      ;;

    "FV3GFS")
      if [ "${fv3gfs_file_fmt}" = "nemsio" ]; then
        fns=( "atm" "sfc" )
        suffix="anl.nemsio"
        fns=( "${fns[@]/%/$suffix}" )

        # Set names of external files if searching on disk.
        if [ "${extrn_mdl_date_julian}" = "TRUE" ]; then
          prefix="${yy}${ddd}${hh}00.gfs.t${hh}z."
        else
          prefix="gfs.t${hh}z."
        fi
        fns_on_disk=( "${fns[@]/#/$prefix}" )

      elif [ "${fv3gfs_file_fmt}" = "grib2" ]; then
        if [ "${extrn_mdl_date_julian}" = "TRUE" ]; then
          fns_on_disk=( "${yy}${ddd}${hh}0${fcst_mn}0${fcst_hh}" )
        else
          fns_on_disk=( "gfs.t${hh}z.pgrb2.0p25.f0${fcst_hh}" )
        fi

      elif [ "${fv3gfs_file_fmt}" = "netcdf" ]; then
        fns=( "atm" "sfc" )
        if [ "${fcst_hh}" = "00" ]; then
          suffix="anl.nc"
        else
          suffix="f0${fcst_hh}.nc"
        fi
        fns=( "${fns[@]/%/$suffix}" )

        # Set names of external files if searching on disk.
        if [ "${extrn_mdl_date_julian}" = "TRUE" ]; then
          prefix="${yy}${ddd}${hh}00.gfs.t${hh}z."
        else
          prefix="gfs.t${hh}z."
        fi
        fns_on_disk=( "${fns[@]/#/$prefix}" )

      fi
      ;;

    "GDASENKF")
      if [ "${MACHINE}" = "WCOSS2" ] ; then
        fns_on_disk=( "gdas.t${hh}z.atmf0${fcst_hh}.nc" "gdas.t${hh}z.sfcf0${fcst_hh}.nc")  # use netcdf
      elif [ "${MACHINE}" = "HERA" ] ; then
        fns_on_disk=( "gdas.t${hh}z.atmf0${fcst_hh}.nc" "gdas.t${hh}z.sfcf0${fcst_hh}.nc")  # use netcdf
      elif [ "${MACHINE}" = "JET" ] ; then
        fns_on_disk=( "${yy}${ddd}${hh}${mn}.gdas.t${hh}z.atmf0${fcst_hh}.${GDAS_MEM_NAME}.nc" "${yy}${ddd}${hh}${mn}.gdas.t${hh}z.sfcf0${fcst_hh}.${GDAS_MEM_NAME}.nc")  # use netcdf
      elif [[ "${MACHINE}" = "ORION" ]] || [[ "${MACHINE}" = "HERCULES" ]]; then
        fns_on_disk=( "${yy}${ddd}${hh}${mn}.gdas.t${hh}z.atmf0${fcst_hh}.${GDAS_MEM_NAME}.nc" "${yy}${ddd}${hh}${mn}.gdas.t${hh}z.sfcf0${fcst_hh}.${GDAS_MEM_NAME}.nc")  # use netcdf
      fi
      ;;
 
    "GEFS")
      fcst_hh=( $( printf "%02d " "${time_offset_hrs}" ) )
      prefix="${yy}${ddd}${hh}${mn}${fcst_mn}"
      prefix2=""
      if [ "${MACHINE}" = "WCOSS2" ] ; then
        prefix="${varname_extrn_mdl_memhead}"".t${hh}z.pgrb2b.0p50.f0"
        prefix2="${varname_extrn_mdl_memhead}"".t${hh}z.pgrb2a.0p50.f0"
        if [ "${EXTRN_MDL_SAVETYPE}" = "GSL" ] ; then
          prefix="${yy}${ddd}${hh}${mn}${fcst_mn}"
          prefix2=""
        fi
      fi
      echo ${varname_extrn_mdl_memhead}
      fns_on_disk=( "${fcst_hh/#/$prefix}" )
      fns_on_disk2=( "${fcst_hh/#/$prefix2}" )
      ;;

    "RAP")
      fns_on_disk=( "${yy}${ddd}${hh}${mn}${fcst_mn}${fcst_hh}" )
      ;;

    "HRRR")
      fns_on_disk=( "${yy}${ddd}${hh}${mn}${fcst_mn}${fcst_hh}" )
      ;;

    "HRRRDAS")
      fns_on_disk=( "wrfnat${WRF_MEM_NAME}_00.grib2" )
      ;;

    "NAM")
      fns=( "" )
      prefix="nam.t${hh}z.bgrdsfi${hh}"
      fns=( "${fns[@]/#/$prefix}" )
      suffix=".tm${hh}"
      fns_on_disk=( "${fns[@]/%/$suffix}" )
      ;;

    "RRFS")
      fns_on_disk=( "rrfs.t${hh}z.natlev.f0${fcst_hh}.grib2" )
      ;;

    *)
      print_err_msg_exit "\
The external model file names (either on disk or in archive files) have 
not yet been specified for this combination of external model (extrn_mdl_name) 
and analysis or forecast (anl_or_fcst):
  extrn_mdl_name = \"${extrn_mdl_name}\"
  anl_or_fcst = \"${anl_or_fcst}\""
      ;;

    esac
    ;;
#
#-----------------------------------------------------------------------
#
# Consider forecast files.
#
#-----------------------------------------------------------------------
#
  "FCST")

    fcst_mn="00"

    case "${extrn_mdl_name}" in

    "GSMGFS")
      fcst_hhh=( $( printf "%03d " "${lbc_spec_fhrs[@]}" ) )
      prefix="gfs.t${hh}z.atmf"
      fns=( "${fcst_hhh[@]/#/$prefix}" )
      suffix=".nemsio"
      fns_on_disk=( "${fns[@]/%/$suffix}" )
      ;;

    "FV3GFS")
      if [ "${fv3gfs_file_fmt}" = "nemsio" ]; then
        fcst_hhh=( $( printf "%03d " "${lbc_spec_fhrs[@]}" ) )
        if [ "${extrn_mdl_date_julian}" = "TRUE" ]; then
          prefix="${yy}${ddd}${hh}00.gfs.t${hh}z.atmf"
        else
          prefix="gfs.t${hh}z.atmf"
        fi
        suffix=".nemsio"
        fns_on_disk_tmp=( "${fcst_hhh[@]/#/${prefix}}" )
        fns_on_disk=( "${fns_on_disk_tmp[@]/%/${suffix}}" )
      elif [ "${fv3gfs_file_fmt}" = "grib2" ]; then
        fcst_hhh=( $( printf "%03d " "${lbc_spec_fhrs[@]}" ) )
        if [ "${extrn_mdl_date_julian}" = "TRUE" ]; then
          prefix=( "${yy}${ddd}${hh}${fcst_mn}0" )
        else
          prefix="gfs.t${hh}z.pgrb2.0p25.f"
        fi
        fns_on_disk=( "${fcst_hhh[@]/#/$prefix}" )
      elif [ "${fv3gfs_file_fmt}" = "netcdf" ]; then
        fcst_hhh=( $( printf "%03d " "${lbc_spec_fhrs[@]}" ) )
        if [ "${extrn_mdl_date_julian}" = "TRUE" ]; then
          prefix="${yy}${ddd}${hh}00.gfs.t${hh}z.atmf"
        else
          prefix="gfs.t${hh}z.atmf"
        fi
        suffix=".nc"
        fns_on_disk_tmp=( "${fcst_hhh[@]/#/${prefix}}" )
        fns_on_disk=( "${fns_on_disk_tmp[@]/%/${suffix}}" )
      fi
      ;;

    "GDASENKF")
      fcst_hhh=( $( printf "%03d " "${lbc_spec_fhrs[@]}" ) )
      if  [ "${MACHINE}" = "HERA" ]; then
        fns_on_disk=( "gdas.t${hh}z.atmf${fcst_hhh[@]}.nc" "gdas.t${hh}z.sfcf${fcst_hhh[@]}.nc")  # use netcdf
      elif  [ "${MACHINE}" = "JET" ]; then
        fns_on_disk=( "${yy}${ddd}${hh}${mn}.gdas.t${hh}z.atmf0${fcst_hh}.${GDAS_MEM_NAME}.nc" "${yy}${ddd}${hh}${mn}.gdas.t${hh}z.sfcf0${fcst_hh}.${GDAS_MEM_NAME}.nc")  # use netcdf
      elif [[ "${MACHINE}" = "ORION" ]] || [[ "${MACHINE}" = "HERCULES" ]]; then
        fns_on_disk=( "${yy}${ddd}${hh}${mn}.gdas.t${hh}z.atmf0${fcst_hh}.${GDAS_MEM_NAME}.nc" "${yy}${ddd}${hh}${mn}.gdas.t${hh}z.sfcf0${fcst_hh}.${GDAS_MEM_NAME}.nc")  # use netcdf
      fi
      ;;

    "GEFS")
      fcst_hh=( $( printf "%02d " "${lbc_spec_fhrs[@]}" ) )
      prefix="${yy}${ddd}${hh}${mn}${fcst_mn}"
      prefix2=""
      if [ "${MACHINE}" = "WCOSS2" ] ; then
        prefix="${varname_extrn_mdl_memhead}"".t${hh}z.pgrb2b.0p50.f0"
        prefix2="${varname_extrn_mdl_memhead}"".t${hh}z.pgrb2a.0p50.f0"
        if [ "${EXTRN_MDL_SAVETYPE}" = "GSL" ] ; then
          prefix="${yy}${ddd}${hh}${mn}${fcst_mn}"
          prefix2=""
        fi
      fi
      fns_on_disk=( "${fcst_hh[@]/#/$prefix}" )
      fns_on_disk2=( "${fcst_hh[@]/#/$prefix2}" )
      ;;

    "RAP")
      # Note that this is GSL RAPX data, not operational NCEP RAP data.
      fcst_hh=( $( printf "%02d " "${lbc_spec_fhrs[@]}" ) )

      prefix="${yy}${ddd}${hh}${mn}${fcst_mn}"
      suffix="${fcst_mn}"
      fns_on_disk=( "${fcst_hh[@]/#/$prefix}" )
      ;;

    "HRRR")
      # Note that this is GSL HRRRX data, not operational NCEP HRRR data.
      fcst_hh=( $( printf "%02d " "${lbc_spec_fhrs[@]}" ) )

      prefix="${yy}${ddd}${hh}${mn}"
      prefix="${yy}${ddd}${hh}${mn}${fcst_mn}"
      suffix="${fcst_mn}"
      fns_on_disk=( "${fcst_hh[@]/#/$prefix}" )
      ;;

    "NAM")
      fcst_hhh=( $( printf "%03d " "${lbc_spec_fhrs[@]}" ) )
      prefix="nam.t${hh}z.bgrdsf"
      fns=( "${fcst_hhh[@]/#/$prefix}" )
      suffix=""
      fns_on_disk=( "${fns[@]/%/$suffix}" )
      ;;

    "RRFS")
      fcst_hhh=( $( printf "%03d " "${lbc_spec_fhrs[@]}" ) )
      prefix="rrfs.t${hh}z.natlev.f"
      fns=( "${fcst_hhh[@]/#/$prefix}" )
      suffix=".grib2"
      fns_on_disk=( "${fns[@]/%/$suffix}" )
      ;;

    *)
      print_err_msg_exit "\
The external model file names have not yet been specified for this com-
bination of external model (extrn_mdl_name) and analysis or forecast
(anl_or_fcst):
  extrn_mdl_name = \"${extrn_mdl_name}\"
  anl_or_fcst = \"${anl_or_fcst}\""
      ;;

    esac
    ;;

  esac
#
#-----------------------------------------------------------------------
#
# Set the system directory (i.e. a directory on disk) in which the external
# model output files for the specified cycle date (cdate) may be located.
# Note that this will be used by the calling script only if the output
# files for the specified cdate actually exist at this location.
#
#-----------------------------------------------------------------------
#
  if [ "${anl_or_fcst}" = "ANL" ]; then
    sysbasedir="${EXTRN_MDL_SYSBASEDIR_ICS}"
  elif [ "${anl_or_fcst}" = "FCST" ]; then
    sysbasedir="${EXTRN_MDL_SYSBASEDIR_LBCS}"
  fi

  sysdir2=""

  case "${extrn_mdl_name}" in

#
# It is not clear which, if any, systems the (old) spectral GFS model is 
# available on, so set sysdir for this external model to a null string.
#
  "GSMGFS")
    case "$MACHINE" in
    "WCOSS2")
      sysdir=""
      ;;
    "HERA")
      sysdir=""
      ;;
    "ORION"|"HERCULES")
      sysdir="$sysbasedir"
      ;;
    "JET")
      sysdir=""
      ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files 
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;


  "FV3GFS")
    case "$MACHINE" in
    "WCOSS2")
      if [ "${retro_or_realtime}" = "RETRO" ]; then
        sysdir="$sysbasedir"
      else
        sysdir="$sysbasedir/gfs.${yyyymmdd}/${hh}/atmos"
      fi
      ;;
    "HERA")
      sysdir="$sysbasedir"
      #sysdir="$sysbasedir/gfs.${yyyymmdd}/${hh}/atmos"
      ;;
    "ORION"|"HERCULES")
      sysdir="$sysbasedir"
      #sysdir="$sysbasedir/gdas.${yyyymmdd}/${hh}/atmos"
      ;;
    "JET")
      sysdir="$sysbasedir"
      ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files 
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;

  "GDASENKF")
    case "$MACHINE" in
    "WCOSS2")
       sysdir="$sysbasedir/enkfgdas.${yyyymmdd}/${hh}/atmos/${GDASENKF_INPUT_SUBDIR}"
       ;;
    "HERA")
       sysdir="$sysbasedir/enkfgdas.${yyyymmdd}/${hh}/atmos/${GDASENKF_INPUT_SUBDIR}"
       ;;
    "JET")
       sysdir="$sysbasedir"
       ;;
    "ORION"|"HERCULES")
       sysdir="$sysbasedir"
       ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files 
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;

  "GEFS")
    case "$MACHINE" in
    "HERA")
       sysdir="$sysbasedir/${GEFS_INPUT_SUBDIR}"
       ;;
     "JET")
       sysdir="$sysbasedir/${GEFS_INPUT_SUBDIR}"
       ;;
    "WCOSS2")
      sysdir="$sysbasedir/gefs.${yyyymmdd}/${hh}/atmos/pgrb2bp5"
      sysdir2="$sysbasedir/gefs.${yyyymmdd}/${hh}/atmos/pgrb2ap5"
      if [ "${EXTRN_MDL_SAVETYPE}" = "GSL" ] ; then
         sysdir="$sysbasedir/${GEFS_INPUT_SUBDIR}"
         sysdir2="$sysdir"
      fi
      ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files 
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;

  "HRRRDAS")
    case "$MACHINE" in
    "HERA")
       sysdir="$sysbasedir"
       ;;
     "JET")
       sysdir="$sysbasedir/${yyyymmdd}${hh}/postprd${WRF_MEM_NAME}"
       ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files 
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;

  "RAP")
    case "$MACHINE" in
    "WCOSS2")
      sysdir="$sysbasedir"
      ;;
    "HERA")
      sysdir="$sysbasedir"
      ;;
    "ORION"|"HERCULES")
      sysdir="$sysbasedir"
      ;;
    "JET")
      sysdir="$sysbasedir"
      ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files 
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;


  "HRRR")
    case "$MACHINE" in
    "WCOSS2")
      sysdir="$sysbasedir"
      ;;
    "HERA")
      sysdir="$sysbasedir"
      ;;
    "ORION"|"HERCULES")
      sysdir="$sysbasedir"
      ;;
    "JET")
      sysdir="$sysbasedir"
      ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files 
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;

  "NAM")
    case "$MACHINE" in
    "WCOSS2")
      sysdir="$sysbasedir"
      ;;
    "HERA")
      sysdir="$sysbasedir"
      ;;
    "ORION"|"HERCULES")
      sysdir="$sysbasedir"
      ;;
    "JET")
      sysdir="$sysbasedir"
      ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;

  "RRFS")
    case "$MACHINE" in
    "WCOSS2")
      sysdir="$sysbasedir/rrfs.${yyyymmdd}/${hh}"
      ;;
    "HERA")
      sysdir="$sysbasedir"
      ;;
    "ORION"|"HERCULES")
      sysdir="$sysbasedir"
      ;;
    "JET")
      sysdir="$sysbasedir"
      ;;
    *)
      print_err_msg_exit "\
The system directory in which to look for external model output files
has not been specified for this external model and machine combination:
  extrn_mdl_name = \"${extrn_mdl_name}\"
  MACHINE = \"$MACHINE\""
      ;;
    esac
    ;;


  *)
    print_err_msg_exit "\
The system directory in which to look for external model output files 
has not been specified for this external model:
  extrn_mdl_name = \"${extrn_mdl_name}\""

  esac
#
#-----------------------------------------------------------------------
#
# Use the eval function to set the output variables.  Note that each of 
# these is set only if the corresponding input variable specifying the
# name to use for the output variable is not empty.
#
#-----------------------------------------------------------------------
#
  if [ ! -z "${varname_extrn_mdl_cdate}" ]; then
    eval ${varname_extrn_mdl_cdate}="${cdate}"
  fi

  if [ ! -z "${varname_extrn_mdl_lbc_spec_fhrs}" ]; then
    lbc_spec_fhrs_str="( "$( printf "\"%s\" " "${lbc_spec_fhrs[@]}" )")"
    eval ${varname_extrn_mdl_lbc_spec_fhrs}=${lbc_spec_fhrs_str}
  fi

  if [ ! -z "${varname_extrn_mdl_fns_on_disk}" ]; then
    fns_on_disk_str="( "$( printf "\"%s\" " "${fns_on_disk[@]}" )")"
    eval ${varname_extrn_mdl_fns_on_disk}=${fns_on_disk_str}
  fi

  if [ ! -z "${varname_extrn_mdl_fns_on_disk2}" ]; then
    fns_on_disk_str2="( "$( printf "\"%s\" " "${fns_on_disk2[@]}" )")"
    eval ${varname_extrn_mdl_fns_on_disk2}=${fns_on_disk_str2}
  fi

  if [ ! -z "${varname_extrn_mdl_sysdir}" ]; then
    eval ${varname_extrn_mdl_sysdir}="${sysdir}"
  fi

  if [ ! -z "${varname_extrn_mdl_sysdir2}" ]; then
    eval ${varname_extrn_mdl_sysdir2}="${sysdir2}"
  fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
  { restore_shell_opts; } > /dev/null 2>&1
}
