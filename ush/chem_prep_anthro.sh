#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2153,SC2012,SC2016
# rrfslint: file-disable=RRFS005
#
if [[ "${CHEM_GROUPS,,}" == *rwc* ]]; then
   GRA2PES_SECTOR=total_minus_res # to not double count those emissions
else
   GRA2PES_SECTOR=total
fi
GRA2PES_YEAR=2021
GRA2PES_VERSION=v1.0
#
NEMO_YEAR=2017
NEMO_GRID=US01
NEMO_VERSION=cb6ae7_2017gb_17j


INDIR_GRA2PES=${CHEM_INPUT}/emissions/anthro/raw/GRA2PES/${GRA2PES_SECTOR}/${GRA2PES_YEAR}${MM}/${DOW_STRING}/
INDIR_NEMO=${CHEM_INPUT}/emissions/anthro/raw/NEMO/hourly/
INDIR_NEI2017_PT=${CHEM_INPUT}/emissions/anthro/raw/NEI2017/point/

OUTDIR=${DATA}
mkdir -p "${OUTDIR}"
#
#
INPUT_GRID_GRA2PES=${CHEM_INPUT}/grids/domain_latlons/GRA2PES${GRA2PES_VERSION}_CONUS4km_grid_info.nc
INPUT_GRID_NEMO=${CHEM_INPUT}/grids/domain_latlons/NEMO_1km_latlon.nc
#
EMISFILE_BASE_RAW1_GRA2PES=${INDIR_GRA2PES}/GRA2PES${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${GRA2PES_YEAR}${MM}_${DOW_STRING}_00to11Z.nc
EMISFILE_BASE_RAW2_GRA2PES=${INDIR_GRA2PES}/GRA2PES${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${GRA2PES_YEAR}${MM}_${DOW_STRING}_12to23Z.nc
#
EMISFILE1_GRA2PES=${OUTDIR}/GRA2PES${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${MESH_NAME}_00to11Z.nc
EMISFILE2_GRA2PES=${OUTDIR}/GRA2PES${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${MESH_NAME}_12to23Z.nc
#
#
EMIS_SECTOR_NEMO=(airports nonpt nonroad np_oilgas othar_all rail onroad_ff10) # ag will move to online
EMIS_SECTOR_NEMO_DAYTYPE=(4 6 4 2 4 2 5)  # ag will be = 2
EMIS_SECTOR_NEMO_PT=(cmv_c1c2_12 cmv_c3_12 othpt pt_oilgas ptegu) # ag
EMIS_SECTOR_NEMO_PT_DAYTYPE=(2 2 4 3 8)

# the following 2 variable are not used
#EMISFILE1_vinterp=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${MESH_NAME}_00to11Z_vinterp.nc
#EMISFILE2_vinterp=${ANTHROEMIS_OUTPUTDIR}/${ANTHRO_EMISINV}${GRA2PES_VERSION}_${GRA2PES_SECTOR}_${MESH_NAME}_12to23Z_vinterp.nc
#
if [[ "${ANTHRO_EMISINV}" == *GRA2PES* ]]; then

if [[ -r ${EMISFILE_BASE_RAW1_GRA2PES} ]] && [[ -r ${EMISFILE_BASE_RAW2_GRA2PES} ]]; then
  echo "Checking to make sure we have corner coords"
  ncdump -hv XLAT_C "${EMISFILE_BASE_RAW1_GRA2PES}"
  #shellcheck disable=SC2181
  if [[ $? != 0 ]]; then
    echo ".. we don't, cutting in from ${INPUT_GRID_GRA2PES}"
    ncks -A -v XLAT_C,XLAT_M,XLONG_C,XLONG_M "${INPUT_GRID_GRA2PES}" "${EMISFILE_BASE_RAW1_GRA2PES}"
    ncks -A -v XLAT_C,XLAT_M,XLONG_C,XLONG_M "${INPUT_GRID_GRA2PES}" "${EMISFILE_BASE_RAW2_GRA2PES}"
  else
    echo "...we do!"
  fi
  echo "Found base emission files: ${EMISFILE_BASE_RAW1_GRA2PES} and ${EMISFILE_BASE_RAW2_GRA2PES}, will interpolate"
  # -- Start the regridding process
  srun -u python -u "${SCRIPT}"   \
             "GRA2PES" \
             "${DATA}" \
             "${INDIR_GRA2PES}" \
             "${OUTDIR}" \
             "${INTERP_WEIGHTS_DIR}" \
             "${YYYY}${MM}${DD}${HH}"

  if [[ ! -r ${EMISFILE1_GRA2PES} ]] || [[ ! -r ${EMISFILE2_GRA2PES} ]]; then
     echo "ERROR: Did not interpolate ${ANTHRO_EMISINV}"
     exit 1
  else
     ncpdq -O -a Time,nCells,nkanthro "${EMISFILE1_GRA2PES}" "${EMISFILE1_GRA2PES}"
     ncpdq -O -a Time,nCells,nkanthro "${EMISFILE2_GRA2PES}" "${EMISFILE2_GRA2PES}"
     ncks -O --mk_rec_dmn Time "${EMISFILE1_GRA2PES}" "${EMISFILE1_GRA2PES}"
     ncks -O --mk_rec_dmn Time "${EMISFILE2_GRA2PES}" "${EMISFILE2_GRA2PES}"
     ncks -O -6  "${EMISFILE1_GRA2PES}" "${EMISFILE1_GRA2PES}"
     ncks -O -6  "${EMISFILE2_GRA2PES}" "${EMISFILE2_GRA2PES}"
     # Vertically interpolate the emissions based on the MPAS grid
     # python ${VINTERP_SCRIPT} ${EMISFILE1} ${INIT_FILE} ${EMISFILE1_vinterp} "PM25-PRI" "h_agl" "zgrid"

     for ihour in $(seq 0 "${my_fcst_length}")
     do
         YYYY_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%Y)
         MM_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%m)
         DD_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%d)
         HH_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%H)
         LINKEDEMISFILE=${UMBRELLA_PREP_CHEM_DATA}/anthro.init.${YYYY_EMIS}-${MM_EMIS}-${DD_EMIS}_${HH_EMIS}.00.00.nc
         if (( 10#${HH_EMIS} > 11 )); then
            offset=12
            EMISFILE=${EMISFILE2_GRA2PES}
         else
            offset=0
            EMISFILE=${EMISFILE1_GRA2PES}
         fi
         t_ix=$(( 10#${HH_EMIS} - 10#${offset} ))
         #
         EMISFILE_FINAL=${OUTDIR}/GRA2PES_${MESH_NAME}_${HH_EMIS}Z.nc
         # Reorder
         if [[ -r ${EMISFILE_FINAL} ]]; then
            ln -sf "${EMISFILE_FINAL}" "${LINKEDEMISFILE}"
         else
            echo "Reordering dimensions -- cell x level x time -- >  Time x Cell x Level "
            ncks -d Time,${t_ix},${t_ix} "${EMISFILE}" "${EMISFILE_FINAL}"
            echo "Created file #${ihour}/${my_fcst_length} at ${EMISFILE_FINAL}"
            ncrename -v PM25-PRI,e_ant_in_unspc_fine "${EMISFILE_FINAL}"
            ncrename -v PM10-PRI,e_ant_in_unspc_coarse "${EMISFILE_FINAL}"
            ncrename -v HC01,e_ant_in_ch4 "${EMISFILE_FINAL}"
            ncrename -v CO,e_ant_in_co "${EMISFILE_FINAL}"
            ncrename -v NH3,e_ant_in_nh3 "${EMISFILE_FINAL}"
            ncrename -v NOX,e_ant_in_nox "${EMISFILE_FINAL}"
            ncrename -v SO2,e_ant_in_so2 "${EMISFILE_FINAL}"
            ln -sf "${EMISFILE_FINAL}" "${LINKEDEMISFILE}"
         fi
     done
  fi # Did interp succeed?
fi # Do the emission files exist
fi # Is GRA2PES listed as one of the anthro inventories?


# Now for NEMO emissions
EMISFILE_NEMO_PROCESSED=${OUTDIR}/NEMO_ANTHRO_${MESH_NAME}.nc
EMISFILE_NEMO_SECTORSUM=${DATA}/NEMO_ANTHRO_${MESH_NAME}_${YYYY}${MM}${DD}${HH}_SECTORSUM.nc
MERGEDATEFILE=${CHEM_INPUT}/emissions/anthro/raw/NEMO/hourly/smk_merge_dates_${NEMO_YEAR}.txt
if [[ "${ANTHRO_EMISINV}" == *NEMO* ]]; then
#
# We need to determine the representative day for the current forecast day
 # First create the smk_merge_dates file if one doesn't exist
   if [[ ! -r "${MERGEDATEFILE}" ]]; then
      srun -n 1 "${HOMErrfs}/ush/chem_create_merge_dates_ann.py" ${NEMO_YEAR}
      # Put it in the shared directory?
      cp "smk_merge_dates_${NEMO_YEAR}.txt" "${MERGEDATEFILE}"
      # In case no permissions, set datefile as one created here
      MERGEDATEFILE="${DATA}/smk_merge_dates_${NEMO_YEAR}.txt"
   fi
 # Then get the day of the year in the NEMO BASE YEAR (2017) that is closest to today's day of the week in the calendar postion
   YYYYMMDD_NEMO_BASE_YEAR=$("${HOMErrfs}/ush/chem_get_merge_date.py" "${YYYY}" "${JJJ}" "${NEMO_YEAR}")
   JJJ_NEMO_BASE_YEAR=$(date +%-j -d "${YYYYMMDD_NEMO_BASE_YEAR}")
   NEMO_EMISFILES_TO_CAT=()
   isect_knt=0
   for isect in "${EMIS_SECTOR_NEMO[@]}"
   do
      # Deterimine the type of representative days
      # The date is in the row that matches todays date and the column
      # determined by daytype
      rowid=$((JJJ_NEMO_BASE_YEAR + 1 + 31)) # 1 for indexing, 31 because it includes the previous December
      colid=${EMIS_SECTOR_NEMO_DAYTYPE[${isect_knt}]}
      testdate=$(awk -F',' -v row_num="${rowid}" -v col_num="${colid}" 'NR==row_num {gsub(/[[:blank:]]/, "", $col_num); print $col_num; exit}' "${MERGEDATEFILE}")
      testfile="${INDIR_NEMO}/${isect}/emis_mole_${isect}_${testdate}_${NEMO_GRID}_cmaq_${NEMO_VERSION}.ncf"
# --- DYNAMIC MULTI-DAY FALLBACK ---
      # If the targeted file doesn't exist, dynamically find the first available 
      # file for that same year and month (e.g., matching 201705*)
      if [[ ! -r "${testfile}" ]]; then
         YYYYMM="${testdate:0:6}"
         first_available=$(ls -1 "${INDIR_NEMO}/${isect}/emis_mole_${isect}_${YYYYMM}"*.ncf 2>/dev/null | head -n 1)
         if [[ -n "${first_available}" ]]; then
            testfile="${first_available}"
         fi
      fi
      if [[ -r "${testfile}" ]]; then
         NEMO_EMISFILES_TO_CAT+=("${testfile}")
      fi
      isect_knt=$((isect_knt+1))
   done
   # Sum the files
#   NEMO_VAR_LIST=("POC,PEC,PMOTHR,PMC")
   NEMO_VAR_LIST=("POC,PEC,PMOTHR,PMC,PAL,PCA,PCL,PFE,PK,PMG,PMN,PNA,PNCOM,PNH4,PNO3,PSI,PSO4,PTI,CO,NO,NO2,NH3,SO2")
   NEMO_PM_VAR_LIST=("POC,PEC,PMOTHR,PAL,PCA,PCL,PFE,PK,PMG,PMN,PNA,PNCOM,PNH4,PNO3,PSI,PSO4,PTI")
   NEI_VAR_LIST=("LATITUDE,LONGITUDE,STKDM,STKHT,STKFLW,STKTK,STKVE")
   srun -n 1 "${HOMErrfs}/ush/chem_merge_emissions.py" "${EMISFILE_NEMO_SECTORSUM}" "${NEMO_VAR_LIST[@]}" "${NEMO_EMISFILES_TO_CAT[@]}"
   # Append the dims - TODO, can only append variables to dim file, not other way around ...
   mv "${EMISFILE_NEMO_SECTORSUM}" "${EMISFILE_NEMO_SECTORSUM}_tmp.nc"
   cp "${INPUT_GRID_NEMO}" "${EMISFILE_NEMO_SECTORSUM}"
   ncks -A "${EMISFILE_NEMO_SECTORSUM}_tmp.nc" "${EMISFILE_NEMO_SECTORSUM}"
   rm -f "${EMISFILE_NEMO_SECTORSUM}_tmp.nc"
   # Interpolate the file, one hour at a time
   mv "${EMISFILE_NEMO_SECTORSUM}" "${EMISFILE_NEMO_SECTORSUM}_total.nc"
   ncks -O -4 "${EMISFILE_NEMO_SECTORSUM}_total.nc" "${EMISFILE_NEMO_SECTORSUM}_total.nc"
   
   for ihour in $(seq -w 0 24)
   do
       istr="${ihour}"
       # Extract 1 hour
       ncks -d TSTEP,"${ihour}","${ihour}" "${EMISFILE_NEMO_SECTORSUM}_total.nc" "${EMISFILE_NEMO_SECTORSUM}"
       # Interpolate it
       if [[ -r "${EMISFILE_NEMO_SECTORSUM}" ]]; then
          srun python -u "${SCRIPT}" \
                           "NEMO_ANTHRO" \
                           "${DATA}" \
                           "${DATA}" \
                           "${OUTDIR}" \
                           "${INTERP_WEIGHTS_DIR}" \
                           "${YYYY}${MM}${DD}${HH}"
          ncap2 -O -s "e_ant_in_unspc_fine=${NEMO_PM_VAR_LIST//,/+}" "${EMISFILE_NEMO_PROCESSED}"  "${EMISFILE_NEMO_PROCESSED}"
          ncap2 -O -s "e_ant_in_nox=NO+NO2" "${EMISFILE_NEMO_PROCESSED}"  "${EMISFILE_NEMO_PROCESSED}"
          ncrename -v PMC,e_ant_in_unspc_coarse "${EMISFILE_NEMO_PROCESSED}"
          ncrename -v CO,e_ant_in_co "${EMISFILE_NEMO_PROCESSED}"
          ncrename -v NH3,e_ant_in_nh3 "${EMISFILE_NEMO_PROCESSED}"
          ncrename -v SO2,e_ant_in_so2 "${EMISFILE_NEMO_PROCESSED}"
          # TODO - if we run with the SNA scheme, we need PNH4,PNO3,PSO4 as seperate emissions but
          # will need to remove it from e_ant_in_unspc_fine
          ncrename -v PNH4,e_ant_in_nh4_a_fine "${EMISFILE_NEMO_PROCESSED}"
          ncrename -v PNO3,e_ant_in_no3_a_fine "${EMISFILE_NEMO_PROCESSED}"
          ncrename -v PSO4,e_ant_in_so4_a_fine "${EMISFILE_NEMO_PROCESSED}"
          ncks -O -x -v "${NEMO_VAR_LIST[@]}" "${EMISFILE_NEMO_PROCESSED}" "${EMISFILE_NEMO_PROCESSED}"
          mv "${EMISFILE_NEMO_PROCESSED}" "${EMISFILE_NEMO_PROCESSED}_${istr}.nc"
          ncks -O -4 "${EMISFILE_NEMO_PROCESSED}_${istr}.nc" "${EMISFILE_NEMO_PROCESSED}_${istr}.nc"
          ncpdq -O -a Time,nCells,nkanthro "${EMISFILE_NEMO_PROCESSED}_${istr}.nc" "${EMISFILE_NEMO_PROCESSED}_${istr}.nc"
       fi
       # Remove the temporary file
       rm -f "${EMISFILE_NEMO_SECTORSUM}"
   done
   
   # Now do the pt source emission files
   NEMO_EMISFILES_PT_TO_CAT=()
   NEMO_STACKFILES_TO_CAT=()
   NEMO_EMISFILE_PT_PROCESSED="${UMBRELLA_PREP_CHEM_DATA}/anthro_pt.init.nc"
   NEMO_STACKFILE_PROCESSED="${UMBRELLA_PREP_CHEM_DATA}/anthro_pt.stack_groups.init.nc"
   isect_knt=0
   for isect in "${EMIS_SECTOR_NEMO_PT[@]}"
   do
      # Deterimine the type of representative days
      # The date is in the row that matches todays date and the column
      # determined by daytype
      rowid=$((JJJ_NEMO_BASE_YEAR + 1 + 31)) # 1 for indexing, 31 because it includes the previous December
      colid=${EMIS_SECTOR_NEMO_PT_DAYTYPE[${isect_knt}]}
      testdate=$(awk -F',' -v row_num="${rowid}" -v col_num="${colid}" 'NR==row_num {gsub(/[[:blank:]]/, "", $col_num); print $col_num; exit}' "${MERGEDATEFILE}")
      testfile=${INDIR_NEI2017_PT}/${isect}/inln_mole_${isect}_${testdate}_12US1_cmaq_${NEMO_VERSION}.ncf
      stackfile=${INDIR_NEI2017_PT}/${isect}/stack_groups_${isect}_12US1_2017gb_17j.ncf
      if [[ -r ${testfile} ]]; then
         # Put them here as NETCDF4, cut out TFLAG, whcih has dim(VAR), not the same between files
         ncks -O -4 -x -v TFLAG "${testfile}" "./tmp_${isect}.nc"
         ncks -O -4 -v "${NEI_VAR_LIST[@]}" "${stackfile}" "./tmp_stack_${isect}.nc"
         NEMO_STACKFILES_TO_CAT+=("./tmp_stack_${isect}.nc")
         NEMO_EMISFILES_PT_TO_CAT+=("./tmp_${isect}.nc")
         
         ncks -O --fix_rec_dmn TSTEP "./tmp_${isect}.nc" "./tmp_${isect}.nc"
         ncks -O --fix_rec_dmn TSTEP "./tmp_stack_${isect}.nc" "./tmp_stack_${isect}.nc"
      fi
      isect_knt=$((isect_knt+1))
   done
   ## Cat all of the point source files together
   srun -n 1 "${HOMErrfs}/ush/chem_merge_pt_emissions.py" "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_VAR_LIST[@]}" "${NEMO_EMISFILES_PT_TO_CAT[@]}"
   srun -n 1 "${HOMErrfs}/ush/chem_merge_pt_emissions.py" "${NEMO_STACKFILE_PROCESSED}" "${NEI_VAR_LIST[@]}" "${NEMO_STACKFILES_TO_CAT[@]}"

   # Update variable names for the chosen mechanism 
   ncap2 -O -s "e_ant_pt_in_unspc_fine=${NEMO_PM_VAR_LIST//,/+}" "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_nox=NO2+NO' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncrename -v PMC,e_ant_pt_in_unspc_coarse "${NEMO_EMISFILE_PT_PROCESSED}"
   ncrename -v CO,e_ant_pt_in_co "${NEMO_EMISFILE_PT_PROCESSED}"
   ncrename -v NH3,e_ant_pt_in_nh3 "${NEMO_EMISFILE_PT_PROCESSED}"
   ncrename -v SO2,e_ant_pt_in_so2 "${NEMO_EMISFILE_PT_PROCESSED}"
   # TODO - if we run with the SNA scheme, we need PNH4,PNO3,PSO4 as seperate emissions but
   # will need to remove it from e_ant_in_unspc_fine
   ncrename -v PNH4,e_ant_pt_in_nh4_a_fine "${NEMO_EMISFILE_PT_PROCESSED}" 
   ncrename -v PNO3,e_ant_pt_in_no3_a_fine "${NEMO_EMISFILE_PT_PROCESSED}"
   ncrename -v PSO4,e_ant_pt_in_so4_a_fine "${NEMO_EMISFILE_PT_PROCESSED}"
   ncks -O -x -v "${NEMO_VAR_LIST[@]}" "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   # Update dimension name for # of stacks
   ncrename -d ROW,nanthro_pt "${NEMO_EMISFILE_PT_PROCESSED}"
   ncrename -d ROW,nanthro_pt "${NEMO_STACKFILE_PROCESSED}"
   # Append the times
   ncks -A -v Time,xtime init.nc "${NEMO_EMISFILE_PT_PROCESSED}"
   ncks -A -v Time,xtime init.nc "${NEMO_STACKFILE_PROCESSED}"
   # Remove singleton dimensions
   ncwa -O -a LAY,COL "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncwa -O -a LAY,COL,TSTEP "${NEMO_STACKFILE_PROCESSED}" "${NEMO_STACKFILE_PROCESSED}"
   # Cast the stack parameters through time
   ncap2 -O -s 'e_ant_pt_in_unspc_fine[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_unspc_fine' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_unspc_coarse[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_unspc_coarse' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_co[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_co' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_nox[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_nox' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_nh3[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_nh3' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_so2[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_so2' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_nh4_a_fine[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_nh4_a_fine' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_no3_a_fine[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_no3_a_fine' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncap2 -O -s 'e_ant_pt_in_so4_a_fine[$Time,$TSTEP,$nanthro_pt]=e_ant_pt_in_so4_a_fine' "${NEMO_EMISFILE_PT_PROCESSED}" "${NEMO_EMISFILE_PT_PROCESSED}"
   ncrename -v LATITUDE,STKLT -v LONGITUDE,STKLG "${NEMO_STACKFILE_PROCESSED}"
#
fi # IS NEMO listed as part of the ANTHRO EMIS inventory?
#
# If they are both listed, let's combine it, prioritizing NEMO
# If only NEMO, link to correct name
for ihour in $(seq 0 "${my_fcst_length}")
do
     YYYY_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%Y)
     MM_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%m)
     DD_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%d)
     HH_EMIS=$(date -d "${CDATE:0:8} ${CDATE:8:2} + ${ihour} hours" +%H)
     LINKEDEMISFILE="${UMBRELLA_PREP_CHEM_DATA}/anthro.init.${YYYY_EMIS}-${MM_EMIS}-${DD_EMIS}_${HH_EMIS}.00.00.nc"
     if [[ "${ANTHRO_EMISINV}" == *GRA2PES* ]] && [[ "${ANTHRO_EMISINV}" == *NEMO* ]]; then
        srun -n 1 "${HOMErrfs}/ush/chem_prep_prioritize_emissions.py" "${EMISFILE_NEMO_PROCESSED}_${HH_EMIS}.nc" "${LINKEDEMISFILE}"
        ln -sf "${EMISFILE_NEMO_PROCESSED}_${HH_EMIS}.nc" "${LINKEDEMISFILE}"
     elif  [[ ! "${ANTHRO_EMISINV}" == *GRA2PES* ]] && [[ "${ANTHRO_EMISINV}" == *NEMO* ]]; then
        ln -sf "${EMISFILE_NEMO_PROCESSED}_${HH_EMIS}.nc" "${LINKEDEMISFILE}"
     fi
done
# Clean up
rm -f "tmp_*.nc" "*.tmp"
