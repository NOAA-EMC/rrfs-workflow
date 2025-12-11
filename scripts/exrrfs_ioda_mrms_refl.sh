#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154,SC2086,SC2068
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
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
YYYYMMDD=${CDATE:0:8}
#
#-----------------------------------------------------------------------
#
# Loop through different time levels
# Get into working directory
#
#-----------------------------------------------------------------------
#
echo "Getting into working directory for radar reflectivity process ..."

for bigmin_this in ${RADARREFL_TIMELEVEL[@]}; do
  bigmin=$( printf %2.2i ${bigmin_this} )
  mkdir "${DATA}/${bigmin}"
  cd "${DATA}/${bigmin}" || exit

  #
  #-----------------------------------------------------------------------
  #
  # link or copy background files
  #
  #-----------------------------------------------------------------------
  #
  meshgriddir="${FIXrrfs}/${MESH_NAME}"
  echo "meshgriddir is $meshgriddir"
  cp "${meshgriddir}"/"${MESH_NAME}".grid.nc grid.nc

  #
  #-----------------------------------------------------------------------
  #
  # link/copy observation files to working directory
  #
  #-----------------------------------------------------------------------
  #
  obs_appendix=${REFLOBS_APPENDIX:-grib2}
  NSSL=${OBSPATH_NSSLMOSIAC}

  mrms="MergedReflectivityQC"
  #
  #-----------------------------------------------------------------------
  #
  # Link to the MRMS operational data
  #
  #-----------------------------------------------------------------------
  #
  if [[ -s filelist_mrms ]]; then
    rm -f filelist_mrms
  fi
  echo "bigmin = ${bigmin}"
  for (( j=0; j < 4; $((j=j+1)) )); do
    min=$( printf %2.2i $(( 10#${bigmin_this} + j )) )
    echo "Looking for data valid:${YYYY}-${MM}-${DD} ${HH}:${min}"
    if [[ -e filelist_mrms ]]; then
      break
    fi
    s=0
    while (( s <= 59 )); do
      ss=$(printf %2.2i ${s})
      nsslfile="${NSSL}/*${mrms}_00.50_${YYYY}${MM}${DD}-${HH}${min}${ss}.${obs_appendix}"
      if [[ -s ${nsslfile} ]]; then
        echo "Found ${nsslfile}"
        nsslfile1="*${mrms}_*_${YYYY}${MM}${DD}-${HH}${min}*.${obs_appendix}"
	numgrib2=$(find ${NSSL}/${nsslfile1} -maxdepth 1 -type f | wc -l)
        echo "Number of GRIB-2 files: ${numgrib2}"
        if (( numgrib2 >= 10 )) && [ ! -e filelist_mrms ]; then
          cp ${NSSL}/${nsslfile1} .
          ls ${nsslfile1} > filelist_mrms
          echo "Creating links for ${YYYY}${MM}${DD}-${HH}${min}"
	  break
        fi
      fi
      ((s+=1))
    done
  done
  #
  #-----------------------------------------------------------------------
  #
  # remove filelist_mrms if zero bytes
  #
  #-----------------------------------------------------------------------
  #
  if [[ -s filelist_mrms ]]; then
     if [[ "${obs_appendix}" == "grib2.gz" ]]; then
        gzip -d ./*.gz
        mv filelist_mrms filelist_mrms_org
        ls "MergedReflectivityQC_*_${YYYY}${MM}${DD}-${HH}????.grib2" > filelist_mrms
     fi

     numgrib2=$(more filelist_mrms | wc -l)
     echo "Using radar data from: $(head -1 filelist_mrms | cut -c10-15)"
     echo "NSSL grib2 file levels = $numgrib2"
  else
     echo "WARNING: Not enough radar reflectivity files available for loop ${bigmin}."
     continue
  fi

#
#  if (( RADAR_REF_THINNING == 2 )); then
#    # heavy data thinning, typically used for EnKF
#    precipdbzhorizskip=1
#    precipdbzvertskip=2
#    clearairdbzhorizskip=2
#    clearairdbzvertskip=4
#  elif (( RADAR_REF_THINNING == 1 )); then
#    # light data thinning, typically used for hybrid EnVar
#    precipdbzhorizskip=1
#    precipdbzvertskip=1
#    clearairdbzhorizskip=1
#    clearairdbzvertskip=1
#  else
#    # no data thinning
     precipdbzhorizskip=0
     precipdbzvertskip=0
     clearairdbzhorizskip=0
     clearairdbzvertskip=0
# fi

cat << EOF > namelist.mosaic
   &setup
    analysis_time = ${CDATE},
    dataPath = './',
   /
   &setup_netcdf
    output_netcdf = .true.,
    max_height = 11001.0,
    use_clear_air_type = .true.,
    precip_dbz_thresh = 10.0,
    clear_air_dbz_thresh = 5.0,
    clear_air_dbz_value = 0.0,
    precip_dbz_horiz_skip = ${precipdbzhorizskip},
    precip_dbz_vert_skip = ${precipdbzvertskip},
    clear_air_dbz_horiz_skip = ${clearairdbzhorizskip},
    clear_air_dbz_vert_skip = ${clearairdbzvertskip},
   /
EOF
  #
  #-----------------------------------------------------------------------
  #
  # Run the radar refl process.
  #
  #-----------------------------------------------------------------------
  #

  module list
  export pgm="process_NSSL_mosaic.exe"
  ${cpreq} "${EXECrrfs}/${pgm}" .
  source prep_step
  ${MPI_RUN_CMD} ./${pgm}
# check the status
  export err=$?
  err_chk

  cp RefInGSI3D.dat  "${COMOUT}/ioda_mrms_refl/${WGF}/rrfs.t${HH}z.RefInGSI3D.bin.${bigmin}"

  #
  #-----------------------------------------------------------------------
  #
  # Run ioda converter to generate radar reflectivity ioda file
  #
  #-----------------------------------------------------------------------
  # pyioda libraries
  PYIODALIB=$(echo "${HOMErrfs}"/sorc/RDASApp/build/lib/python3.*)
  export PYTHONPATH=${PYIODALIB}:${PYTHONPATH}
  "${HOMErrfs}"/ush/MRMS2ioda.py -i ./Gridded_ref.nc -c "${YYYY}-${MM}-${DD}T${HH}:${bigmin}:00" -o "ioda_mrms_${YYYYMMDD}${HH}_${bigmin}.nc4"

  # file count sanity check and copy to COMOUT
  if [[ -s "ioda_mrms_${YYYYMMDD}${HH}_${bigmin}.nc4" ]]; then
    ${cpreq} "ioda_mrms_${YYYYMMDD}${HH}_${bigmin}.nc4" "${COMOUT}/ioda_mrms_refl/${WGF}"
  else
    echo "FATAL ERROR: no ioda MRMS file generated."
    err_exit # err_exit if no ioda files generated at the development stage
  fi

done # done with the bigmin for-loop
