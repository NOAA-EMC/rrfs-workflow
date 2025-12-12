#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154,SC2086,SC2068
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
cpreq=${cpreq:-cpreq}
cd "${DATA}" || exit 1

#
#-----------------------------------------------------------------------
#
# Extract from CDATE the starting year, month, day, and hour of the
# forecast.  These are needed below for various operations.
#
#-----------------------------------------------------------------------
#

YYYY=${CDATE:0:4}
MM=${CDATE:4:2}
DD=${CDATE:6:2}
HH=${CDATE:8:2}

#
#-----------------------------------------------------------------------
#
# Copy/link input and output files
#
#-----------------------------------------------------------------------
#

# Model background
if [[ -r "${UMBRELLA_PREP_IC_DATA}/init.nc" ]]; then
  echo "INFO: Skipping nonvar cloud analysis because this is a cold start"
  echo "INFO: The 'cldfrac' field, which is required, is not available for cold starts"
  exit 0
else
  initial_file=mpasout.nc
fi
ln -snf "${UMBRELLA_PREP_IC_DATA}/${initial_file}" .

# MPAS invariant file
zeta_levels=${EXPDIR}/config/ZETA_LEVELS.txt
nlevel=$(wc -l < "${zeta_levels}")
ln -snf "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.invariant.nc_L${nlevel}_${prefix}" ./invariant.nc

# Processed observations
${cpreq} "${COMOUT}/nonvar_bufrobs/${WGF}/NASALaRC_cloud4mpas.bin" .
${cpreq} "${COMOUT}/nonvar_bufrobs/${WGF}/LightningInMPAS.dat" .
${cpreq} "${COMOUT}/nonvar_bufrobs/${WGF}/mpas_metarcloud.bin" .
${cpreq} "${COMOUT}/nonvar_reflobs/${WGF}/RefInGSI3D.dat" .

#
#-----------------------------------------------------------------------
#
# Create namelist on the fly and run program
#
# See sorc/RRFS_UTILS for details
#
#-----------------------------------------------------------------------
#

cat << EOF > gsiparm.anl

 &SETUP
  iyear=${YYYY},
  imonth=${MM},
  iday=${DD},
  ihour=${HH},
  iminute=00,
  dump_cld_cover_3d=0
 /
 &RAPIDREFRESH_CLDSURF
   l_conserve_thetaV=.true.,
   r_cleanSnow_WarmTs_threshold=5.0,
   i_conserve_thetaV_iternum=3,
   l_cld_bld=.true.,
   cld_bld_hgt=1200.0,
   build_cloud_frac_p=0.50,
   clear_cloud_frac_p=0.10,
   iclean_hydro_withRef_allcol=1,
   i_lightpcp=1,
   l_numconc=.true.,
   l_precip_clear_only=.false.,
   i_T_Q_adjust=1,
   i_precip_vertical_check=0,
   l_rtma3d=.false.,
   l_qnr_from_qr=.false.,
   n0_rain=100000000.0,
 /
EOF

module list
export pgm="mpas_nonvarcldana.exe"
${cpreq} "${EXECrrfs}/${pgm}" .
source prep_step
${MPI_RUN_CMD} ./${pgm}
export err=$?
err_chk

# No need to copy output b/c ${initial_file} was linked from UMBRELLA_PREP_IC_DATA

# Copy log files to COM directory
if [[ "${DO_SPINUP:-FALSE}" == "TRUE" ]];  then
  ${cpreq} stdout_cloudanalysis* "${COMOUT}/nonvar_cldana_spinup/${WGF}${MEMDIR}/"
else
  ${cpreq} stdout_cloudanalysis* "${COMOUT}/nonvar_cldana/${WGF}${MEMDIR}/"
fi

exit 0
