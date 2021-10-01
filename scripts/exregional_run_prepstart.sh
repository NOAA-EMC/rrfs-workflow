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
valid_args=( "cycle_dir" "cycle_type" "modelinputdir" "lbcs_root" "fg_root")
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
# Compute date & time components for the SST analysis time relative to current analysis time
YYJJJ00000000=`date +"%y%j00000000" -d "${START_DATE} 1 day ago"`
YYJJJ1200=`date +"%y%j1200" -d "${START_DATE} 1 day ago"`
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

BKTYPE=0
if [ ${cycle_type} == "spinup" ]; then
   echo "spin up cycle"
  for cyc_start in "${CYCL_HRS_SPINSTART[@]}"; do
    if [ ${HH} -eq ${cyc_start} ]; then
      BKTYPE=1
    fi
  done
else
  echo " product cycle"
  for cyc_start in "${CYCL_HRS_PRODSTART[@]}"; do
    if [ ${HH} -eq ${cyc_start} ]; then
      if [ ${DO_SPINUP} == "TRUE" ]; then
        BKTYPE=2   # using 1-h forecast from spinup cycle
      else
        BKTYPE=1
      fi
    fi
  done
fi

cd_vrfy ${modelinputdir}

if [ ${BKTYPE} -eq 1 ] ; then  # cold start, use prepare cold strat initial files from ics
    bkpath=${lbcs_root}/$YYYYMMDD$HH/ics
    if [ -r "${bkpath}/gfs_data.tile7.halo0.nc" ]; then
      cp_vrfy ${bkpath}/gfs_bndy.tile7.000.nc gfs_bndy.tile7.000.nc        
      cp_vrfy ${bkpath}/gfs_ctrl.nc gfs_ctrl.nc        
      cp_vrfy ${bkpath}/gfs_data.tile7.halo0.nc gfs_data.tile7.halo0.nc        
      cp_vrfy ${bkpath}/sfc_data.tile7.halo0.nc sfc_data.tile7.halo0.nc        
      print_info_msg "$VERBOSE" "cold start from $bkpath"
    else
      print_err_msg_exit "Error: cannot find cold start initial condition from : ${bkpath}"
    fi

    if [ ${DO_SURFACE_CYCLE} == "TRUE" ]; then  # cycle surface fields

# figure out which surface is available
      surface_file_dir_name=fcst_fv3lam
      bkpath_find="missing"
      restart_prefix_find="missing"
      for ndayinhour in 00 24 48
      do 
        if [ "${bkpath_find}" == "missing" ]; then
          restart_prefix=$( date +%Y%m%d.%H0000. -d "${START_DATE} ${ndayinhour} hours ago" )

          offset_hours=$(( ${DA_CYCLE_INTERV} + ${ndayinhour} ))
          YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${offset_hours} hours ago" )
          bkpath=${fg_root}/${YYYYMMDDHHmInterv}/${surface_file_dir_name}/RESTART  

          n=${DA_CYCLE_INTERV}
          while [[ $n -le 6 ]] ; do
             checkfile=${bkpath}/${restart_prefix}sfc_data.nc
             if [ -r "${checkfile}" ] && [ "${bkpath_find}" == "missing" ]; then
               bkpath_find=${bkpath}
               restart_prefix_find=${restart_prefix}
               print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as surface for analysis "
             fi
 
             n=$((n + ${DA_CYCLE_INTERV}))
             offset_hours=$(( ${n} + ${ndayinhour} ))
             YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${offset_hours} hours ago" )
             bkpath=${fg_root}/${YYYYMMDDHHmInterv}/${surface_file_dir_name}/RESTART  # cycling, use background from RESTART
             print_info_msg "$VERBOSE" "Trying this path: ${bkpath}"
          done
        fi

      done

# rename the soil mositure and temperature fields in restart file
      rm -f cycle_surface.done
      if [ "${bkpath_find}" == "missing" ]; then
        print_info_msg "Warning: cannot find surface from previous cycle"
      else
        checkfile=${bkpath_find}/${restart_prefix_find}sfc_data.nc
        if [ -r "${checkfile}" ]; then
          cp_vrfy ${checkfile}  ${restart_prefix_find}sfc_data.nc
          mv sfc_data.tile7.halo0.nc cold.sfc_data.tile7.halo0.nc
          ncks -v geolon,geolat cold.sfc_data.tile7.halo0.nc geolonlat.nc
          ln_vrfy -sf ${restart_prefix_find}sfc_data.nc sfc_data.tile7.halo0.nc
          ncks --append geolonlat.nc sfc_data.tile7.halo0.nc
          ncrename -v tslb,stc -v smois,smc -v sh2o,slc sfc_data.tile7.halo0.nc
          echo "cycle surface with ${checkfile}" > cycle_surface.done
        else
          print_info_msg "Warning: cannot find surface from previous cycle"
        fi
      fi
    fi
