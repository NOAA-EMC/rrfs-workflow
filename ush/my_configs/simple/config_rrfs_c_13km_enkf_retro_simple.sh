MACHINE="wcoss2"
version="v0.8.6"
#RESERVATION="rrfsens"
EXPT_BASEDIR="/lfs/h3/emc/lam/noscrub/hui.liu/runs_co13km/rrfs.${version}"
EXPT_SUBDIR="rrfs_co13km_enkf"

PREDEF_GRID_NAME=RRFS_CONUS_13km
#PREDEF_GRID_NAME=GSD_RAP13km

. set_rrfs_config_general.sh

DO_ENSEMBLE="TRUE"

#DO_ENSFCST="TRUE"
#DO_DACYCLE="TRUE"
#DO_SURFACE_CYCLE="TRUE"

DO_SPINUP="FALSE"
DO_SAVE_DA_OUTPUT="FALSE"
DO_POST_SPINUP="FALSE"    #rui
DO_POST_PROD="FALSE"      #rui

DO_RETRO="TRUE"
DO_NONVAR_CLDANAL="FALSE"
#DO_ENVAR_RADAR_REF="TRUE"
DO_SMOKE_DUST="FALSE"
DO_PM_DA="FALSE"

#DO_REFL2TTEN="FALSE"
#RADARREFL_TIMELEVEL=(0)
#FH_DFI_RADAR="0.0,0.25,0.5"
#DO_SOIL_ADJUST="TRUE"
#DO_RADDA="FALSE"
#DO_BUFRSND="TRUE"
#USE_FVCOM="TRUE"
#PREP_FVCOM="TRUE"

DO_GLM_FED_DA="FALSE"
GLMFED_DATA_MODE="FULL"  # retros 20220608-now use FULL; retros 20230714-now and real-time on Jet use FULL or TILES
PREP_MODEL_FOR_FED="TRUE" # adds field to ens restart files to be used by control member EnVar

USE_CLM="TRUE"
DO_PARALLEL_PRDGEN="FALSE"
DO_GSIDIAG_OFFLINE="FALSE"

DO_ENS_BLENDING="FALSE"

if [[ ${DO_ENS_BLENDING} == "TRUE" ]] ; then
  ENS_BLENDING_LENGTHSCALE=960
  BLEND="TRUE"          # TRUE:  Blend RRFS and GDAS EnKF
                      # FALSE: Don't blend, activate cold2warm start only, and use either GDAS or RRFS
  USE_HOST_ENKF="TRUE"  # TRUE:  Final EnKF (u,v,t,delp,sphum) will be GDAS (no blending)
                      # FALSE: Final EnKF (u,v,t,delp,sphum) will be RRFS (no blending)
fi

if [[ ${DO_ENSFCST} == "TRUE" ]] ; then
  EXPT_SUBDIR="rrfs_conus13_enfcst"
  DO_SPINUP="FALSE"
  DO_SAVE_DA_OUTPUT="FALSE"
  DO_NONVAR_CLDANAL="FALSE"
  DO_POST_PROD="TRUE"
fi

EXTRN_MDL_ICS_OFFSET_HRS="30"
EXTRN_MDL_LBCS_OFFSET_HRS="6"
LBC_SPEC_INTVL_HRS="1"
BOUNDARY_LEN_HRS="12"
BOUNDARY_PROC_GROUP_NUM="4"

EXTRN_MDL_NAME_ICS="GEFS"
EXTRN_MDL_NAME_LBCS="GEFS"
FV3GFS_FILE_FMT_ICS="grib2"
FV3GFS_FILE_FMT_LBCS="grib2"

# retro period:
DATE_FIRST_CYCL="20240506"
DATE_LAST_CYCL="20240512"
CYCL_HRS=( "00" "12" )
CYCL_HRS_SPINSTART=("06" "18")
CYCL_HRS_PRODSTART=("00" "12")
if [[ ${DO_ENSFCST} == "TRUE" ]] ; then
  CYCL_HRS_STOCH=("00" "06" "12" "18")
