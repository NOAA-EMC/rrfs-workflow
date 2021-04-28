#!/bin/bash

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

This is the ex-script for the task that runs radar reflectivity preprocess
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
valid_args=( "CYCLE_DIR" "WORKDIR")
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
#
"WCOSS_C" | "WCOSS")
#
  . /apps/lmod/lmod/init/sh
  module purge
  module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/soft/modulefiles
  module load intel/16.1.150 impi/5.1.1.109 netcdf/4.3.0 
  module list
  
  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np 36"
  ;;
#
"HERA")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun"
  ;;
#
"JET")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun"
  ;;
#
"ODIN")
#
  module list

  ulimit -s unlimited
  ulimit -a
  APRUN="srun -n 36"
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
set -x
START_DATE=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
YYYYMMDDHH=$(date +%Y%m%d%H -d "${START_DATE}")
JJJ=$(date +%j -d "${START_DATE}")

YYYY=${YYYYMMDDHH:0:4}
MM=${YYYYMMDDHH:4:2}
DD=${YYYYMMDDHH:6:2}
HH=${YYYYMMDDHH:8:2}
YYYYMMDD=${YYYYMMDDHH:0:8}
#
#-----------------------------------------------------------------------
#
# Get into working directory
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Getting into working directory for radar reflectivity process ..."

cd ${WORKDIR}

fixdir=$FIX_GSI/
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}

print_info_msg "$VERBOSE" "fixdir is $fixdir"
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"

#
#-----------------------------------------------------------------------
#
# link or copy background files
#
#-----------------------------------------------------------------------

cp_vrfy ${fixgriddir}/fv3_grid_spec          fv3sar_grid_spec.nc

#
#-----------------------------------------------------------------------
#
# link/copy observation files to working directory 
#
#-----------------------------------------------------------------------

NSSL=${OBSPATH_NSSLMOSIAC}

mrms="MRMS_MergedReflectivityQC"

echo "${MM0} ${MM1} ${MM2} ${MM3}"

# Link to the MRMS operational data
for min in ${MM0} ${MM1} ${MM2} ${MM3}
do
  echo "Looking for data valid:"${YYYY}"-"${MM}"-"${DD}" "${HH}":"${min}
  s=0
  while [[ $s -le 59 ]]; do
    if [ $s -lt 10 ]; then
      ss=0${s}
    else
      ss=$s
    fi
    nsslfile=${NSSL}/${YYYY}${MM}${DD}-${HH}${min}${ss}.${mrms}_00.50_${YYYY}${MM}${DD}-${HH}${min}${ss}.grib2
    if [ -s $nsslfile ]; then
      echo 'Found '${nsslfile}
      numgrib2=$(ls ${NSSL}/${YYYY}${MM}${DD}-${HH}${min}*.${mrms}_*_${YYYY}${MM}${DD}-${HH}${min}*.grib2 | wc -l)
      echo 'Number of GRIB-2 files: '${numgrib2}
      if [ ${numgrib2} -ge 10 ] && [ ! -e filelist_mrms ]; then
        ln -sf ${NSSL}/${YYYY}${MM}${DD}-${HH}${min}*.${mrms}_*_${YYYY}${MM}${DD}-${HH}${min}*.grib2 . 
        ls ${YYYY}${MM}${DD}-${HH}${min}*.${mrms}_*_${YYYY}${MM}${DD}-${HH}${min}*.grib2 > filelist_mrms
        echo 'Creating links for ${YYYY}${MM}${DD}-${HH}${min}'
      fi
    fi
    ((s+=1))
  done
done

# remove filelist_mrms if zero bytes
if [ ! -s filelist_mrms ]; then
  rm -f filelist_mrms
fi

if [ -s filelist_mrms ]; then
   numgrib2=$(more filelist_mrms | wc -l)
   print_info_msg "$VERBOSE" "Using radar data from: `head -1 filelist_mrms | cut -c10-15`"
   print_info_msg "$VERBOSE" "NSSL grib2 file levels = $numgrib2"
else
   echo "ERROR: Not enough radar reflectivity files available."
   exit 1
fi

#-----------------------------------------------------------------------
#
# copy bufr table from fix directory
#
#-----------------------------------------------------------------------
BUFR_TABLE=${fixdir}/prepobs_prep_RAP.bufrtable

cp_vrfy $BUFR_TABLE prepobs_prep.bufrtable

#-----------------------------------------------------------------------
#
# Build namelist and run executable 
#
#   tversion      : data source version
#                   = 1 NSSL 1 tile grib2 for single level
#                   = 4 NSSL 4 tiles binary
#                   = 8 NSSL 8 tiles netcdf
#   bkversion     : grid type (background will be used in the analysis)
#                   0 for ARW  (default)
#                   1 for FV3LAM
#   analysis_time : process obs used for this analysis date (YYYYMMDDHH)
#   dataPath      : path of the radar reflectivity mosaic files.
#
#-----------------------------------------------------------------------

cat << EOF > mosaic.namelist
 &setup
  tversion=1,
  bkversion=1,
  analysis_time = ${YYYYMMDDHH},
  dataPath = './',
 /

EOF

#
#-----------------------------------------------------------------------
#
# Copy the executable to the run directory.
#
#-----------------------------------------------------------------------
#
exect="${EXECDIR}/process_NSSL_mosaic.exe"

if [ -f ${EXECDIR}/$exect ]; then
  print_info_msg "$VERBOSE" "
Copying the radar process  executable to the run directory..."
  cp_vrfy ${EXECDIR}/${exect} ${WORKDIR}
else
  print_err_msg_exit "\
The executable specified in GSI_exect does not exist:
  exect = \"${EXECDIR}/$exect\"
Build radar process and rerun."
fi
#
#
#-----------------------------------------------------------------------
#
# Run the process.
#
#-----------------------------------------------------------------------
#
$APRUN ./${exect} > stdout 2>&1 || print_err_msg "\
Call to executable to run radar refl process returned with nonzero exit code."
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
RADAR REFL PROCESS completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

