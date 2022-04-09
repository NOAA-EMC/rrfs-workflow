
OBSPATH_NSSLMOSIAC=/public/data/radar/nssl/mrms/conus
FFG_DIR=/public/data/grids/ncep/ffg/grib2
AIRCRAFT_REJECT="/home/amb-verif/acars_RR/amdar_reject_lists"
SFCOBS_USELIST="/lfs4/BMC/amb-verif/rap_ops_mesonet_uselists"
SST_ROOT="/lfs4/BMC/public/data/grids/ncep/sst/0p083deg/grib2"
GVF_ROOT="/public/data/sat/ncep/viirs/gvf/grib2"

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
  LIGHTNING_ROOT=/scratch2/BMC/public/data/lightning
  ENKF_FCST=/scratch1/NCEPDEV/rstprod/com/gfs/prod
fi

if [[ $MACHINE == "wcoss_dell_p3" ]] ; then
  EXTRN_MDL_SOURCE_BASEDIR_ICS=/gpfs/dell1/nco/ops/com/gfs/prod
  EXTRN_MDL_SOURCE_BASEDIR_LBCS=/gpfs/dell1/nco/ops/com/gfs/prod
  OBSPATH=/gpfs/hps/nco/ops/com/rap/prod
  OBSPATH_NSSLMOSIAC=/gpfs/dell1/nco/ops/dcom/prod/ldmdata/obs/upperair/mrms/conus/MergedReflectivityQC
  ENKF_FCST=/gpfs/dell1/nco/ops/com/gfs/prod
  SST_ROOT=/gpfs/dell1/nco/ops/com/gfs/prod
  GVF_ROOT=/gpfs/dell1/nco/ops/dcom/prod/viirs
  IMSSNOW_ROOT=/gpfs/hps/nco/ops/com/rap/prod
fi

# set up for retrospective test:
if [[ $DO_RETRO == "TRUE" ]] ; then

  if [[ $MACHINE == "jet" ]] ; then

    if [[ ${DO_ENSEMBLE} == "TRUE" ]]; then
       if [[ ${EXTRN_MDL_NAME_ICS} == "GEFS" ]]; then
         EXTRN_MDL_SOURCE_BASEDIR_ICS="/mnt/lfs4/HFIP/gsihyb/Chunhua.Zhou/data/GEFS/public/pgrb2"
       elif [[ ${EXTRN_MDL_NAME_ICS} == "HRRRDAS" ]]; then
         EXTRN_MDL_SOURCE_BASEDIR_ICS="/mnt/lfs4/HFIP/gsihyb/Chunhua.Zhou/data/HRRRE"
       fi
       EXTRN_MDL_SOURCE_BASEDIR_LBCS="/mnt/lfs4/HFIP/gsihyb/Chunhua.Zhou/data/GEFS/public/pgrb2"
       OBSPATH=/mnt/lfs4/HFIP/gsihyb/Chunhua.Zhou/data/obs
    else
