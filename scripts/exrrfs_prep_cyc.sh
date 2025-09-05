#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHrrfs/source_util_funcs.sh
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

This is the ex-script for the prep_cyc tasks for the specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set environment
#
#-----------------------------------------------------------------------
#
case $MACHINE in

  "WCOSS2")
    ncores=$(( NNODES_PREP_CYC*PPN_PREP_CYC))
    APRUN="mpiexec -n ${ncores} -ppn ${PPN_PREP_CYC}"
    ;;

  "HERA")
    APRUN="srun --export=ALL --mem=0"
    ;;

  "ORION")
    ulimit -s unlimited
    ulimit -a
    APRUN="srun --export=ALL"
    ;;

  "HERCULES")
    ulimit -s unlimited
    ulimit -a
    APRUN="srun --export=ALL"
    ;;

  "JET")
    APRUN="srun --export=ALL --mem=0"
    ;;

  *)
    err_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN = \"$APRUN\""
    ;;

esac
export FIXLAM=${FIXLAM:-${FIXrrfs}/lam/${PREDEF_GRID_NAME}}
#
#-----------------------------------------------------------------------
#
# Setup environment variable for running case
#
#-----------------------------------------------------------------------
#
#### TOBEREMOVED
gridspec_dir=${gridspec_dir:-""}
CONT_CYCLE_DATA_ROOT=${COMOUT}
####

#### change FG_ROOT to COMrrfs before code delivery
FG_ROOT=${COMrrfs}

LBCS_ROOT=${COMrrfs}
ICS_ROOT=${shared_output_data_ics}

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
YYYYJJJHH=${YYYY}${JJJ}${HH}

current_time=$(date "+%T")
cdate_crnt_fhr=$( date --utc --date "${YYYYMMDD} ${HH} UTC" "+%Y%m%d%H" )

YYYYMMDDm1=$(date +%Y%m%d -d "${START_DATE} 1 days ago")
YYYYMMDDm2=$(date +%Y%m%d -d "${START_DATE} 2 days ago")
YYYYMMDDm3=$(date +%Y%m%d -d "${START_DATE} 3 days ago")
#
#-----------------------------------------------------------------------
#
# Compute date & time components for the SST analysis time relative to current analysis time
#
#-----------------------------------------------------------------------
#
YYJJJ00000000=`date +"%y%j00000000" -d "${START_DATE} 1 day ago"`
YYJJJ1200=`date +"%y%j1200" -d "${START_DATE} 1 day ago"`
YYJJJ2200000000=`date +"%y%j2200000000" -d "${START_DATE} 1 day ago"`
#
#-----------------------------------------------------------------------
#
# Determine early exit for running blending vs 1 time step ensinit.
#
#-----------------------------------------------------------------------
#
run_blending=${COMOUT}/run_blending
run_ensinit=${COMOUT}/run_ensinit
if [[ $CYCLE_SUBTYPE == "ensinit" && -e $run_blending && ! -e $run_ensinit ]]; then
   echo "clean exit ensinit, blending used instead of ensinit."
   exit 0
fi
#
#-----------------------------------------------------------------------
#
# #### go to INPUT directory.
# prepare initial conditions for ensemble free forecast after ensemble DA
#
#-----------------------------------------------------------------------
#
if [ "${DO_ENSFCST}" = "TRUE" ] &&  [ "${DO_ENKFUPDATE}" = "TRUE" ]; then
  bkpath=${COMrrfs}/enkfrrfs.${PDY}/${cyc}/${mem_num}/forecast/DA_OUTPUT
  #if [ ${WGF} == "enkf" ] || [ ${WGF} == "ensf" ]; then
  #  bkpath=${COMrrfs}/enkfrrfs.${PDY}/${cyc}/forecast/DA_OUTPUT
  #fi
  filelistn="fv_core.res.tile1.nc fv_srf_wnd.res.tile1.nc fv_tracer.res.tile1.nc phy_data.nc sfc_data.nc"
  checkfile=${bkpath}/coupler.res
  n_iolayouty=$(($IO_LAYOUT_Y-1))
  list_iolayout=$(seq 0 $n_iolayouty)
  if [ -r "${checkfile}" ] ; then
    cpreq -p ${bkpath}/coupler.res    coupler.res
    cpreq -p ${bkpath}/gfs_ctrl.nc    gfs_ctrl.nc
    cpreq -p ${bkpath}/fv_core.res.nc fv_core.res.nc
    if [ "${IO_LAYOUT_Y}" == "1" ]; then
      for file in ${filelistn}; do
        cpreq -p ${bkpath}/${file} ${file}
      done
    else
      for file in ${filelistn}; do
         for ii in $list_iolayout
         do
           iii=$(printf %4.4i $ii)
           cpreq -p ${bkpath}/${file}.${iii} ${file}.${iii}
         done
      done
    fi
  else
    err_exit "Can not find ensemble DA analysis output for running ensemble free forecast, \
  check ${bkpath} for needed files."
  fi
  SFC_CYC=0