fi
#CYCL_HRS_RECENTER=("19")
CYCLEMONTH="05"
CYCLEDAY="6-12"

STARTYEAR=${DATE_FIRST_CYCL:0:4}
STARTMONTH=${DATE_FIRST_CYCL:4:2}
STARTDAY=${DATE_FIRST_CYCL:6:2}
STARTHOUR="00"
ENDYEAR=${DATE_LAST_CYCL:0:4}
ENDMONTH=${DATE_LAST_CYCL:4:2}
ENDDAY=${DATE_LAST_CYCL:6:2}
ENDHOUR="23"

PREEXISTING_DIR_METHOD="upgrade"      # or "rename"
INITIAL_CYCLEDEF="${DATE_FIRST_CYCL}0000 ${DATE_LAST_CYCL}2300 12:00:00"
BOUNDARY_CYCLEDEF="${DATE_FIRST_CYCL}0000 ${DATE_LAST_CYCL}2300 06:00:00"
PROD_CYCLEDEF="${DATE_FIRST_CYCL}0000 ${DATE_LAST_CYCL}2300 01:00:00"
PRODLONG_CYCLEDEF="00 01 01 01 2100 *"

#RECENTER_CYCLEDEF="00 19 * 10 2022 *"
ARCHIVE_CYCLEDEF="${DATE_FIRST_CYCL}1500 ${DATE_LAST_CYCL}2300 24:00:00"

if [[ ${DO_ENSFCST} == "TRUE" ]] ; then
  BOUNDARY_LEN_HRS="36"
  LBC_SPEC_INTVL_HRS="3"
  DO_SPINUP="FALSE"
  INITIAL_CYCLEDEF="00 01 01 01 2100 *"
  BOUNDARY_CYCLEDEF="${DATE_FIRST_CYCL}0000 ${DATE_LAST_CYCL}2300 06:00:00"
  PROD_CYCLEDEF="${DATE_FIRST_CYCL}0000 ${DATE_LAST_CYCL}2300 06:00:00"
  PRODLONG_CYCLEDEF="00 01 01 01 2100 *"
  RECENTER_CYCLEDEF="${DATE_FIRST_CYCL}0000 ${DATE_LAST_CYCL}2300 06:00:00"
fi

if [[ $DO_SPINUP == "TRUE" ]] ; then
  SPINUP_CYCLEDEF="${DATE_FIRST_CYCL}0600 ${DATE_LAST_CYCL}2300 12:00:00"
fi
if [[ $DO_SAVE_DA_OUTPUT == "TRUE" ]] ; then
  SAVEDA_CYCLEDEF="${DATE_FIRST_CYCL}1200 ${DATE_LAST_CYCL}2300 06:00:00"
fi

FCST_LEN_HRS="1"
FCST_LEN_HRS_SPINUP="1"
POSTPROC_LEN_HRS="1"
#FCST_LEN_HRS_CYCLES=(48 18 18 18 18 18 48 18 18 18 18 18 48 18 18 18 18 18 48 18 18 18 18 18)
for i in {0..23}; do FCST_LEN_HRS_CYCLES[$i]=1; done
for i in {0..23..6}; do FCST_LEN_HRS_CYCLES[$i]=1; done
if [[ ${DO_ENSFCST} == "TRUE" ]]; then
  for i in {0..23..06}; do FCST_LEN_HRS_CYCLES[$i]=36; done 
  FCST_LEN_HRS="36"
  POSTPROC_LEN_HRS="36"
  BOUNDARY_PROC_GROUP_NUM="8"
fi

DA_CYCLE_INTERV="1"
RESTART_INTERVAL="1"
RESTART_INTERVAL_LONG="1"
netcdf_diag=.true.
binary_diag=.false.
WRTCMP_output_file="netcdf_parallel"
WRTCMP_ideflate="1"
WRTCMP_quantize_nsd="18"

