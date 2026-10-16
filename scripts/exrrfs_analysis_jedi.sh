#!/bin/bash
set -x

source ${FIXrrfs}/workflow/${WGF}/workflow.conf

export FIX_GSI="${FIXrrfs}/gsi"
export FIX_JEDI="${FIXrrfs}/jedi"
export FIXLAM=${FIXLAM:-${HOMErrfs}/fix/lam/RRFS_NA_3km}
export PARM_JCB="${PARMrrfs}/jedi"
# RDASApp ships the JCB templates' python driver, the CRTM coefficients and the offline sonde
# tools in its source tree, so the ex-script needs the clone itself and not only the
# executables installed into exec/.
export RDASAPP_DIR="${RDASAPP_DIR:-${HOMErrfs}/sorc/RDASApp}"
export FIX_CRTM_JEDI="${FIX_CRTM_JEDI:-${RDASAPP_DIR}/fix/expr_data/fv3_2024052700/data/crtm}"

# Switches the Rocoto workflow carries in config.sh but the NCO workflow.conf does not. The
# defaults match ush/config_defaults.sh in the Rocoto workflow; a retro overrides them by
# appending to workflow.conf.
export JCB_CONFIG_CONV=${JCB_CONFIG_CONV:-"rdas-atmosphere-templates-fv3_c13.yaml"}
export JCB_CONFIG_DBZ=${JCB_CONFIG_DBZ:-"rdas-atmosphere-templates-fv3_c13_dbz.yaml"}
export DO_DACOLD=${DO_DACOLD:-"FALSE"}
export EXT_SONDE=${EXT_SONDE:-"FALSE"}
export DO_RADDA=${DO_RADDA:-"FALSE"}

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

This is the ex-script for the task that runs a JEDI variational analysis
with RRFS for the specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Configuration Parameters
#
#-----------------------------------------------------------------------
#
if [[ ! -v OB_TYPE ]]; then
  OB_TYPE="conv"
fi
export OB_TYPE=${OB_TYPE}
ob_type=${OB_TYPE}
mem_type=${MEM_TYPE:-"MEMBER"}
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

# Job size. workflow.conf does not carry these yet, so the defaults match
# NNODES/PPN/TPP_RUN_ANALYSIS_JEDI in the Rocoto workflow's ush/config_defaults.sh.
NNODES_ANALYSIS_JEDI=${NNODES_ANALYSIS_JEDI:-10}
PPN_ANALYSIS_JEDI=${PPN_ANALYSIS_JEDI:-24}
TPP_ANALYSIS_JEDI=${TPP_ANALYSIS_JEDI:-1}

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
  export OMP_NUM_THREADS=${TPP_ANALYSIS_JEDI}
  ncores=$(( NNODES_ANALYSIS_JEDI*PPN_ANALYSIS_JEDI ))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_ANALYSIS_JEDI} --cpu-bind core --depth ${OMP_NUM_THREADS}"
  APRUN_UA="mpiexec -n 1 -ppn 1 --cpu-bind core --depth 1"
  ;;
#
"URSA")
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=${TPP_ANALYSIS_JEDI}
  ncores=$(( NNODES_ANALYSIS_JEDI*PPN_ANALYSIS_JEDI ))
  APRUN="srun --export=ALL -n ${ncores} --ntasks-per-node=${PPN_ANALYSIS_JEDI} --cpus-per-task=${OMP_NUM_THREADS}"
  APRUN_UA="srun --export=ALL -n 1"
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
# define fix and background path
#
#-----------------------------------------------------------------------
#
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
bkpath=${FORECAST_INPUT_PRODUCT}
# decide background type
if [ -r "${bkpath}/coupler.res" ]; then
  BKTYPE=0              # warm start
else
  BKTYPE=1              # cold start
  regional_ensemble_option=1
fi

if  [ ${ob_type} != "conv" ] || [ ${BKTYPE} -eq 1 ]; then #not using GDAS
  l_both_fv3sar_gfs_ens=.false.
