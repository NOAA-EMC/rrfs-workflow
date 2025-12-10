#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154,SC2086,SC2068
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1

#
#-----------------------------------------------------------------------
#
# Copy input files required for all 3 programs
#
#-----------------------------------------------------------------------
#

meshgriddir="${FIXrrfs}/${MESH_NAME}"
echo "INFO: meshgriddir is $meshgriddir"

${cpreq} "${meshgriddir}"/"${MESH_NAME}".grid.nc mesh.nc

#
#-----------------------------------------------------------------------
#
# NASA LaRC observation processing
#
# See sorc/RRFS_UTILS for details
#
#-----------------------------------------------------------------------
#

${cpreq} "${OBSPATH}/${CDATE}.rap.t${cyc}z.lgycld.tm00.bufr_d" lgycld.bufr_d

cat << EOF > namelist.nasalarc
 &setup
  analysis_time = ${CDATE},
  bufrfile='NASALaRCCloudInGSI_bufr.bufr',
  npts_rad=${NONVAR_LARC_NPTS},
  ioption=2,
  userDX=${NONVAR_USER_DX},
  proj_name="${NONVAR_PROJ_NAME}",
  debug=0,
 /
EOF

module list
export pgm="process_larccld.exe"
${cpreq} "${EXECrrfs}/${pgm}" .
source prep_step
${MPI_RUN_CMD} ./${pgm}
export err=$?
err_chk

${cpreq} NASALaRC_cloud4mpas.bin "${COMOUT}/nonvar_bufrobs/${WGF}/NASALaRC_cloud4mpas.bin"

#
#-----------------------------------------------------------------------
#
# Lightning observation processing
#
# See sorc/RRFS_UTILS for details
#
#-----------------------------------------------------------------------
#

${cpreq} "${OBSPATH}/${CDATE}.rap.t${cyc}z.lghtng.tm00.bufr_d" lghtngbufr

cat << EOF > namelist.lightning
 &setup
  analysis_time = ${CDATE},
  minute=00,
  trange_start=-10,
  trange_end=10,
  obs_type = "bufr",
  proj_name = '${NONVAR_PROJ_NAME}',
  search_rad = ${NONVAR_SEARCH_RAD},
  debug=0
 /
EOF

module list
export pgm="process_Lightning.exe"
${cpreq} "${EXECrrfs}/${pgm}" .
source prep_step
${MPI_RUN_CMD} ./${pgm}
export err=$?
err_chk

${cpreq} LightningInMPAS.dat "${COMOUT}/nonvar_bufrobs/${WGF}/LightningInMPAS.dat"

#
#-----------------------------------------------------------------------
#
# METAR cloud observation processing
#
# See sorc/RRFS_UTILS for details
#
#-----------------------------------------------------------------------
#

${cpreq} "${OBSPATH}/${CDATE}.rap.t${cyc}z.prepbufr.tm00" prepbufr

cat << EOF > namelist.metarcld
 &setup
  analysis_time = ${CDATE},
  prepbufrfile='prepbufr',
  twindin=0.5,
  metar_impact_radius=${NONVAR_METAR_IMPACT},
  proj_name="${NONVAR_PROJ_NAME}",
  debug=0,
 /
EOF

module list
export pgm="process_metarcld.exe"
${cpreq} "${EXECrrfs}/${pgm}" .
source prep_step
${MPI_RUN_CMD} ./${pgm}
export err=$?
err_chk

${cpreq} mpas_metarcloud.bin "${COMOUT}/nonvar_bufrobs/${WGF}/mpas_metarcloud.bin"

exit 0
