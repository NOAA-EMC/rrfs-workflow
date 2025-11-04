#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154,SC2086,SC2068
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1
#
#-----------------------------------------------------------------------
#
# Copy required input files
#
#-----------------------------------------------------------------------
#

meshgriddir="${FIXrrfs}"/meshes
echo "INFO: meshgriddir is $meshgriddir"

${cpreq} "${meshgriddir}"/"${MESH_NAME}".grid.nc mesh.nc
${cpreq} "${OBSPATH}/${CDATE}.rap.t${cyc}z.prepbufr.tm00" prepbufr
${cpreq} "${FIXrrfs}"/cloudanalysis/prepobs_prep_RAP.bufrtable prepobs_prep.bufrtable

#
#-----------------------------------------------------------------------
#
# Generate namelist on the fly
#
#-----------------------------------------------------------------------
#

if [[ "${MESH_NAME}" == "conus3km" ]] || [[ "${MESH_NAME}" == "south3.5km" ]]; then
  impact_radius=20
  proj_name="CONUS"
elif [[ "${MESH_NAME}" == "conus12km" ]]; then
  impact_radius=40
  proj_name="CONUS"
else
  echo "FATAL ERROR: Nonvariational cloud analysis is incompatible with mesh: ${MESH_NAME}"
  err_exit
fi

cat << EOF > namelist.metarcld
 &setup
  analysis_time = ${CDATE},
  prepbufrfile='prepbufr'
  twindin=0.5,
  metar_impact_radius=${impact_radius},
  proj_name="${proj_name}",
  debug=0,
 /
EOF

#
#-----------------------------------------------------------------------
#
# Run the program
#
#-----------------------------------------------------------------------
#

module list
export pgm="process_metarcld.exe"
${cpreq} "${EXECrrfs}/${pgm}" .
source prep_step
${MPI_RUN_CMD} ./${pgm}
# check the status
export err=$?
err_chk

cp mpas_metarcloud.bin  "${COMOUT}/process_metarcld/${WGF}/mpas_metarcloud.bin"

exit 0