fi
#
#---------------------------------------------------------------------
#
# decide regional_ensemble_option: global ensemble (1) or FV3LAM ensemble (5)
#
#---------------------------------------------------------------------
#
echo "regional_ensemble_option is ",${regional_ensemble_option:-1}
print_info_msg "$VERBOSE" "FIX_GSI is $FIX_GSI"
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"
print_info_msg "$VERBOSE" "default bkpath is $bkpath"
print_info_msg "$VERBOSE" "background type is $BKTYPE"
mkdir -p data/inputs
#
# Check if we have enough FV3-LAM ensembles when regional_ensemble_option=5
#
if  [[ ${regional_ensemble_option:-1} -eq 5 ]]; then
  ens_nstarthr=$( printf "%02d" ${DA_CYCLE_INTERV} )
  imem=1
  ifound=0
  for hrs in ${CYCL_HRS_HYB_FV3LAM_ENS[@]}; do
  if [ $HH == ${hrs} ]; then

  while [[ $imem -le ${NUM_ENS_MEMBERS} ]];do
    memcharv0=$( printf "%03d" $imem )
    memchar=m$( printf "%03d" $imem )
    mkdir -p data/inputs/mem${memcharv0}

    YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${DA_CYCLE_INTERV} hours ago" )
    YYYYMMDDInterv=${YYYYMMDDHHmInterv:0:8}
    HHInterv=${YYYYMMDDHHmInterv:8:2}
    restart_prefix="${YYYYMMDD}.${HH}0000."
    bkpathmem=${COMrrfs}/enkfrrfs.${YYYYMMDDInterv}/${HHInterv}/${memchar}/forecast/RESTART
    dynvarfile=${bkpathmem}/${restart_prefix}fv_core.res.tile1.nc
    tracerfile=${bkpathmem}/${restart_prefix}fv_tracer.res.tile1.nc
    phyvarfile=${bkpathmem}/${restart_prefix}phy_data.nc
    if [ -r "${dynvarfile}" ] && [ -r "${tracerfile}" ] && [ -r "${phyvarfile}" ] ; then
      ln -snf ${bkpathmem}/${restart_prefix}fv_core.res.tile1.nc       data/inputs/mem${memcharv0}/fv3_dynvars
      ln -snf ${bkpathmem}/${restart_prefix}fv_tracer.res.tile1.nc     data/inputs/mem${memcharv0}/fv3_tracer
      ln -snf ${bkpathmem}/${restart_prefix}phy_data.nc                data/inputs/mem${memcharv0}/fv3_phyvars
      ln -snf ${bkpathmem}/${restart_prefix}sfc_data.nc                data/inputs/mem${memcharv0}/fv3_sfcdata
      ln -snf ${bkpathmem}/${restart_prefix}fv_srf_wnd.res.tile1.nc    data/inputs/mem${memcharv0}/fv_srf_wnd.res.tile1.nc
      ln -snf ${bkpathmem}/${restart_prefix}coupler.res                data/inputs/mem${memcharv0}/coupler.res
      (( ifound += 1 ))
    else
      print_info_msg "WARNING: Cannot find ensemble files: ${dynvarfile} ${tracerfile} ${phyvarfile} "
    fi
    (( imem += 1 ))
  done

  fi
  done

  if [[ $ifound -ne ${NUM_ENS_MEMBERS} ]] || [[ ${BKTYPE} -eq 1 ]]; then
    print_info_msg "Not enough FV3_LAM ensembles, will fall to GDAS"
    regional_ensemble_option=1
    l_both_fv3sar_gfs_ens=.false.
  fi
