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
. $USHdir/set_FV3nml_ens_stoch_seeds.sh
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

This is the ex-script for the task that runs a forecast with FV3 for the
specified cycle.
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
valid_args=( \
"cdate" \
"cycle_type" \
"cycle_subtype" \
"ensmem_indx" \
"slash_ensmem_subdir" \
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
# Determine early exit for running blending vs 1 time step ensinit.
#
#-----------------------------------------------------------------------
#
run_blending=${NWGES_BASEDIR}/${cdate}/run_blending
run_ensinit=${NWGES_BASEDIR}/${cdate}/run_ensinit
if [[ ${cycle_subtype} == "ensinit" && -e $run_blending && ! -e $run_ensinit ]]; then
   echo "clean exit ensinit, blending used instead of ensinit."
   exit 0
fi
#
#-----------------------------------------------------------------------
#
# Set environments
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case $MACHINE in

  "WCOSS2")
    OMP_NUM_THREADS=${TPP_RUN_FCST}
    OMP_STACKSIZE=1G
    export MPICH_ABORT_ON_ERROR=1
    export MALLOC_MMAP_MAX_=0
    export MALLOC_TRIM_THRESHOLD_=134217728
    export MPICH_REDUCE_NO_SMP=1
    export FOR_DISABLE_KMP_MALLOC=TRUE
    export FI_OFI_RXM_RX_SIZE=40000
    export FI_OFI_RXM_TX_SIZE=40000
    export MPICH_OFI_STARTUP_CONNECT=1
    export MPICH_OFI_VERBOSE=1
    export MPICH_OFI_NIC_VERBOSE=1
    APRUN="mpiexec -n ${PE_MEMBER01} -ppn ${PPN_RUN_FCST} --cpu-bind core --depth ${OMP_NUM_THREADS}"
    ;;

  "HERA")
    APRUN="srun --export=ALL --mem=0"
    ;;

  "ORION")
    APRUN="srun --export=ALL --mem=0"
    ;;

  "HERCULES")
    APRUN="srun --export=ALL"
    ;;

  "JET")
    APRUN="srun --export=ALL --mem=0"
    if [ "${PREDEF_GRID_NAME}" == "RRFS_NA_3km" ]; then
      OMP_NUM_THREADS=4
    else
      OMP_NUM_THREADS=2
    fi
    ;;

  *)
    err_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN = \"$APRUN\""
    ;;

esac
#
#-----------------------------------------------------------------------
#
export KMP_AFFINITY=scatter
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
export OMP_STACKSIZE=${OMP_STACKSIZE:-1024m}
#
#-----------------------------------------------------------------------
#
# Create links in the INPUT subdirectory of the current run directory to
# the grid and (filtered) orography files.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Creating links in the INPUT subdirectory of the current run directory to
the grid and (filtered) orography files ..."

# Create links to fix files in the FIXLAM directory.

cd ${run_dir}/INPUT

relative_or_null=""

# Symlink to mosaic file with a completely different name.
target="${FIXLAM}/${CRES}${DOT_OR_USCORE}mosaic.halo${NH3}.nc" # must use *mosaic.halo3.nc
symlink="grid_spec.nc"
if [ -f "${target}" ]; then
  ln -sf ${relative_or_null} $target $symlink
else
  err_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

# Symlink to halo-3 grid file with "halo3" stripped from name.
mosaic_fn="grid_spec.nc"
grid_fn=$( get_charvar_from_netcdf "${mosaic_fn}" "gridfiles" )

target="${FIXLAM}/${CRES}${DOT_OR_USCORE}grid.tile7.halo${NH3}.nc"
symlink="${grid_fn}"
if [ -f "${target}" ]; then
  ln -sf ${relative_or_null} $target $symlink
else
  err_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

# Symlink to halo-4 grid file with "${CRES}_" stripped from name.
#
# If this link is not created, then the code hangs with an error message
# like this:
#
#   check netcdf status=           2
#  NetCDF error No such file or directory
# Stopped
#
# Note that even though the message says "Stopped", the task still con-
# sumes core-hours.
#
target="${FIXLAM}/${CRES}${DOT_OR_USCORE}grid.tile${TILE_RGNL}.halo${NH4}.nc"
symlink="grid.tile${TILE_RGNL}.halo${NH4}.nc"
if [ -f "${target}" ]; then
  ln -sf ${relative_or_null} $target $symlink
