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

This is the ex-script for the task that runs bufr (cloud, metar, lightning) preprocess
with FV3 for the specified cycle.
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
valid_args=( "CYCLE_DIR" )
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
# Set environment
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case $MACHINE in
#
"WCOSS2")
  APRUN="mpiexec -n 1 -ppn 1"
  ;;
#
"HERA")
  APRUN="srun --export=ALL"
  ;;
#
"JET")
  APRUN="srun --export=ALL"
  ;;
#
"ORION")
  APRUN="srun --export=ALL"
  ;;
#
"HERCULES")
  APRUN="srun --export=ALL"
  ;;
#
esac
#
#-----------------------------------------------------------------------
#
# Extract from CDATE the starting year, month, day, and hour of the
# forecast.  These are needed below for various operations.
#
#-----------------------------------------------------------------------
#
START_DATE=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
YYYYMMDDHH=$(date +%Y%m%d%H -d "${START_DATE}")
JJJ=$(date +%j -d "${START_DATE}")

YYYY=${YYYYMMDDHH:0:4}
MM=${YYYYMMDDHH:4:2}
DD=${YYYYMMDDHH:6:2}
HH=${YYYYMMDDHH:8:2}
YYYYMMDD=${YYYYMMDDHH:0:8}

YYJJJHH=$(date +"%y%j%H" -d "${START_DATE}")
PREYYJJJHH=$(date +"%y%j%H" -d "${START_DATE} 1 hours ago")
#
#-----------------------------------------------------------------------
#
# Define fix dir
#
#-----------------------------------------------------------------------
#
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"
#
#-----------------------------------------------------------------------
#
# link or copy background files
#
#-----------------------------------------------------------------------
#
cp ${fixgriddir}/fv3_grid_spec  fv3sar_grid_spec.nc
#
#-----------------------------------------------------------------------
#
# copy bufr table
#
#-----------------------------------------------------------------------
#
BUFR_TABLE=${FIX_GSI}/prepobs_prep_RAP.bufrtable
cp $BUFR_TABLE prepobs_prep.bufrtable
#
#-----------------------------------------------------------------------
#
#   set observation soruce 
#
#-----------------------------------------------------------------------
if [[ "${NET}" = "RTMA"* ]] && [[ "${RTMA_OBS_FEED}" = "NCO" ]]; then
  SUBH=$(date +%M -d "${START_DATE}")
  obs_source="rtma_ru"
  obsfileprefix=${obs_source}
  obspath_tmp=${OBSPATH}/${obs_source}.${YYYYMMDD}
else
  SUBH=""
  obs_source=${OBSTYPE_SOURCE}
  if [[ ${HH} -eq '00' || ${HH} -eq '12' ]]; then
    obs_source=${OBSTYPE_SOURCE}_e
  fi

  case $MACHINE in

  "WCOSS2")

    obsfileprefix=${obs_source}
    obspath_tmp=${OBSPATH}/${obs_source}.${YYYYMMDD}

    if [ "${DO_RETRO}" = "TRUE" ]; then
       obsfileprefix=${YYYYMMDDHH}.${obs_source}
       obspath_tmp=${OBSPATH}
    fi

    ;;
  "JET" | "HERA" | "ORION" | "HERCULES")

    obsfileprefix=${YYYYMMDDHH}.${obs_source}
    obspath_tmp=${OBSPATH}

  esac
fi
#
#-----------------------------------------------------------------------
#
# Link to the observation lightning bufr files
#
#-----------------------------------------------------------------------
#
run_lightning=false
obs_file=${obspath_tmp}/${obsfileprefix}.t${HH}${SUBH}z.lghtng.tm00.bufr_d
print_info_msg "$VERBOSE" "obsfile is $obs_file"
if [ -r "${obs_file}" ]; then
   cp "${obs_file}" "lghtngbufr"
   run_lightning=true
else
   print_info_msg "$VERBOSE" "WARNING: ${obs_file} does not exist!"
fi
#
#-----------------------------------------------------------------------
#
# Build namelist and run executable for lightning
#
#   analysis_time : process obs used for this analysis date (YYYYMMDDHH)
#   minute        : process obs used for this analysis minute (integer)
#   trange_start  : obs time window start (minutes before analysis time)
#   trange_end    : obs time window end (minutes after analysis time)
#   bkversion     : grid type (background will be used in the analysis)
#                   0 for ARW  (default)
#                   1 for FV3LAM
#-----------------------------------------------------------------------
#
cat << EOF > namelist.lightning
 &setup
  analysis_time = ${YYYYMMDDHH},
  minute=00,
  trange_start=-10,
  trange_end=10,
  grid_type = "${PREDEF_GRID_NAME}",
  obs_type = "bufr"
 /

