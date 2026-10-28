#!/bin/bash
set -x

source ${FIXrrfs}/workflow/${WGF}/workflow.conf

export FIX_GSI="${FIXrrfs}/gsi"
export FIX_JEDI="${FIX_RRFS_JEDI:-${FIXrrfs}/jedi}"
export FIXLAM=${FIXLAM:-${HOMErrfs}/fix/lam/RRFS_NA_3km}
export PARM_JCB="${PARMrrfs}/jedi"
# RDASApp ships the JCB templates' python driver in its source tree, so the ex-script needs the
# clone itself and not only the executables installed into exec/.
export RDASAPP_DIR="${RDASAPP_DIR:-${HOMErrfs}/sorc/RDASApp}"

# Switches the Rocoto workflow carries in config.sh but the NCO workflow.conf does not; a retro
# overrides them by appending to workflow.conf. The JCB template defaults to the NA 3 km grid the
# base definition runs.
export JCB_CONFIG_ENKF=${JCB_CONFIG_ENKF:-"rdas-atmosphere-templates-fv3_na3km_getkf.yaml"}
export NUM_ENS_MEMBERS=${NUM_ENS_MEMBERS:-30}

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

This is the ex-script for the task that runs the JEDI EnKF (GETKF)
analysis with RRFS for the specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set environment
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a
export OOPS_TRACE=0
export LD_LIBRARY_PATH="${RDASAPP_DIR}/build/lib64:${LD_LIBRARY_PATH}"

# Job size. workflow.conf does not carry these yet, so the defaults are for the NA 3 km grid,
# whose JCB template and input_lam_C3463_NP32X60.nml fix the layout at 32x60 = 1920 tasks.
NNODES_ANALYSIS_ENKF_JEDI=${NNODES_ANALYSIS_ENKF_JEDI:-48}
PPN_ANALYSIS_ENKF_JEDI=${PPN_ANALYSIS_ENKF_JEDI:-40}
TPP_ANALYSIS_ENKF_JEDI=${TPP_ANALYSIS_ENKF_JEDI:-1}

case $MACHINE in
#
"WCOSS2")
  export FI_MR_CACHE_MONITOR=memhooks
  export FI_MR_CACHE_MAX_COUNT=0
  export MPICH_ENV_DISPLAY=1
  export MPICH_OFI_STARTUP_CONNECT=1
  export MPICH_OFI_VERBOSE=1
  export MPICH_MPIIO_HINTS='*.tile1.nc:romio_cb_read=disable,*.sfc_data.nc:romio_cb_read=disable,*.phy_data.nc:romio_cb_read=disable,*.fv_*.res.nc:romio_cb_write=enable,*.sfc_data.nc:romio_cb_write=enable'
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=${TPP_ANALYSIS_ENKF_JEDI}
  export MALLOC_MMAP_THRESHOLD_=1048576
  export MALLOC_TRIM_THRESHOLD_=1048576
  ncores=$(( NNODES_ANALYSIS_ENKF_JEDI*PPN_ANALYSIS_ENKF_JEDI ))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_ANALYSIS_ENKF_JEDI} --cpu-bind core --depth ${OMP_NUM_THREADS}"
  ;;
#
"URSA")
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=${TPP_ANALYSIS_ENKF_JEDI}
  ncores=$(( NNODES_ANALYSIS_ENKF_JEDI*PPN_ANALYSIS_ENKF_JEDI ))
  APRUN="srun --export=ALL -n ${ncores} --ntasks-per-node=${PPN_ANALYSIS_ENKF_JEDI} --cpus-per-task=${OMP_NUM_THREADS}"
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

YYYY=${YYYYMMDDHH:0:4}
MM=${YYYYMMDDHH:4:2}
DD=${YYYYMMDDHH:6:2}
HH=${YYYYMMDDHH:8:2}
#
#-----------------------------------------------------------------------
#
# Define fix path
#
#-----------------------------------------------------------------------
#
fixgriddir=${FIX_GSI}/${PREDEF_GRID_NAME}

cpreq -p ${fixgriddir}/fv3_coupler.res  coupler.res
chmod 644 coupler.res
ln -snf ${fixgriddir}/fv3_akbk       fv3_akbk
ln -snf ${fixgriddir}/fv3_grid_spec  fv3_grid_spec

# update times in coupler.res to current cycle time
sed -i "s/yyyy/${YYYY}/" coupler.res
sed -i "s/mm/${MM}/"     coupler.res
sed -i "s/dd/${DD}/"     coupler.res
sed -i "s/hh/${HH}/"     coupler.res
#
#-----------------------------------------------------------------------
#
# Loop through the members and link each background into the run directory.
# JEDI writes the analysis in place, so the write goes straight through the
# links into the member's forecast INPUT directory; the forecast job then
# converts the analyzed A-grid wind to D-grid (exrrfs_forecast.sh).
# phy_data.nc_prepdbz is the reflectivity-only copy prep_cyc made.
#
#-----------------------------------------------------------------------
#
mkdir -p data/inputs
ncold=0
for imem in $(seq 1 ${NUM_ENS_MEMBERS}); do
  memchar="m"$(printf %03i $imem)
  memcharv0="mem"$(printf %03i $imem)
  bkpath=${FORECAST_INPUT_PRODUCT}/${memchar}/INPUT

  # a member without a restart coupler.res is a cold start, which GETKF cannot read
  if [ ! -r "${bkpath}/coupler.res" ]; then
    ncold=$(( ncold + 1 ))
  fi

  mkdir -p data/inputs/${memcharv0}
  ln -snf ${bkpath}/fv_core.res.tile1.nc       data/inputs/${memcharv0}/fv_core.res.tile1.nc
  ln -snf ${bkpath}/fv_tracer.res.tile1.nc     data/inputs/${memcharv0}/fv_tracer.res.tile1.nc
  ln -snf ${bkpath}/sfc_data.nc                data/inputs/${memcharv0}/sfc_data.nc
  ln -snf ${bkpath}/phy_data.nc_prepdbz        data/inputs/${memcharv0}/phy_data.nc_prepdbz
  ln -snf ${bkpath}/fv_srf_wnd.res.tile1.nc    data/inputs/${memcharv0}/fv_srf_wnd.res.tile1.nc
  ln -snf ${bkpath}/coupler.res                data/inputs/${memcharv0}/coupler.res
