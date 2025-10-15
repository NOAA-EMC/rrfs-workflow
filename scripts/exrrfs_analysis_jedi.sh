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

This is the ex-script for the task that runs a analysis with FV3 for the
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
valid_args=( "cycle_dir" "jedi_type" "mem_type" \
             "slash_ensmem_subdir" \
             "rrfse_fg_root" "satbias_dir" "ob_type" )
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
# Set environment.
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -v unlimited
ulimit -a
export OOPS_TRACE=0
export LD_LIBRARY_PATH="${RDASAPP_DIR}/build/lib64:${LD_LIBRARY_PATH}"

case $MACHINE in
#
"WCOSS2")
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export OMP_STACKSIZE=500M
  export OMP_NUM_THREADS=1 #${TPP_RUN_ANALYSIS}
  #ncores=160 #$(( NNODES_RUN_ANALYSIS*PPN_RUN_ANALYSIS))
  APRUN="mpirun -n 160 -ppn 80 --cpu-bind core --depth 1"
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
# define fix and background path
#
#-----------------------------------------------------------------------
#
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
if [ "${CYCLE_TYPE}" = "spinup" ]; then
  if [ "${mem_type}" = "MEAN" ]; then
    bkpath=${cycle_dir}/ensmean/fcst_fv3lam_spinup/INPUT
  else
    bkpath=${cycle_dir}${slash_ensmem_subdir}/fcst_fv3lam_spinup/INPUT
  fi
else
  if [ "${mem_type}" = "MEAN" ]; then
    bkpath=${cycle_dir}/ensmean/fcst_fv3lam/INPUT
  else
    bkpath=${cycle_dir}${slash_ensmem_subdir}/fcst_fv3lam/INPUT
  fi
