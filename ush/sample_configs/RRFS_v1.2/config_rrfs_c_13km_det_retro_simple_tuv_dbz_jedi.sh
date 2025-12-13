
# Machine options
MACHINE="wcoss2"
MACHINETYPE="backup"
version="v0.8.6"
ACCOUNT="RRFS-DEV"

# Directory settings
EXPT_BASEDIR="/lfs/h2/emc/da/noscrub/samuel.degelia/rrfs-workflow_radar/rrfs-workflow/expt_dirs/May2024_retro_radar/$version"
EXPT_SUBDIR="rrfs_conus_13km.20251104.mgbf"
STMP="${EXPT_BASEDIR}"
PTMP="${EXPT_BASEDIR}"
NWGES="${EXPT_BASEDIR}/nwges"

PREDEF_GRID_NAME=RRFS_CONUS_13km

. set_rrfs_config_general.sh
. set_rrfs_config_SDL_VDL_MixEn.sh

ACCOUNT=RRFS-DEV
HPSS_ACCOUNT="RRFS-DEV"
QUEUE_DEFAULT="dev"
QUEUE_HPSS="dev_transfer"
QUEUE_FCST="dev"
QUEUE_POST="dev"
QUEUE_PRDGEN="dev"
QUEUE_ANALYSIS="dev"
QUEUE_GRAPHICS="dev"

# JEDI options
DO_IODA_BUFR="TRUE"
DO_JEDIVAR="TRUE"
DA_SYSTEM="JEDI"
DO_DACOLD="FALSE"
DO_DACYCLE="TRUE"
#DO_ENSEMBLE="TRUE"
#DO_ENSFCST="TRUE"
#DO_ENS_BLENDING="TRUE"

# Radar DA options
DO_IODA_MRMS="TRUE"
DO_ENVAR_RADAR_REF="TRUE"
RADARREFL_TIMELEVEL=(0)
FH_DFI_RADAR="0.0,0.25,0.5"

# Other options
DO_SURFACE_CYCLE="FALSE"
DO_SPINUP="FALSE"
DO_SAVE_INPUT="TRUE"
DO_POST_SPINUP="FALSE"
DO_POST_PROD="TRUE"
DO_RETRO="TRUE"
DO_NONVAR_CLDANAL="FALSE"
DO_REFL2TTEN="FALSE"
DO_SMOKE_DUST="FALSE"
EBB_DCYCLE="2"
DO_PM_DA="FALSE"
DO_SOIL_ADJUST="FALSE"
DO_RADDA="FALSE"          # radiance
DO_BUFRSND="FALSE"
USE_FVCOM="FALSE"
PREP_FVCOM="FALSE"
USE_CLM="TRUE"
DO_PARALLEL_PRDGEN="FALSE"
DO_GSIDIAG_OFFLINE="TRUE"
DO_UPDATE_BC="FALSE"
DO_GLM_FED_DA="FALSE"
GLMFED_DATA_MODE="FULL"  # retros 20220608-now use FULL; retros 20230714-now and real-time on Jet use FULL or TILES

EXTRN_MDL_ICS_OFFSET_HRS="6"
LBC_SPEC_INTVL_HRS="1"
EXTRN_MDL_LBCS_OFFSET_HRS="6"
BOUNDARY_LEN_HRS="18"
BOUNDARY_PROC_GROUP_NUM="4"

# retro period:
DATE_FIRST_CYCL="20240506"
DATE_LAST_CYCL="20240512"
CYCL_HRS=( "00" "12" )
CYCL_HRS_SPINSTART=("03" "15")
CYCL_HRS_PRODSTART=("00" "12")
CYCLEMONTH="5"
CYCLEDAY="6-12"
SOIL_SURGERY_time=2024050604    # not used

STARTYEAR=${DATE_FIRST_CYCL:0:4}
STARTMONTH=${DATE_FIRST_CYCL:4:2}
STARTDAY=${DATE_FIRST_CYCL:6:2}
STARTHOUR="00"
ENDYEAR=${DATE_LAST_CYCL:0:4}
ENDMONTH=${DATE_LAST_CYCL:4:2}
ENDDAY=${DATE_LAST_CYCL:6:2}
ENDHOUR="23"