else

# Setup the INPUT directory for warm start cycles, which can be spin-up cycle or product cycle.
#
# First decide the source of the first guess (fg_restart_dirname) depending on cycle_type and BKTYPE:
#  1. If cycle is spinup cycle (cycle_type == spinup) or it is the product start cycle (BKTYPE==2),
#             looking for the first guess from spinup forecast (fcst_fv3lam_spinup)
#  2. Others, looking for the first guess from product forecast (fcst_fv3lam)
#
  if [ ${cycle_type} == "spinup" ] || [ ${BKTYPE} -eq 2 ]; then
     fg_restart_dirname=fcst_fv3lam_spinup
  else
     fg_restart_dirname=fcst_fv3lam
  fi

  YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${DA_CYCLE_INTERV} hours ago" )
  bkpath=${fg_root}/${YYYYMMDDHHmInterv}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART

#   let us figure out which backgound is available
#
#   the restart file from FV3 has a name like: ${YYYYMMDD}.${HH}0000.fv_core.res.tile1.nc
#   But the restart files for the forecast length has a name like: fv_core.res.tile1.nc
#   So the defination of restart_prefix needs a "." at the end.
#
  restart_prefix="${YYYYMMDD}.${HH}0000."
  n=${DA_CYCLE_INTERV}
  while [[ $n -le 6 ]] ; do
    checkfile=${bkpath}/${restart_prefix}fv_core.res.tile1.nc
    checkfile1=${bkpath}/${restart_prefix}fv_tracer.res.tile1.nc
    if [ -r "${checkfile}" ] && [ -r "${checkfile1}" ]; then
      print_info_msg "$VERBOSE" "Found ${checkfile}; Use it as background for analysis "
      break
    else
      n=$((n + ${DA_CYCLE_INTERV}))
      YYYYMMDDHHmInterv=$( date +%Y%m%d%H -d "${START_DATE} ${n} hours ago" )
      bkpath=${fg_root}/${YYYYMMDDHHmInterv}/${fg_restart_dirname}/RESTART  # cycling, use background from RESTART
      print_info_msg "$VERBOSE" "Trying this path: ${bkpath}"
    fi
  done
#
  checkfile=${bkpath}/${restart_prefix}fv_core.res.tile1.nc
  checkfile1=${bkpath}/${restart_prefix}fv_tracer.res.tile1.nc
  if [ -r "${checkfile}" ] && [ -r "${checkfile1}" ] ; then
    cp_vrfy ${bkpath}/${restart_prefix}fv_core.res.tile1.nc       fv_core.res.tile1.nc 
    cp_vrfy ${bkpath}/${restart_prefix}fv_tracer.res.tile1.nc     fv_tracer.res.tile1.nc
    cp_vrfy ${bkpath}/${restart_prefix}sfc_data.nc                sfc_data.nc 
    cp_vrfy ${bkpath}/${restart_prefix}coupler.res                coupler.res
    cp_vrfy ${bkpath}/${restart_prefix}fv_core.res.nc             fv_core.res.nc
    cp_vrfy ${bkpath}/${restart_prefix}fv_srf_wnd.res.tile1.nc    fv_srf_wnd.res.tile1.nc
    cp_vrfy ${bkpath}/${restart_prefix}phy_data.nc                phy_data.nc
    cp_vrfy ${fg_root}/${YYYYMMDDHHmInterv}/${fg_restart_dirname}/INPUT/gfs_ctrl.nc  gfs_ctrl.nc

# do SST update at ${SST_update_hour}z for the restart sfc_data.nc
    if [ ${HH} -eq ${SST_update_hour} ]; then
       echo "Update SST at ${SST_update_hour}z"
       if [ -r "${SST_ROOT}/latest.SST" ]; then
          cp ${SST_ROOT}/latest.SST .
       elif [ -r "${SST_ROOT}/${YYJJJ00000000}" ]; then
          cp ${SST_ROOT}/${YYJJJ00000000} latest.SST
       else
         ${ECHO} "${SST_ROOT} data does not exist!!"
         ${ECHO} "ERROR: No SST update at ${time_str}!!!!"
       fi
       if [ -r "latest.SST" ]; then
         cp_vrfy ${FIXgsm}/RTG_SST_landmask.dat                ./RTG_SST_landmask.dat
         ln_vrfy ./latest.SST                                  ./SSTRTG
         cp_vrfy ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec  ./fv3_grid_spec
         cp_vrfy ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_akbk       ./fv3_akbk

cat << EOF > sst.namelist
&setup
  bkversion=1,
  iyear=${YYYY}
  imonth=${MM}
  iday=${DD}
  ihr=${HH}