fi
#
if  [[ ${regional_ensemble_option:-1} -eq 1 || ${l_both_fv3sar_gfs_ens} = ".true." ]]; then #using GDAS
  #-----------------------------------------------------------------------
  # Make a list of the latest GFS EnKF ensemble
  #-----------------------------------------------------------------------
  stampcycle=$(date -d "${START_DATE}" +%s)
  minHourDiff=100
  loops="009"    # or 009s for GFSv15
  ftype="nc"  # or nemsio for GFSv15
  foundgdasens="false"
  echo "no ens found" >> filelist03

  for loop in $loops; do
    for timelist in $(ls ${ENKF_FCST}/enkfgdas.*/*/atmos/mem080/gdas*.atmf${loop}.${ftype} 2>/dev/null); do
      availtimeyyyymmdd=$(echo ${timelist} | cut -d'/' -f9 | cut -c 10-17)
      availtimehh=$(echo ${timelist} | cut -d'/' -f10)
      availtime=${availtimeyyyymmdd}${availtimehh}
      avail_time=$(echo "${availtime}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
      avail_time=$(date -d "${avail_time}")

      loopfcst=$(echo ${loop}| cut -c 1-3)      # for nemsio 009s to get 009
      stamp_avail=$(date -d "${avail_time} ${loopfcst} hours" +%s)

      hourDiff=$(echo "($stampcycle - $stamp_avail) / (60 * 60 )" | bc);
      if [[ ${stampcycle} -lt ${stamp_avail} ]]; then
         hourDiff=$(echo "($stamp_avail - $stampcycle) / (60 * 60 )" | bc);
      fi

      if [[ ${hourDiff} -lt ${minHourDiff} ]]; then
         minHourDiff=${hourDiff}
         enkfcstname=gdas.t${availtimehh}z.atmf${loop}
         eyyyymmdd=$(echo ${availtime} | cut -c1-8)
         ehh=$(echo ${availtime} | cut -c9-10)
         foundgdasens="true"
      fi
    done
  done

  if [ ${foundgdasens} = "true" ]; then
    ls ${ENKF_FCST}/enkfgdas.${eyyyymmdd}/${ehh}/atmos/mem???/${enkfcstname}.nc > filelist03
  fi
fi

#
#-----------------------------------------------------------------------
#
# JCB - JEDI Configuration Builder
#
#-----------------------------------------------------------------------
#
anav_type=${ob_type}
# pyioda libraries
shopt -s nullglob
dirs=("$RDASAPP_DIR"/build/lib/python3.*)
PYIODALIB=${dirs[0]}
shopt -u nullglob
WXFLOWLIB=${RDASAPP_DIR}/sorc/wxflow/src
JCBLIB=${RDASAPP_DIR}/sorc/jcb/src
export PYTHONPATH="${JCBLIB}:${WXFLOWLIB}:${PYIODALIB}:${PYTHONPATH}"

if [[ ${anav_type} == "conv" ]]; then
  jcb_config=${JCB_CONFIG_CONV}
elif [[ ${anav_type} == "radardbz" ]]; then
  jcb_config=${JCB_CONFIG_DBZ}
fi
cpreq -p ${PARM_JCB}/${jcb_config} .
cpreq -p ${FIX_GSI}/gsd_sfcobs_uselist.txt .
cpreq -p ${FIX_GSI}/gsd_sfcobs_provider.txt .
cpreq -p ${USHrrfs}/run_jcb.py .

#sed - rdas-atmosphere-templates.yaml
# set other placeholders
WIN_ISO="${YYYY}-${MM}-${DD}T${HH}:00:00Z"
WIN_PREFIX="${YYYY}${MM}${DD}.${HH}0000."
SUFFIX="${CDATE}"
jedi_yaml="jedivar.yaml"

# do replacements
chmod u+w ${jcb_config}
sed -i \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_ISO@|'${WIN_ISO}'|" \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_PREFIX@|'${WIN_PREFIX}'|" \
  -e "s|@SUFFIX@|${SUFFIX}|g" \
  ${jcb_config}

python run_jcb.py "${YYYYMMDDHH}" "${jcb_config}" "${jedi_yaml}"

if [[ ! -s "${jedi_yaml}" ]]; then
  echo "ERROR: ${jedi_yaml} was not created or is empty"
  exit 1
fi

#
#-----------------------------------------------------------------------
#
# link or copy background and grib configuration files
#
#  Using ncks to add phis (terrain) into cold start input background.
#           it is better to change GSI to use the terrain from fix file.
#-----------------------------------------------------------------------
#
n_iolayouty=$(($IO_LAYOUT_Y-1))
list_iolayout=$(seq 0 $n_iolayouty)

if [ ${BKTYPE} -eq 1 ]; then  # cold start uses background from INPUT
  ln -snf ${fixgriddir}/phis.nc  phis.nc
  ncks -A -v  phis  phis.nc  ${bkpath}/gfs_data.tile7.halo0.nc

  ln -snf ${bkpath}/sfc_data.tile7.halo0.nc  fv3_sfcdata
  ln -snf ${bkpath}/gfs_data.tile7.halo0.nc  fv3_dynvars
  ln -s fv3_dynvars  fv3_tracer

  fv3lam_bg_type=1
else                          # cycle uses background from restart
  if [ "${IO_LAYOUT_Y}" == "1" ]; then
    ln -snf ${bkpath}/fv_core.res.tile1.nc  fv3_dynvars
    ln -snf ${bkpath}/fv_srf_wnd.res.tile1.nc fv_srf_wnd.res.tile1.nc
    ln -snf ${bkpath}/fv_tracer.res.tile1.nc  fv3_tracer
    ln -snf ${bkpath}/sfc_data.nc  fv3_sfcdata
    ln -snf ${bkpath}/phy_data.nc  fv3_phyvars
  else
    for ii in ${list_iolayout}
    do
      iii=$(printf %4.4i $ii)
      ln -snf ${bkpath}/fv_core.res.tile1.nc.${iii}  fv3_dynvars.${iii}
      ln -snf ${bkpath}/fv_tracer.res.tile1.nc.${iii}  fv3_tracer.${iii}
      ln -snf ${bkpath}/sfc_data.nc.${iii}  fv3_sfcdata.${iii}
      ln -snf ${bkpath}/phy_data.nc.${iii}  fv3_phyvars.${iii}
      ln -snf ${gridspec_dir}/fv3_grid_spec.${iii}  fv3_grid_spec.${iii}
    done
  fi
  fv3lam_bg_type=0
fi

# update times in coupler.res to current cycle time
cpreq -p ${fixgriddir}/fv3_coupler.res  coupler.res
chmod 644 coupler.res
sed -i "s/yyyy/${YYYY}/" coupler.res
sed -i "s/mm/${MM}/"     coupler.res
sed -i "s/dd/${DD}/"     coupler.res
sed -i "s/hh/${HH}/"     coupler.res
#
#-----------------------------------------------------------------------
#
# link observation files
# copy observation files to working directory
#
#-----------------------------------------------------------------------
#
mkdir -p data/obs
cp ${COMOUT}/ioda_*.nc data/obs/.
#
#-----------------------------------------------------------------------
#
# including satellite radiance data
#
#-----------------------------------------------------------------------
mkdir -p data/satbias_in  data/satbias_out

cp "${FIX_JEDI}/"satbias_init/*.tlapse.txt data/satbias_in/.

if [[ ${DO_RADDA} == "TRUE" ]]; then # copy bias from previous cycle
  satcounter=1
  maxcounter=240
  echo 'COMOUT =', ${COMOUT}
  cur_comout=${COMOUT}
  while [ $satcounter -lt $maxcounter ]; do
    # COMOUT ends in <RUN>.YYYYMMDD/HH/analysis, so step back two levels to reach the cycle
    # hour and one more for the day, then rebuild the same path an hour earlier.
    cur_hour=$(basename "$(dirname "$cur_comout")")   # HH
    cur_date=$(basename "$(dirname "$(dirname "$cur_comout")")")  # <RUN>.YYYYMMDD
    cur_date=${cur_date#*.}                           # YYYYMMDD
    run_dir_name=$(basename "$(dirname "$(dirname "$cur_comout")")")

    # Compute previous cycle using date arithmetic
    prev_cycle=$(date -u -d "${cur_date} ${cur_hour} -1 hours" +%Y%m%d%H)

    # Extract previous date and hour
    prev_date=${prev_cycle:0:8}
    prev_hour=${prev_cycle:8:2}

    # Construct previous COMOUT path
    prev_comout=$(dirname "$(dirname "$(dirname "$cur_comout")")")/${run_dir_name%.*}.${prev_date}/${prev_hour}/analysis

    # Check if previous cycle exists
    if [ -d "$prev_comout/satbias_out" ]; then
        echo "[$satcounter] Previous cycle exists: $prev_comout/satbias_out"
        ls  -l $prev_comout/satbias_out
        # Copy satbias_out files from current COMOUT to your target directory
        cp ${prev_comout}/satbias_out/* data/satbias_in/.
        break   # exit WHILE loop
    else
        echo "[$satcounter] Previous cycle does NOT exist: $prev_comout"
    fi

    # Prepare COMOUT for next iteration (move to previous cycle)
    cur_comout=$prev_comout

    # Increment counter
    satcounter=$((satcounter + 1))

  done
# If not find satbias from previous 10 days, copy it from satbias_init
  if [ $satcounter -eq $maxcounter ]; then
    echo "Not found satbias from previous 10 days, copy it from satbias_init"
    cp "${FIX_JEDI}/"satbias_init/*.nc data/satbias_in/.
  fi
fi
#
#-----------------------------------------------------------------------
#
# Set fixed files
#   berror_stats = forecast model background error statistics
#   crtm         = CRTM coefficients for the radiance operators
#   field_table  = FV3 tracer table
#   mgbf*        = multigrid beta filter namelists for the hybrid B
#
#-----------------------------------------------------------------------
#
ln -snf ${FIX_CRTM_JEDI} data/crtm
mkdir -p INPUT
ln -snf ${fixgriddir}/fv3_akbk  fv3_akbk
ln -snf ${fixgriddir}/fv3_grid_spec  fv3_grid_spec
ln -snf ${FIXLAM}/${CRES}_grid.tile7.halo3.nc INPUT/${CRES}_grid.tile7.halo3.nc
ln -snf ${FIXLAM}/${CRES}_grid.tile7.halo3.nc INPUT/${CRES}_grid.tile7.nc
ln -snf ${FIXLAM}/${CRES}_mosaic.halo3.nc INPUT/grid_spec.nc
cpreq -p ${FIX_JEDI}/dynamics_lam_cmaq.yaml .
cpreq -p ${FIX_JEDI}/field_table .
cpreq -p ${FIX_JEDI}/fmsmpp.nml .
# berror_stats is per-domain in the NCO fix tree; the Rocoto workflow takes it from the top of
# FIX_JEDI and fmsmpp.nml from the domain directory, which is the other way round here.
cpreq -p ${FIX_JEDI}/${PREDEF_GRID_NAME}/berror_stats .
cpreq -p ${FIX_JEDI}/${PREDEF_GRID_NAME}/gsiparm_regional.anl .
cpreq -p ${FIX_JEDI}/${PREDEF_GRID_NAME}/input_lam* .
cpreq -p ${FIX_JEDI}/${PREDEF_GRID_NAME}/mgbf* .
ln -snf ${RDASAPP_DIR}/fix/expr_data/fv3_2024052700/DataFix .
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
# If performing reflectivity analysis, prepare phy_data.nc files
#-----------------------------------------------------------------------
#
if [[ ${anav_type} == "radardbz" ]]; then
  cpreq -p ${USHrrfs}/prep_phydata_dbz.py ./
  python prep_phydata_dbz.py fv3_phyvars
  if [[ ${regional_ensemble_option:-1} ]]; then
    imem=1
    while [[ $imem -le ${NUM_ENS_MEMBERS} ]];do
      memcharv0=$( printf "%03d" $imem )
      python prep_phydata_dbz.py data/inputs/mem${memcharv0}/fv3_phyvars
      imem=$((imem+1))
    done
  fi
fi
#
#-----------------------------------------------------------------------
# Final adpupa preprocessing.
#
# This is done in the analysis task, rather than in ioda_bufr, because the
# optional sonde extension step needs rsig information derived from the
# background file.
#
# EXT_SONDE=TRUE:
#   create ioda_adpupa.sondeext.nc, then patch that file.
#
# EXT_SONDE=FALSE:
#   patch the original ioda_adpupa.nc file.
#
# In both cases, the final file consumed by JEDI is:
#   data/obs/ioda_adpupa.nc
#-----------------------------------------------------------------------
#
if [[ "${EXT_SONDE}" == "TRUE" ]]; then
  cp data/obs/ioda_adpupa.nc .
  cpreq -p "${RDASAPP_DIR}"/rrfs-test/IODA/offline_rsig.py .
  cpreq -p "${RDASAPP_DIR}"/rrfs-test/IODA/offline_ioda_sonde_ext.py .
  ./offline_rsig.py
  ./offline_ioda_sonde_ext.py -i ioda_adpupa.nc -r rsig.txt -o ioda_adpupa.sondeext.nc

  if [[ ! -f "ioda_adpupa.sondeext.nc" ]]; then
    echo "FATAL: expected patched adpupa file not found: ioda_adpupa.sondeext.nc" >&2
    exit 1
  fi

  cp ioda_adpupa.sondeext.nc data/obs/ioda_adpupa.nc
fi
#
#-----------------------------------------------------------------------
#
# Run JEDI. Note that we have to launch the analysis from the current
# cycle's run directory because the JEDI executable will look for input
# files in the current directory.
#
#-----------------------------------------------------------------------
#
export OMP_NUM_THREADS=1
export pgm="fv3jedi_var.x"
cpreq -p ${EXECrrfs}/${pgm} ./${pgm}

. prep_step

${APRUN} ./$pgm ${jedi_yaml} >>$pgmout 2>errfile
export err=$?; err_chk
cp $pgmout ${COMOUT}/${RUN}.t${HH}z.jediout_${anav_type}.tm00
cp ${jcb_config} ${COMOUT}
cp ${jedi_yaml} ${COMOUT}/jedivar_${anav_type}.yaml
mv errfile errfile_jedi
#
#-----------------------------------------------------------------------
#
# Convert A-grid wind increments to D-grid wind increments.
#
# JEDI aliases the analyzed A-grid wind to ua_anl/va_anl and leaves every
# other analyzed variable in place under its normal name; the D-grid u/v
# wind (never touched by JEDI) still needs to be updated to match.
# rdas_ua2u.x's --in_anl mode does that in place: computes the A-grid wind
# increment (ua_anl-ua, va_anl-va), converts it to a D-grid increment, adds
# it to the background u/v already in the file, and removes ua_anl/va_anl
# (--remove_anl_winds). fv3_dynvars is a link into the forecast INPUT
# directory, so the forecast reads the updated winds directly.
#
#-----------------------------------------------------------------------
#
# Disable HDF5's advisory file locking to avoid intermittent failures
export HDF5_USE_FILE_LOCKING=FALSE
export pgm="rdas_ua2u.x"
cpreq -p ${EXECrrfs}/${pgm} ./${pgm}

${APRUN_UA} ./${pgm} ua_update_u --in_grid=fv3_grid_spec --in_anl=fv3_dynvars --remove_anl_winds >>$pgmout 2>errfile
export err=$?; err_chk
mv errfile errfile_ua2u

# Save the Jdiag files for diagnostic tools
cp jdiag* ${COMOUT} || print_info_msg "WARNING: no jdiag files to save"
cp -r data/satbias_out ${COMOUT}/.
#
#-----------------------------------------------------------------------
#
# touch a file "jedi_complete.txt" after the successful JEDI run. This is to inform
# the successful analysis for the EnKF recentering
#
#-----------------------------------------------------------------------
#
touch ${COMOUT}/jedi_complete.txt
if [[ ${anav_type} == "radardbz" || ${anav_type} == "conv_dbz" ]]; then
  touch ${COMOUT}/jedi_complete_radar.txt # for nonvarcldanl
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
JEDIVAR PROCESS completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
