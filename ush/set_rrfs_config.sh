
OBSPATH_NSSLMOSIAC=/public/data/radar/nssl/mrms/conus
FFG_DIR=/public/data/grids/ncep/ffg/grib2
AIRCRAFT_REJECT="/home/amb-verif/acars_RR/amdar_reject_lists"
SFCOBS_USELIST="/lfs4/BMC/amb-verif/rap_ops_mesonet_uselists"

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

# set up for retrospective test:
if [[ $DO_RETRO == "TRUE" ]] ; then

  if [[ $MACHINE == "jet" ]] ; then
#    EXTRN_MDL_SOURCE_BASEDIR_ICS=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/hrrr/conus/wrfnat/grib2
#    EXTRN_MDL_SOURCE_BASEDIR_LBCS=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/rap/full/wrfnat/grib2
    EXTRN_MDL_SOURCE_BASEDIR_ICS=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/gfs/0p25deg/grib2
    EXTRN_MDL_SOURCE_BASEDIR_LBCS=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/gfs/0p25deg/grib2
    OBSPATH=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/obs_rap
    OBSPATH_NSSLMOSIAC=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/reflectivity
    LIGHTNING_ROOT=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/lightning
    ENKF_FCST=/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/enkf/atm
    AIRCRAFT_REJECT="/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/amdar_reject_lists"
    SFCOBS_USELIST="/mnt/lfs4/BMC/wrfruc/Ruifang.Li/data/mesonet_uselists"
  fi
  if [[ $MACHINE == "hera" ]] ; then
#    EXTRN_MDL_SOURCE_BASEDIR_ICS=/scratch2/BMC/zrtrr/rli/data/hrrr/conus/wrfnat/grib2
#    EXTRN_MDL_SOURCE_BASEDIR_LBCS=/scratch2/BMC/zrtrr/rli/data/rap/full/wrfnat/grib2
    EXTRN_MDL_SOURCE_BASEDIR_ICS=/scratch2/BMC/zrtrr/rli/data/gfs/0p25deg/grib2
    EXTRN_MDL_SOURCE_BASEDIR_LBCS=/scratch2/BMC/zrtrr/rli/data/gfs/0p25deg/grib2
    OBSPATH=/scratch2/BMC/zrtrr/rli/data/obs_rap
    OBSPATH_NSSLMOSIAC=/scratch2/BMC/zrtrr/rli/data/reflectivity
    LIGHTNING_ROOT=/scratch2/BMC/zrtrr/rli/data/lightning
    ENKF_FCST=/scratch2/BMC/zrtrr/rli/data/enkf/atm
    AIRCRAFT_REJECT="/scratch2/BMC/zrtrr/rli/data/amdar_reject_lists"
    SFCOBS_USELIST="/scratch2/BMC/zrtrr/rli/data/mesonet_uselists"
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
  if [[ $LBCS_ICS_ONLY == "TRUE" ]]; then
    CLEAN_OLDRUN_HRS="7777"
    CLEAN_OLDFCST_HRS="7777"
  fi
fi