else
  err_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

relative_or_null=""

# Symlink to halo-0 orography file with "${CRES}_" and "halo0" stripped from name.
target="${FIXLAM}/${CRES}${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo${NH0}.nc"
symlink="oro_data.nc"
if [ -f "${target}" ]; then
  ln -sf ${relative_or_null} $target $symlink
else
  err_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

#
# Symlink to halo-4 orography file with "${CRES}_" stripped from name.
#
# If this link is not created, then the code hangs with an error message
# like this:
#
#   check netcdf status=           2
#  NetCDF error No such file or directory
# Stopped
#
# Note that even though the message says "Stopped", the task still con-
# sumes core-hours.
#
target="${FIXLAM}/${CRES}${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
symlink="oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
if [ -f "${target}" ]; then
  ln -sf ${relative_or_null} $target $symlink
else
  err_exit "\
Cannot create symlink because target does not exist:
  target = \"$target\""
fi

#
# If using some specific physics suites such as FV3_HRRR or FV3_RAP, there are two files 
# (that contain statistics of the orography) that are needed by the gravity 
# wave drag parameterization in that suite.  Below, create symlinks to these 
# files in the run directory.
#
suites=( "RRFS_sas" "FV3_RAP" "FV3_HRRR" "FV3_HRRR_gf" "FV3_GFS_v15_thompson_mynn_lam3km" "FV3_GFS_v17_p8" )
if [[ ${suites[@]} =~ "${CCPP_PHYS_SUITE}" ]] ; then
  fileids=( "ss" "ls" )
  for fileid in "${fileids[@]}"; do
    target="${FIXLAM}/${CRES}${DOT_OR_USCORE}oro_data_${fileid}.tile${TILE_RGNL}.halo${NH0}.nc"
    symlink="oro_data_${fileid}.nc"
    if [ -f "${target}" ]; then
      ln -sf ${relative_or_null} $target $symlink
    else
      err_exit "\
Cannot create symlink because target does not exist:
  target = \"${target}\"
  symlink = \"${symlink}\""
    fi
  done
fi
#
#-----------------------------------------------------------------------
#
# The FV3 model looks for the following files in the INPUT subdirectory
# of the run directory:
#
#   gfs_data.nc
#   sfc_data.nc
#   gfs_bndy*.nc
#   gfs_ctrl.nc
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Creating links with names that FV3 looks for in the INPUT subdirectory
of the current run directory (run_dir), where
  run_dir = \"${run_dir}\"
..."

BKTYPE=1    # cold start using INPUT
if [ -r ${run_dir}/INPUT/coupler.res ] ; then
  BKTYPE=0  # cycling using RESTART
fi
print_info_msg "$VERBOSE" "
The forecast has BKTYPE $BKTYPE (1:cold start ; 0 cycling)"

cd ${run_dir}/INPUT

relative_or_null=""

n_iolayouty=$(($IO_LAYOUT_Y-1))
list_iolayout=$(seq 0 $n_iolayouty)

if [ "${DO_NON_DA_RUN}" = "TRUE" ]; then
  target="${CYCLE_DIR}${SLASH_ENSMEM_SUBDIR}/ics/gfs_data.tile${TILE_RGNL}.halo${NH0}.nc"
else
  if [ ${BKTYPE} -eq 1 ]; then
    target="gfs_data.tile${TILE_RGNL}.halo${NH0}.nc"
  else
    target="fv_core.res.tile1.nc"
  fi
fi
symlink="gfs_data.nc"
if [ -f "${target}.0000" ]; then
  for ii in ${list_iolayout}
  do
    iii=$(printf %4.4i $ii)
    if [ -f "${target}.${iii}" ]; then
      ln -sf ${relative_or_null} $target.${iii} $symlink.${iii}
    else
      err_exit "\
      Cannot create symlink because target does not exist:
      target = \"$target.$iii\""
    fi
  done
else
  if [ -f "${target}" ]; then
    ln -sf ${relative_or_null} $target $symlink
  else
    err_exit "\
    Cannot create symlink because target does not exist:
    target = \"$target\""
  fi
fi