fi
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
    memchar=mem$( printf "%04d" $imem )

    YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${DA_CYCLE_INTERV} hours ago" )
    restart_prefix="${YYYYMMDD}.${HH}0000."
    slash_ensmem_subdir=$memchar
    bkpathmem=${rrfse_fg_root}/${YYYYMMDDHHmInterv}/${slash_ensmem_subdir}/fcst_fv3lam/RESTART
    if [ ${DO_SPINUP} == "TRUE" ]; then
      for cycl_hrs in ${CYCL_HRS_PRODSTART_ENS[@]}; do
       if [ $HH == ${cycl_hrs} ]; then
         bkpathmem=${rrfse_fg_root}/${YYYYMMDDHHmInterv}/${slash_ensmem_subdir}/fcst_fv3lam_spinup/RESTART
       fi
      done
    fi
    dynvarfile=${bkpathmem}/${restart_prefix}fv_core.res.tile1.nc
    tracerfile=${bkpathmem}/${restart_prefix}fv_tracer.res.tile1.nc
    phyvarfile=${bkpathmem}/${restart_prefix}phy_data.nc
    if [ -r "${dynvarfile}" ] && [ -r "${tracerfile}" ] && [ -r "${phyvarfile}" ] ; then
      ln -snf ${bkpathmem}/${restart_prefix}fv_core.res.tile1.nc       fv3SAR${ens_nstarthr}_ens_mem${memcharv0}-fv3_dynvars
      ln -snf ${bkpathmem}/${restart_prefix}fv_tracer.res.tile1.nc     fv3SAR${ens_nstarthr}_ens_mem${memcharv0}-fv3_tracer
      ln -snf ${bkpathmem}/${restart_prefix}phy_data.nc                fv3SAR${ens_nstarthr}_ens_mem${memcharv0}-fv3_phyvars
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
  cat "no ens found" >> filelist03

  case $MACHINE in

  "WCOSS2")

    for loop in $loops; do
      for timelist in $(ls ${ENKF_FCST}/enkfgdas.*/*/atmos/mem080/gdas*.atmf${loop}.${ftype}); do
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

    if [ ${foundgdasens} = "true" ]
    then
      ls ${ENKF_FCST}/enkfgdas.${eyyyymmdd}/${ehh}/atmos/mem???/${enkfcstname}.nc > filelist03
    fi

    ;;
  "JET" | "HERA" | "ORION" | "HERCULES" | "GAEA" )

    for loop in $loops; do
      for timelist in $(ls ${ENKF_FCST}/*.gdas.t*z.atmf${loop}.mem080.${ftype}); do
        availtimeyy=$(basename ${timelist} | cut -c 1-2)
        availtimeyyyy=20${availtimeyy}
        availtimejjj=$(basename ${timelist} | cut -c 3-5)
        availtimemm=$(date -d "${availtimeyyyy}0101 +$(( 10#${availtimejjj} - 1 )) days" +%m)
        availtimedd=$(date -d "${availtimeyyyy}0101 +$(( 10#${availtimejjj} - 1 )) days" +%d)
        availtimehh=$(basename ${timelist} | cut -c 6-7)
        availtime=${availtimeyyyy}${availtimemm}${availtimedd}${availtimehh}
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
           enkfcstname=${availtimeyy}${availtimejjj}${availtimehh}00.gdas.t${availtimehh}z.atmf${loop}
           foundgdasens="true"
        fi
      done
    done

    if [ $foundgdasens = "true" ]; then
      ls ${ENKF_FCST}/${enkfcstname}.mem0??.${ftype} >> filelist03
    fi

  esac
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
WXFLOWLIB=${RDASAPP_DIR}/sorc/wxflow/src
JCBLIB=${RDASAPP_DIR}/sorc/jcb/src
export PYTHONPATH="${JCBLIB}:${WXFLOWLIB}:${PYIODALIB}:${PYTHONPATH}"

cp ${PARMdir}/rdas-atmosphere-templates-fv3_c13.yaml .
cp ${USHdir}/run_jcb.py .

#sed - rdas-atmosphere-templates.yaml
WIN_BEG=$(date -u -d "${YYYY}-${MM}-${DD} ${HH}:00:00 UTC -1 hour -30 minutes" +"%Y-%m-%dT%H:%M:%SZ")
WIN_END=$(date -u -d "${YYYY}-${MM}-${DD} ${HH}:00:00 UTC +1 hour +30 minutes" +"%Y-%m-%dT%H:%M:%SZ")
# set other placeholders
WIN_ISO="${YYYY}-${MM}-${DD}T${HH}:00:00Z"
WIN_PREFIX="${YYYY}${MM}${DD}.${HH}0000."
SUFFIX="${CDATE}"
jcb_config="rdas-atmosphere-templates-fv3_c13.yaml"
jedi_yaml="jedivar.yaml"

# do replacements
sed -i \
  -e "s|@WINDOW_BEGIN@|'${WIN_BEG}'|" \
  -e "s|@WINDOW_END@|'${WIN_END}'|" \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_ISO@|'${WIN_ISO}'|" \
  -e "s|@ATMOSPHERE_BACKGROUND_TIME_PREFIX@|'${WIN_PREFIX}'|" \
  -e "s|@SUFFIX@|${SUFFIX}|g" \
  ${jcb_config}

python run_jcb.py "${YYYYMMDDHH}" "${jcb_config}" "${jedi_yaml}"
#
#-----------------------------------------------------------------------
#
# link or copy background and grib configuration files
#
#  Using ncks to add phis (terrain) into cold start input background.
#           it is better to change GSI to use the terrain from fix file.
#  Adding radar_tten array to fv3_tracer. Should remove this after add this array in
#           radar_tten converting code.
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
    if [ "${anav_type}" = "AERO" ]; then
      cp ${bkpath}/fv_tracer.res.tile1.nc  fv3_tracer
    else
      ln -snf ${bkpath}/fv_tracer.res.tile1.nc  fv3_tracer
    fi
    ln -snf ${bkpath}/sfc_data.nc  fv3_sfcdata
    ln -snf ${bkpath}/phy_data.nc  fv3_phyvars
  else
    for ii in ${list_iolayout}
    do
      iii=`printf %4.4i $ii`
      ln -snf ${bkpath}/fv_core.res.tile1.nc.${iii}  fv3_dynvars.${iii}
      if [ "${anav_type}" = "AERO" ]; then
        cp ${bkpath}/fv_tracer.res.tile1.nc.${iii}  fv3_tracer.${iii}
      else
        ln -snf ${bkpath}/fv_tracer.res.tile1.nc.${iii}  fv3_tracer.${iii}
      fi
      ln -snf ${bkpath}/sfc_data.nc.${iii}  fv3_sfcdata.${iii}
      ln -snf ${bkpath}/phy_data.nc.${iii}  fv3_phyvars.${iii}
      ln -snf ${gridspec_dir}/fv3_grid_spec.${iii}  fv3_grid_spec.${iii}
    done
  fi
  fv3lam_bg_type=0
fi

# update times in coupler.res to current cycle time
cp ${fixgriddir}/fv3_coupler.res  coupler.res
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
cp $COMOUT/ioda_*.nc data/obs/.
#
#-----------------------------------------------------------------------
#
# including satellite radiance data
#
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
#
# Create links to fix files in the FIXgsi directory.
# Set fixed files
#   berror   = forecast model background error statistics
#   specoef  = CRTM spectral coefficients
#   trncoef  = CRTM transmittance coefficients
#   emiscoef = CRTM coefficients for IR sea surface emissivity model
#   aerocoef = CRTM coefficients for aerosol effects
#   cldcoef  = CRTM coefficients for cloud effects
#   satinfo  = text file with information about assimilation of brightness temperatures
#   satangl  = angle dependent bias correction file (fixed in time)
#   pcpinfo  = text file with information about assimilation of prepcipitation rates
#   ozinfo   = text file with information about assimilation of ozone data
#   errtable = text file with obs error for conventional data (regional only)
#   convinfo = text file with information about assimilation of conventional data
#   bufrtable= text file ONLY needed for single obs test (oneobstest=.true.)
#   bftab_sst= bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)
#
#-----------------------------------------------------------------------
#
mkdir -p INPUT
ln -snf ${fixgriddir}/fv3_akbk  fv3_akbk
ln -snf ${fixgriddir}/fv3_grid_spec  fv3_grid_spec
ln -snf ${FIXLAM}/C775_grid.tile7.halo3.nc INPUT/C775_grid.tile7.halo3.nc
ln -snf ${FIXLAM}/C775_mosaic.halo3.nc INPUT/grid_spec.nc
cp ${FIX_JEDI}/coupler.res .
cp ${FIX_JEDI}/dynamics_lam_cmaq.yaml .
cp ${FIX_JEDI}/field_table .
cp ${FIX_JEDI}/fmsmpp.nml .
cp ${FIX_JEDI}/gfs-restart.yaml .
cp ${FIX_JEDI}/${PREDEF_GRID_NAME}/berror_stats .
cp ${FIX_JEDI}/${PREDEF_GRID_NAME}/gsiparm_regional.anl .
cp ${FIX_JEDI}/${PREDEF_GRID_NAME}/input_lam_C775_NP16X10.nml .
#
#-----------------------------------------------------------------------
#
# CRTM Spectral and Transmittance coefficients
# set coefficient under crtm_coeffs_path='./crtm_coeffs/',
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
#
# cycling radiance bias corretion files
#
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
# skip radar reflectivity analysis if no RRFSE ensemble
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
#
# Build the GSI namelist on-the-fly
#    most configurable paramters take values from settings in config.sh
#                                             (var_defns.sh in runtime)
#
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
#
# Run the JEDI.  Note that we have to launch the forecast from
# the current cycle's run directory because the JEDI executable will look
# for input files in the current directory.
#
#-----------------------------------------------------------------------
#
#export OOPS_TRACE=1
#export OOPS_DEBUG=1
export OMP_NUM_THREADS=1
export pgm="fv3jedi_var.x"
jedi_exec="${EXECdir}/bin/${pgm}"
cp ${jedi_exec} ${analworkdir}/${pgm}

. prep_step

${APRUN} ./$pgm jedivar.yaml >>$pgmout 2>errfile
export err=$?; err_chk
mv errfile errfile_jedi
#
#-----------------------------------------------------------------------
#
# touch a file "gsi_complete.txt" after the successful GSI run. This is to inform
# the successful analysis for the EnKF recentering
#
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
# Loop over first and last outer loops to generate innovation
# diagnostic files for indicated observation types (groups)
#
# NOTE:  Since we set miter=2 in GSI namelist SETUP, outer
#        loop 03 will contain innovations with respect to
#        the analysis.  Creation of o-a innovation files
#        is triggered by write_diag(3)=.true.  The setting
#        write_diag(1)=.true. turns on creation of o-g
#        innovation files.
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
PREPBUFR PROCESS completed successfully!!!

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

