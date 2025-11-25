#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2153,SC2012
#
# --- Set the file expression and lat/lon dimension names
#
#ANTHROEMIS_STATICDIR=${CHEM_INPUT}/emissions/anthro/raw/${ANTHRO_EMISINV}/  # this is not used
#
# TODO, if residential wood burning emissions are turned on, we need to use the
# GRA2PES_VERSION=total_minus_res to not double count those emissions
GRA2PES_SECTOR=total
GRA2PES_YEAR=2021
GRA2PES_VERSION=v1.0
#
ANTHROEMIS_INPUTDIR=${CHEM_INPUT}/emissions/anthro/raw/${ANTHRO_EMISINV}/${GRA2PES_SECTOR}/${GRA2PES_YEAR}${MM}/${DOW_STRING}/
ANTHROEMIS_OUTPUTDIR=${DATA}
#TODO:
#ANTHROEMIS_OUTPUTDIR=${CHEM_INPUT}/emissions/anthro/processed/${ANTHRO_EMISINV}/${MOY}/${DOW_STRING}/
mkdir -p "${ANTHROEMIS_OUTPUTDIR}"

EMISFILE_BASE_RAW1=${CHEM_INPUT}/emissions/anthro/raw/${ANTHRO_EMISINV}/${GRA2PES_SECTOR}/${GRA2PES_YEAR}${MM}/${DOW_STRING}/${ANTHRO_EMISINV}${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${GRA2PES_YEAR}${MM}_${DOW_STRING}_00to11Z.nc
EMISFILE_BASE_RAW2=${CHEM_INPUT}/emissions/anthro/raw/${ANTHRO_EMISINV}/${GRA2PES_SECTOR}/${GRA2PES_YEAR}${MM}/${DOW_STRING}/${ANTHRO_EMISINV}${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${GRA2PES_YEAR}${MM}_${DOW_STRING}_12to23Z.nc
INPUT_GRID=${CHEM_INPUT}/grids/domain_latlons/${ANTHRO_EMISINV}${GRA2PES_VERSION}_CONUS4km_grid_info.nc

EMISFILE1=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${MESH_NAME}_00to11Z.nc
EMISFILE2=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${MESH_NAME}_12to23Z.nc
# the following 2 variable are not used
#EMISFILE1_vinterp=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${MESH_NAME}_00to11Z_vinterp.nc
#EMISFILE2_vinterp=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${MESH_NAME}_12to23Z_vinterp.nc
#
if [[ -r ${EMISFILE_BASE_RAW1} ]] && [[ -r ${EMISFILE_BASE_RAW2} ]]; then
  echo "Checking to make sure we have corner coords"
  ncdump -hv XLAT_C "${EMISFILE_BASE_RAW1}"
  #shellcheck disable=SC2181
  if [[ $? -ne 0 ]]; then
    echo ".. we don't, cutting in from ${INPUT_GRID}"
    ncks -A -v XLAT_C,XLAT_M,XLONG_C,XLONG_M "${INPUT_GRID}" "${EMISFILE_BASE_RAW1}"
    ncks -A -v XLAT_C,XLAT_M,XLONG_C,XLONG_M "${INPUT_GRID}" "${EMISFILE_BASE_RAW2}"
  else
    echo "...we do!"
  fi
  echo "Found base emission files: ${EMISFILE_BASE_RAW1} and ${EMISFILE_BASE_RAW2}, will interpolate"
  # -- Start the regridding process
  mpirun -np "${nt}" python -u "${SCRIPT}"   \
             "GRA2PES" \
             "${DATA}" \
             "${ANTHROEMIS_INPUTDIR}" \
             "${ANTHROEMIS_OUTPUTDIR}" \
             "${INTERP_WEIGHTS_DIR}" \
             "${YYYY}${MM}${DD}${HH}" \
             "${MESH_NAME}"

  if [[ ! -r ${EMISFILE1} ]] || [[ ! -r ${EMISFILE2} ]]; then
     echo "ERROR: Did not interpolate ${ANTHRO_EMISINV}"
     exit 1
  else
     ncpdq -O -a Time,nCells,nkemit "${EMISFILE1}" "${EMISFILE1}"
     ncpdq -O -a Time,nCells,nkemit "${EMISFILE2}" "${EMISFILE2}"
     ncks -O --mk_rec_dmn Time "${EMISFILE1}" "${EMISFILE1}"
     ncks -O --mk_rec_dmn Time "${EMISFILE2}" "${EMISFILE2}"
     ncks -O -6  "${EMISFILE1}" "${EMISFILE1}"
     ncks -O -6  "${EMISFILE2}" "${EMISFILE2}"
     # Vertically interpolate the emissions based on the MPAS grid
     # python ${VINTERP_SCRIPT} ${EMISFILE1} ${INIT_FILE} ${EMISFILE1_vinterp} "PM25-PRI" "h_agl" "zgrid"

     for ihour in $(seq 0 "${my_fcst_length}")
     do
         YYYY_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%Y)
         MM_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%m)
         DD_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%d)
         HH_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%H)
         # the following two variables are not used
         #MOY_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%B)
         #DOW_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%A)
         LINKEDEMISFILE=${UMBRELLA_PREP_CHEM_DATA}/anthro.init.${YYYY_EMIS}-${MM_EMIS}-${DD_EMIS}_${HH_EMIS}.00.00.nc
         if (( 10#${HH_EMIS} > 11 )); then
            offset=12
            EMISFILE=${EMISFILE2}
         else
            offset=0
            EMISFILE=${EMISFILE1}
         fi
         t_ix=$(( 10#${HH_EMIS} - 10#${offset} ))
         #
         EMISFILE_FINAL=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}_${MESH_NAME}_${HH_EMIS}Z.nc
         # Reorder
         if [[ -r ${EMISFILE_FINAL} ]]; then
            ln -sf "${EMISFILE_FINAL}" "${LINKEDEMISFILE}"
         else
            echo "Reordering dimensions -- cell x level x time -- >  Time x Cell x Level "
            ncks -d Time,${t_ix},${t_ix} "${EMISFILE}" "${EMISFILE_FINAL}"
            echo "Created file #${ihour}/${my_fcst_length} at ${EMISFILE_FINAL}"
            ncrename -v PM25-PRI,e_ant_in_unspc_fine -v PM10-PRI,e_ant_in_unspc_coarse "${EMISFILE_FINAL}"
            ncrename -v HC01,e_ant_in_ch4 "${EMISFILE_FINAL}"
          # TODO, other species
            ncap2 -O -s 'e_ant_in_smoke_fine=0.0*e_ant_in_unspc_fine' "${EMISFILE_FINAL}" "${EMISFILE_FINAL}"
            ncap2 -O -s 'e_ant_in_smoke_coarse=0.0*e_ant_in_unspc_fine' "${EMISFILE_FINAL}" "${EMISFILE_FINAL}"
            ncap2 -O -s 'e_ant_in_dust_fine=0.0*e_ant_in_unspc_fine' "${EMISFILE_FINAL}" "${EMISFILE_FINAL}"
            ncap2 -O -s 'e_ant_in_dust_coarse=0.0*e_ant_in_unspc_fine' "${EMISFILE_FINAL}" "${EMISFILE_FINAL}"
            ln -sf "${EMISFILE_FINAL}" "${LINKEDEMISFILE}"
         fi
     done
  fi # Did interp succeed?
fi # Do the emission files exist