EOF

#
#-----------------------------------------------------------------------
#
# Run the process for lightning bufr file 
#
#-----------------------------------------------------------------------
#
export pgm="process_Lightning.exe"
. prep_step

if [[ "$run_lightning" == true ]]; then
  $APRUN ${EXECdir}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
  mv errfile errfile_lightning

  cp LightningInFV3LAM.dat ${COMOUT}/rrfs.t${HH}z.LightningInFV3LAM.bin
fi
#
#-----------------------------------------------------------------------
#
# Link to the observation NASA LaRC cloud bufr file
#
#-----------------------------------------------------------------------
#
obs_file=${obspath_tmp}/${obsfileprefix}.t${HH}${SUBH}z.lgycld.tm00.bufr_d
print_info_msg "$VERBOSE" "obsfile is $obs_file"
run_cloud=false
if [ -r "${obs_file}" ]; then
   cp "${obs_file}" "lgycld.bufr_d"
   run_cloud=true
else
   print_info_msg "$VERBOSE" "WARNING: ${obs_file} does not exist!"
fi
#
#-----------------------------------------------------------------------
#
# Build namelist and run executable for NASA LaRC cloud
#
#   analysis_time : process obs used for this analysis date (YYYYMMDDHH)
#   bufrfile      : result BUFR file name
#   npts_rad      : number of grid point to build search box (integer)
#   ioption       : interpolation options
#                   = 1 is nearest neighrhood
#                   = 2 is median of cloudy fov
#   bkversion     : grid type (background will be used in the analysis)
#                   = 0 for ARW  (default)
#                   = 1 for FV3LAM
#-----------------------------------------------------------------------
#
if [ "${PREDEF_GRID_NAME}" = "GSD_RAP13km" ] || [ "${PREDEF_GRID_NAME}" = "RRFS_CONUS_13km" ]; then
   npts_rad_number=1
   metar_impact_radius_number=9
else
   npts_rad_number=3
   metar_impact_radius_number=20
fi

cat << EOF > namelist.nasalarc
 &setup
  analysis_time = ${YYYYMMDDHH},
  bufrfile='NASALaRCCloudInGSI_bufr.bufr',
  npts_rad=$npts_rad_number,
  ioption = 2,
  grid_type = "${PREDEF_GRID_NAME}",
 /
EOF

#
#-----------------------------------------------------------------------
#
# Run the process for NASA LaRc cloud  bufr file 
#
#-----------------------------------------------------------------------
#
export pgm="process_larccld.exe"
. prep_step
if [[ "$run_cloud" == true ]]; then
  $APRUN ${EXECdir}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
  mv errfile errfile_larccld

  cp NASALaRC_cloud4fv3.bin $COMOUT/rrfs.t${HH}z.NASALaRC_cloud4fv3.bin
fi
#
#-----------------------------------------------------------------------
#
# Link to the observation prepbufr bufr file for METAR cloud
#
#-----------------------------------------------------------------------
#
obs_file=${obspath_tmp}/${obsfileprefix}.t${HH}${SUBH}z.prepbufr.tm00 
print_info_msg "$VERBOSE" "obsfile is $obs_file"
run_metar=false
if [ -r "${obs_file}" ]; then
   cp "${obs_file}" "prepbufr"
   run_metar=true
else
   print_info_msg "$VERBOSE" "WARNING: ${obs_file} does not exist!"
fi
#
#-----------------------------------------------------------------------
#
# Build namelist for METAR cloud
#
#   analysis_time   : process obs used for this analysis date (YYYYMMDDHH)
#   analysis_minute : process obs used for this analysis minute (integer)
#   prepbufrfile    : input prepbufr file name
#   twindin         : observation time window (real: hours before and after analysis time)
#
#-----------------------------------------------------------------------
#
cat << EOF > namelist.metarcld
 &setup
  analysis_time = ${YYYYMMDDHH},
  prepbufrfile='prepbufr',
  twindin=0.5,
  metar_impact_radius=$metar_impact_radius_number,
  grid_type = "${PREDEF_GRID_NAME}",
 /
EOF

#
#-----------------------------------------------------------------------
#
# Run the process for METAR cloud bufr file 
#
#-----------------------------------------------------------------------
#
export pgm="process_metarcld.exe"
. prep_step
if [[ "$run_metar" == true ]]; then
  $APRUN ${EXECdir}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
  mv errfile errfile_metarcld

  cp fv3_metarcloud.bin $COMOUT/rrfs.t${HH}z.fv3_metarcloud.bin
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
BUFR PROCESS completed successfully!!!

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