PREEXISTING_DIR_METHOD="upgrade"
INITIAL_CYCLEDEF="${DATE_FIRST_CYCL}0000 ${DATE_LAST_CYCL}2300 12:00:00"
BOUNDARY_CYCLEDEF="${DATE_FIRST_CYCL}0000 ${DATE_LAST_CYCL}2300 12:00:00"
# ----------define long/short fcst intervals ------------------------
PROD_CYCLEDEF="00 01-11,13-23 ${CYCLEDAY} ${CYCLEMONTH} ${STARTYEAR} *"
PRODLONG_CYCLEDEF="00 00-23/12 ${CYCLEDAY} ${CYCLEMONTH} ${STARTYEAR} *"
#
if [[ $DO_SPINUP == "TRUE" ]] ; then
  SPINUP_CYCLEDEF="00 07-08,15-20 ${CYCLEDAY} ${CYCLEMONTH} ${STARTYEAR} *"
fi

FCST_LEN_HRS="3"
FCST_LEN_HRS_SPINUP="1"
#FCST_LEN_HRS_CYCLES=(48 18 18 18 18 18 48 18 18 18 18 18 48 18 18 18 18 18 48 18 18 18 18 18)
for i in {0..23}; do FCST_LEN_HRS_CYCLES[$i]=3; done
for i in {0..23..6}; do FCST_LEN_HRS_CYCLES[$i]=12; done
# set up post ---------------------------------------------

WTIME_RUN_FCST_LONG="06:30:00"
WTIME_RUN_ANALYSIS="00:50:00"

DA_CYCLE_INTERV="1"
RESTART_INTERVAL="1"
RESTART_INTERVAL_LONG="1"
POSTPROC_LEN_HRS="3"
POSTPROC_LONG_LEN_HRS="12"

# 15 min output upto 18 hours
OUTPUT_FH="1 -1"
#OUTPUT_FH="0.0 0.25 0.50 0.75 1.0 1.25 1.50 1.75 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0"
#NFHMAX_HF="12"
#NFHOUT="3"

# ------------------------
USE_RRFSE_ENS="TRUE"           # use enkf output
#USE_RRFSE_ENS="FALSE"         # not use enkf output
#-------------------------

CYCL_HRS_HYB_FV3LAM_ENS=("00" "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "22" "23")

SST_update_hour=01
GVF_update_hour=04
SNOWICE_update_hour=01
netcdf_diag=.true.
binary_diag=.false.
WRTCMP_output_file="netcdf_parallel"
WRTCMP_ideflate="1"
WRTCMP_quantize_nsd="18"

regional_ensemble_option=1      # 1 use GDAS ensemble
#  regional_ensemble_option=5   # 5 use RRFS ensemble from enkf
if [[ ${USE_RRFSE_ENS} == "TRUE" ]]; then
  regional_ensemble_option=5    # 5 for RRFS ensemble
fi

# -------- GEFS, FV3GFS, GDASENKF, etc ---------
EXTRN_MDL_NAME_ICS="FV3GFS"
EXTRN_MDL_NAME_LBCS="FV3GFS"
FV3GFS_FILE_FMT_ICS="grib2"
FV3GFS_FILE_FMT_LBCS="grib2"
EXTRN_MDL_DATE_JULIAN="TRUE"

envir="test"

NET="rrfs"
TAG="c13"

ARCHIVEDIR="/1year/BMC/wrfruc/rrfs_dev1"
NCL_REGION="conus"
MODEL="rrfs"
RUN="rrfs"

. set_rrfs_config.sh

#STMP="/lfs/h2/emc/stmp/$USER/May2024_retro/$version/$EXPT_SUBDIR"
#PTMP="/lfs/h2/emc/ptmp/$USER/May2024_retro/$version/$EXPT_SUBDIR"
#NWGES="/lfs/h2/emc/ptmp/$USER/May2024_retro/$version/$EXPT_SUBDIR/nwges"

#STMP="${EXPT_BASEDIR}/stmp"        # contains input files.
#PTMP="${EXPT_BASEDIR}"
#NWGES="${EXPT_BASEDIR}/nwges"      # boundary, cold initial, restart files
#-------------------------------------------------
if [[ ${regional_ensemble_option} == "5" ]]; then
#-------------------------------------------------
# RRFSE directory contains ensemble restart files for GSI hybrid.
RRFSE_NWGES="/lfs/h3/emc/lam/noscrub/hui.liu/runs_co13km/rrfs.v0.8.6/nwges_enkf"
#RRFSE_NWGES=""

  NUM_ENS_MEMBERS=30     # FV3LAM ensemble size for GSI hybrid analysis
  CYCL_HRS_PRODSTART_ENS=( "07" "19" )
fi
