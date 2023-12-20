
#  setup for real-time runs on JET
OBSPATH_NSSLMOSIAC=/public/data/radar/nssl/mrms/conus
FFG_DIR=/public/data/grids/ncep/ffg/grib2
AIRCRAFT_REJECT="/home/amb-verif/acars_RR/amdar_reject_lists"
SFCOBS_USELIST="/lfs4/BMC/amb-verif/rap_ops_mesonet_uselists"
SST_ROOT="/lfs4/BMC/public/data/grids/ncep/sst/0p083deg/grib2"
GVF_ROOT="/public/data/sat/ncep/viirs/gvf/grib2"
FVCOM_DIR="/mnt/lfs4/BMC/public/data/grids/glerl/owaq"
FVCOM_FILE="tsfc_fv3grid"
OBSPATH_PM="/lfs4/BMC/public/data/airnow/hourly_aqobs"
BERROR_FN="rrfs_glb_berror.l127y770.f77"

if [[ $MACHINE == "hera" ]] ; then

# for using RAP as boundary and initial
#  EXTRN_MDL_SOURCE_BASEDIR_ICS=/scratch2/BMC/public/data/grids/rap/full/wrfnat/grib2
#  EXTRN_MDL_SOURCE_BASEDIR_LBCS=/scratch2/BMC/public/data/grids/rap/full/wrfnat/grib2
# for using GFS as boundary and initial
  EXTRN_MDL_SOURCE_BASEDIR_ICS=/scratch2/BMC/public/data/grids/gfs/0p25deg/grib2
  EXTRN_MDL_SOURCE_BASEDIR_LBCS=/scratch2/BMC/public/data/grids/gfs/0p25deg/grib2
# observations
  OBSPATH=/scratch2/BMC/public/data/grids/rap/obs
  OBSPATH_NSSLMOSIAC=/scratch2/BMC/public/data/radar/nssl/mrms/conus
  OBSPATH_PM=/scratch2/BMC/public/data/airnow/hourly_aqobs
  LIGHTNING_ROOT=/scratch2/BMC/public/data/lightning
  ENKF_FCST=/scratch1/NCEPDEV/rstprod/com/gfs/prod
fi

# for real-time wcoss2 runs
if [[ $MACHINE == "wcoss2" ]] ; then
  EXTRN_MDL_SOURCE_BASEDIR_ICS=/lfs/h1/ops/prod/com/gfs/v16.3
  EXTRN_MDL_SOURCE_BASEDIR_LBCS=/lfs/h1/ops/prod/com/gfs/v16.3
  OBSPATH=/lfs/h1/ops/prod/com/obsproc/v1.1
  OBSPATH_NSSLMOSIAC=/lfs/h1/ops/prod/dcom/ldmdata/obs/upperair/mrms/conus/MergedReflectivityQC
  ENKF_FCST=/lfs/h1/ops/prod/com/gfs/v16.3
  SST_ROOT=/lfs/h1/ops/prod/com/nsst/v1.2
  GVF_ROOT=/lfs/h1/ops/prod/dcom/viirs
  IMSSNOW_ROOT=/lfs/h1/ops/prod/com/obsproc/v1.1
  FIRE_RAVE_DIR=/lfs/h2/emc/lam/noscrub/emc.lam/RAVE_rawdata/RAVE_NA
  FVCOM_DIR="/lfs/h1/ops/prod/com/nosofs/v3.5"
  FVCOM_FILE="fvcom"
  RAPHRR_SOIL_ROOT="/lfs/h1/ops/prod/com"
fi

