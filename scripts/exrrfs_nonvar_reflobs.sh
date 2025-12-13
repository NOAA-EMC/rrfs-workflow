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
#
YYYY=${CDATE:0:4}
MM=${CDATE:4:2}
DD=${CDATE:6:2}
HH=${CDATE:8:2}

#
#-----------------------------------------------------------------------
#
# link or copy background files
#
#-----------------------------------------------------------------------
#
meshgriddir="${FIXrrfs}/${MESH_NAME}"
echo "INFO: meshgriddir is $meshgriddir"
cp "${meshgriddir}"/"${MESH_NAME}".grid.nc mesh.nc

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
for (( j=0; j < 4; $((j=j+1)) )); do
  min=$( printf %2.2i ${j} )
  echo "Looking for data valid:${YYYY}-${MM}-${DD} ${HH}:${min}"
  if [[ -s filelist_mrms ]]; then
    break
  fi
  s=0
  while (( s <= 59 )); do
    ss=$(printf %2.2i ${s})
    nsslfile="${NSSL}/${mrms}_00.50_${YYYY}${MM}${DD}-${HH}${min}${ss}.${obs_appendix}"
    if [[ -s ${nsslfile} ]]; then
      echo "Found ${nsslfile}"
      nsslfile1="*${mrms}_*_${YYYY}${MM}${DD}-${HH}${min}*.${obs_appendix}"
      numgrib2=$(find ${NSSL}/${nsslfile1} -maxdepth 1 -type f | wc -l)
      echo "Number of GRIB-2 files: ${numgrib2}"
      if (( "${numgrib2}" >= 10 )) && [[ ! -e filelist_mrms ]]; then
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
# Unzip GRIB2 files if needed, then run program
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
  echo "FATAL ERROR: Not enough radar reflectivity files were found"
  err_exit
fi

cat << EOF > namelist.mosaic
   &setup
    tversion = 1,
    analysis_time = ${CDATE},
    dataPath = './',
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
export pgm="process_NSSL_mosaic_nonvar.exe"
${cpreq} "${EXECrrfs}/${pgm}" .
source prep_step
${MPI_RUN_CMD} ./${pgm}
# check the status
export err=$?
err_chk

${cpreq} RefInGSI3D.dat "${COMOUT}/nonvar_reflobs/${WGF}/RefInGSI3D.dat"

exit 0