if [ "${DO_NON_DA_RUN}" = "TRUE" ]; then
  target="${CYCLE_DIR}${SLASH_ENSMEM_SUBDIR}/ics/sfc_data.tile${TILE_RGNL}.halo${NH0}.nc"
  symlink="sfc_data.nc"
  ln -sf ${relative_or_null} $target $symlink

  target="${CYCLE_DIR}${SLASH_ENSMEM_SUBDIR}/ics/gfs_ctrl.nc"
  symlink="gfs_ctrl.nc"
  ln -sf ${relative_or_null} $target $symlink

  target="${CYCLE_DIR}${SLASH_ENSMEM_SUBDIR}/ics/gfs_bndy.tile${TILE_RGNL}.000.nc"
  symlink="gfs_bndy.tile${TILE_RGNL}.000.nc"
  ln -sf ${relative_or_null} $target $symlink

  for fhr in $(seq -f "%03g" ${LBC_SPEC_INTVL_HRS} ${LBC_SPEC_INTVL_HRS} ${FCST_LEN_HRS}); do
    target="${CYCLE_DIR}${SLASH_ENSMEM_SUBDIR}/lbcs/gfs_bndy.tile${TILE_RGNL}.${fhr}.nc"
    symlink="gfs_bndy.tile${TILE_RGNL}.${fhr}.nc"
    ln -sf ${relative_or_null} $target $symlink
  done
else
  if [ ${BKTYPE} -eq 1 ]; then
    target="sfc_data.tile${TILE_RGNL}.halo${NH0}.nc"
    symlink="sfc_data.nc"
    if [ -f "${target}" ]; then
      ln -sf ${relative_or_null} $target $symlink
    else
      err_exit "\
      Cannot create symlink because target does not exist:
      target = \"$target\""
    fi
  else
    if [ -f "sfc_data.nc.0000" ] || [ -f "sfc_data.nc" ]; then
      print_info_msg "$VERBOSE" "
      sfc_data.nc is available at INPUT directory"
    else
      err_exit "\
      sfc_data.nc is not available for cycling"
    fi
  fi
fi

if [ "${DO_SMOKE_DUST}" = "TRUE" ]; then
  ln -snf  ${FIX_SMOKE_DUST}/${PREDEF_GRID_NAME}/dust12m_data.nc  ${run_dir}/INPUT/dust12m_data.nc
  ln -snf  ${FIX_SMOKE_DUST}/${PREDEF_GRID_NAME}/emi_data.nc      ${run_dir}/INPUT/emi_data.nc
  yyyymmddhh=${cdate:0:10}
  echo ${yyyymmddhh}
  if [ ${cycle_type} = "spinup" ]; then
    smokefile=${NWGES_BASEDIR}/RAVE_INTP/SMOKE_RRFS_data_${yyyymmddhh}00_spinup.nc
  else
    smokefile=${NWGES_BASEDIR}/RAVE_INTP/SMOKE_RRFS_data_${yyyymmddhh}00.nc
  fi
  echo "try to use smoke file=",${smokefile}
  if [ -f ${smokefile} ]; then
    ln -snf ${smokefile} ${run_dir}/INPUT/SMOKE_RRFS_data.nc
  else
    ln -snf ${FIX_SMOKE_DUST}/${PREDEF_GRID_NAME}/dummy_24hr_smoke.nc ${run_dir}/INPUT/SMOKE_RRFS_data.nc
    echo "WARNING: Smoke file is not available, use dummy_24hr_smoke.nc instead"
  fi
fi
#
#-----------------------------------------------------------------------
#
# Create links in the current run directory to fixed (i.e. static) files
# in the FIXam directory.  These links have names that are set to the
# names of files that the forecast model expects to exist in the current
# working directory when the forecast model executable is called (and
# that is just the run directory).
#
#-----------------------------------------------------------------------
#
cd ${run_dir}

print_info_msg "$VERBOSE" "
Creating links in the current run directory (run_dir) to fixed (i.e.
static) files in the FIXam directory:
  FIXam = \"${FIXam}\"
  run_dir = \"${run_dir}\""

relative_or_null=""

