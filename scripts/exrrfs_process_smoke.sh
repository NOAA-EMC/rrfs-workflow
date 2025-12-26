#!/bin/bash
set -x

source ${FIXrrfs}/workflow/${WGF}/workflow.conf

#
#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. $USHrrfs/source_util_funcs.sh
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

This is the script for the task that runs smoke emissions preprocessing.
========================================================================"
#
#-----------------------------------------------------------------------
#
#
# Link the the hourly, interpolated RAVE data from $rave_dir so it
# is reused
#
#-----------------------------------------------------------------------
LN=/bin/ln
echo "Cycle date: ${CDATE}"

rave_base_prefix="${COMrrfs}/RAVE_INTP/rave_intp"

for i in $(seq 0 24); do
   timestr=$(${NDATE} -$((i+1)) ${CDATE})
   daystr=${timestr:0:8}

   intp_fname=${PREDEF_GRID_NAME}_intp_${timestr}00_${timestr}59.nc
   rave_day_dir="${rave_base_prefix}.${daystr}"
   if  [ -f ${rave_day_dir}/${intp_fname} ]; then
      ${LN} -sf ${rave_day_dir}/${intp_fname} ${DATA}/${intp_fname}
      echo "${rave_day_dir}/${intp_fname} interpolated file available to reuse"
   else
      echo "${rave_day_dir}/${intp_fname} interpolated file not available to reuse"  
   fi
done

#-----------------------------------------------------------------------
#
#  link RAVE data to work directory  $DATA
#
#-----------------------------------------------------------------------

if [ -d ${FIRE_RAVE_DIR}/${PDYm1}/rave ]; then
   fire_rave_dir_work=${DATA}
   ${LN} -snf ${FIRE_RAVE_DIR}/${PDY}/rave/RAVE-HrlyEmiss-3km_* ${fire_rave_dir_work}/.
   ${LN} -snf ${FIRE_RAVE_DIR}/${PDYm1}/rave/RAVE-HrlyEmiss-3km_* ${fire_rave_dir_work}/.
   ${LN} -snf ${FIRE_RAVE_DIR}/${PDYm2}/rave/RAVE-HrlyEmiss-3km_* ${fire_rave_dir_work}/.
else
   fire_rave_dir_work=${FIRE_RAVE_DIR}
fi

#
#-----------------------------------------------------------------------
#
# Call the Python script for this job.
#
#-----------------------------------------------------------------------
#

python -u  ${USHrrfs}/generate_fire_emissions.py \
  "${FIX_SMOKE_DUST}/${PREDEF_GRID_NAME}" \
  "${fire_rave_dir_work}" \
  "${DATA}" \
  "${PREDEF_GRID_NAME}" 
export err=$?; err_chk

#Copy the the hourly, interpolated RAVE data to $rave_dir so it
# is maintained there for future cycles.
for file in ${DATA}/RAVE-HrlyEmiss-* ${DATA}/RRFS_NA_3km_intp_* ${DATA}/SMOKE_RRFS_data_*
do
   filename=$(basename "$file")
   daystr=$(echo "$filename" | grep -o '[0-9]\{8\}' | head -1)
   [ -z "$daystr" ] && continue

   rave_day_dir="${rave_base_prefix}.${daystr}"
   if [ ! -f "${rave_day_dir}/${filename}" ]; then
      cpreq -p ${file} ${rave_day_dir}
      echo "Copied file: $filename → $rave_day_dir/" 
   fi
done

echo "Copy RAVE interpolated files completed"

#
#-----------------------------------------------------------------------
#
# Print exit message.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