#        EXTRN_MDL_SOURCE_BASEDIR_ICS=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/hrrr/conus/wrfnat/grib2
#        EXTRN_MDL_SOURCE_BASEDIR_LBCS=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/rap/full/wrfnat/grib2
       EXTRN_MDL_SOURCE_BASEDIR_ICS=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/gfs/0p25deg/grib2
       EXTRN_MDL_SOURCE_BASEDIR_LBCS=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/gfs/0p25deg/grib2
       OBSPATH=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/obs_rap
    fi

    OBSPATH_NSSLMOSIAC=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/reflectivity
    LIGHTNING_ROOT=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/lightning
    ENKF_FCST=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/enkf/atm
    AIRCRAFT_REJECT="/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/amdar_reject_lists"
    SFCOBS_USELIST="/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/mesonet_uselists"
    SST_ROOT="/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/highres_sst"
    GVF_ROOT="/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/gvf/grib2"
    IMSSNOW_ROOT="/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/snow/ims96/grib2"
  fi
  if [[ $MACHINE == "hera" ]] ; then

    if [[ ${DO_ENSEMBLE} == "TRUE" ]]; then
      if [[ ${EXTRN_MDL_NAME_ICS} == "GEFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="/scratch1/BMC/wrfruc/chunhua/data/GEFS/pgrb2"
      elif [[ ${EXTRN_MDL_NAME_ICS} == "HRRRDAS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="/scratch1/BMC/wrfruc/chunhua/data/HRRRDAS"
      elif [[ ${EXTRN_MDL_NAME_ICS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_ICS="/scratch1/BMC/wrfruc/chunhua/data/GDASENKF"
      fi
      if [[ ${EXTRN_MDL_NAME_LBCS} == "GEFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="/scratch1/BMC/wrfruc/chunhua/data/GEFS/pgrb2"
      elif [[ ${EXTRN_MDL_NAME_LBCS} == "GDASENKF" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="/scratch1/BMC/wrfruc/chunhua/data/GDASENKF"
      elif [[ ${EXTRN_MDL_NAME_LBCS} == "FV3GFS" ]]; then
        EXTRN_MDL_SOURCE_BASEDIR_LBCS="/scratch1/BMC/wrfruc/chunhua/data/FV3GFS"
      fi
      OBSPATH="/scratch1/BMC/wrfruc/chunhua/data/obs"
    else
#    EXTRN_MDL_SOURCE_BASEDIR_ICS=/scratch2/BMC/zrtrr/rli/data/hrrr/conus/wrfnat/grib2
#    EXTRN_MDL_SOURCE_BASEDIR_LBCS=/scratch2/BMC/zrtrr/rli/data/rap/full/wrfnat/grib2
      EXTRN_MDL_SOURCE_BASEDIR_ICS=/scratch2/BMC/zrtrr/rli/data/gfs/0p25deg/grib2
      EXTRN_MDL_SOURCE_BASEDIR_LBCS=/scratch2/BMC/zrtrr/rli/data/gfs/0p25deg/grib2
      OBSPATH=/scratch2/BMC/zrtrr/rli/data/obs_rap
    fi

    OBSPATH_NSSLMOSIAC=/scratch2/BMC/zrtrr/rli/data/reflectivity
    LIGHTNING_ROOT=/scratch2/BMC/zrtrr/rli/data/lightning
    ENKF_FCST=/scratch2/BMC/zrtrr/rli/data/enkf/atm
    AIRCRAFT_REJECT="/scratch2/BMC/zrtrr/rli/data/amdar_reject_lists"
    SFCOBS_USELIST="/scratch2/BMC/zrtrr/rli/data/mesonet_uselists"
    SST_ROOT="/scratch2/BMC/zrtrr/rli/data/highres_sst"
    GVF_ROOT="/scratch2/BMC/zrtrr/rli/data/gvf/grib2"
    IMSSNOW_ROOT="/scratch2/BMC/zrtrr/rli/data/snow/ims96/grib2"
  fi
  if [[ $MACHINE == "orion" ]] ; then
    EXTRN_MDL_SOURCE_BASEDIR_ICS=/work/noaa/wrfruc/mhu/rrfs/data/gfs
    EXTRN_MDL_SOURCE_BASEDIR_LBCS=/work/noaa/wrfruc/mhu/rrfs/data/gfs
    OBSPATH=/work/noaa/wrfruc/mhu/rrfs/data/obs_rap
  fi
fi

# clean system
if [[ $DO_RETRO == "TRUE" ]] ; then
  CLEAN_OLDPROD_HRS="240"
  CLEAN_OLDLOG_HRS="240"
  CLEAN_OLDRUN_HRS="240"
  CLEAN_OLDFCST_HRS="240"
  CLEAN_OLDSTMPPOST_HRS="240"
  CLEAN_NWGES_HRS="240"
  if [[ $LBCS_ICS_ONLY == "TRUE" ]]; then
    CLEAN_OLDRUN_HRS="7777"
    CLEAN_OLDFCST_HRS="7777"
  fi
fi
