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

This is the ex-script for the task that runs the JEDI EnKF analysis with
FV3 for the specified cycle.
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
valid_args=( "cycle_dir" "NWGES_DIR" "ob_type" )
process_args valid_args "$@"

ulimit -s unlimited
ulimit -v unlimited
ulimit -a
export OOPS_TRACE=0
export LD_LIBRARY_PATH="${RDASAPP_DIR}/build/lib64:${LD_LIBRARY_PATH}"

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
  export OMP_NUM_THREADS=1 #${TPP_RUN_ANALYSIS}
  ncores=$((NNODES_RUN_ENKF_JEDI*PPN_RUN_ENKF_JEDI))
  ppn=${PPN_RUN_ENKF_JEDI}
  APRUN="mpirun -n ${ncores} -ppn ${ppn} --cpu-bind core --depth 1"
  ;;
#
"HERA")
  APRUN="srun"
  ;;
  #
"GAEA")
  APRUN="srun"
  ;;
#
"JET")
  APRUN="srun"
  ;;
#
"ORION")
  APRUN="srun"
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
#
#-----------------------------------------------------------------------
#
# Define fix path
#
#-----------------------------------------------------------------------
#
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
if [ "${CYCLE_TYPE}" = "spinup" ]; then
   enkfanal_nwges_dir="${NWGES_DIR}/anal_enkf_jedi_spinup"
else
   enkfanal_nwges_dir="${NWGES_DIR}/anal_enkf_jedi"
fi
mkdir -p ${enkfanal_nwges_dir}

cp ${fixgriddir}/fv3_coupler.res    coupler.res
cp ${fixgriddir}/fv3_akbk           fv3_akbk
cp ${fixgriddir}/fv3_grid_spec      fv3_grid_spec

# update times in coupler.res to current cycle time
sed -i "s/yyyy/${YYYY}/" coupler.res
sed -i "s/mm/${MM}/"     coupler.res
sed -i "s/dd/${DD}/"     coupler.res
sed -i "s/hh/${HH}/"     coupler.res

#
#-----------------------------------------------------------------------
#
# Loop through the members, link the background into run directory
#
#-----------------------------------------------------------------------
#
mkdir -p data/inputs
for imem in  $(seq 1 $nens); do

  memchar="mem"$(printf %04i $imem)
  memcharv0="mem"$(printf %03i $imem)
  slash_ensmem_subdir=$memchar
  if [ "${CYCLE_TYPE}" = "spinup" ]; then
    bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam_spinup/INPUT
  else
    bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam/INPUT
  fi

  # decide background type
  if [ -r "${bkpath}/coupler.res" ]; then
    BKTYPE=0              # warm start
  else
    BKTYPE=1              # cold start
  fi

  mkdir data/inputs/${memcharv0}
  bkpath=${bkpath}.jedi
  ln -snf ${bkpath}/fv_core.res.tile1.nc       data/inputs/${memcharv0}/fv_core.res.tile1.nc
  ln -snf ${bkpath}/fv_tracer.res.tile1.nc     data/inputs/${memcharv0}/fv_tracer.res.tile1.nc
  ln -snf ${bkpath}/sfc_data.nc                data/inputs/${memcharv0}/sfc_data.nc
  ln -snf ${bkpath}/phy_data.nc                data/inputs/${memcharv0}/phy_data.nc
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
WXFLOWLIB=${RDASAPP_DIR}/sorc/wxflow/src
JCBLIB=${RDASAPP_DIR}/sorc/jcb/src
export PYTHONPATH="${JCBLIB}:${WXFLOWLIB}:${PYIODALIB}:${PYTHONPATH}"

cp ${PARMdir}/${JCB_CONFIG_ENKF_OBSERVER} .
cp ${PARMdir}/${JCB_CONFIG_ENKF_SOLVER} .
cp ${USHdir}/run_jcb.py .

#sed - rdas-atmosphere-templates.yaml
# set other placeholders
WIN_ISO="${YYYY}-${MM}-${DD}T${HH}:00:00Z"
WIN_PREFIX="${YYYY}${MM}${DD}.${HH}0000."
SUFFIX="${CDATE}"
jedi_yaml_observer="jedienkf_observer.yaml"
jedi_yaml_solver="jedienkf_solver.yaml"

# do replacements
sed -i \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_ISO@|'${WIN_ISO}'|" \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_PREFIX@|'${WIN_PREFIX}'|" \
  -e "s|@SUFFIX@|${SUFFIX}|g" \
  ${JCB_CONFIG_ENKF_OBSERVER}
sed -i \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_ISO@|'${WIN_ISO}'|" \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_PREFIX@|'${WIN_PREFIX}'|" \
  -e "s|@SUFFIX@|${SUFFIX}|g" \
  ${JCB_CONFIG_ENKF_SOLVER}

python run_jcb.py "${YYYYMMDDHH}" "${JCB_CONFIG_ENKF_OBSERVER}" "${jedi_yaml_observer}"
python run_jcb.py "${YYYYMMDDHH}" "${JCB_CONFIG_ENKF_SOLVER}" "${jedi_yaml_solver}"

