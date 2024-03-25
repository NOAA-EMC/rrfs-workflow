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

This is the ex-script for the task that generates initial condition
(IC), surface, and zeroth hour lateral boundary condition (LBC0) files
(in NetCDF format) for the FV3-LAM.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Source the file containing definitions of variables associated with the
# external model for ICs.
#
#-----------------------------------------------------------------------
#
extrn_mdl_staging_dir="${CYCLE_DIR}${SLASH_ENSMEM_SUBDIR}/ics/tmp_ICS"
extrn_mdl_var_defns_fp="${extrn_mdl_staging_dir}/${EXTRN_MDL_ICS_VAR_DEFNS_FN}"
. ${extrn_mdl_var_defns_fp}
#
#-----------------------------------------------------------------------
#
# Get the starting month, day, and hour of the the external model forecast.
#
#-----------------------------------------------------------------------
#
yyyymmdd="${EXTRN_MDL_CDATE:0:8}"
mm="${EXTRN_MDL_CDATE:4:2}"
dd="${EXTRN_MDL_CDATE:6:2}"
hh="${EXTRN_MDL_CDATE:8:2}"

fhr="${EXTRN_MDL_ICS_OFFSET_HRS}"
cdate_crnt_fhr=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${fhr} hours" "+%Y%m%d%H" )
#
# Get the month, day, and hour corresponding to the current forecast time
# of the the external model.
#
mm="${cdate_crnt_fhr:4:2}"
dd="${cdate_crnt_fhr:6:2}"
hh="${cdate_crnt_fhr:8:2}"
#
#-----------------------------------------------------------------------
#
# Run large-scale blending
#
#-----------------------------------------------------------------------
# NOTES:
# * The large-scale blending is broken down into 4 major parts
#   1) chgres_winds: This part rotates the coldstart winds from chgres to the model D-grid.
#                    It is based on atmos_cubed_sphere/tools/external_ic.F90#L433, and it
#                    is equivalent to the fv3jedi tool called ColdStartWinds.
#   2) remap_dwinds: This part vertically remaps the D-grid winds.
#                    It is based on atmos_cubed_sphere/tools/external_ic.F90#L3485, and it
#                    is part of the fv3jedi tool called VertRemap.
#   3) remap_scalar: This part vertically remaps all other variables.
#                    It is based on atmos_cubed_sphere/tools/external_ic.F90#L2942, and it
#                    is the other part of the fv3jedi tool called VertRemap.
#   4) raymond:      This is the actual blending code which uses the raymond filter. The
#                    raymond filter is a sixth-order tangent low-pass implicit filter
#                    and can be controlled via the cutoff length scale (Lx).
#
# * Currently blended fields: u, v, t, dpres, and sphum
#     -) Blending only works with GDASENKF (netcdf)
#
# * Two RRFS EnKF member files are needed: fv_core and fv_tracer.
#     -) fv_core contains u, v, t, and dpres
#     -) fv_tracer contains sphum
#
# * Before we can do any blending, the coldstart files from chgres need to be
#   processed. This includes rotating the winds and vertically remapping all the
#   variables. The cold start file has u_w, v_w, u_s, and v_s which correspond
#   to the D-grid staggering.
#     -) u_s is the D-grid south face tangential wind component (m/s)
#     -) v_s is the D-grid south face normal wind component (m/s)
#     -) u_w is the D-grid west  face normal wind component (m/s)
#     -) v_w is the D-grid west  face tangential wind component (m/s)
#     -) https://github.com/NOAA-GFDL/GFDL_atmos_cubed_sphere/blob/bdeee64e860c5091da2d169b1f4307ad466eca2c/tools/external_ic.F90
#     -) https://dtcenter.org/sites/default/files/events/2020/20201105-1300p-fv3-gfdl-1.pdf
#
pgm="blending"
. prep_step

yyyymmdd="${cdate_crnt_fhr:0:8}"
hh="${cdate_crnt_fhr:8:2}"
cdate_crnt_fhr_m1=$( date --utc --date "${yyyymmdd} ${hh} UTC - 1 hours" "+%Y%m%d%H" )

