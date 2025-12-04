#!/bin/bash
set -x

source ${FIXrrfs}/workflow/${WGF}/workflow.conf

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

This is the ex-script for the task that runs the GLM gridded lightning
data preprocessing with RRFS for the specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
print_input_args valid_args

export OBS_EAST=$GLMFED_EAST_ROOT
export OBS_WEST=$GLMFED_WEST_ROOT
export MODE=$GLMFED_DATA_MODE
export PREP_MODEL=${PREP_MODEL:-0}
#
#-----------------------------------------------------------------------
#
# Run the lightning processing and copy output file 
# to umbrella data directory.
#
#-----------------------------------------------------------------------
# 
python -u ${HOMErrfs}/ush/process_lightning.py
if [ -f ${shared_output_data}/fedobs.nc ] && [ -s ${DATA}/fedobs.nc ]; then
  rm -f ${shared_output_data}/fedobs.nc
fi
#ln -s ${DATA}/fedobs.nc ${shared_output_data}/fedobs.nc
cpreq ${DATA}/fedobs.nc ${shared_output_data}/fedobs.nc
cpreq -p fedobs.nc ${COMOUT_ANALYSIS}/fedobs.nc

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
LIGHTNING PROCESSING completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