regex_search="^[ ]*([^| ]+)[ ]*[|][ ]*([^| ]+)[ ]*$"
num_symlinks=${#CYCLEDIR_LINKS_TO_FIXam_FILES_MAPPING[@]}
for (( i=0; i<${num_symlinks}; i++ )); do

  mapping="${CYCLEDIR_LINKS_TO_FIXam_FILES_MAPPING[$i]}"
  symlink=$( printf "%s\n" "$mapping" | \
             sed -n -r -e "s/${regex_search}/\1/p" )
  target=$( printf "%s\n" "$mapping" | \
            sed -n -r -e "s/${regex_search}/\2/p" )

  symlink="${run_dir}/$symlink"
  target="$FIXam/$target"
  if [ -f "${target}" ]; then
    ln -sf ${relative_or_null} $target $symlink
  else
    err_exit "\
  Cannot create symlink because target does not exist:
    target = \"$target\""
  fi

done

ln -sf ${relative_or_null} ${FIXam}/optics_??.dat ${run_dir}
ln -sf ${relative_or_null} ${FIXam}/aeroclim.m??.nc ${run_dir}
#
#-----------------------------------------------------------------------
#
# If running this cycle/ensemble member combination more than once (e.g.
# using rocotoboot), remove any time stamp file that may exist from the
# previous attempt.
#
#-----------------------------------------------------------------------
#
cd ${run_dir}
rm -f time_stamp.out
#
#-----------------------------------------------------------------------
#
# Create links in the current run directory to cycle-independent (and
# ensemble-member-independent) model input files in the main experiment
# directory.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Creating links in the current run directory to cycle-independent model
input files in the main experiment directory..."

relative_or_null=""

ln -sf ${relative_or_null} ${DATA_TABLE_FP} ${run_dir}
ln -sf ${relative_or_null} ${FIELD_TABLE_FP} ${run_dir}
ln -sf ${relative_or_null} ${UFS_YAML_FP} ${run_dir}

#
# Determine if running stochastic physics for the specified cycles in CYCL_HRS_STOCH
#
STOCH="FALSE"
if [ "${DO_ENSEMBLE}" = TRUE ] && ([ "${DO_SPP}" = TRUE ] || [ "${DO_SPPT}" = TRUE ] || [ "${DO_SHUM}" = TRUE ] \
  || [ "${DO_SKEB}" = TRUE ] || [ "${DO_LSM_SPP}" =  TRUE ]); then
   for cyc_start in "${CYCL_HRS_STOCH[@]}"; do
     if [ ${HH} -eq ${cyc_start} ]; then 
       STOCH="TRUE"
     fi
   done
fi

if [ ${BKTYPE} -eq 0 ]; then
  # cycling, using namelist for cycling forecast
  if [ "${STOCH}" = "TRUE" ]; then
    cp ${FV3_NML_RESTART_STOCH_FP} ${run_dir}/${FV3_NML_FN}
   else
    cp ${FV3_NML_RESTART_FP} ${run_dir}/${FV3_NML_FN}
  fi
else
  if [ -f "INPUT/cycle_surface.done" ]; then
  # namelist for cold start with surface cycle
    cp ${FV3_NML_CYCSFC_FP} ${run_dir}/${FV3_NML_FN}
  else
  # cold start, using namelist for cold start
    if [ "${STOCH}" = "TRUE" ]; then
      cp ${FV3_NML_STOCH_FP} ${run_dir}/${FV3_NML_FN}
     else
      cp ${FV3_NML_FP} ${run_dir}/${FV3_NML_FN}
    fi
  fi
fi

if [ "${STOCH}" = "TRUE" ]; then
  if [ ${BKTYPE} -eq 0 ] && [ ${DO_ENSFCST_MULPHY} = "TRUE" ]; then
    ensmem_num=$(echo "${ensmem_indx}" | awk '{print $1+0}')
    cp ${FV3_NML_RESTART_STOCH_FP}_ensphy${ensmem_num} ${run_dir}/${FV3_NML_FN}_base 
    rm -fr ${run_dir}/field_table
    cp ${PARMdir}/field_table.rrfsens_phy${ensmem_indx} ${run_dir}/field_table
  else
    cp ${run_dir}/${FV3_NML_FN} ${run_dir}/${FV3_NML_FN}_base
  fi
  set_FV3nml_ens_stoch_seeds cdate="$cdate"
  export err=$?
  if [ $err -ne 0 ]; then
    err_exit "\
 Call to function to create the ensemble-based namelist for the current 
 cycle's (cdate) run directory (run_dir) failed: 
   cdate = \"${cdate}\"
   run_dir = \"${run_dir}\""
  fi
fi
#
#-----------------------------------------------------------------------
#
# Call the function that creates the model configuration file within each
# cycle directory.
#
#-----------------------------------------------------------------------
#
$USHdir/create_model_configure_file.py \
  --path-to-defns ${GLOBAL_VAR_DEFNS_FP} \
  --cdate "${cdate}" \
  --cycle_type "${cycle_type}" \
  --cycle_subtype "${cycle_subtype}" \
  --stoch "${STOCH}" \
  --run-dir "${run_dir}" \
  --fhrot "${FHROT}" \
  --nthreads "${OMP_NUM_THREADS}" \
  --restart_hrs="${RESTART_HRS}"
export err=$?
if [ $err -ne 0 ]; then
  err_exit "Call to function to create the model_configure file for
the current cycle's (cdate) run directory (DATA) failed:
  DATA = \"${run_dir}\""
fi
#
#-----------------------------------------------------------------------
#
# Call the function that creates the diag_table file within each
# cycle directory.
#
#-----------------------------------------------------------------------
#
$USHdir/create_diag_table_file.py \
  --path-to-defns ${GLOBAL_VAR_DEFNS_FP} \
  --run-dir ${run_dir}
export err=$?
if [ $err -ne 0 ]; then
  err_exit "Call to function to create the diag_table file for
the current cycle's (cdate) run directory (DATA) failed:
  DATA = \"${run_dir}\""
fi

# copy over diag_table for multiphysics ensemble
if [ "${STOCH}" = "TRUE" ] && [ ${BKTYPE} -eq 0 ] && [ ${DO_ENSFCST_MULPHY} = "TRUE" ]; then
  rm -fr ${run_dir}/diag_table
  cp ${PARMdir}/diag_table.rrfsens_phy${ensmem_indx} ${run_dir}/diag_table
fi

#
#-----------------------------------------------------------------------
#
# Call the function that creates the UFS configuration file within each
# cycle directory.
#
#-----------------------------------------------------------------------
#
$USHdir/create_ufs_configure_file.py \
  --path-to-defns ${GLOBAL_VAR_DEFNS_FP} \
  --run-dir ${run_dir} 
export err=$?
if [ $err -ne 0 ]; then
  err_exit "Call to function to create the UFS configuration file for
the current cycle's (cdate) run directory (DATA) failed:
  DATA = \"${run_dir}\""
fi
#
#-----------------------------------------------------------------------
#
# If INPUT/phy_data.nc exists, convert it from NetCDF4 to NetCDF3
# (happens for cycled runs, not cold-started)
#
#-----------------------------------------------------------------------
#
if [[ -f phy_data.nc ]] ; then
  echo "convert phy_data.nc from NetCDF4 to NetCDF3"
  cd INPUT
  rm -f phy_data.nc3 phy_data.nc4
  cp -fp phy_data.nc phy_data.nc4
  if ( ! time ( module purge ; module load intel szip hdf5 netcdf nco ; module list ; set -x ; ncks -3 --64 phy_data.nc4 phy_data.nc3) ) ; then
    mv -f phy_data.nc4 phy_data.nc
    rm -f phy_data.nc3
    echo "NetCDF 4=>3 conversion failed. :-( Continuing with NetCDF 4 data."
  else
    mv -f phy_data.nc3 phy_data.nc
  fi
  cd ..
fi
#
#-----------------------------------------------------------------------
#
# Run the FV3-LAM model.  Note that we have to launch the forecast from
# the current cycle's directory because the FV3 executable will look for
# input files in the current directory. Since those files have been
# staged in the cycle directory, the current directory must be the cycle
# directory.
#
#-----------------------------------------------------------------------
#
export pgm="ufs_model"
cp ${FV3_EXEC_FP} ${run_dir}/$pgm
. prep_step

$APRUN ${run_dir}/$pgm >>$pgmout 2>errfile
export err=$?; err_chk
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
FV3 forecast completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Save grid_spec files for restart subdomain.
#
#-----------------------------------------------------------------------
#
if [ ${BKTYPE} -eq 1 ] && [ ${n_iolayouty} -ge 1 ]; then
  for ii in ${list_iolayout}
  do
    iii=$(printf %4.4i $ii)
    if [ -f "grid_spec.nc.${iii}" ]; then
      cp grid_spec.nc.${iii} ${gridspec_dir}/fv3_grid_spec.${iii}
    else
      err_exit "\
      Cannot create symlink because target does not exist:
      target = \"grid_spec.nc.$iii\""
    fi
  done
fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