# set up for retrospective test:
if [[ $DO_RETRO == "TRUE" ]] ; then

  if [[ $MACHINE == "jet" ]] ; then
    RETRODATAPATH="/lfs4/BMC/wrfruc/RRFS_RETRO_DATA"
    if [ ${EXTRN_MDL_NAME_ICS} == "FV3GFS" ] ; then
      EXTRN_MDL_SOURCE_BASEDIR_ICS=${RETRODATAPATH}/gfs/0p25deg/grib2
    elif [ ${EXTRN_MDL_NAME_ICS} == "GEFS" ] ; then
      EXTRN_MDL_SOURCE_BASEDIR_ICS=${RETRODATAPATH}/GEFS
    elif [[ ${EXTRN_MDL_NAME_ICS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="${RETRODATAPATH}/enkf/atm"
    fi
    if [ ${EXTRN_MDL_NAME_LBCS} == "FV3GFS" ] ; then
      EXTRN_MDL_SOURCE_BASEDIR_LBCS=${RETRODATAPATH}/gfs/0p25deg/grib2
    elif [ ${EXTRN_MDL_NAME_LBCS} == "GEFS" ] ; then
      EXTRN_MDL_SOURCE_BASEDIR_LBCS=${RETRODATAPATH}/GEFS
    fi

    OBSPATH=${RETRODATAPATH}/obs_rap
    OBSPATH_PM=${RETRODATAPATH}/pm
    OBSPATH_NSSLMOSIAC=${RETRODATAPATH}/reflectivity
    LIGHTNING_ROOT=${RETRODATAPATH}/lightning
    ENKF_FCST=${RETRODATAPATH}/enkf/atm
    AIRCRAFT_REJECT=${RETRODATAPATH}/amdar_reject_lists
    SFCOBS_USELIST=${RETRODATAPATH}/mesonet_uselists
    SST_ROOT=${RETRODATAPATH}/highres_sst
    GVF_ROOT=${RETRODATAPATH}/gvf/grib2
    IMSSNOW_ROOT=${RETRODATAPATH}/snow/ims96/grib2
    RAPHRR_SOIL_ROOT=${RETRODATAPATH}/rap_hrrr_soil
    FIRE_RAVE_DIR=${RETRODATAPATH}/RAVE_RAW
  fi

  if [[ $MACHINE == "hera" ]] ; then
    RETRODATAPATH="/scratch2/BMC/zrtrr/RRFS_RETRO_DATA"
    if [[ ${DO_ENSEMBLE} == "TRUE" ]]; then
      if [[ ${EXTRN_MDL_NAME_ICS} == "GEFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="${RETRODATAPATH}/GEFS"
      elif [[ ${EXTRN_MDL_NAME_ICS} == "HRRRDAS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="${RETRODATAPATH}/HRRRDAS"
      elif [[ ${EXTRN_MDL_NAME_ICS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="${RETRODATAPATH}/enkf/atm"
      fi
      if [[ ${EXTRN_MDL_NAME_LBCS} == "GEFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="${RETRODATAPATH}/GEFS"
      elif [[ ${EXTRN_MDL_NAME_LBCS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="${RETRODATAPATH}/GDASENKF"
      elif [[ ${EXTRN_MDL_NAME_LBCS} == "FV3GFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="${RETRODATAPATH}/FV3GFS"
      fi
    else
      EXTRN_MDL_SOURCE_BASEDIR_ICS=${RETRODATAPATH}/gfs/0p25deg/grib2
      EXTRN_MDL_SOURCE_BASEDIR_LBCS=${RETRODATAPATH}/gfs/0p25deg/grib2
    fi

    OBSPATH=${RETRODATAPATH}/obs_rap
    OBSPATH_NSSLMOSIAC=${RETRODATAPATH}/reflectivity
    OBSPATH_PM=${RETRODATAPATH}/pm
    LIGHTNING_ROOT=${RETRODATAPATH}/lightning
    ENKF_FCST=${RETRODATAPATH}/enkf/atm
    AIRCRAFT_REJECT=${RETRODATAPATH}/amdar_reject_lists
    SFCOBS_USELIST=${RETRODATAPATH}/mesonet_uselists
    SST_ROOT=${RETRODATAPATH}/highres_sst
    GVF_ROOT=${RETRODATAPATH}/gvf/grib2
    IMSSNOW_ROOT=${RETRODATAPATH}/snow/ims96/grib2
    RAPHRR_SOIL_ROOT=${RETRODATAPATH}/rap_hrrr_soil
    FIRE_RAVE_DIR=${RETRODATAPATH}/RAVE_RAW
  fi
  if [[ $MACHINE == "orion" ]] || [[ $MACHINE == "hercules" ]] ; then
    if [[ ${DO_ENSEMBLE} == "TRUE" ]]; then
      if [[ ${EXTRN_MDL_NAME_ICS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="/work/noaa/wrfruc/mhu/rrfs/data/enkf/atm"
      elif [[ ${EXTRN_MDL_NAME_ICS} == "FV3GFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="/work/noaa/wrfruc/mhu/rrfs/data/gfs/0p25deg/grib2"
      fi
      if [[ ${EXTRN_MDL_NAME_LBCS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="/work/noaa/wrfruc/mhu/rrfs/data/enkf/atm"
      elif [[ ${EXTRN_MDL_NAME_LBCS} == "FV3GFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="/work/noaa/wrfruc/mhu/rrfs/data/gfs/0p25deg/grib2"
      fi
    else
      EXTRN_MDL_SOURCE_BASEDIR_ICS=/work/noaa/wrfruc/mhu/rrfs/data/gfs/0p25deg/grib2
      EXTRN_MDL_SOURCE_BASEDIR_LBCS=/work/noaa/wrfruc/mhu/rrfs/data/gfs/0p25deg/grib2
    fi
    OBSPATH=/work/noaa/wrfruc/mhu/rrfs/data/obs_rap
    OBSPATH_NSSLMOSIAC=/work/noaa/wrfruc/mhu/rrfs/data/reflectivity
    LIGHTNING_ROOT=/work/noaa/wrfruc/mhu/rrfs/data/lightning
    ENKF_FCST=/work/noaa/wrfruc/mhu/rrfs/data/enkf/atm
    AIRCRAFT_REJECT="/work/noaa/wrfruc/mhu/rrfs/data/amdar_reject_lists"
    SFCOBS_USELIST="/work/noaa/wrfruc/mhu/rrfs/data/mesonet_uselists"
    SST_ROOT="/work/noaa/wrfruc/mhu/rrfs/data/highres_sst"
    GVF_ROOT="/work/noaa/wrfruc/mhu/rrfs/data/gvf/grib2"
    IMSSNOW_ROOT="/work/noaa/wrfruc/mhu/rrfs/data/snow/ims96/grib2"
  fi
  if [[ $MACHINE == "wcoss2" ]] ; then
    RETRODATAPATH="/lfs/h2/emc/lam/noscrub/emc.lam/rrfs_retro_data"
    if [[ ${DO_ENSEMBLE} == "TRUE" ]]; then
      if [[ ${EXTRN_MDL_NAME_ICS} == "GEFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="${RETRODATAPATH}/GEFS/dsg"
      elif [[ ${EXTRN_MDL_NAME_ICS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="${RETRODATAPATH}/enkf/atm"
      elif [[ ${EXTRN_MDL_NAME_ICS} == "FV3GFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="${RETRODATAPATH}/gfs/0p25deg/grib2"
      fi
      if [[ ${EXTRN_MDL_NAME_LBCS} == "GEFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="${RETRODATAPATH}/GEFS/dsg"
      elif [[ ${EXTRN_MDL_NAME_LBCS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="${RETRODATAPATH}/enkf/atm"
      elif [[ ${EXTRN_MDL_NAME_LBCS} == "FV3GFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="${RETRODATAPATH}/gfs/0p25deg/grib2"
      fi
    else
      EXTRN_MDL_SOURCE_BASEDIR_ICS=${RETRODATAPATH}/gfs
      EXTRN_MDL_SOURCE_BASEDIR_LBCS=${RETRODATAPATH}/gfs
    fi
    OBSPATH=${RETRODATAPATH}/obs_rap
    OBSPATH_NSSLMOSIAC=${RETRODATAPATH}/reflectivity/upperair/mrms/conus/MergedReflectivityQC/
    LIGHTNING_ROOT=${RETRODATAPATH}/lightning
    ENKF_FCST=${RETRODATAPATH}/enkf/atm
    AIRCRAFT_REJECT="${RETRODATAPATH}/amdar_reject_lists"
    SFCOBS_USELIST="${RETRODATAPATH}/mesonet_uselists"
    SST_ROOT="${RETRODATAPATH}/highres_sst"
    GVF_ROOT="${RETRODATAPATH}/gvf/grib2"
    IMSSNOW_ROOT="${RETRODATAPATH}/snow/ims96/grib2"
    RAPHRR_SOIL_ROOT="/lfs/h2/emc/lam/noscrub/emc.lam/rrfs_retro_data/rap_hrrr_soil"
  fi
fi

# clean system
if [[ $DO_RETRO == "TRUE" ]] ; then
  CLEAN_OLDPROD_HRS="720"
  CLEAN_OLDLOG_HRS="720"
  CLEAN_OLDRUN_HRS="720"
  CLEAN_OLDFCST_HRS="720"
  CLEAN_OLDSTMPPOST_HRS="720"
  CLEAN_NWGES_HRS="720"
  if [[ $LBCS_ICS_ONLY == "TRUE" ]]; then
    CLEAN_OLDRUN_HRS="7777"
    CLEAN_OLDFCST_HRS="7777"
  fi  
fi