#
#-----------------------------------------------------------------------
#
# link observation files
# copy observation files to working directory
#
#-----------------------------------------------------------------------
#
mkdir -p data/obs
cp $COMOUT/ioda_*.nc data/obs/.

#
#-----------------------------------------------------------------------
#
# Copy in other fix files needed
#
#-----------------------------------------------------------------------
#

mkdir -p INPUT
ln -snf ${FIXLAM}/${CRES}_grid.tile7.halo3.nc INPUT/${CRES}_grid.tile7.halo3.nc
ln -snf ${FIXLAM}/${CRES}_grid.tile7.halo3.nc INPUT/${CRES}_grid.tile7.nc
ln -snf ${FIXLAM}/${CRES}_mosaic.halo3.nc INPUT/grid_spec.nc
cp ${FIX_JEDI}/dynamics_lam_cmaq.yaml .
cp ${FIX_JEDI}/field_table .
cp ${FIX_JEDI}/${PREDEF_GRID_NAME}/fmsmpp.nml .
cp ${FIX_JEDI}/${PREDEF_GRID_NAME}/input_lam* .

#
#-----------------------------------------------------------------------
#
# Early exit if this is a cold start cycle and DO_DACOLD is False
#
#-----------------------------------------------------------------------
#

if [[ "${DO_DACOLD}" = "FALSE" && "${BKTYPE}" -eq 1 ]]; then
  echo "Not performing DA for cold cycles - do early clean exit"
  exit 0
fi

#
#-----------------------------------------------------------------------
# Restripe the output directory for faster analysis writing
#-----------------------------------------------------------------------
#

if [ "${PREDEF_GRID_NAME}" == "RRFS_NA_3km" ]; then
  stripesize=30
else
  stripesize=8
fi

for imem in  $(seq 1 $nens); do
  memcharv0="mem"$(printf %03i $imem)
  mkdir ${memcharv0}
  cd "${memcharv0}"
  for f in inc_jedi.fv_core.res.nc \
           inc_jedi.fv_srf_wnd.res.nc \
           inc_jedi.fv_tracer.res.nc \
           inc_jedi.phy_data.nc \
           inc_jedi.sfc_data.nc
  do
    rm -f "$f"
    lfs setstripe --stripe-count ${stripesize} --stripe-size 1048576 --pool disk "$f"
  done
  cd ..
done

#
#-----------------------------------------------------------------------
#
# Run JEDI-based EnKF for the observer step
#
#-----------------------------------------------------------------------
#
#export OOPS_TRACE=1
#export OOPS_DEBUG=1
export OMP_NUM_THREADS=1
export pgm="fv3jedi_letkf.x"
jedi_exec="${EXECdir}/bin/${pgm}"
cp "${jedi_exec}" "${enkfworkdir}/${pgm}"

. prep_step

${APRUN} ./$pgm jedienkf_observer.yaml >>$pgmout 2>errfile
export err=$?; err_chk
cp $pgmout ${COMOUT}/rrfs.t${HH}z.jediout_observer.tm00
cp ${JCB_CONFIG_ENKF_OBSERVER} ${COMOUT}
cp jedienkf_observer.yaml ${COMOUT}/jedienkf_observer.yaml
mv errfile errfile_jedi_observer

#
#-----------------------------------------------------------------------
#
# Run JEDI-based EnKF for the solver step
#
#-----------------------------------------------------------------------
#
#export OOPS_TRACE=1
#export OOPS_DEBUG=1
export OMP_NUM_THREADS=1
export pgm="fv3jedi_letkf.x"
jedi_exec="${EXECdir}/bin/${pgm}"
cp "${jedi_exec}" "${enkfworkdir}/${pgm}"

. prep_step

${APRUN} ./$pgm jedienkf_solver.yaml >>$pgmout 2>errfile
export err=$?; err_chk
cp $pgmout ${COMOUT}/rrfs.t${HH}z.jediout_solver.tm00
cp ${JCB_CONFIG_ENKF_SOLVER} ${COMOUT}
cp jedienkf_solver.yaml ${COMOUT}/jedienkf_solver.yaml
mv errfile errfile_jedi_solver

# Save the Jdiag files for diagnostic tools
for diag in jdiag*.nc; do
  base=${diag%.nc}
  cp "$diag" "${COMOUT}/${base}_enkf.nc"
done

#
#-----------------------------------------------------------------------
#
# Move increments to INPUT.jedi
#
#-----------------------------------------------------------------------
#

for imem in  $(seq 1 $nens); do
  memchar="mem"$(printf %04i $imem)
  memcharv0="mem"$(printf %03i $imem)
  slash_ensmem_subdir=$memchar
  if [ "${CYCLE_TYPE}" = "spinup" ]; then
    bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam_spinup/INPUT
  else
    bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam/INPUT
  fi
  bkpath=${bkpath}.jedi
  mv ${memcharv0}/* ${bkpath}
done

print_info_msg "
========================================================================
JEDI-EnKF PROCESS completed successfully!!!

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