else
  #
  #-----------------------------------------------------------------------
  #
  # go to INPUT directory.
  # prepare initial conditions for 
  #     cold start if BKTYPE=1 
  #     warm start if BKTYPE=0
  #     spinupcyc + warm start if BKTYPE=2
  #       the previous 6 cycles are searched to find the restart files
  #       valid at this time from the closet previous cycle.
  #
  #-----------------------------------------------------------------------
  #
  BKTYPE=0
  if [ "${CYCLE_TYPE}" = "spinup" ]; then
    echo "spin up cycle"
    for cyc_start in "${CYCL_HRS_SPINSTART[@]}"; do
      if [ ${HH} -eq ${cyc_start} ]; then
        BKTYPE=1
      fi
    done
    if [ "${CYCLE_SUBTYPE}" = "spinup" ]; then
      echo "ensinit cycle - warm start from 1 timestep restart files"
      BKTYPE=0
    fi
  else
    echo " product cycle"
    for cyc_start in "${CYCL_HRS_PRODSTART[@]}"; do
      if [ ${HH} -eq ${cyc_start} ]; then
        if [ "${DO_SPINUP}" = "TRUE" ]; then
          BKTYPE=2   # using 1-h forecast from spinup cycle
        else
          BKTYPE=1
        fi
      fi
    done
  fi
  if [ "${DO_ENS_BLENDING}" = "TRUE" ] &&
     [ -e $run_blending ] && [ ! -e $run_ensinit ] &&
     [ "${CYCLE_TYPE}" = "spinup" ] && [ "${CYCLE_SUBTYPE}" = "spinup" ]; then
     BKTYPE=3
  fi

  # cycle surface 
  SFC_CYC=0
  if [ "${DO_SURFACE_CYCLE}" = "TRUE" ]; then  # cycle surface fields
    if [ "${DO_SPINUP}" = "TRUE" ]; then
      if [ "${CYCLE_TYPE}" = "spinup" ]; then
        for cyc_start in "${CYCL_HRS_SPINSTART[@]}"; do
          SFC_CYCL_HH=$(( ${cyc_start} + ${SURFACE_CYCLE_DELAY_HRS} ))
          if [ ${HH} -eq ${SFC_CYCL_HH} ]; then
            if [ "${SURFACE_CYCLE_DELAY_HRS}" = "0" ]; then
              SFC_CYC=1  # cold start
            else
              SFC_CYC=2  # delayed surface cycle
            fi
          fi
        done
      fi
    else
      for cyc_start in "${CYCL_HRS_PRODSTART[@]}"; do
        if [ ${HH} -eq ${cyc_start} ]; then
          SFC_CYC=1  # cold start
        fi
      done
    fi
  fi

  # if do surface surgery, then skip surface cycle
  if [ ${YYYYMMDDHH} -eq ${SOIL_SURGERY_time} ] ; then
    if [ "${CYCLE_TYPE}" = "spinup" ]; then
      SFC_CYC=3  # skip for soil surgery
    fi
  fi

  if [ ${BKTYPE} -eq 1 ] ; then  # cold start, use prepare cold strat initial files from ics
    bkpath=${ICS_ROOT}
    if [ -r "${bkpath}/gfs_data.tile7.halo0.nc" ]; then
      ln -s ${bkpath}/gfs_bndy.tile7.000.nc gfs_bndy.tile7.000.nc        
      ln -s ${bkpath}/gfs_ctrl.nc gfs_ctrl.nc        
      ln -s ${bkpath}/gfs_data.tile7.halo0.nc gfs_data.tile7.halo0.nc        
      ln -s ${bkpath}/sfc_data.tile7.halo0.nc sfc_data.tile7.halo0.nc        
      ln -s ${bkpath}/gfs_bndy.tile7.000.nc bk_gfs_bndy.tile7.000.nc
      ln -s ${bkpath}/gfs_data.tile7.halo0.nc bk_gfs_data.tile7.halo0.nc
      ln -s ${bkpath}/sfc_data.tile7.halo0.nc bk_sfc_data.tile7.halo0.nc
      print_info_msg "$VERBOSE" "cold start from $bkpath"
      echo "${YYYYMMDDHH}(${CYCLE_TYPE}): cold start at ${current_time} from $bkpath "
    else
      err_exit "Cannot find cold start initial condition from : ${bkpath}"
    fi

  elif [[ $BKTYPE == 3 ]]; then
    if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
      bkpath=${ICS_ROOT}
    else
      bkpath=${ICS_ROOT}
    fi
    if [ -r "${bkpath}/coupler.res" ]; then
      cpreq -p ${bkpath}/fv_core.res.nc fv_core.res.nc
      cpreq -p ${bkpath}/fv_core.res.tile1.nc fv_core.res.tile1.nc
      cpreq -p ${bkpath}/fv_srf_wnd.res.tile1.nc fv_srf_wnd.res.tile1.nc
      cpreq -p ${bkpath}/fv_tracer.res.tile1.nc fv_tracer.res.tile1.nc
      cpreq -p ${bkpath}/phy_data.nc phy_data.nc
      cpreq -p ${bkpath}/sfc_data.nc sfc_data.nc
      cpreq -p ${bkpath}/gfs_ctrl.nc gfs_ctrl.nc

      ln -s ${bkpath}/coupler.res bk_coupler.res
      ln -s ${bkpath}/fv_core.res.nc bk_fv_core.res.nc
      ln -s ${bkpath}/fv_core.res.tile1.nc bk_fv_core.res.tile1.nc
      ln -s ${bkpath}/fv_srf_wnd.res.tile1.nc bk_fv_srf_wnd.res.tile1.nc
      ln -s ${bkpath}/fv_tracer.res.tile1.nc bk_fv_tracer.res.tile1.nc
      ln -s ${bkpath}/phy_data.nc bk_phy_data.nc
      ln -s ${bkpath}/sfc_data.nc bk_sfc_data.nc
      echo "${YYYYMMDDHH}(${CYCLE_TYPE}): blended warm start at ${current_time} from $bkpath "
    else
      err_exit "Error: cannot find blended warm start initial condition from : ${bkpath}"
    fi
    # generate coupler.res with right date
    head -1 bk_coupler.res > coupler.res
    tail -1 bk_coupler.res >> coupler.res
    tail -1 bk_coupler.res >> coupler.res

    # remove checksum from restart files. Checksum will cause trouble if model initializes from blended ics
    filelistn="fv_core.res.nc fv_core.res.tile1.nc fv_srf_wnd.res.tile1.nc fv_tracer.res.tile1.nc phy_data.nc sfc_data.nc"

    for file in ${filelistn}; do
      ncatted -a checksum,,d,, ${file}
    done
    ncatted -O -a source,global,c,c,'FV3GFS GAUSSIAN NETCDF FILE' fv_core.res.tile1.nc
  else

  # Setup the INPUT directory for warm start cycles, which can be spin-up cycle or product cycle.
  #
  # First decide the source of the first guess (fg_restart_dirname) depending on CYCLE_TYPE and BKTYPE:
  #  1. If cycle is spinup cycle (CYCLE_TYPE == spinup) or it is the product start cycle (BKTYPE==2),
  #             looking for the first guess from spinup forecast (forecast_spinup)
  #  2. Others, looking for the first guess from product forecast (forecast)
  #
  fg_restart_dirname=forecast
  #
  #   let us figure out which background is available
  #
  #   the restart file from FV3 has a name like: ${YYYYMMDD}.${HH}0000.fv_core.res.tile1.nc
  #   But the restart files for the forecast length has a name like: fv_core.res.tile1.nc
  #   So the defination of restart_prefix needs a "." at the end.
  #
  if [ "${CYCLE_SUBTYPE}" = "spinup" ] ; then
    restart_prefix=$( date "+%Y%m%d.%H%M%S" -d "${YYYYMMDD} ${HH} + ${DT_ATMOS} seconds" ).
  else
    restart_prefix="${YYYYMMDD}.${HH}0000."
  fi

  if [ "${CYCLE_SUBTYPE}" = "spinup" ] ; then
    # point to the 0-h cycle for the warm start from the 1 timestep restart files
    fg_restart_dirname=forecast
    bkpath=${FG_ROOT}/${RUN}.${PDY}/${cyc}_spinup/${mem_num}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
    ctrl_bkpath=${FG_ROOT}/${RUN}.${PDY}/${cyc}_spinup/${mem_num}/forecast/INPUT
  else
    YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${DA_CYCLE_INTERV} hours ago" )
    YYYYMMDDInterv=`echo ${YYYYMMDDHHmInterv} | cut -c1-8`
    HHInterv=`echo ${YYYYMMDDHHmInterv} | cut -c9-10`
    if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
      if [ ${CYCLE_TYPE} == "spinup" ]; then
        bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${mem_num}/${fg_restart_dirname}/RESTART
      else
        if [ ${cyc} == "08" ] || [ ${cyc} == "20" ]; then
          bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${mem_num}/${fg_restart_dirname}/RESTART
        else
          bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${mem_num}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
        fi
      fi
    else
      if [ ${CYCLE_TYPE} == "spinup" ]; then
        bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${fg_restart_dirname}/RESTART
      else
        if [ ${BKTYPE} -eq 2 ]; then
          bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${fg_restart_dirname}/RESTART
        else
          bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
        fi
      fi
    fi

    n=${DA_CYCLE_INTERV}
    while [[ $n -le 6 ]] ; do
      checkfile=${bkpath}/${restart_prefix}coupler.res
      if [ -r "${checkfile}" ] ; then
        print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as background for analysis "
        break
      else
        n=$((n + ${DA_CYCLE_INTERV}))
        YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${n} hours ago" )
        YYYYMMDDInterv=`echo ${YYYYMMDDHHmInterv} | cut -c1-8`
        HHInterv=`echo ${YYYYMMDDHHmInterv} | cut -c9-10`
        if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
          if [ ${CYCLE_TYPE} == "spinup" ]; then
            bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${mem_num}/${fg_restart_dirname}/RESTART
          else
            bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${mem_num}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
          fi
        else
          if [ ${CYCLE_TYPE} == "spinup" ]; then
            bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${fg_restart_dirname}/RESTART
          else
            bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
          fi
        fi
        print_info_msg "$VERBOSE" "Trying this path: ${bkpath}"
      fi
    done

    checkfile=${bkpath}/${restart_prefix}coupler.res
    # spin-up cycle is not success, try to find background from full cycle
    if [ ! -r "${checkfile}" ] && [ ${BKTYPE} -eq 2 ]; then
     print_info_msg "$VERBOSE" "cannot find background from spin-up cycle, try product cycle"
     fg_restart_dirname=forecast
     YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${DA_CYCLE_INTERV} hours ago" )
     YYYYMMDDInterv=`echo ${YYYYMMDDHHmInterv} | cut -c1-8`
     HHInterv=`echo ${YYYYMMDDHHmInterv} | cut -c9-10`
     if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
       bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${mem_num}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
     else
       bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
     fi

     restart_prefix="${YYYYMMDD}.${HH}0000."
     n=${DA_CYCLE_INTERV}
     while [[ $n -le 6 ]] ; do
       checkfile=${bkpath}/${restart_prefix}coupler.res
       if [ -r "${checkfile}" ] ; then
         print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as background for analysis "
         break
       else
         n=$((n + ${DA_CYCLE_INTERV}))
         YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${n} hours ago" )
         YYYYMMDDInterv=`echo ${YYYYMMDDHHmInterv} | cut -c1-8`
         HHInterv=`echo ${YYYYMMDDHHmInterv} | cut -c9-10`
         if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
           bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${mem_num}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
         else
           bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
         fi
         print_info_msg "$VERBOSE" "Trying this path: ${bkpath}"
       fi
     done
    fi
  fi

  filelistn="fv_core.res.tile1.nc fv_srf_wnd.res.tile1.nc fv_tracer.res.tile1.nc phy_data.nc sfc_data.nc"
  checkfile=${bkpath}/${restart_prefix}coupler.res
  n_iolayouty=$(($IO_LAYOUT_Y-1))
  list_iolayout=$(seq 0 $n_iolayouty)
  if [ -r "${checkfile}" ] ; then
    cpreq -p ${bkpath}/${restart_prefix}coupler.res      bk_coupler.res
    cpreq -p ${bkpath}/${restart_prefix}fv_core.res.nc   fv_core.res.nc
    if [ "${IO_LAYOUT_Y}" = "1" ]; then
      for file in ${filelistn}; do
        if [ "${CYCLE_SUBTYPE}" = "spinup" ]; then
          #cpreq -p ${ctrl_bkpath}/${file}  ${file}
          cpreq -p ${bkpath}/${restart_prefix}${file}  ${file}
        else
          cpreq -p ${bkpath}/${restart_prefix}${file}  ${file}
        fi
        ln -s ${bkpath}/${restart_prefix}${file}  bk_${file}
      done
    else
      for file in ${filelistn}; do
        for ii in $list_iolayout
        do
          iii=$(printf %4.4i $ii)
          if [ "${CYCLE_SUBTYPE}" = "spinup" ]; then
            #cpreq -p ${ctrl_bkpath}/${file}.${iii}  ${file}.${iii}
            cpreq -p ${bkpath}/${restart_prefix}${file}.${iii}  ${file}.${iii}
          else
            cpreq -p ${bkpath}/${restart_prefix}${file}.${iii}  ${file}.${iii}
          fi
          ln -s ${bkpath}/${restart_prefix}${file}.${iii}  bk_${file}.${iii}
        done
      done
    fi
    if [ "${CYCLE_SUBTYPE}" = "spinup" ] ; then
      cpreq -p ${FG_ROOT}/${RUN}.${PDY}/${cyc}_spinup/${mem_num}/${fg_restart_dirname}/INPUT/gfs_ctrl.nc  gfs_ctrl.nc
    else
      if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
        if [ "${CYCLE_TYPE}" = "spinup" ]; then
          cpreq -p ${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${mem_num}/${fg_restart_dirname}/INPUT/gfs_ctrl.nc  gfs_ctrl.nc
        else
          if [ ${cyc} == "08" ] || [ ${cyc} == "20" ]; then
            cpreq -p ${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${mem_num}/${fg_restart_dirname}/INPUT/gfs_ctrl.nc  gfs_ctrl.nc
          else
            cpreq -p ${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${mem_num}/${fg_restart_dirname}/INPUT/gfs_ctrl.nc  gfs_ctrl.nc
          fi
        fi
      else
        if [ "${CYCLE_TYPE}" = "spinup" ]; then
          cpreq -p ${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${fg_restart_dirname}/INPUT/gfs_ctrl.nc  gfs_ctrl.nc
        else
          if [ ${BKTYPE} == "2" ]; then
            cpreq -p ${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}_spinup/${fg_restart_dirname}/INPUT/gfs_ctrl.nc  gfs_ctrl.nc
          else
            cpreq -p ${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${fg_restart_dirname}/INPUT/gfs_ctrl.nc  gfs_ctrl.nc
          fi
        fi
      fi
    fi
    echo "${YYYYMMDDHH}(${CYCLE_TYPE}): warm start at ${current_time} from ${checkfile} "
    #
    # remove checksum from restart files. Checksum will cause trouble if model initializes from analysis
    #
    if [ "${IO_LAYOUT_Y}" = "1" ]; then
      for file in ${filelistn}; do
        ncatted -a checksum,,d,, ${file}
      done
      ncatted -O -a source,global,c,c,'FV3GFS GAUSSIAN NETCDF FILE' fv_core.res.tile1.nc
    else
      for file in ${filelistn}; do
        for ii in $list_iolayout
        do
          iii=$(printf %4.4i $ii)
          ncatted -a checksum,,d,, ${file}.${iii}
        done
      done
      for ii in $list_iolayout
      do
        iii=$(printf %4.4i $ii)
        ncatted -O -a source,global,c,c,'FV3GFS GAUSSIAN NETCDF FILE' fv_core.res.tile1.nc.${iii}
      done
    fi
    ncatted -a checksum,,d,, fv_core.res.nc

    # generate coupler.res with right date
    if [ "${CYCLE_SUBTYPE}" = "spinup" ] && [ "${DO_ENSINIT}" = "TRUE" ] ; then
      # from the 1 timestep restart files, when doing the ensemble initialization
      head -2 bk_coupler.res > coupler.res
      head -2 bk_coupler.res | tail -1 >> coupler.res
    else
      head -1 bk_coupler.res > coupler.res
      tail -1 bk_coupler.res >> coupler.res
      tail -1 bk_coupler.res >> coupler.res
    fi
  else
    err_exit "Cannot find background: ${checkfile}"
  fi
fi
#
#-----------------------------------------------------------------------
#
# do snow/ice update at ${SNOWICE_update_hour}z for the restart sfc_data.nc
#
#-----------------------------------------------------------------------
#
COMINobsproc="${COMINobsproc:-$(compath.py obsproc/${obsproc_ver})}"
if [ ${HH} -eq ${SNOWICE_update_hour} ] && [ "${CYCLE_TYPE}" = "prod" ] ; then
  echo "Update snow cover based on imssnow  at ${SNOWICE_update_hour}z"
  if [ -r "${COMINobsproc}/latest.SNOW_IMS" ]; then
    cpreq -p ${COMINobsproc}/latest.SNOW_IMS .
  elif [ -r "${COMINobsproc}/${YYJJJ2200000000}" ]; then
    cpreq -p ${COMINobsproc}/${YYJJJ2200000000} latest.SNOW_IMS
  elif [ -r "${COMINobsproc}/${OBSTYPE_SOURCE}.${YYYYMMDD}/${OBSTYPE_SOURCE}.t${HH}z.imssnow.grib2" ]; then
    cpreq -p ${COMINobsproc}/${OBSTYPE_SOURCE}.${YYYYMMDD}/${OBSTYPE_SOURCE}.t${HH}z.imssnow.grib2  latest.SNOW_IMS
  elif [ -r "${COMINobsproc}/${OBSTYPE_SOURCE}_e.${YYYYMMDD}/${OBSTYPE_SOURCE}_e.t${HH}z.imssnow.grib2" ]; then
    cpreq -p ${COMINobsproc}/${OBSTYPE_SOURCE}_e.${YYYYMMDD}/${OBSTYPE_SOURCE}_e.t${HH}z.imssnow.grib2  latest.SNOW_IMS
  else
    echo "${COMINobsproc} data does not exist!!"
    echo "WARNING: No snow update at ${HH}!!!!"
  fi
  if [ -r "latest.SNOW_IMS" ]; then
    ln -sf ./latest.SNOW_IMS                imssnow2
    if [ "${IO_LAYOUT_Y}" = "1" ]; then
      ln -sf ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec  fv3_grid_spec
    else
      for ii in ${list_iolayout}
      do
         iii=$(printf %4.4i $ii)
         ln -sf ${gridspec_dir}/fv3_grid_spec.${iii}  fv3_grid_spec.${iii}
      done
    fi
    export pgm="process_imssnow_fv3lam.exe"
    . prep_step

    ${APRUN} ${EXECrrfs}/$pgm ${IO_LAYOUT_Y} >>$pgmout 2>errfile
    export err=$?; err_chk
    mv errfile errfile_imssnow

    snowice_reference_time=$(wgrib2 -t latest.SNOW_IMS | tail -1) 
    echo "${YYYYMMDDHH}(${CYCLE_TYPE}): update snow/ice using ${snowice_reference_time}"
  else
     echo "WARNING: No latest IMS SNOW file for update at ${YYYYMMDDHH}!!!!"
  fi
else
  echo "NOTE: No update for IMS SNOW/ICE at ${YYYYMMDDHH}!"
fi
#
#-----------------------------------------------------------------------
#
# do SST update at ${SST_update_hour}z for the restart sfc_data.nc
#
#-----------------------------------------------------------------------
#
COMINnsst="${COMINnsst:-$(compath.py nsst/${nsst_ver})}"
if [ ${HH} -eq ${SST_update_hour} ] && [ "${CYCLE_TYPE}" = "prod" ] ; then
  echo "Update SST at ${SST_update_hour}z"
  if [ -r "${COMINnsst}/latest.SST" ]; then
    cpreq -p ${COMINnsst}/latest.SST .
  elif [ -r "${COMINnsst}/${YYJJJ00000000}" ]; then
    cpreq -p ${COMINnsst}/${YYJJJ00000000} latest.SST
  elif [ -r "${COMINnsst}/nsst.$YYYYMMDD/rtgssthr_grb_0.083.grib2" ]; then 
    cpreq -p ${COMINnsst}/nsst.$YYYYMMDD/rtgssthr_grb_0.083.grib2 latest.SST
  elif [ -r "${COMINnsst}/nsst.$YYYYMMDDm1/rtgssthr_grb_0.083.grib2" ]; then 
    cpreq -p ${COMINnsst}/nsst.$YYYYMMDDm1/rtgssthr_grb_0.083.grib2 latest.SST
  else
    echo "${COMINnsst} data does not exist!!"
    echo "WARNING: No SST update at ${HH}!!!!"
  fi
  if [ -r "latest.SST" ]; then
    cpreq -p ${FIXam}/RTG_SST_landmask.dat               RTG_SST_landmask.dat
    ln -sf ./latest.SST                                  SSTRTG
    cpreq -p ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_akbk     fv3_akbk

cat << EOF > sst.namelist
&setup
  bkversion=1,
  iyear=${YYYY}
  imonth=${MM}
  iday=${DD}
  ihr=${HH}
/
EOF

    export pgm="process_updatesst.exe"

    if [ "${IO_LAYOUT_Y}" = "1" ]; then
      ln -sf ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec  fv3_grid_spec

      . prep_step
      ${APRUN} ${EXECrrfs}/$pgm >>$pgmout 2>errfile
      export err=$?; err_chk
      mv errfile errfile_updatesst
    else
      for ii in ${list_iolayout}
      do
        iii=$(printf %4.4i $ii)
        ln -sf ${gridspec_dir}/fv3_grid_spec.${iii}  fv3_grid_spec
        ln -sf sfc_data.nc.${iii} sfc_data.nc         

        . prep_step
        ${APRUN} ${EXECrrfs}/$pgm >>$pgmout 2>errfile
        export err=$?; err_chk
        mv errfile errfile_updatesst_${iii}

        ls -l > list_sstupdate.${iii}
      done
      rm -f sfc_data.nc
    fi

    sst_reference_time=$(wgrib2 -t latest.SST) 
    echo "${YYYYMMDDHH}(${CYCLE_TYPE}): update SST using ${sst_reference_time}"
  else
    echo "WARNING: No latest SST file for update at ${YYYYMMDDHH}!!!!"
  fi
else
   echo "NOTE: No update for SST at ${YYYYMMDDHH}!"
fi

#-----------------------------------------------------------------------
#
#  smoke/dust cycling
#
#-----------------------------------------------------------------------
if [ "${DO_SMOKE_DUST}" = "TRUE" ] && [ "${CYCLE_TYPE}" = "spinup" ]; then  # cycle smoke/dust fields
  if_cycle_smoke_dust="FALSE"
  if [ ${HH} -eq 4 ] || [ ${HH} -eq 16 ] ; then
     if_cycle_smoke_dust="TRUE"
  elif [ ${HH} -eq 6 ] && [ -f ${COMOUT}/../04_spinup/cycle_smoke_dust_skipped.txt ]; then
     if_cycle_smoke_dust="TRUE"
  elif [ ${HH} -eq 18 ] && [ -f ${COMOUT}/../16_spinup/cycle_smoke_dust_skipped.txt ]; then
     if_cycle_smoke_dust="TRUE"
  fi
  if [ "${if_cycle_smoke_dust}" = "TRUE" ] ; then
      # figure out which surface is available
      surface_file_dir_name=forecast
      bkpath_find="missing"
      restart_prefix_find="missing"
      restart_prefix=$( date +%Y%m%d.%H0000. -d "${START_DATE}" )
      if [ "${bkpath_find}" = "missing" ]; then

          offset_hours=${DA_CYCLE_INTERV}
          YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${offset_hours} hours ago" )
          YYYYMMDDInterv=`echo ${YYYYMMDDHHmInterv} | cut -c1-8`
          HHInterv=`echo ${YYYYMMDDHHmInterv} | cut -c9-10`
          bkpath=${COMrrfs}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/forecast/RESTART
          n=${DA_CYCLE_INTERV}
          while [[ $n -le 25 ]] ; do
             if [ "${IO_LAYOUT_Y}" = "1" ]; then
               checkfile=${bkpath}/${restart_prefix}fv_tracer.res.tile1.nc
             else
               checkfile=${bkpath}/${restart_prefix}fv_tracer.res.tile1.nc.0000
             fi
             if [ -r "${checkfile}" ] && [ "${bkpath_find}" = "missing" ]; then
               bkpath_find=${bkpath}
               restart_prefix_find=${restart_prefix}
               print_info_msg "$VERBOSE" "Found ${checkfile}; Use it for smoke/dust cycle "
               break
             fi
 
             n=$((n + ${DA_CYCLE_INTERV}))
             offset_hours=${n}
             YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${offset_hours} hours ago" )
             YYYYMMDDInterv=`echo ${YYYYMMDDHHmInterv} | cut -c1-8`
             HHInterv=`echo ${YYYYMMDDHHmInterv} | cut -c9-10`
             bkpath=${FG_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${surface_file_dir_name}/RESTART  # cycling, use background from RESTART
             print_info_msg "$VERBOSE" "Trying this path: ${bkpath}"
          done
      fi

      # check if there are tracer file in continue cycle data space:
      if [ "${bkpath_find}" = "missing" ]; then
        #### All required file should exist; there is no need for continue cycle data space
        # err_exit "FATAL: missing fv_tracer.res.tile1.nc"
        echo "WARNING: can not find fv_tracer for smoke/dust cycling at ${HH}"
      fi

      # cycle smoke/dust
      rm -f cycle_smoke_dust.done
      if [ "${bkpath_find}" = "missing" ]; then
        print_info_msg "Warning: cannot find smoke/dust files from previous cycle"
        touch ${COMOUT}/cycle_smoke_dust_skipped.txt
      else
        if [ "${IO_LAYOUT_Y}" = "1" ]; then
          checkfile=${bkpath_find}/${restart_prefix_find}fv_tracer.res.tile1.nc
          if [ -r "${checkfile}" ]; then
            ncks -A -v smoke,dust,coarsepm ${checkfile}  fv_tracer.res.tile1.nc
          fi
        else
          for ii in ${list_iolayout}
          do
            iii=$(printf %4.4i $ii)
            checkfile=${bkpath_find}/${restart_prefix_find}fv_tracer.res.tile1.nc.${iii}
            if [ -r "${checkfile}" ]; then
              ncks -A -v smoke,dust,coarsepm ${checkfile}  fv_tracer.res.tile1.nc.${iii}
            fi
          done
        fi
        echo "${YYYYMMDDHH}(${CYCLE_TYPE}): cycle smoke/dust from ${checkfile} "
      fi
  fi
fi
#
#-----------------------------------------------------------------------
#
#  surface cycling
#
#-----------------------------------------------------------------------
#
#SFC_CYC=2
if_update_ice="TRUE"
if [ ${SFC_CYC} -eq 1 ] || [ ${SFC_CYC} -eq 2 ] ; then  # cycle surface fields

    # figure out which surface is available
    surface_file_dir_name=surface
    restart_prefix_find="missing"
    restart_suffix_find="missing"
    bkpath=${FG_ROOT}/${surface_file_dir_name}

    restart_prefix=$( date +%Y%m%d.%H0000. -d "${START_DATE}" )
    if [ -r "${bkpath}/${restart_prefix}sfc_data.nc.sync" ]; then
      restart_prefix_find=${restart_prefix}
      restart_suffix_find="sync"
    else
      for ndayinhour in 00 24 48 72
      do 
        if [ "${restart_suffix_find}" = "missing" ]; then
          restart_prefix=$( date +%Y%m%d.%H0000. -d "${START_DATE} ${ndayinhour} hours ago" )

          offset_hours=$(( ${DA_CYCLE_INTERV} + ${ndayinhour} ))
          YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${offset_hours} hours ago" )

          n=${DA_CYCLE_INTERV}
          while [[ $n -le 13 ]] ; do
             if [ "${IO_LAYOUT_Y}" = "1" ]; then
               checkfile=${bkpath}/${restart_prefix}sfc_data.nc.${YYYYMMDDHHmInterv}
             else
               checkfile=${bkpath}/${restart_prefix}sfc_data.nc.${YYYYMMDDHHmInterv}.0000
             fi
             if [ -r "${checkfile}" ] && [ "${restart_suffix_find}" == "missing" ]; then
               restart_prefix_find=${restart_prefix}
               restart_suffix_find=${YYYYMMDDHHmInterv}
               print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as surface for analysis "
             fi
 
             n=$((n + ${DA_CYCLE_INTERV}))
             offset_hours=$(( ${n} + ${ndayinhour} ))
             YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${offset_hours} hours ago" )
             print_info_msg "$VERBOSE" "Trying this cycle: ${YYYYMMDDHHmInterv}"
          done
        fi
      done
    fi
    surface_file_path=$bkpath

    # check if there are surface file in continue cycle data space:
    if [ "${restart_suffix_find}" = "missing" ] || [ "${restart_prefix_find}" = "missing" ]; then
      surface_file_path=${CONT_CYCLE_DATA_ROOT}/surface
      for ndayinhour in 00 24
      do 
        if [ "${restart_suffix_find}" = "missing" ]; then
          restart_prefix=$( date +%Y%m%d.%H0000. -d "${START_DATE} ${ndayinhour} hours ago" )

          offset_hours=$(( ${DA_CYCLE_INTERV} + ${ndayinhour} ))
          YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${offset_hours} hours ago" )

          n=${DA_CYCLE_INTERV}
          while [[ $n -le 2 ]] ; do
            if [ "${IO_LAYOUT_Y}" = "1" ]; then
              checkfile=${surface_file_path}/${restart_prefix}sfc_data.nc.${YYYYMMDDHHmInterv}
            else
              checkfile=${surface_file_path}/${restart_prefix}sfc_data.nc.${YYYYMMDDHHmInterv}.0000
            fi
            if [ -r "${checkfile}" ] && [ "${restart_suffix_find}" == "missing" ]; then
              restart_prefix_find=${restart_prefix}
              restart_suffix_find=${YYYYMMDDHHmInterv}
              print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as surface for analysis "
            fi
 
            n=$((n + ${DA_CYCLE_INTERV}))
            offset_hours=$(( ${n} + ${ndayinhour} ))
            YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${offset_hours} hours ago" )
            print_info_msg "$VERBOSE" "Trying this cycle: ${YYYYMMDDHHmInterv}"
          done
        fi
      done
    fi

    # rename the soil mositure and temperature fields in restart file
      rm -f cycle_surface.done
      if [ "${restart_suffix_find}" = "missing" ] || [ "${restart_prefix_find}" = "missing" ]; then
        print_info_msg "WARNING: cannot find surface from previous cycle"
      else
        if [ "${IO_LAYOUT_Y}" = "1" ]; then
          checkfile=${surface_file_path}/${restart_prefix_find}sfc_data.nc.${restart_suffix_find}
        else
          checkfile=${surface_file_path}/${restart_prefix_find}sfc_data.nc.${restart_suffix_find}.0000
        fi
        if [ -r "${checkfile}" ]; then
          if [ ${SFC_CYC} -eq 1 ]; then   # cycle surface at cold start cycle
            if [ "${IO_LAYOUT_Y}" = "1" ]; then 
              cpreq -p ${checkfile}  ${restart_prefix_find}sfc_data.nc
              mv sfc_data.tile7.halo0.nc cold.sfc_data.tile7.halo0.nc
              ncks -v geolon,geolat cold.sfc_data.tile7.halo0.nc geolonlat.nc
              ln -sf ${restart_prefix_find}sfc_data.nc sfc_data.tile7.halo0.nc
              ncks --append geolonlat.nc sfc_data.tile7.halo0.nc
              ncrename -v tslb,stc -v smois,smc -v sh2o,slc sfc_data.tile7.halo0.nc
            else
              print_info_msg "WARNING: cannot do surface cycle in cold start with sudomain restart files"
            fi
          else
	    export pgm="update_ice.exe"

            if [ "${IO_LAYOUT_Y}" = "1" ]; then 
              cpreq -p ${checkfile}  ${restart_prefix_find}sfc_data.nc
              mv sfc_data.nc gfsice.sfc_data.nc
              mv ${restart_prefix_find}sfc_data.nc sfc_data.nc
              ncatted -a checksum,,d,, sfc_data.nc
              if [ "${if_update_ice}" = "TRUE" ]; then
		. prep_step
                ${APRUN} ${EXECrrfs}/$pgm >>$pgmout 2>errfile
                export err=$?; err_chk
		mv errfile errfile_cycleICE
              fi
            else
              checkfile=${surface_file_path}/${restart_prefix_find}sfc_data.nc.${restart_suffix_find}
              for ii in ${list_iolayout}
              do
                iii=$(printf %4.4i $ii)
                cpreq -p ${checkfile}.${iii}  ${restart_prefix_find}sfc_data.nc.${iii}
                mv sfc_data.nc.${iii} gfsice.sfc_data.nc.${iii}
                mv ${restart_prefix_find}sfc_data.nc.${iii} sfc_data.nc.${iii}
                ncatted -a checksum,,d,, sfc_data.nc.${iii}
              done
              ls -l > list_cycle_sfc
              for ii in ${list_iolayout}
              do
                iii=$(printf %4.4i $ii)
                ln -sf sfc_data.nc.${iii} sfc_data.nc
                ln -sf gfsice.sfc_data.nc.${iii} gfsice.sfc_data.nc
                if [ "${if_update_ice}" = "TRUE" ]; then
		  . prep_step
                  ${APRUN} ${EXECrrfs}/$pgm >>$pgmout 2>errfile
                  export err=$?; err_chk
		  mv errfile errfile_cycleICE.${iii}
                fi
              done
              rm -f sfc_data.nc gfsice.sfc_data.nc
            fi
          fi
          echo "cycle surface with ${checkfile}" > cycle_surface.done
          echo "${YYYYMMDDHH}(${CYCLE_TYPE}): cycle surface with ${checkfile} "
        else
          print_info_msg "WARNING: cannot find surface from previous cycle"
        fi
      fi
fi

#-----------------------------------------------------------------------
#
# do update_GVF at ${GVF_update_hour}z for the restart sfc_data.nc
#
#-----------------------------------------------------------------------
Update_GVF=0
if [ "${CYCLE_TYPE}" = "spinup" ]; then
  if [ ${HH} -eq ${GVF_update_hour} ]; then
    Update_GVF=1
  fi
  if [ ${HH} -eq "03" ] ||  [ ${HH} -eq "15" ]; then
    Update_GVF=2
  fi
fi
if [ ${Update_GVF} -ge 1 ]; then
   latestGVF=$(ls ${GVF_ROOT}/GVF-WKL-GLB_v?r?_npp_s*_e${YYYYMMDDm1}_c${YYYYMMDD}*.grib2)
   latestGVF2=$(ls ${GVF_ROOT}/GVF-WKL-GLB_v?r?_npp_s*_e${YYYYMMDDm2}_c${YYYYMMDDm1}*.grib2)
   latestGVF3=$(ls ${GVF_ROOT}/GVF-WKL-GLB_v?r?_npp_s*_e${YYYYMMDDm3}_c${YYYYMMDDm2}*.grib2)
   if [ ! -r "${latestGVF}" ]; then
     if [ -r "${latestGVF2}" ]; then
       latestGVF=${latestGVF2}
     else
       if [ -r "${latestGVF3}" ]; then
         latestGVF=${latestGVF3}
       else
         print_info_msg "WARNING: cannot find GVF observation file"
       fi
     fi
   fi

   if [ -r "${latestGVF}" ]; then
      cpreq -p ${latestGVF} ./GVF-WKL-GLB.grib2
      ln -sf ${FIX_GSI}/gvf_VIIRS_4KM.MAX.1gd4r.new  gvf_VIIRS_4KM.MAX.1gd4r.new
      ln -sf ${FIX_GSI}/gvf_VIIRS_4KM.MIN.1gd4r.new  gvf_VIIRS_4KM.MIN.1gd4r.new

      if [ ${Update_GVF} -eq 2 ]; then
        ln -sf sfc_data.tile7.halo0.nc sfc_data.nc
      fi
      export pgm="update_GVF.exe"
      if [ "${IO_LAYOUT_Y}" = "1" ]; then
        ln -sf ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec  fv3_grid_spec
        . prep_step
        if [ ${Update_GVF} -eq 2 ]; then
          ${APRUN} ${EXECrrfs}/$pgm "cold" >>$pgmout 2>errfile
        else
          ${APRUN} ${EXECrrfs}/$pgm "warm" >>$pgmout 2>errfile
        fi
        export err=$?; err_chk
	mv errfile errfile_updateGVF
        if [ $err -ne 0 ]; then
          err_exit "Running \"update_GVF.exe\" failed."
        fi
      else
        for ii in ${list_iolayout}
        do
          iii=$(printf %4.4i $ii)
          ln -sf ${gridspec_dir}/fv3_grid_spec.${iii}  fv3_grid_spec
          ln -sf sfc_data.nc.${iii} sfc_data.nc
	  . prep_step
          if [ ${Update_GVF} -eq 2 ]; then
            ${APRUN} ${EXECrrfs}/$pgm "cold" >>$pgmout 2>errfile
          else
            ${APRUN} ${EXECrrfs}/$pgm "warm" >>$pgmout 2>errfile
          fi
          export err=$?; err_chk
	  mv errfile errfile_updateGVF.${iii}
          if [ $err -ne 0 ]; then
            err_exit "Running \"update_GVF.exe\" failed."
          fi

          ls -l > list_updateGVF.${iii}
        done
        rm -f sfc_data.nc
      fi
      echo "${YYYYMMDDHH}(${CYCLE_TYPE}): update GVF with ${latestGVF} "
   fi
fi

fi
#-----------------------------------------------------------------------
#
# go to INPUT directory.
# prepare boundary conditions:
#       the previous 12 cycles are searched to find the boundary files
#       that can cover the forecast length.
#       The 0-h boundary is copied and others are linked.
#
#-----------------------------------------------------------------------

if [[ "${NET}" = "RTMA"* ]]; then
    #find a bdry file, make sure it exists and was written out completely.
    for i in $(seq 0 24); do #track back up to 24 cycles to find bdry files
      lbcDIR="${LBCS_ROOT}/$(date -d "${START_DATE} ${i} hours ago" +"%Y%m%d%H")/lbcs"
      if [[  -f ${lbcDIR}/gfs_bndy.tile7.001.nc ]]; then
        age=$(( $(date +%s) - $(date -r ${lbcDIR}/gfs_bndy.tile7.001.nc +%s) ))
        [[ age -gt 300 ]] && break
      fi
    done
    ln -snf ${lbcDIR}/gfs_bndy.tile7.000.nc .
    ln -snf ${lbcDIR}/gfs_bndy.tile7.001.nc .

else
  num_fhrs=( "${#FCST_LEN_HRS_CYCLES[@]}" )
  ihh=$( expr ${HH} + 0 )
  if [ ${num_fhrs} -gt ${ihh} ]; then
     FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_CYCLES[${ihh}]}
  else
     FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS}
  fi
  if [ "${CYCLE_TYPE}" = "spinup" ]; then
     FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_SPINUP}
  fi 
  print_info_msg "$VERBOSE" " The forecast length for cycle (\"${HH}\") is
                 ( \"${FCST_LEN_HRS_thiscycle}\") "

#   let us figure out which boundary file is available
  bndy_prefix=gfs_bndy.tile7
  n=${EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS}
  end_search_hr=$(( 12 + ${EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS} ))
  YYYYMMDDHHmInterv=$(date +%Y%m%d%H -d "${START_DATE} ${n} hours ago")
  YYYYMMDDInterv=`echo ${YYYYMMDDHHmInterv} | cut -c1-8`
  HHInterv=`echo ${YYYYMMDDHHmInterv} | cut -c9-10`
  if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
    lbcs_path=${LBCS_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${mem_num}/lbcs
  else
    lbcs_path=${LBCS_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/lbcs
  fi
  while [[ $n -le ${end_search_hr} ]] ; do
    last_bdy_time=$(( n + ${FCST_LEN_HRS_thiscycle} ))
    last_bdy=$(printf %3.3i $last_bdy_time)
    checkfile=${lbcs_path}/${bndy_prefix}.${last_bdy}.nc
    if [ -r "${checkfile}" ]; then
      print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as boundary for forecast "
      break
    else
      n=$((n + 1))
      YYYYMMDDHHmInterv=$(date +%Y%m%d%H -d "${START_DATE} ${n} hours ago")
      YYYYMMDDInterv=`echo ${YYYYMMDDHHmInterv} | cut -c1-8`
      HHInterv=`echo ${YYYYMMDDHHmInterv} | cut -c9-10`
      if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
        lbcs_path=${LBCS_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/${mem_num}/lbcs
      else
        lbcs_path=${LBCS_ROOT}/${RUN}.${YYYYMMDDInterv}/${HHInterv}/lbcs
      fi
    fi
  done
#
  relative_or_null="--relative"
  nb=1
  if [ -r "${checkfile}" ]; then
    while [ $nb -le ${FCST_LEN_HRS_thiscycle} ]
    do
      bdy_time=$(( ${n} + ${nb} ))
      this_bdy=$(printf %3.3i $bdy_time)
      local_bdy=$(printf %3.3i $nb)

      if [ -f "${lbcs_path}/${bndy_prefix}.${this_bdy}.nc" ]; then
        ln -sf ${relative_or_null} ${lbcs_path}/${bndy_prefix}.${this_bdy}.nc ${bndy_prefix}.${local_bdy}.nc
      fi

      nb=$((nb + 1))
    done
# check 0-h boundary condition
    if [ ! -f "${bndy_prefix}.000.nc" ]; then
      this_bdy=$(printf %3.3i ${n})
      cpreq -p ${lbcs_path}/${bndy_prefix}.${this_bdy}.nc ${bndy_prefix}.000.nc 
    fi
  else
    err_exit "Cannot find boundary file: ${checkfile}"
  fi
fi 
#
#-----------------------------------------------------------------------
#
# conduct surface surgery to transfer RAP/HRRR surface fields into RRFS.
# 
# This surgery only needs to be done once to give RRFS a good start of the surface.
# Please consult Ming or Tanya first before turning on this surgery.
#
#-----------------------------------------------------------------------
# 
if [ ${SFC_CYC} -eq 3 ] ; then

   do_lake_surgery=".false."
   if [ "${USE_CLM}" = "TRUE" ]; then
     do_lake_surgery=".true."
   fi
   raphrrr_com=${COMROOT}
   COMIN_RAP=$(compath.py rap/${rap_ver})
   COMIN_HRRR=$(compath.py hrrr/${hrrr_ver})
   rapfile='missing'
   hrrrfile='missing'
   hrrr_akfile='missing'
   current_cdate=${YYYYMMDD}${HH}
   new_cdate=$($NDATE -1 ${current_cdate})
   new_pdy=$(echo ${new_cdate}| cut -c1-8)
   new_cyc=$(echo ${new_cdate}| cut -c9-10)
   if [ -r ${COMIN_RAP}/nwges/rapges/rap_${new_cdate}f001 ]; then
     ln -s ${COMIN_RAP}/nwges/rapges/rap_${new_cdate}f001 sfc_rap
     rapfile='sfc_rap'
   fi
   if [ -r ${COMIN_HRRR}/nwges/hrrrges_sfc/conus/hrrr_${new_cdate}f001 ]; then
     ln -s ${COMIN_HRRR}/nwges/hrrrges_sfc/conus/hrrr_${new_cdate}f001 sfc_hrrr
     hrrrfile='sfc_hrrr'
   fi
 
   export pgm="use_raphrrr_sfc.exe"
   if [ "${IO_LAYOUT_Y}" = "1" ]; then
     ln -sf ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec  fv3_grid_spec
   else
     for ii in ${list_iolayout}
     do
       iii=$(printf %4.4i $ii)
       ln -sf ${gridspec_dir}/fv3_grid_spec.${iii}  fv3_grid_spec
     done
   fi

     for file in ${rapfile} ${hrrrfile} ${hrrr_akfile}
     do
       if [ "${file}" = "missing" ]; then
         continue
       else
         if [ "${file}" = "${rapfile}" ]; then

cat << EOF > use_raphrrr_sfc.namelist
&setup
rapfile=${rapfile}
hrrrfile='missing'
hrrr_akfile='missing'
rrfsfile='sfc_data.nc'
do_lake_surgery=${do_lake_surgery}
update_snow=true
/
EOF
           cp use_raphrrr_sfc.namelist use_raphrrr_sfc.namelist_rap

         elif [ "${file}" = "${hrrrfile}" ]; then

cat << EOF > use_raphrrr_sfc.namelist
&setup
rapfile='missing'
hrrrfile=${hrrrfile}
hrrr_akfile='missing'
rrfsfile='sfc_data.nc'
do_lake_surgery=${do_lake_surgery}
update_snow=false
/
EOF
           cp use_raphrrr_sfc.namelist use_raphrrr_sfc.namelist_hrrr

         elif [ "${file}" = "${hrrr_akfile}" ]; then

cat << EOF > use_raphrrr_sfc.namelist
&setup
rapfile='missing'
hrrrfile='missing'
hrrr_akfile=${hrrr_akfile}
rrfsfile='sfc_data.nc'
do_lake_surgery=${do_lake_surgery}
update_snow=false
/
EOF

           cp use_raphrrr_sfc.namelist use_raphrrr_sfc.namelist_hrrrak
         fi
       fi
       if [ "${IO_LAYOUT_Y}" = "1" ]; then
         cp sfc_data.nc sfc_data.nc_read
	 . prep_step
         ${APRUN} ${EXECrrfs}/$pgm >>$pgmout 2>errfile
         export err=$?; err_chk
	 mv errfile errfile_sfc_surgery.${file}
       else
         for ii in ${list_iolayout}
         do
           iii=$(printf %4.4i $ii)
           ln -sf sfc_data.nc.${iii} sfc_data.nc
           cp sfc_data.nc sfc_data.nc_read
	   . prep_step
           ${APRUN} ${EXECrrfs}/$pgm >>$pgmout 2>errfile
           export err=$?; err_chk
	   mv errfile errfile_sfc_surgery.${iii}.${file}
           ls -l > list_sfc_sugery.${iii}
         done
         rm -f sfc_data.nc
       fi
     done
     echo "${YYYYMMDDHH}(${CYCLE_TYPE}): run surface surgery"
fi
# snow surgery
# ncks -A -v weasdl,weasdi,sheleg,snodl,snodi,snwdph,sncovr,sncovr_ice sfc_data.nc_RAP_SNOW_HRRR sfc_data.nc
#
#-----------------------------------------------------------------------
#
# Process FVCOM Data
#
#-----------------------------------------------------------------------
#
if [ "${USE_FVCOM}" = "TRUE" ] && [ ${SFC_CYC} -eq 2 ] ; then
  FVCOM_DIR=$(compath.py nosofs/${nosofs_ver})
  # Remap the FVCOM output from the 5 lakes onto the RRFS grid
  if [ "${PREP_FVCOM}" = "TRUE" ]; then
    ${USHrrfs}/fvcom_prep.sh \
                  INPUT_DATA="${DATA}" \
                  FIXLAM="${FIXLAM}" \
                  FVCOM_DIR="${FVCOM_DIR}" \
	          YYYYJJJHH="${YYYYJJJHH}" \
                  YYYYMMDD="${YYYYMMDD}" \
                  YYYYMMDDm1="${YYYYMMDDm1}" \
                  HH="${HH}"
    export err=$?
    [[ ${err} -gt 0 ]]&& echo "WARNING FVCOM data process failed"
    INPUT_DATA=${DATA}
    cd ${INPUT_DATA}
    # FVCOM_DIR needs to be redefined here to find 
    FVCOM_DIR=${INPUT_DATA}/fvcom_remap
    latest_fvcom_file="${FVCOM_DIR}/${FVCOM_FILE}"
    fvcomtime=${YYYYJJJHH}
    fvcom_data_fp="${latest_fvcom_file}_${fvcomtime}.nc"
  else
    latest_fvcom_file="${FVCOM_DIR}/${FVCOM_FILE}"
    if [ ${HH} -gt 12 ]; then 
      starttime_fvcom="$(date +%Y%m%d -d "${START_DATE}") 12"
    else
      starttime_fvcom="$(date +%Y%m%d -d "${START_DATE}") 00"
    fi
    for ii in $(seq 0 3)
    do
       jumphour=$((${ii} * 12))
       fvcomtime=$(date +%Y%j%H -d "${starttime_fvcom}  ${jumphour} hours ago")
       fvcom_data_fp="${latest_fvcom_file}_${fvcomtime}.nc"
       if [ -f "${fvcom_data_fp}" ]; then
         break 
       fi
    done
  fi

  if [ ! -f "${fvcom_data_fp}" ]; then
    print_info_msg "\
The file or path (fvcom_data_fp) does not exist:
  fvcom_data_fp = \"${fvcom_data_fp}\"
Please check the following user defined variables:
  FVCOM_DIR = \"${FVCOM_DIR}\"
  FVCOM_FILE= \"${FVCOM_FILE}\" "

  else
    cpreq -p ${fvcom_data_fp} fvcom.nc

    #Format for fvcom_time: YYYY-MM-DDTHH:00:00.000000
    fvcom_time="${YYYY}-${MM}-${DD}T${HH}:00:00.000000"

    pgm="fvcom_to_FV3"

    # decide surface
    if [ ${BKTYPE} -eq 1 ] ; then
      FVCOM_WCSTART='cold'
      surface_file='sfc_data.tile7.halo0.nc'
    else
      FVCOM_WCSTART='warm'
      surface_file='sfc_data.nc'
    fi
    . prep_step
    ${APRUN} ${EXECrrfs}/$pgm ${surface_file} fvcom.nc ${FVCOM_WCSTART} ${fvcom_time} ${IO_LAYOUT_Y} >>$pgmout 2>errfile
    export err=$?; err_chk
    mv errfile errfile_fvcom
  fi
fi
#
#-----------------------------------------------------------------------
#
# This job share data with job outside of current cycle
#   Copy output to COMOUT
#
#-----------------------------------------------------------------------
#
ln -s ${DATA}/*.nc ${FORECAST_INPUT_PRODUCT}
if [ -s ${DATA}/coupler.res ]; then
  ln -s ${DATA}/coupler.res ${FORECAST_INPUT_PRODUCT}
fi
if [ -s ${DATA}/fv3_grid_spec ]; then
  ln -s ${DATA}/fv3_grid_spec ${FORECAST_INPUT_PRODUCT}
fi
if [ -s ${DATA}/bk_coupler.res ]; then
  ln -s ${DATA}/bk_coupler.res ${FORECAST_INPUT_PRODUCT}
fi
if [ $(eval ls ${DATA}/gvf*|wc -l) -gt 0 ]; then
  ln -s ${DATA}/gvf* ${FORECAST_INPUT_PRODUCT}
fi
if [ $(eval ls ${DATA}/*.grib2|wc -l) -gt 0 ]; then
  ln -s ${DATA}/*.grib2 ${FORECAST_INPUT_PRODUCT}
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
Prepare start completed successfully!!!

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