/
EOF
         ${EXECDIR}/process_updatesst > stdout_sstupdate 2>&1
       else
         echo "ERROR: No latest SST file for update at ${YYYYMMDDHH}!!!!"
       fi
    else
       echo "NOTE: No update for SST at ${YYYYMMDDHH}!"
    fi
    
  else
    print_err_msg_exit "Error: cannot find background: ${checkfile}"
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
    #find a bdry file last modified before current cycle time and size > 100M 
    #to make sure it exists and was written out completely. 
    TIME1HAGO=$(date -d "${START_DATE} 58 minute" +"%Y-%m-%d %H:%M:%S")
    bdryfile1=${lbcs_root}/$(cd $lbcs_root;find . -name "gfs_bndy.tile7.001.nc" ! -newermt "$TIME1HAGO" -size +100M | xargs ls -1rt |tail -n 1)
    bdryfile0=$(echo $bdryfile1 | sed -e "s/gfs_bndy.tile7.001.nc/gfs_bndy.tile7.000.nc/")
    ln_vrfy -snf ${bdryfile0} .
    ln_vrfy -snf ${bdryfile1} .

else
  num_fhrs=( "${#FCST_LEN_HRS_CYCLES[@]}" )
  ihh=$( expr ${HH} + 0 )
  if [ ${num_fhrs} -gt ${ihh} ]; then
     FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_CYCLES[${ihh}]}
  else
     FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS}
  fi
  if [ ${cycle_type} == "spinup" ]; then
     FCST_LEN_HRS_thiscycle=${FCST_LEN_HRS_SPINUP}
  fi 
  print_info_msg "$VERBOSE" " The forecast length for cycle (\"${HH}\") is
                 ( \"${FCST_LEN_HRS_thiscycle}\") "

#   let us figure out which boundary file is available
  bndy_prefix=gfs_bndy.tile7
  n=${EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS}
  end_search_hr=$(( 12 + ${EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS} ))
  YYYYMMDDHHmInterv=$(date +%Y%m%d%H -d "${START_DATE} ${n} hours ago")
  lbcs_path=${lbcs_root}/${YYYYMMDDHHmInterv}/lbcs
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
      lbcs_path=${lbcs_root}/${YYYYMMDDHHmInterv}/lbcs
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
        ln_vrfy -sf ${relative_or_null} ${lbcs_path}/${bndy_prefix}.${this_bdy}.nc ${bndy_prefix}.${local_bdy}.nc
      fi

      nb=$((nb + 1))
    done
# check 0-h boundary condition
    if [ ! -f "${bndy_prefix}.000.nc" ]; then
      this_bdy=$(printf %3.3i ${n})
      cp_vrfy ${lbcs_path}/${bndy_prefix}.${this_bdy}.nc ${bndy_prefix}.000.nc 
    fi
  else
    print_err_msg_exit "Error: cannot find boundary file: ${checkfile}"
  fi

fi 

#
#-----------------------------------------------------------------------
#
# condut surface surgery to transfer RAP/HRRR surface fields into RRFS.
# 
# This surgery only needs to be done once to give RRFS a good start of the surfcase.
# Please consult Ming or Tanya first before turning on this surgery.
#
#-----------------------------------------------------------------------
#
if [ ${YYYYMMDDHH} -eq 9999999999 ]; then
   raphrrr_com=/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/com/
#   cp_vrfy ${FIX_GSI}/use_raphrrr_sfc.namelist                                  use_raphrrr_sfc.namelist
   ln_vrfy -sf ${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec                     fv3_grid_spec
   ln -s ${raphrrr_com}/rap/prod/rap.${YYYYMMDD}/rap.t${HH}z.wrf_inout_smoke    sfc_rap
   ln -s ${raphrrr_com}/hrrr/prod/hrrr.${YYYYMMDD}/conus/hrrr.t${HH}z.wrf_inout sfc_hrrr
   ln -s ${raphrrr_com}/hrrr/prod/hrrr.${YYYYMMDD}/alaska/hrrrak.t${HH}z.wrf_inout sfc_hrrrak
 
cat << EOF > use_raphrrr_sfc.namelist
&setup
rapfile='sfc_rap'
hrrrfile='sfc_hrrr'
hrrr_akfile='sfc_hrrrak'
rrfsfile='sfc_data.nc'
/
EOF

   exect="use_raphrrr_sfc.exe"
   if [ -f ${EXECDIR}/$exect ]; then
      print_info_msg "$VERBOSE" "
      Copying the surface surgery executable to the run directory..."
      cp_vrfy ${EXECDIR}/${exect} ${exect}

      ./${exect} > stdout 2>&1 || print_info_msg "\
      Call to executable to run surface surgery returned with nonzero exit code."
   else
      print_info_msg "\
      The executable specified in exect does not exist:
      exect = \"${EXECDIR}/$exect\"
      Build executable and rerun."
   fi
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
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

