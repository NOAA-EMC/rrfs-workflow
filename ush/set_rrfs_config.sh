
#  setup for real-time runs on JET
OBSPATH_NSSLMOSIAC=/public/data/radar/nssl/mrms/conus
FFG_DIR=/public/data/grids/ncep/ffg/grib2
AIRCRAFT_REJECT="/home/role.amb-verif/acars_RR/amdar_reject_lists"
SFCOBS_USELIST="/lfs4/BMC/amb-verif/rap_ops_mesonet_uselists"
SST_ROOT="/lfs4/BMC/public/data/grids/ncep/sst/0p083deg/grib2"
GVF_ROOT="/public/data/sat/ncep/viirs/gvf/grib2"
FVCOM_DIR="/mnt/lfs4/BMC/public/data/grids/glerl/owaq"
FVCOM_FILE="tsfc_fv3grid"
OBSPATH_PM="/lfs4/BMC/public/data/airnow/hourly_aqobs"
BERROR_FN="rrfs_glb_berror.l127y770.f77"
if [[ $GLMFED_DATA_MODE == "FULL" ]] ; then
  GLMFED_EAST_ROOT="/public/data/sat/nesdis/goes-east/glm/full-disk"
  GLMFED_WEST_ROOT="/public/data/sat/nesdis/goes-east/glm/full-disk"
else
  GLMFED_EAST_ROOT="/public/data/sat/noaaport/goes-east/glm/tiled"
  GLMFED_WEST_ROOT="/public/data/sat/noaaport/goes-west/glm/tiled"
fi


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
  OBSPATH=/lfs/h1/ops/prod/com/obsproc/v1.2
  OBSPATH_NSSLMOSIAC=/lfs/h1/ops/prod/dcom/ldmdata/obs/upperair/mrms/conus/MergedReflectivityQC
  ENKF_FCST=/lfs/h1/ops/prod/com/gfs/v16.3
  SST_ROOT=/lfs/h1/ops/prod/com/nsst/v1.2
  GVF_ROOT=/lfs/h1/ops/prod/dcom/viirs
  IMSSNOW_ROOT=/lfs/h1/ops/prod/com/obsproc/v1.2
  FIRE_RAVE_DIR=/lfs/h1/ops/prod/dcom
  FVCOM_DIR="/lfs/h1/ops/prod/com/nosofs/v3.5"
  FVCOM_FILE="fvcom"
  FVCOM_DIR="/lfs/h2/emc/lam/noscrub/emc.lam/OWAQ_fv3"
  FVCOM_FILE="tsfc_fv3grid"
  RAPHRRR_SOIL_ROOT="/lfs/h1/ops/prod/com"
  GLMFED_EAST_ROOT="/lfs/h1/ops/prod/dcom/ldmdata/obs/GOES-16/GLM/tiles"
  GLMFED_WEST_ROOT="/lfs/h1/ops/prod/dcom/ldmdata/obs/GOES-17/GLM/tiles"
  AIRCRAFT_REJECT="/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS/gsi"
  SFCOBS_USELIST="/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS/gsi"
  if [[ $OBSTYPE_SOURCE == "rrfs" ]]; then
    OBSPATH=/lfs/h2/emc/lam/noscrub/emc.lam/obsproc.DATA/CRON/rrfs/com/obsproc/v1.0
    IMSSNOW_ROOT=/lfs/h2/emc/lam/noscrub/emc.lam/obsproc.DATA/CRON/rrfs/com/obsproc/v1.0
  fi
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
    if [[ $GLMFED_DATA_MODE == "FULL" ]] ; then
      GLMFED_EAST_ROOT=${RETRODATAPATH}/sat/nesdis/goes-east/glm/full-disk
      GLMFED_WEST_ROOT=${RETRODATAPATH}/sat/nesdis/goes-east/glm/full-disk
    else
      GLMFED_EAST_ROOT=${RETRODATAPATH}/sat/noaaport/goes-east/glm/tiled
      GLMFED_WEST_ROOT=${RETRODATAPATH}/sat/noaaport/goes-west/glm/tiled
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
    RAPHRRR_SOIL_ROOT=${RETRODATAPATH}/rap_hrrr_soil
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
    GLMFED_EAST_ROOT=${RETRODATAPATH}/sat/nesdis/goes-east/glm/full-disk
    GLMFED_WEST_ROOT=${RETRODATAPATH}/sat/nesdis/goes-east/glm/full-disk
    ENKF_FCST=${RETRODATAPATH}/enkf/atm
    AIRCRAFT_REJECT=${RETRODATAPATH}/amdar_reject_lists
    SFCOBS_USELIST=${RETRODATAPATH}/mesonet_uselists
    SST_ROOT=${RETRODATAPATH}/highres_sst
    GVF_ROOT=${RETRODATAPATH}/gvf/grib2
    IMSSNOW_ROOT=${RETRODATAPATH}/snow/ims96/grib2
    RAPHRRR_SOIL_ROOT=${RETRODATAPATH}/rap_hrrr_soil
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
    RAPHRRR_SOIL_ROOT="/work2/noaa/wrfruc/murdzek/RRFS_input_data/rap_hrrr_soil"
  fi
  if [[ $MACHINE == "wcoss2" ]] ; then
  # for winter 2022  
    #RETRODATAPATH="/lfs/h2/emc/lam/noscrub/emc.lam/rrfs_retro_data"
  # for spring 2023  
 #   RETRODATAPATH="/lfs/h2/emc/lam/noscrub/donald.e.lippi/rrfs-stagedata"
  #for Feb 2022
#    RETRODATAPATH="/lfs/h2/emc/da/noscrub/donald.e.lippi/rrfs-stagedata"
  # for Jan 2024
    RETRODATAPATH="/lfs/h3/emc/rrfstemp/donald.e.lippi/rrfs-stagedata"
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
      EXTRN_MDL_SOURCE_BASEDIR_ICS=${RETRODATAPATH}/gfs/0p25deg/grib2
      EXTRN_MDL_SOURCE_BASEDIR_LBCS=${RETRODATAPATH}/gfs/0p25deg/grib2
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
    RAPHRRR_SOIL_ROOT="${RETRODATAPATH}/rap_hrrr_soil"
    GLMFED_EAST_ROOT="${RETRODATAPATH}/sat/nesdis/goes-east/glm/full-disk"
    GLMFED_WEST_ROOT="${RETRODATAPATH}/sat/nesdis/goes-east/glm/full-disk"
    FIRE_RAVE_DIR=${RETRODATAPATH}/RAVE_RAW
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