done
#
#-----------------------------------------------------------------------
#
# JCB - JEDI Configuration Builder
#
#-----------------------------------------------------------------------
#
# pyioda libraries
shopt -s nullglob
dirs=("$RDASAPP_DIR"/build/lib/python3.*)
PYIODALIB=${dirs[0]}
shopt -u nullglob
WXFLOWLIB=${RDASAPP_DIR}/sorc/wxflow/src
JCBLIB=${RDASAPP_DIR}/sorc/jcb/src
export PYTHONPATH="${JCBLIB}:${WXFLOWLIB}:${PYIODALIB}:${PYTHONPATH}"

cpreq -p ${PARM_JCB}/${JCB_CONFIG_ENKF} .
cpreq -p ${FIX_GSI}/gsd_sfcobs_uselist.txt .
cpreq -p ${FIX_GSI}/gsd_sfcobs_provider.txt .
cpreq -p ${USHrrfs}/run_jcb.py .

# set other placeholders
WIN_ISO="${YYYY}-${MM}-${DD}T${HH}:00:00Z"
WIN_PREFIX="${YYYY}${MM}${DD}.${HH}0000."
SUFFIX="${CDATE}"
jedi_yaml="jedienkf.yaml"

# do replacements
chmod u+w ${JCB_CONFIG_ENKF}
sed -i \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_ISO@|'${WIN_ISO}'|" \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_PREFIX@|'${WIN_PREFIX}'|" \
  -e "s|@SUFFIX@|${SUFFIX}|g" \
  ${JCB_CONFIG_ENKF}

python run_jcb.py "${YYYYMMDDHH}" "${JCB_CONFIG_ENKF}" "${jedi_yaml}"

if [[ ! -s "${jedi_yaml}" ]]; then
  echo "ERROR: ${jedi_yaml} was not created or is empty"
  exit 1
fi
#
#-----------------------------------------------------------------------
#
# Perform some YAML post processing that JCB cannot handle yet. These sed
# patches should be removed once JCB picks up the upstream OOPS/JEDI
# functionality they work around (currently only available via a fork of
# OOPS built into RDASApp).
#
#-----------------------------------------------------------------------
#
# Since JCB does not support OSDF yet, do a sed replacement to turn these on
sed -i 's/^ *distribution:$/      use data frame container: true\
      redistribution:/' "${jedi_yaml}"

# Turn off all jdiag (obsdataout) outputs -- writing these out is costly and
# not currently used downstream. Revisit once a separate hofx task exists.
sed -i '/^[[:space:]]*obsdataout:/,+6 s/^/#/' "${jedi_yaml}"
#
#-----------------------------------------------------------------------
#
# link observation files
# copy observation files to working directory
#
#-----------------------------------------------------------------------
#
mkdir -p data/obs
cp ${COMOUT}/analysis/ioda_*.nc data/obs/.
#
#-----------------------------------------------------------------------
#
# Set fixed files
#   field_table  = FV3 tracer table
#   input_lam*   = FV3 namelist for the layout in the JCB template
#
#-----------------------------------------------------------------------
#
mkdir -p INPUT
ln -snf ${FIXLAM}/${CRES}_grid.tile7.halo3.nc INPUT/${CRES}_grid.tile7.halo3.nc
ln -snf ${FIXLAM}/${CRES}_grid.tile7.halo3.nc INPUT/${CRES}_grid.tile7.nc
ln -snf ${FIXLAM}/${CRES}_mosaic.halo3.nc INPUT/grid_spec.nc
cpreq -p ${FIX_JEDI}/dynamics_lam_cmaq.yaml .
cpreq -p ${FIX_JEDI}/field_table .
# the per-grid namelists live in parm beside the JCB templates that have to match them
cpreq -p ${PARM_JCB}/${PREDEF_GRID_NAME}/fmsmpp.nml .
cpreq -p ${PARM_JCB}/${PREDEF_GRID_NAME}/input_lam* .
ln -snf ${RDASAPP_DIR}/fix/expr_data/fv3_2024052700/DataFix .
#
#-----------------------------------------------------------------------
#
# Early exit if any member is a cold start
#
#-----------------------------------------------------------------------
#
if [ ${ncold} -gt 0 ]; then
  echo "${ncold} member(s) have no restart files (cold start) - no EnKF update this cycle"
  exit 0
fi
#
#-----------------------------------------------------------------------
#
# Run JEDI-based GETKF (single-shot, writes the full ensemble analysis
# directly in place)
#
#-----------------------------------------------------------------------
#
export OMP_NUM_THREADS=1
export pgm="fv3jedi_letkf.x"
cpreq -p ${EXECrrfs}/${pgm} ./${pgm}

. prep_step

${APRUN} ./$pgm ${jedi_yaml} >>$pgmout 2>errfile
export err=$?; err_chk
cp $pgmout ${COMOUT}/analysis/${RUN}.t${HH}z.jediout_getkf.tm00
cp ${JCB_CONFIG_ENKF} ${COMOUT}/analysis
cp ${jedi_yaml} ${COMOUT}/analysis/${jedi_yaml}
mv errfile errfile_jedi_enkf

print_info_msg "
========================================================================
JEDI-EnKF PROCESS completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