# Check for 1h RRFS EnKF files, if at least one missing then use 1tstep initialization
if [[ $DO_ENS_BLENDING == "TRUE" ]]; then

  # Files to denote whether running blending or ensinit
  run_blending=${NWGES_BASEDIR}/${cdate_crnt_fhr}/run_blending
  run_ensinit=${NWGES_BASEDIR}/${cdate_crnt_fhr}/run_ensinit

  # Initialize a counter for the number of existing files
  existing_files=0

  # Loop through each ensemble member and check if the 1h RRFS EnKF files exist
  for imem in $(seq 1 ${NUM_ENS_MEMBERS}); do
      ensmem=$( printf "%04d" $imem )
      checkfile="${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}/mem${ensmem}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.coupler.res"
      if [[ -f $checkfile ]]; then
          ((existing_files++))
          echo "checkfile count: $existing_files"
      else
          echo "File missing: $checkfile"
      fi
  done

  # Check if the number of existing files is equal to the total number of ensemble members
  if [[ $existing_files -eq ${NUM_ENS_MEMBERS} ]]; then
      # Check if run_blending file exists, and if not, touch it
      if [[ ! -f $run_blending ]]; then
          touch $run_blending
      fi
      blendmsg="Do blending!"
      if [[ -f $run_ensinit ]]; then
         rm -f $run_ensinit
      fi
  else
      # Check if run_ensinit file exists, and if not, touch it
      if [[ ! -f $run_ensinit ]]; then
          touch $run_ensinit
      fi
      blendmsg="Do ensinit!"
  fi
  echo "`date`"
  echo "Blending check: There are ${existing_files}/${NUM_ENS_MEMBERS} ensemble members. $blendmsg"

  if [ -f $run_blending ] &&
     [ ! -f $run_ensinit ] &&
     [ $EXTRN_MDL_NAME_ICS = "GDASENKF" ]; then

     echo "Blending Starting."

     # F2Py shared object files to PYTHONPATH
     export PYTHONPATH=$PYTHONPATH:$LIB64dir

     # Required NETCDF files - RRFS
     cp ${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.fv_core.res.tile1.nc ./fv_core.res.tile1.nc
     cp ${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.fv_tracer.res.tile1.nc ./fv_tracer.res.tile1.nc
     #cp ${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.fv_core.res.nc ./fv_core.res.nc

     # Shortcut the file names/arguments.
     Lx=$ENS_BLENDING_LENGTHSCALE
     glb=./out.atm.tile${TILE_RGNL}.nc
     reg=./fv_core.res.tile1.nc
     trcr=./fv_tracer.res.tile1.nc

     # Blend OR finish convert cold2warm start without blending.
     blend=${BLEND}                 # TRUE:  Blend RRFS and GDAS EnKF
                                    # FALSE: Don't blend, activate cold2warm start only, and use either GDAS or RRFS
     use_host_enkf=${USE_HOST_ENKF} # ignored if blend="TRUE".
                                    # TRUE:  Final EnKF will be GDAS (no blending)
                                    # FALSE: Final EnKF will be RRFS (no blending)
     python ${USHdir}/blending_fv3.py $Lx $glb $reg $trcr $blend $use_host_enkf
     cp ./fv_core.res.tile1.nc ${ics_dir}/.
     cp ./fv_tracer.res.tile1.nc ${ics_dir}/.

     # Move the remaining RESTART files to INPUT
     cp ${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.coupler.res             ${ics_dir}/coupler.res
     cp ${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.fv_core.res.nc          ${ics_dir}/fv_core.res.nc
     cp ${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.fv_srf_wnd.res.tile1.nc ${ics_dir}/fv_srf_wnd.res.tile1.nc
     cp ${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.phy_data.nc             ${ics_dir}/phy_data.nc
     cp ${NWGES_BASEDIR}/${cdate_crnt_fhr_m1}${SLASH_ENSMEM_SUBDIR}/fcst_fv3lam/RESTART/${yyyymmdd}.${hh}0000.sfc_data.nc             ${ics_dir}/sfc_data.nc
     cp gfs_ctrl.nc ${ics_dir}
     cp gfs.bndy.nc ${ics_dir}/gfs_bndy.tile${TILE_RGNL}.000.nc
  fi
fi
#
#-----------------------------------------------------------------------
#
# Move initial condition, surface, control, and 0-th hour lateral bound-
# ary files to ICs_BCs directory. Only do this if blending is off or on-
# ly for the first DA cycle if blending is on inorder to coldstart the
# system.
#-----------------------------------------------------------------------
#
if [[ $DO_ENS_BLENDING = "FALSE" || ($DO_ENS_BLENDING = "TRUE" && -f $run_ensinit ) ]]; then
  mv out.atm.tile${TILE_RGNL}.nc \
        ${ics_dir}/gfs_data.tile${TILE_RGNL}.halo${NH0}.nc

  mv out.sfc.tile${TILE_RGNL}.nc \
        ${ics_dir}/sfc_data.tile${TILE_RGNL}.halo${NH0}.nc

  mv gfs_ctrl.nc ${ics_dir}

  mv gfs.bndy.nc ${ics_dir}/gfs_bndy.tile${TILE_RGNL}.000.nc
fi
#
#-----------------------------------------------------------------------
#
# copy results to nwges for longe time disk storage.
#
#-----------------------------------------------------------------------
#
cp ${ics_dir}/*.nc ${ics_nwges_dir}/.
if [ $DO_ENS_BLENDING = "TRUE" ] && [ -f $run_blending ] && [ ! -f $run_ensinit ]; then
  cp ${ics_dir}/coupler.res ${ics_nwges_dir}/.
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
Initial condition, surface, and zeroth hour lateral boundary condition
files (in NetCDF format) for FV3 generated successfully!!!

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