# set up post
OUTPUT_FH="1 -1"

WTIME_RUN_FCST="00:30:00"
WTIME_MAKE_LBCS="04:00:00"

envir="para"
ARCHIVEDIR="/1year/BMC/wrfruc/rrfs_dev1"
NCL_REGION="conus"
MODEL="rrfs_b"

if [[ ${DO_ENSEMBLE}  == "TRUE" ]]; then
   NUM_ENS_MEMBERS=30
#   DO_ENSCONTROL="TRUE"
   DO_GSIOBSERVER="TRUE"
   DO_ENKFUPDATE="TRUE"
#   DO_RECENTER="TRUE"
   DO_ENS_GRAPHICS="FALSE"
   DO_ENKF_RADAR_REF="FALSE"
   DO_ENSPOST="FALSE"
   DO_ENSINIT="TRUE"

   RADAR_REF_THINNING="2"
   ARCHIVEDIR="/5year/BMC/wrfruc/rrfs_enkf"
   CLEAN_OLDFCST_HRS="12"
   CLEAN_OLDSTMPPOST_HRS="12"
   cld_bld_hgt=0.0
   l_precip_clear_only=.true.
   write_diag_2=.true.

   START_TIME_SPINUP="00:30:00"
   NUM_ENS_MEMBERS_FCST=5   #rui
   if [[ ${DO_ENSFCST} == "TRUE" ]] ; then
     NUM_ENS_MEMBERS=${NUM_ENS_MEMBERS_FCST}
     WTIME_RUN_FCST="01:45:00"
     WTIME_MAKE_LBCS="01:30:00"
     DO_ENSFCST_MULPHY="TRUE"
     DO_SPP="TRUE"
     DO_SPPT="FALSE"
     DO_SKEB="FALSE"
     SPPT_MAG="0.5"
     DO_LSM_SPP="TRUE"
     DO_RECENTER="TRUE"
   fi

   CLEAN_OLDFCST_HRS="48"
   CLEAN_OLDSTMPPOST_HRS="48"
fi

SPPINT=36
LNDPINT=180

RUN_ensctrl="rrfs"
RUN="enkfrrfs"
TAG="c13e"
if [[ ${DO_ENSFCST} == "TRUE" ]] ; then
  RUN="refs"
  TAG="c13ef"
fi

. set_rrfs_config.sh

#STMP="${EXPT_BASEDIR}/stmp_enkf"   # input files.
#PTMP="${EXPT_BASEDIR}"             # output files.
#NWGES="${EXPT_BASEDIR}/nwges"      # save boundary, cold initial, restart files

STMP="/lfs/h2/emc/stmp/hui.liu/runs_co13km/stmp_enkf"   # input files.
PTMP="/lfs/h2/emc/ptmp/hui.liu/runs_co13km"             # output files.
NWGES="/lfs/h2/emc/ptmp/hui.liu/runs_co13km/nwges"      # save boundary, cold initial, restart files

if [[ ${DO_ENSFCST} == "TRUE" ]] ; then
  STMP="${EXPT_BASEDIR}/stmp_enfcst"
  PTMP="${EXPT_BASEDIR}"       
  NWGES="${EXPT_BASEDIR}/nwges"
fi
#----------------------------------
ENSCTRL_STMP="/lfs/h2/emc/stmp/hui.liu/runs_co13km/stmp" 
ENSCTRL_PTMP="/lfs/h2/emc/ptmp/hui.liu/runs_co13km" 
ENSCTRL_NWGES="/lfs/h2/emc/ptmp/hui.liu/runs_co13km/nwges" 

#ENSCTRL_STMP="${EXPT_BASEDIR}/stmp"
#ENSCTRL_PTMP="${EXPT_BASEDIR}"
#ENSCTRL_NWGES="${EXPT_BASEDIR}/nwges"
