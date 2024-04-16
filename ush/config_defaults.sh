#
#-----------------------------------------------------------------------
#
# This file sets the experiment's configuration variables (which are
# global shell variables) to their default values.  For many of these
# variables, the valid values that they may take on are defined in the
# file $USHdir/valid_param_vals.sh.
#
#-----------------------------------------------------------------------
#

#
#-----------------------------------------------------------------------
#
# WCOSS Implementation Standards document:
#
#   NCEP Central Operations
#   WCOSS Implementation Standards
#   January 19, 2022
#   Version 11.0.0
#
#-----------------------------------------------------------------------
#
version="0.1.0"
#
#-----------------------------------------------------------------------
#
# mach_doc_start
# Set machine and queue parameters.
#
# MACHINE:
# Machine on which the workflow will run.
#
# MACHINETYPE:
# decide Machine type for wcoss2 (backup or primary)
#
# ACCOUNT:
# The account under which to submit jobs to the queue (project name).
#
# SERVICE_ACCOUNT:
# The account under which to submit non-reservation jobs to the queue.
# Defaults to ACCOUNT if not set.
#
# HPSS_ACCOUNT:
# The account under which to submit non-reservation jobs to the queue.
# Defaults to SERVICE_ACCOUNT if not set.
#
# SCHED:
# The job scheduler to use (e.g. slurm).  Set this to an empty string in
# order for the experiment generation script to set it depending on the
# machine.
#
# WORKFLOW_MANAGER:
# The workflow manager to use (e.g. rocoto). This is set to "rocoto" by
# default. Valid options: "rocoto", "ecflow", or "none"
#
# PARTITION_DEFAULT:
# If using the slurm job scheduler (i.e. if SCHED is set to "slurm"), 
# the default partition to which to submit workflow tasks.  If a task 
# does not have a specific variable that specifies the partition to which 
# it will be submitted (e.g. PARTITION_HPSS, PARTITION_FCST; see below), 
# it will be submitted to the partition specified by this variable.  If 
# this is not set or is set to an empty string, it will be (re)set to a 
# machine-dependent value.  This is not used if SCHED is not set to 
# "slurm".
#
# QUEUE_DEFAULT:
# The default queue or QOS (if using the slurm job scheduler, where QOS
# is Quality of Service) to which workflow tasks are submitted.  If a 
# task does not have a specific variable that specifies the queue to which 
# it will be submitted (e.g. QUEUE_HPSS, QUEUE_FCST; see below), it will 
# be submitted to the queue specified by this variable.  If this is not 
# set or is set to an empty string, it will be (re)set to a machine-
# dependent value.
#
# PARTITION_HPSS:
# If using the slurm job scheduler (i.e. if SCHED is set to "slurm"), 
# the partition to which the tasks that get or create links to external 
# model files [which are needed to generate initial conditions (ICs) and 
# lateral boundary conditions (LBCs)] are submitted.  If this is not set 
# or is set to an empty string, it will be (re)set to a machine-dependent 
# value.  This is not used if SCHED is not set to "slurm".
#
# QUEUE_HPSS:
# The queue or QOS to which the tasks that get or create links to external 
# model files [which are needed to generate initial conditions (ICs) and 
# lateral boundary conditions (LBCs)] are submitted.  If this is not set 
# or is set to an empty string, it will be (re)set to a machine-dependent 
# value.
#
# PARTITION_SFC_CLIMO:
# If using the slurm job scheduler (i.e. if SCHED is set to "slurm"), 
# the partition to which the task that generates the surface climatology
# files is submitted.  If this is not set or set to an empty string, it
# wil be (re)set to a machine-dependent value.  This is not used if SCHED
# is not set to "slurm."
#
# PARTITION_FCST:
# If using the slurm job scheduler (i.e. if SCHED is set to "slurm"), 
# the partition to which the task that runs forecasts is submitted.  If 
# this is not set or set to an empty string, it will be (re)set to a 
# machine-dependent value.  This is not used if SCHED is not set to 
# "slurm".
#
# QUEUE_FCST:
# The queue or QOS to which the task that runs a forecast is submitted.  
# If this is not set or set to an empty string, it will be (re)set to a 
# machine-dependent value.
#
# QUEUE_ANALYSIS:
# The queue or QOS to which the task that runs a analysis is submitted.  
# If this is not set or set to an empty string, it will be (re)set to a 
# machine-dependent value.
#
# PARTITION_PRDGEN:
# If using the slurm job scheduler (i.e. if SCHED is set to "slurm"), 
# the partition to which the task that remaps output grids is submitted.  If 
# this is not set or set to an empty string, it will be (re)set to a 
# machine-dependent value.  This is not used if SCHED is not set to 
# "slurm".
#
# QUEUE_PRDGEN:
# The queue or QOS to which the task that prodgen is submitted.  
# If this is not set or set to an empty string, it will be (re)set to a 
# machine-dependent value.
#
# PARTITION_POST:
# If using the slurm job scheduler (i.e. if SCHED is set to "slurm"), 
# the partition to which the task that upp is submitted.
#
# QUEUE_POST:
# The queue or QOS to which the task that upp is submitted.  
# If this is not set or set to an empty string, it will be (re)set to a 
# machine-dependent value.
#
# RESERVATION:
# The reservation for major tasks.  
#
# RESERVATION_POST:
# The reservation for post tasks.  
#
# mach_doc_end
#
#-----------------------------------------------------------------------
#
MACHINE="BIG_COMPUTER"
MACHINETYPE="primary"
ACCOUNT=""
SERVICE_ACCOUNT=""
HPSS_ACCOUNT=""
RESERVATION=""
RESERVATION_POST=""
SCHED=""
WORKFLOW_MANAGER="rocoto"
PARTITION_DEFAULT=""
QUEUE_DEFAULT=""
PARTITION_HPSS=""
QUEUE_HPSS=""
PARTITION_SFC_CLIMO=""
PARTITION_FCST=""
QUEUE_FCST=""
PARTITION_GRAPHICS=""
QUEUE_GRAPHICS=""
PARTITION_ANALYSIS=""
QUEUE_ANALYSIS=""
PARTITION_PRDGEN=""
QUEUE_PRDGEN=""
PARTITION_POST=""
QUEUE_POST=""
#
#-----------------------------------------------------------------------
#
# Set cron-associated parameters.
#
# USE_CRON_TO_RELAUNCH:
# Flag that determines whether or not to add a line to the user's cron 
# table to call the experiment launch script every CRON_RELAUNCH_INTVL_MNTS 
# minutes.
#
# CRON_RELAUNCH_INTVL_MNTS:
# The interval (in minutes) between successive calls of the experiment
# launch script by a cron job to (re)launch the experiment (so that the
# workflow for the experiment kicks off where it left off).
#
#-----------------------------------------------------------------------
#
USE_CRON_TO_RELAUNCH="FALSE"
CRON_RELAUNCH_INTVL_MNTS="03"
#
#-----------------------------------------------------------------------
#
# dir_doc_start
# Set directories.
#
# EXPT_BASEDIR:
# The base directory in which the experiment directory will be created.  
# If this is not specified or if it is set to an empty string, it will
# default to ${HOMErrfs}/../expt_dirs.  
#
# EXPT_SUBDIR:
# The name that the experiment directory (without the full path) will
# have.  The full path to the experiment directory, which will be contained
# in the variable EXPTDIR, will be:
#
#   EXPTDIR="${EXPT_BASEDIR}/${EXPT_SUBDIR}"
#
# This cannot be empty.  If set to a null string here, it must be set to
# a (non-empty) value in the user-defined experiment configuration file.
#
# dir_doc_end
#
#-----------------------------------------------------------------------
#
EXPT_BASEDIR=""
EXPT_SUBDIR=""
#
#-----------------------------------------------------------------------
#
# COMINgfs:
# The beginning portion of the directory containing files generated by 
# the external model (FV3GFS) that the initial and lateral boundary 
# condition generation tasks need in order to create initial and boundary
# condition files for a given cycle on the native FV3-LAM grid.  For a 
# cycle that starts on the date specified by the variable yyyymmdd 
# (consisting of the 4-digit year followed by the 2-digit month followed
# by the 2-digit day of the month) and hour specified by the variable hh
# (consisting of the 2-digit hour-of-day), the directory in which the 
# workflow will look for the external model files is:
#
#   $COMINgfs/gfs.$yyyymmdd/$hh
#
# FIXLAM_NCO_BASEDIR:
# The base directory containing pregenerated grid, orography, and surface 
# climatology files.  For the pregenerated grid specified by PREDEF_GRID_NAME, 
# these "fixed" files are located in:
#
#   ${FIXLAM_NCO_BASEDIR}/${PREDEF_GRID_NAME}
#
# The workflow scripts will create a symlink in the experiment directory
# that will point to a subdirectory (having the name of the grid being
# used) under this directory.  This variable should be set to a null 
# string in this file, but it can be specified in the user-specified 
# workflow configuration file (EXPT_CONFIG_FN).
#
# STMP:
# The beginning portion of the directory that will contain cycle-dependent
# model input files, symlinks to cycle-independent input files, and raw 
# (i.e. before post-processing) forecast output files for a given cycle.
# For a cycle that starts on the date specified by yyyymmdd and hour 
# specified by hh (where yyyymmdd and hh are as described above) [so that
# the cycle date (cdate) is given by cdate="${yyyymmdd}${hh}"], the 
# directory in which the aforementioned files will be located is:
#
#   $STMP/tmpnwprd/$RUN/$cdate
#
# NET, envir, RUN:
# Variables used in forming the path to the directory that will contain
# the output files from the post-processor (UPP) for a given cycle (see
# definition of PTMP below).  These are defined in the WCOSS Implementation
# Standards document as follows:
#
#   NET:
#   Model name (first level of com directory structure)
#
#   envir:
#   Set to "test" during the initial testing phase, "para" when running
#   in parallel (on a schedule), and "prod" in production.
#
#   RUN:
#   Name of model run (third level of com directory structure).
#
# PTMP:
# The beginning portion of the directory that will contain the output 
# files from the post-processor (UPP) for a given cycle.  For a cycle 
# that starts on the date specified by yyyymmdd and hour specified by hh
# (where yyyymmdd and hh are as described above), the directory in which
# the UPP output files will be placed will be:
# 
#   $PTMP/com/$NET/$envir/$RUN.$yyyymmdd/$hh
#
# NWGES:
# The beginning portion of the directory that will contain the output 
# files from the forecast for a given cycle.  For a cycle 
# that starts on the date specified by yyyymmdd and hour specified by hh
# (where yyyymmdd and hh are as described above), the directory in which
# the forecast output files will be placed will be:
#   $NWGES/$NET/$envir/$RUN.$yyyymmdd/$hh
# 
# Setup default observation locations for data assimilation:
#
#    OBSTYPE_SOURCE: observation file source: rap or rrfs
#    OBSPATH:   observation BUFR file path
#    OBSPATH_NSSLMOSIAC: location of NSSL radar reflectivity 
#    LIGHTNING_ROOT: location of lightning observations
#    GLMFED_[EAST/WEST]_ROOT: location of lightning observations
#    ENKF_FCSTL: location of global ensemble forecast
#    FFG_DIR: location of flash flood guidance for QPF comparison
#
# Setup default locations for global SST and update time:
#   SST_ROOT: locations of global SST
#   SST_update_hour: cycle time for updating SST 
#
# Setup default locations for GVF and update time:
#   GVF_ROOT: locations of GVF observations
#   GVF_update_hour: cycle time for updating GVF 
#
# Setup default locations for IMS snow/ice and update time:
#   IMSSNOW_ROOT: locations of IMS snow/ice observations
#   SNOWICE_update_hour: cycle time for updating snow/ice 
#
# Setup default resource data locations for soil surgery and time:
#   RAPHRRR_SOIL_ROOT: locations of RAP/HRRR forecast netcdf files
#   SOIL_SURGERY_time: cycle time for soil surgery 
#
# Setup default data locations for cycle surface/bias correction coefficient
#   smoke/dust during machine switch and version update
#   CONT_CYCLE_DATA_ROOT: locations of surface, bias correction coefficient files
#
# Setup default locations for FIRE_RRFS files and update time
#  FIRE_RAVE_DIR
#  FIRE_RRFS_ROOT
#  FIRE_RRFS_update_hour
#-----------------------------------------------------------------------
#
COMINgfs="/base/path/of/directory/containing/gfs/input/files"
FIXLAM_NCO_BASEDIR=""
STMP="/base/path/of/directory/containing/model/input/and/raw/output/files"
ENSCTRL_STMP="/base/path/of/directory/containing/model/input/and/raw/output/files"
RRFSE_NWGES_BASEDIR="/base/path/of/directory/containing/model/restart/files"
NET="rrfs"
envir="para"
RUN="experiment_name"
RUN_ensctrl="experiment_name"
TAG="dev_grid"
PTMP="/base/path/of/directory/containing/postprocessed/output/files"
ENSCTRL_PTMP="/base/path/of/directory/containing/postprocessed/output/files"
NWGES="/base/path/of/directory/containing/model/output/files"
ENSCTRL_NWGES="/base/path/of/directory/containing/model/restart/files"
RRFSE_NWGES="/base/path/of/directory/containing/model/output/files"

ARCHIVEDIR="/5year/BMC/wrfruc/rrfs_dev1"
NCARG_ROOT="/apps/ncl/6.5.0-CentOS6.10_64bit_nodap_gnu447"
NCL_HOME="/home/rtrr/RRFS/graphics"
NCL_REGION="conus"
MODEL="NO MODEL CHOSEN"

OBSTYPE_SOURCE="rap"
OBSPATH="/public/data/grids/rap/obs"
OBSPATH_NSSLMOSIAC="/public/data/radar/mrms"
OBSPATH_PM="/mnt/lfs1/BMC/wrfruc/hwang/rrfs_sd/pm"
LIGHTNING_ROOT="/public/data/lightning"
GLMFED_EAST_ROOT="/public/data/sat/nesdis/goes-east/glm/full-disk/"
GLMFED_WEST_ROOT="/public/data/sat/nesdis/goes-east/glm/full-disk/"
ENKF_FCST="/lfs4/BMC/public/data/grids/enkf/atm"
FFG_DIR="/public/data/grids/ncep/ffg/grib2"
SST_ROOT="/lfs4/BMC/public/data/grids/ncep/sst/0p083deg/grib2"
SST_update_hour=99
GVF_ROOT="/public/data/sat/ncep/viirs/gvf/grib2"
GVF_update_hour=99
IMSSNOW_ROOT="/public/data/grids/ncep/snow/ims96/grib2"
SNOWICE_update_hour=99
RAPHRRR_SOIL_ROOT="/mnt/lfs4/BMC/rtwbl/mhu/wcoss/nco/com"
SOIL_SURGERY_time=9999999999
FIRE_RAVE_DIR="/lfs4/BMC/public/data/grids/nesdis/3km_fire_emissions"
FIRE_RRFS_ROOT="/mnt/lfs4/BMC/gsd-fv3-dev/FIRE_RRFS_ROOT"
FIRE_RRFS_update_hour=99
CONT_CYCLE_DATA_ROOT="/lfs/h2/emc/lam/noscrub/emc.lam/nwges"
#
#-----------------------------------------------------------------------
#
# Set workflow environments.
#
# DOT_OR_USCORE:
# Set the sparator character(s) to use in the names of the grid, mosaic,
# and orography fixed files. Ideally, the same separator should be used 
# in the names of these fixed files as the surface climatology fixed files 
# (which always use a "." as the separator), i.e. ideally, DOT_OR_USCORE 
# should be set to "."
#
# RELATIVE_LINK_FLAG:
# How to make links. Relative links by default. Empty string for
# absolute paths in links.
#
#-----------------------------------------------------------------------
#
DOT_OR_USCORE="_"
RELATIVE_LINK_FLAG="--relative"
#
#-----------------------------------------------------------------------
#
# Set file names.
#
# EXPT_CONFIG_FN:
# Name of the user-specified configuration file for the forecast experiment.
#
# RGNL_GRID_NML_FN:
# Name of file containing the namelist settings for the code that generates
# a "ESGgrid" type of regional grid.
#
# FV3_NML_BASE_SUITE_FN:
# Name of Fortran namelist file containing the forecast model's base suite
# namelist, i.e. the portion of the namelist that is common to all physics
# suites.
#
# FV3_NML_YAML_CONFIG_FN:
# Name of YAML configuration file containing the forecast model's namelist
# settings for various physics suites.
#
# FV3_NML_BASE_ENS_FN:
# Name of Fortran namelist file containing the forecast model's base 
# ensemble namelist, i.e. the the namelist file that is the starting point 
# from which the namelist files for each of the enesemble members are
# generated.
#
# DIAG_TABLE_FN:
# Name of a template file that specifies the output fields of the
# forecast model (ufs-weather-model: diag_table) followed by the name
# of the ccpp_phys_suite. Its default value is the name of the file
# that the ufs weather model expects to read in.
#
# FIELD_TABLE_TMPL_FN:
# Name of a template file that specifies the tracers in IC/LBC files of the 
# forecast model (ufs-weather-model: field_table) followed by 
# [dot_ccpp_phys_suite]. Its default value is the name of the file that the 
# ufs weather model expects to read in.
#
# MODEL_CONFIG_TMPL_FN:
# Name of a template file that contains settings and configurations for the 
# NUOPC/ESMF main component (ufs-weather-model: model_config). Its default 
# value is the name of the file that the ufs weather model expects to read in.
#
# UFS_CONFIG_TMPL_FN:
# Name of a template file that contains information about the various UFS 
# components and their run sequence (ufs-weather-model: nems.configure). 
# Its default value is the name of the file that the ufs weather model expects 
# to read in.
#
# FV3_EXEC_FN:
# Name to use for the forecast model executable when it is copied from
# the directory in which it is created in the build step to the executables
# directory (EXECdir; this is set during experiment generation).
#
# WFLOW_XML_FN:
# Name of the rocoto workflow XML file that the experiment generation
# script creates and that defines the workflow for the experiment.
#
# WFLOW_XML_TMPL_FN:
# Name of the template file of the rocoto workflow XML file (WFLOW_XML_FN).
#
# GLOBAL_VAR_DEFNS_FN:
# Name of file (a shell script) containing the defintions of the primary 
# experiment variables (parameters) defined in this default configuration 
# script and in the user-specified configuration as well as secondary 
# experiment variables generated by the experiment generation script.  
# This file is sourced by many scripts (e.g. the J-job scripts corresponding 
# to each workflow task) in order to make all the experiment variables 
# available in those scripts.
#
# EXTRN_MDL_ICS_VAR_DEFNS_FN:
# Name of file (a shell script) containing the defintions of variables 
# associated with the external model from which ICs are generated.  This 
# file is created by the GET_EXTRN_ICS_TN task because the values of the
# variables it contains are not known before this task runs.  The file is
# then sourced by the MAKE_ICS_TN task.
#
# EXTRN_MDL_LBCS_VAR_DEFNS_FN:
# Name of file (a shell script) containing the defintions of variables 
# associated with the external model from which LBCs are generated.  This 
# file is created by the GET_EXTRN_LBCS_TN task because the values of the
# variables it contains are not known before this task runs.  The file is
# then sourced by the MAKE_ICS_TN task.
#
# WFLOW_LAUNCH_SCRIPT_FN:
# Name of the script that can be used to (re)launch the experiment's rocoto
# workflow.
#
# WFLOW_LAUNCH_LOG_FN:
# Name of the log file that contains the output from successive calls to
# the workflow launch script (WFLOW_LAUNCH_SCRIPT_FN).
#
#-----------------------------------------------------------------------
#
EXPT_CONFIG_FN="config.sh"

RGNL_GRID_NML_FN="regional_grid.nml"

DATA_TABLE_FN="data_table"
DIAG_TABLE_FN="diag_table"
FIELD_TABLE_FN="field_table"
FV3_NML_BASE_SUITE_FN="input.nml.FV3"
FV3_NML_YAML_CONFIG_FN="FV3.input.yml"
FV3_NML_BASE_ENS_FN="input.nml.base_ens"
MODEL_CONFIG_FN="model_configure"
UFS_CONFIG_FN="ufs.configure"
FV3_EXEC_FN="ufs_model"
WFLOW_XML_FN="FV3LAM_wflow.xml"

WFLOW_XML_TMPL_FN="FV3LAM_wflow.xml"

GLOBAL_VAR_DEFNS_FN="var_defns.sh"
EXTRN_MDL_ICS_VAR_DEFNS_FN="extrn_mdl_ics_var_defns.sh"
EXTRN_MDL_LBCS_VAR_DEFNS_FN="extrn_mdl_lbcs_var_defns.sh"
WFLOW_LAUNCH_SCRIPT_FN="launch_FV3LAM_wflow.sh"
WFLOW_LAUNCH_LOG_FN="log.launch_FV3LAM_wflow"
#
#-----------------------------------------------------------------------
#
# Set forecast parameters.
#
# DATE_FIRST_CYCL:
# Starting date of the first forecast in the set of forecasts to run.  
# Format is "YYYYMMDD". Note that this does not include the hour-of-day.
#
# DATE_LAST_CYCL:
# Starting date of the last forecast in the set of forecasts to run.
# Format is "YYYYMMDD". Note that this does not include the hour-of-day.
#
# STARTYEAR,STARTMONTH,STARTDAY,STARTHOUR:
# Year,month,day and hour of the first cycle in the set of forecasts to run
#
# ENDYEAR,ENDMONTH,ENDDAY,ENDHOUR:
# Year,month,day and hour of the last cycle in the set of forecasts to run
#
# CYCL_HRS:
# An array containing the hours of the day at which to launch forecasts.
# Forecasts are launched at these hours on each day from DATE_FIRST_CYCL
# to DATE_LAST_CYCL, inclusive.  Each element of this array must be a 
# two-digit string representing an integer that is less than or equal to
# 23, e.g. "00", "03", "12", "23".
#
# CYCL_HRS_SPINSTART:
# An array containing the hours of the day at which the spin up cycle starts.
#
# CYCL_HRS_PRODSTART:
# An array containing the hours of the day at which the product cycle starts,
# from cold start input or from spin-up cycle forcast
#
# CYCL_HRS_PRODSTART_ENS:
# An array containing the hours of the day at which the product cycle starts,
# from cold start input or from spin-up cycle forcast, for the ensemble.
# this is only needed for locating the RRFS ensemble files for the the 
# deterministic hybrid analysis.
#
# CYCL_HRS_RECENTER:
# An array containing the hours of the day at which the ensemble recenter is on
#
# CYCL_HRS_STOCH:
# An array containing the hours of the day at which the stochastics physcis 
# is on this might include: SPPT, SHUM, SKEB, SPP, LSM_SPP
#
# BOUNDARY_LEN_HRS:
# The length of boundary condition for normal forecast, in integer hours.
#
# BOUNDARY_LONG_LEN_HRS:
# The length of boundary condition for long forecast, in integer hours.
#
# BOUNDARY_PROC_GROUP_NUM:
# The number of groups used to run make_lbcs, in integer from 1 to forecast 
# longest hours.
#
# FCST_LEN_HRS:
# The length of each forecast, in integer hours.
#
# FCST_LEN_HRS_SPINUP:
# The length of each forecast in spin up cycles, in integer hours.
#
# FCST_LEN_HRS_CYCLES:
# The length of forecast for each cycle, in integer hours.
# When it empty, all forecast will be FCST_LEN_HRS
#
# DA_CYCLE_INTERV:
# Data assimilation cycle interval, in integer hours for now.
#
# RESTART_INTERVAL:
# Set up frequenency or list of the forecast hours that FV3 should
# generate the restart files.
#
# RESTART_INTERVAL_LONG:
# Set up frequenency or list of the forecast hours that FV3 should
# generate the restart files.
#
# POSTPROC_LEN_HRS:
# The length of post process, in integer hours.
#
# POSTPROC_LONG_LEN_HRS:
# The length of long post process, in integer hours.
#
# CYCL_HRS_HYB_FV3LAM_ENS:
# An array containing the hours of the day at which the GSI hybrid using 
# FV3LAM ensemeble.
#
#-----------------------------------------------------------------------
#
DATE_FIRST_CYCL="YYYYMMDD"
DATE_LAST_CYCL="YYYYMMDD"
STARTYEAR="2022"
STARTMONTH="10"
STARTDAY="21"
STARTHOUR="00"
ENDYEAR="2022"
ENDMONTH="10"
ENDDAY="21"
ENDHOUR="23"
CYCL_HRS=( "HH1" "HH2" )
CYCL_HRS_SPINSTART=( "HH1" "HH2" )
CYCL_HRS_PRODSTART=( "HH1" "HH2" )
CYCL_HRS_PRODSTART_ENS=( "HH1" "HH2" )
CYCL_HRS_RECENTER=( "HH1" "HH2" )
CYCL_HRS_STOCH=( "HH1" "HH2" )
BOUNDARY_LEN_HRS="0"
BOUNDARY_LONG_LEN_HRS="0"
BOUNDARY_PROC_GROUP_NUM="1"
POSTPROC_LEN_HRS="1"
POSTPROC_LONG_LEN_HRS="1"
FCST_LEN_HRS="24"
FCST_LEN_HRS_SPINUP="1"
FCST_LEN_HRS_CYCLES=()

OUTPUT_FH_15min="0 0.25 0.5 0.75 1 1.25 1.5 1.75 2 2.25 2.5 2.75 3 3.25 3.5 3.75 4 4.25 4.5 4.75 5 5.25 5.5 5.75 6 6.25 6.5 6.75 7 7.25 7.5 7.75 8 8.25 8.5 8.75 9 9.25 9.5 9.75 10 10.25 10.5 10.75 11 11.25 11.5 11.75 12 12.25 12.5 12.75 13 13.25 13.5 13.75 14 14.25 14.5 14.75 15 15.25 15.5 15.75 16 16.25 16.5 16.75 17 17.25 17.5 17.75 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60"

DA_CYCLE_INTERV="1"
RESTART_INTERVAL="1 2"
RESTART_INTERVAL_LONG="1 2"
CYCL_HRS_HYB_FV3LAM_ENS=( "99" )
#-----------------------------------------------------------------------
#
# Set cycle definition for each group.  The cycle definition sets the cycle
# time that the group will run. It has two way to set up:
#  1) 00 HHs DDs MMs YYYYs *
#       HHs can be "01-03/01" or "01,02,03" or "*"
#       DDs,MMs can be "01-03" or "01,02,03" or "*"
#       YYYYs can be "2020-2021" or "2020,2021" or "*"
#  2)   start_time(YYYYMMDDHH00) end_time(YYYYMMDDHH00) interval(HH:MM:SS)
#       for example: 202104010000 202104310000 12:00:00
#  The default cycle definition is:
#     "00 01 01 01 2100 *"
#  which will likely never get to run.
#
# AT_START_CYCLEDEF:
# cycle definition for "at start" group
# This group runs: make_grid, make_orog, make_sfc_climo
#
# INITIAL_CYCLEDEF:
# cycle definition for "initial" group
# This group runs get_extrn_ics, make_ics
#
# BOUNDARY_CYCLEDEF:
# cycle definition for "boundary" group
# This group runs: get_extrn_lbcs,make_lbcs
#
# BOUNDARY_LONG_CYCLEDEF:
# cycle definition for "boundary_long" group
# This group runs: get_extrn_lbcs_long,make_lbcs
#
# SPINUP_CYCLEDEF:
# cycle definition for spin-up cycle group
# This group runs: anal_gsi_input_spinup and data process, run_fcst_spinup, 
# run_post_spinup
#
# PROD_CYCLEDEF:
# cycle definition for product cycle group
# This group runs: anal_gsi_input and data process, run_fcst, python_skewt, 
# run_post, run_clean
#
# SAVEDA_CYCLEDEF:
# cycle definition for saving DA output files
# This group runs: save_da_output
#
# RECENTER_CYCLEDEF:
# cycle definition for recenter cycle group
# This group runs: recenter
#
# PRODLONG_CYCLEDEF:
# same as PROD_CYCLEDEF, but for long forecast 
#
# ARCHIVE_CYCLEDEF:
# cycle definition for "archive" group
# This group runs: run_archive
#
#-----------------------------------------------------------------------
#
CYCLEDAY="*"
CYCLEMONTH="*"
AT_START_CYCLEDEF="00 01 01 01 2100 *"
INITIAL_CYCLEDEF="00 01 01 01 2100 *"
BOUNDARY_CYCLEDEF="00 01 01 01 2100 *"
BOUNDARY_LONG_CYCLEDEF="00 01 01 01 2100 *"
SPINUP_CYCLEDEF="00 01 01 01 2100 *"
PROD_CYCLEDEF="00 01 01 01 2100 *"
RECENTER_CYCLEDEF="00 01 01 01 2100 *"
PRODLONG_CYCLEDEF="00 01 01 01 2100 *"
ARCHIVE_CYCLEDEF="00 01 01 01 2100 *"
SAVEDA_CYCLEDEF="00 01 01 01 2100 *"
#
#-----------------------------------------------------------------------
#
# GSI Namelist parameters configurable across differnt applications
# if we need to tune one GSI namelist parameter, we can elevate it to a 
# shell variable and assign value in config.sh and give it a default 
# value in config_default.sh In realtime testing, don't need to regenerate 
# the whole workflow, you can tweak $EXPTDIR/var_defns.sh and 
# $FIX_GSI/gsiparm.anl.sh to make sure the change is expected and then 
# put it back into config.sh and config_default.sh
# (need to follow FORTRAN namelist convetion)
#
#-----------------------------------------------------------------------
#
# &SETUP  and &BKGERR
niter1=50
niter2=50
l_obsprvdiag=.false.
diag_radardbz=.false.
diag_fed=.false.
if_model_fed=.false.
innov_use_model_fed=.false.
write_diag_2=.false.
bkgerr_vs=1.0
bkgerr_hzscl=0.7,1.4,2.80   #no trailing ,
usenewgfsberror=.true.
netcdf_diag=.false.
binary_diag=.true.

# &HYBRID_ENSEMBLE
l_both_fv3sar_gfs_ens=.false.
weight_ens_gfs=1.0
weight_ens_fv3sar=1.0
readin_localization=.true.     #if true, it overwrites the "beta1_inv/ens_h/ens_v" setting
beta1_inv=0.15                 #beata_inv is 1-ensemble_wgt
ens_h=110                      #horizontal localization scale of "Gaussian function=exp(-0.5)" for EnVar (km)
ens_v=3                        #vertical localization scale of "Gaussian function=exp(-0.5)" for EnVar (positive:grids, negative:lnp)
ens_h_radardbz=4.10790         #horizontal localization scale of "Gaussian function=exp(-0.5)" for radardbz EnVar (km)
ens_v_radardbz=-0.30125        #vertical localization scale of "Gaussian function=exp(-0.5)" for radardbz EnVar (positive:grids, negative:lnp)
nsclgrp=1
ngvarloc=1
r_ensloccov4tim=1.0
r_ensloccov4var=1.0
r_ensloccov4scl=1.0
regional_ensemble_option=1     #1 for GDAS ; 5 for FV3LAM ensemble
grid_ratio_fv3=2.0             #fv3 resolution 3km, so analysis=3*2=6km
grid_ratio_ens=3               #if analysis is 3km, then ensemble=3*3=9km. GDAS ensemble is 20km
i_en_perts_io=1                #0 or 1: original file   3: pre-processed ensembles
q_hyb_ens=.false.
ens_fast_read=.false.
CORRLENGTH=300                 #horizontal localization scale of "Gaspari-Cohn function=0" for EnKF (km)
LNSIGCUTOFF=0.5                #vertical localization scale of "Gaspari-Cohn function=0" for EnKF (lnp)
CORRLENGTH_radardbz=18         #horizontal localization scale of "Gaspari-Cohn function=0" for radardbz EnKF (km)
LNSIGCUTOFF_radardbz=0.5       #vertical localization scale of "Gaspari-Cohn function=0" for radardbz EnKF (lnp)
assign_vdl_nml=.false.
vdl_scale=0

# &RAPIDREFRESH_CLDSURF
l_PBL_pseudo_SurfobsT=.false.
l_PBL_pseudo_SurfobsQ=.false.
i_use_2mQ4B=0
i_use_2mT4B=0
i_T_Q_adjust=1
l_rtma3d=.false.
i_precip_vertical_check=0
l_cld_uncertainty=.false.
#  &CHEM 
laeroana_fv3smoke=.false.
berror_fv3_cmaq_regional=.false.
berror_fv3_sd_regional=.false.
#-----------------------------------------------------------------------
# HYBENSMEM_NMIN:
#    Minimum number of ensemble members required a hybrid GSI analysis 
#
HYBENSMEM_NMIN=80
ANAVINFO_FN="anavinfo.rrfs"
ANAVINFO_SD_FN="anavinfo.rrfs_sd"
ANAVINFO_DBZ_FN="anavinfo.rrfs_dbz"
ANAVINFO_CONV_DBZ_FN="anavinfo.rrfs_conv_dbz"
ANAVINFO_CONV_DBZ_FED_FN="anavinfo.rrfs_conv_dbz_fed"
ANAVINFO_DBZ_FED_FN="anavinfo.rrfs_dbz_fed"
ENKF_ANAVINFO_FN="anavinfo.rrfs"
ENKF_ANAVINFO_DBZ_FN="anavinfo.enkf.rrfs_dbz"
CONVINFO_FN="convinfo.rrfs"
CONVINFO_SD_FN="convinfo.rrfs_sd"
BERROR_FN="rap_berror_stats_global_RAP_tune" #under $FIX_GSI
BERROR_SD_FN="berror.rrfs_sd" # for test only
OBERROR_FN="errtable.rrfs"
HYBENSINFO_FN="hybens_info.rrfs"
AIRCRAFT_REJECT=""
SFCOBS_USELIST=""
#
#-----------------------------------------------------------------------
#
# default namelist for nonvar cloud analysis
#
#-----------------------------------------------------------------------
#
cld_bld_hgt=1200.0
l_precip_clear_only=.false.
l_qnr_from_qr=.false.
#
#-----------------------------------------------------------------------
#
# default weighting for control analysis in ensemble recentering
#
#-----------------------------------------------------------------------
#
beta_recenter=1.0
#
#-----------------------------------------------------------------------
#
# Set initial and lateral boundary condition generation parameters.  
#
# EXTRN_MDL_NAME_ICS:
# The name of the external model that will provide fields from which 
# initial condition (including and surface) files will be generated for
# input into the forecast model.
#
# EXTRN_MDL_NAME_LBCS:
# The name of the external model that will provide fields from which 
# lateral boundary condition (LBC) files will be generated for input into
# the forecast model.
#
# EXTRN_MDL_SAVETYPE:
#`define how EXTRN_MDL_NAME_ICS and EXTRN_MDL_NAME_LBCS were saved (such as GSL, NCO)
#
# EXTRN_MDL_ICS_OFFSET_HRS:
# Initial file offset hours.
#
# LBC_SPEC_INTVL_HRS:
# The interval (in integer hours) with which LBC files will be generated.
# We will refer to this as the boundary update interval.  Note that the
# model specified in EXTRN_MDL_NAME_LBCS must have data available at a
# frequency greater than or equal to that implied by LBC_SPEC_INTVL_HRS.
# For example, if LBC_SPEC_INTVL_HRS is set to 6, then the model must have
# data availble at least every 6 hours.  It is up to the user to ensure 
# that this is the case.
#
# EXTRN_MDL_LBCS_OFFSET_HRS:
# Boundary file offset hours.
#
# LBCS_SEARCH_HRS:
# When search boundary conditions tasks from previous cycles in prep_cyc step,
# For example: 0 means search start for the same cycle lbcs task.
#              1 means search start for 1-h previous cycle lbcs task.
#              2 means search start for 2-h previous cycle lbcs task.
#
# EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS:
# When search boundary conditions from previous cycles in prep_start step,
# the search will start at cycle before (this parameter) of current cycle.
# For example: 0 means search start at the same cycle lbcs directory.
#              1 means search start at 1-h previous cycle  lbcs directory.
#              2 means search start at 2-h previous cycle  lbcs directory.
#
# FV3GFS_FILE_FMT_ICS:
# If using the FV3GFS model as the source of the ICs (i.e. if EXTRN_MDL_NAME_ICS
# is set to "FV3GFS"), this variable specifies the format of the model
# files to use when generating the ICs.
#
# FV3GFS_FILE_FMT_LBCS:
# If using the FV3GFS model as the source of the LBCs (i.e. if 
# EXTRN_MDL_NAME_LBCS is set to "FV3GFS"), this variable specifies the 
# format of the model files to use when generating the LBCs.
#
# EXTRN_MDL_DATE_JULIAN:
# Flag to determine whether or not the file name of the external model 
# for IC/LBCS is a Julian date.
#
#-----------------------------------------------------------------------
#
EXTRN_MDL_NAME_ICS="FV3GFS"
EXTRN_MDL_NAME_LBCS="FV3GFS"
EXTRN_MDL_SAVETYPE="NONE"
EXTRN_MDL_ICS_OFFSET_HRS="0"
LBC_SPEC_INTVL_HRS="6"
EXTRN_MDL_LBCS_OFFSET_HRS=""
EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS="0"
LBCS_SEARCH_HRS="6"
FV3GFS_FILE_FMT_ICS="nemsio"
FV3GFS_FILE_FMT_LBCS="nemsio"
EXTRN_MDL_DATE_JULIAN="FALSE"
#
#-----------------------------------------------------------------------
#
# Set NOMADS online data associated parameters.
#
# NOMADS:
# Flag controlling whether or not using NOMADS online data.
#
# NOMADS_file_type:
# Flag controlling the format of data.
#
#-----------------------------------------------------------------------
#
NOMADS="FALSE"
NOMADS_file_type="nemsio"
#
#-----------------------------------------------------------------------
#
# User-staged external model directories and files.
#
# USE_USER_STAGED_EXTRN_FILES:
# Flag that determines whether or not the workflow will look for the 
# external model files needed for generating ICs and LBCs in user-specified
# directories.
#
# EXTRN_MDL_SOURCE_BASEDIR_ICS:
# Directory in which to look for external model files for generating ICs.
# If USE_USER_STAGED_EXTRN_FILES is set to "TRUE", the workflow looks in 
# this directory (specifically, in a subdirectory under this directory 
# named "YYYYMMDDHH" consisting of the starting date and cycle hour of 
# the forecast, where YYYY is the 4-digit year, MM the 2-digit month, DD 
# the 2-digit day of the month, and HH the 2-digit hour of the day) for 
# the external model files specified by the array EXTRN_MDL_FILES_ICS 
# (these files will be used to generate the ICs on the native FV3-LAM 
# grid).  This variable is not used if USE_USER_STAGED_EXTRN_FILES is 
# set to "FALSE".
# 
# EXTRN_MDL_FILES_ICS:
# Array containing the names of the files to search for in the directory
# specified by EXTRN_MDL_SOURCE_BASEDIR_ICS.  This variable is not used
# if USE_USER_STAGED_EXTRN_FILES is set to "FALSE".
#
# EXTRN_MDL_SOURCE_BASEDIR_LBCS:
# Analogous to EXTRN_MDL_SOURCE_BASEDIR_ICS but for LBCs instead of ICs.
#
# EXTRN_MDL_FILES_LBCS:
# Analogous to EXTRN_MDL_FILES_ICS but for LBCs instead of ICs.
#
#-----------------------------------------------------------------------
#
USE_USER_STAGED_EXTRN_FILES="FALSE"
EXTRN_MDL_SOURCE_BASEDIR_ICS=""
EXTRN_MDL_FILES_ICS=( "ICS_file1" "ICS_file2" "..." )
EXTRN_MDL_SOURCE_BASEDIR_LBCS=""
EXTRN_MDL_FILES_LBCS=( "LBCS_file1" "LBCS_file2" "..." )
#
#-----------------------------------------------------------------------
#
# Set CCPP-associated parameters.
#
# CCPP_PHYS_SUITE:
# The physics suite that will run using CCPP (Common Community Physics
# Package).  The choice of physics suite determines the forecast model's 
# namelist file, the diagnostics table file, the field table file, and 
# the XML physics suite definition file that are staged in the experiment 
# directory or the cycle directories under it.
#
#-----------------------------------------------------------------------
#
CCPP_PHYS_SUITE="FV3_GFS_v16"
#
#-----------------------------------------------------------------------
#
# Set GRID_GEN_METHOD.  This variable specifies the method to use to 
# generate a regional grid in the horizontal.  The values that it can 
# take on are:
#
# * "GFDLgrid":
#   This setting will generate a regional grid by first generating a 
#   "parent" global cubed-sphere grid and then taking a portion of tile
#   6 of that global grid -- referred to in the grid generation scripts
#   as "tile 7" even though it doesn't correspond to a complete tile --
#   and using it as the regional grid.  Note that the forecast is run on
#   only on the regional grid (i.e. tile 7, not tiles 1 through 6).
#
# * "ESGgrid":
#   This will generate a regional grid using the map projection developed
#   by Jim Purser of EMC.
#
# Note that:
#
# 1) If the experiment is using one of the predefined grids (i.e. if 
#    PREDEF_GRID_NAME is set to the name of one of the valid predefined 
#    grids), then GRID_GEN_METHOD will be reset to the value of 
#    GRID_GEN_METHOD for that grid.  This will happen regardless of 
#    whether or not GRID_GEN_METHOD is assigned a value in the user-
#    specified experiment configuration file, i.e. any value it may be
#    assigned in the experiment configuration file will be overwritten.
#
# 2) If the experiment is not using one of the predefined grids (i.e. if 
#    PREDEF_GRID_NAME is set to a null string), then GRID_GEN_METHOD must 
#    be set in the experiment configuration file.  Otherwise, it will 
#    remain set to a null string, and the experiment generation will 
#    fail because the generation scripts check to ensure that it is set 
#    to a non-empty string before creating the experiment directory.
#
#-----------------------------------------------------------------------
#
GRID_GEN_METHOD=""
#
#-----------------------------------------------------------------------
#
# Set parameters specific to the "GFDLgrid" method of generating a regional
# grid (i.e. for GRID_GEN_METHOD set to "GFDLgrid").  The following 
# parameters will be used only if GRID_GEN_METHOD is set to "GFDLgrid". 
# In this grid generation method:
#
# * The regional grid is defined with respect to a "parent" global cubed-
#   sphere grid.  Thus, all the parameters for a global cubed-sphere grid
#   must be specified in order to define this parent global grid even 
#   though the model equations are not integrated on (they are integrated
#   only on the regional grid).
#
# * GFDLgrid_RES is the number of grid cells in either one of the two 
#   horizontal directions x and y on any one of the 6 tiles of the parent
#   global cubed-sphere grid.  The mapping from GFDLgrid_RES to a nominal
#   resolution (grid cell size) for a uniform global grid (i.e. Schmidt
#   stretch factor GFDLgrid_STRETCH_FAC set to 1) for several values of
#   GFDLgrid_RES is as follows:
#
#     GFDLgrid_RES      typical cell size
#     ------------      -----------------
#              192                  50 km
#              384                  25 km
#              768                  13 km
#             1152                 8.5 km
#             3072                 3.2 km
#
#   Note that these are only typical cell sizes.  The actual cell size on
#   the global grid tiles varies somewhat as we move across a tile.
#
# * Tile 6 has arbitrarily been chosen as the tile to use to orient the
#   global parent grid on the sphere (Earth).  This is done by specifying 
#   GFDLgrid_LON_T6_CTR and GFDLgrid_LAT_T6_CTR, which are the longitude
#   and latitude (in degrees) of the center of tile 6.
#
# * Setting the Schmidt stretching factor GFDLgrid_STRETCH_FAC to a value
#   greater than 1 shrinks tile 6, while setting it to a value less than 
#   1 (but still greater than 0) expands it.  The remaining 5 tiles change
#   shape as necessary to maintain global coverage of the grid.
#
# * The cell size on a given global tile depends on both GFDLgrid_RES and
#   GFDLgrid_STRETCH_FAC (since changing GFDLgrid_RES changes the number
#   of cells in the tile, and changing GFDLgrid_STRETCH_FAC modifies the
#   shape and size of the tile).
#
# * The regional grid is embedded within tile 6 (i.e. it doesn't extend
#   beyond the boundary of tile 6).  Its exact location within tile 6 is
#   is determined by specifying the starting and ending i and j indices
#   of the regional grid on tile 6, where i is the grid index in the x
#   direction and j is the grid index in the y direction.  These indices
#   are stored in the variables 
#
#     GFDLgrid_ISTART_OF_RGNL_DOM_ON_T6G
#     GFDLgrid_JSTART_OF_RGNL_DOM_ON_T6G
#     GFDLgrid_IEND_OF_RGNL_DOM_ON_T6G
#     GFDLgrid_JEND_OF_RGNL_DOM_ON_T6G
#
# * In the forecast model code and in the experiment generation and workflow
#   scripts, for convenience the regional grid is denoted as "tile 7" even
#   though it doesn't map back to one of the 6 faces of the cube from 
#   which the parent global grid is generated (it maps back to only a 
#   subregion on face 6 since it is wholly confined within tile 6).  Tile
#   6 may be referred to as the "parent" tile of the regional grid.
#
# * GFDLgrid_REFINE_RATIO is the refinement ratio of the regional grid 
#   (tile 7) with respect to the grid on its parent tile (tile 6), i.e.
#   it is the number of grid cells along the boundary of the regional grid
#   that abut one cell on tile 6.  Thus, the cell size on the regional 
#   grid depends not only on GFDLgrid_RES and GFDLgrid_STRETCH_FAC (because
#   the cell size on tile 6 depends on these two parameters) but also on 
#   GFDLgrid_REFINE_RATIO.  Note that as on the tiles of the global grid, 
#   the cell size on the regional grid is not uniform but varies as we 
#   move across the grid.
#
# Definitions of parameters that need to be specified when GRID_GEN_METHOD
# is set to "GFDLgrid":
#
# GFDLgrid_LON_T6_CTR:
# Longitude of the center of tile 6 (in degrees).
#
# GFDLgrid_LAT_T6_CTR:
# Latitude of the center of tile 6 (in degrees).
#
# GFDLgrid_RES:
# Number of points in each of the two horizontal directions (x and y) on
# each tile of the parent global grid.  Note that the name of this parameter
# is really a misnomer because although it has the stirng "RES" (for 
# "resolution") in its name, it specifies number of grid cells, not grid
# size (in say meters or kilometers).  However, we keep this name in order
# to remain consistent with the usage of the word "resolution" in the 
# global forecast model and other auxiliary codes.
#
# GFDLgrid_STRETCH_FAC:
# Stretching factor used in the Schmidt transformation applied to the
# parent cubed-sphere grid.
#
# GFDLgrid_REFINE_RATIO:
# Cell refinement ratio for the regional grid, i.e. the number of cells
# in either the x or y direction on the regional grid (tile 7) that abut
# one cell on its parent tile (tile 6).
#
# GFDLgrid_ISTART_OF_RGNL_DOM_ON_T6G:
# i-index on tile 6 at which the regional grid (tile 7) starts.
#
# GFDLgrid_IEND_OF_RGNL_DOM_ON_T6G:
# i-index on tile 6 at which the regional grid (tile 7) ends.
#
# GFDLgrid_JSTART_OF_RGNL_DOM_ON_T6G:
# j-index on tile 6 at which the regional grid (tile 7) starts.
#
# GFDLgrid_JEND_OF_RGNL_DOM_ON_T6G:
# j-index on tile 6 at which the regional grid (tile 7) ends.
#
# GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES:
# Flag that determines the file naming convention to use for grid, orography,
# and surface climatology files (or, if using pregenerated files, the
# naming convention that was used to name these files).  These files 
# usually start with the string "C${RES}_", where RES is an integer.
# In the global forecast model, RES is the number of points in each of
# the two horizontal directions (x and y) on each tile of the global grid
# (defined here as GFDLgrid_RES).  If this flag is set to "TRUE", RES will
# be set to GFDLgrid_RES just as in the global forecast model.  If it is
# set to "FALSE", we calculate (in the grid generation task) an "equivalent
# global uniform cubed-sphere resolution" -- call it RES_EQUIV -- and 
# then set RES equal to it.  RES_EQUIV is the number of grid points in 
# each of the x and y directions on each tile that a global UNIFORM (i.e. 
# stretch factor of 1) cubed-sphere grid would have to have in order to
# have the same average grid size as the regional grid.  This is a more
# useful indicator of the grid size because it takes into account the 
# effects of GFDLgrid_RES, GFDLgrid_STRETCH_FAC, and GFDLgrid_REFINE_RATIO
# in determining the regional grid's typical grid size, whereas simply
# setting RES to GFDLgrid_RES doesn't take into account the effects of
# GFDLgrid_STRETCH_FAC and GFDLgrid_REFINE_RATIO on the regional grid's
# resolution.  Nevertheless, some users still prefer to use GFDLgrid_RES
# in the file names, so we allow for that here by setting this flag to
# "TRUE".
#
# Note that:
#
# 1) If the experiment is using one of the predefined grids (i.e. if 
#    PREDEF_GRID_NAME is set to the name of one of the valid predefined
#    grids), then:
#
#    a) If the value of GRID_GEN_METHOD for that grid is "GFDLgrid", then
#       these parameters will get reset to the values for that grid.  
#       This will happen regardless of whether or not they are assigned 
#       values in the user-specified experiment configuration file, i.e. 
#       any values they may be assigned in the experiment configuration 
#       file will be overwritten.
#
#    b) If the value of GRID_GEN_METHOD for that grid is "ESGgrid", then
#       these parameters will not be used and thus do not need to be reset
#       to non-empty strings.
#
# 2) If the experiment is not using one of the predefined grids (i.e. if 
#    PREDEF_GRID_NAME is set to a null string), then:
#
#    a) If GRID_GEN_METHOD is set to "GFDLgrid" in the user-specified 
#       experiment configuration file, then these parameters must be set
#       in that configuration file.
#
#    b) If GRID_GEN_METHOD is set to "ESGgrid" in the user-specified 
#       experiment configuration file, then these parameters will not be 
#       used and thus do not need to be reset to non-empty strings.
#
#-----------------------------------------------------------------------
#
GFDLgrid_LON_T6_CTR=""
GFDLgrid_LAT_T6_CTR=""
GFDLgrid_RES=""
GFDLgrid_STRETCH_FAC=""
GFDLgrid_REFINE_RATIO=""
GFDLgrid_ISTART_OF_RGNL_DOM_ON_T6G=""
GFDLgrid_IEND_OF_RGNL_DOM_ON_T6G=""
GFDLgrid_JSTART_OF_RGNL_DOM_ON_T6G=""
GFDLgrid_JEND_OF_RGNL_DOM_ON_T6G=""
GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES=""
#
#-----------------------------------------------------------------------
#
# Set parameters specific to the "ESGgrid" method of generating a regional
# grid (i.e. for GRID_GEN_METHOD set to "ESGgrid").
#
# ESGgrid_LON_CTR:
# The longitude of the center of the grid (in degrees).
#
# ESGgrid_LAT_CTR:
# The latitude of the center of the grid (in degrees).
#
# ESGgrid_DELX:
# The cell size in the zonal direction of the regional grid (in meters).
#
# ESGgrid_DELY:
# The cell size in the meridional direction of the regional grid (in 
# meters).
#
# ESGgrid_NX:
# The number of cells in the zonal direction on the regional grid.
#
# ESGgrid_NY:
# The number of cells in the meridional direction on the regional grid.
#
# ESGgrid_WIDE_HALO_WIDTH:
# The width (in units of number of grid cells) of the halo to add around
# the regional grid before shaving the halo down to the width(s) expected
# by the forecast model.  
#
# ESGgrid_PAZI:
# The rotational parameter for the ESG grid (in degrees).
#
# In order to generate grid files containing halos that are 3-cell and
# 4-cell wide and orography files with halos that are 0-cell and 3-cell
# wide (all of which are required as inputs to the forecast model), the
# grid and orography tasks first create files with halos around the 
# regional domain of width ESGgrid_WIDE_HALO_WIDTH cells. These are 
# first stored in files. The files are then read in and "shaved" down to 
# obtain grid files with 3-cell-wide and 4-cell-wide halos and orography 
# files with 0-cell-wide (i.e. no halo) and 3-cell-wide halos.  For this 
# reason, we refer to the original halo that then gets shaved down as the 
# "wide" halo, i.e. because it is wider than the 0-cell-wide, 3-cell-wide, 
# and 4-cell-wide halos that we will eventually end up with.  Note that 
# the grid and orography files with the wide halo are only needed as 
# intermediates in generating the files with 0-cell-, 3-cell-, and 4-cell-
# wide halos; they are not needed by the forecast model.  
# NOTE: Probably don't need to make ESGgrid_WIDE_HALO_WIDTH a user-specified 
#       variable.  Just set it in the function set_gridparams_ESGgrid.sh.
#
# Note that:
#
# 1) If the experiment is using one of the predefined grids (i.e. if 
#    PREDEF_GRID_NAME is set to the name of one of the valid predefined
#    grids), then:
#
#    a) If the value of GRID_GEN_METHOD for that grid is "GFDLgrid", then
#       these parameters will not be used and thus do not need to be reset
#       to non-empty strings.
#
#    b) If the value of GRID_GEN_METHOD for that grid is "ESGgrid", then
#       these parameters will get reset to the values for that grid.  
#       This will happen regardless of whether or not they are assigned 
#       values in the user-specified experiment configuration file, i.e. 
#       any values they may be assigned in the experiment configuration 
#       file will be overwritten.
#
# 2) If the experiment is not using one of the predefined grids (i.e. if 
#    PREDEF_GRID_NAME is set to a null string), then:
#
#    a) If GRID_GEN_METHOD is set to "GFDLgrid" in the user-specified 
#       experiment configuration file, then these parameters will not be 
#       used and thus do not need to be reset to non-empty strings.
#
#    b) If GRID_GEN_METHOD is set to "ESGgrid" in the user-specified 
#       experiment configuration file, then these parameters must be set
#       in that configuration file.
#
#-----------------------------------------------------------------------
#
ESGgrid_LON_CTR=""
ESGgrid_LAT_CTR=""
ESGgrid_DELX=""
ESGgrid_DELY=""
ESGgrid_NX=""
ESGgrid_NY=""
ESGgrid_WIDE_HALO_WIDTH=""
ESGgrid_PAZI=""
#
#-----------------------------------------------------------------------
#
# Set computational parameters for the forecast. 
#
# DT_ATMOS:
# The main forecast model integraton time step.  As described in the 
# forecast model documentation, "It corresponds to the frequency with 
# which the top level routine in the dynamics is called as well as the 
# frequency with which the physics is called."
#
# LAYOUT_X, LAYOUT_Y:
# The number of MPI tasks (processes) to use in the two horizontal 
# directions (x and y) of the regional grid when running the forecast 
# model.
#
# BLOCKSIZE:
# The amount of data that is passed into the cache at a time.
#
# IO_LAYOUT_X,IO_LAYOUT_Y:
# When wrtie out restrat files, how many subdomain files will be write in
# x and y directory. Right now, please always set IO_LAYOUT_X=1.
# LAYOUT_Y/IO_LAYOUT_Y needs to be a integer number.
#
# FH_DFI_RADAR:
# the forecast hour to use radar tten, this is used  to set the fh_dfi_radar 
# parameter in input.nml, e.g. FH_DFI_RADAR="0.0,0.25,0.5,0.75,1.0"
# will set fh_dfi_radar = 0.0,0.25,0.5,0.75,1.0 in input.nml* and
# it tells the model to read at the 0, 15, 30, 45 minutes,
# and apply radar tten from 0-60 minutes of forecasts.
#
# Here, we set these parameters to null strings.  This is so that, for 
# any one of these parameters:
#
# 1) If the experiment is using a predefined grid, then if the user 
#    sets the parameter in the user-specified experiment configuration 
#    file (EXPT_CONFIG_FN), that value will be used in the forecast(s).
#    Otherwise, the default value of the parameter for that predefined 
#    grid will be used.
#
# 2) If the experiment is not using a predefined grid (i.e. it is using
#    a custom grid whose parameters are specified in the experiment 
#    configuration file), then the user must specify a value for the 
#    parameter in that configuration file.  Otherwise, the parameter 
#    will remain set to a null string, and the experiment generation 
#    will fail because the generation scripts check to ensure that all 
#    the parameters defined in this section are set to non-empty strings
#    before creating the experiment directory.
#
# NFHOUT: 
# Output frequency in hours after forecast hour "nfhmax_hf".
#
# NFHMAX_HF:
# Number of forecast hours until output frequency "nfhout" takes affect. 
#
# NFHOUT_HF:
# Output frequency in hours until forecast hour "nfhmax_hf".
#
# NSOUT
# Frequency of writing out forecast files in time steps
#
# NSOUT_MIN
# Frequency of writing out forecast files in minutes
#
# OUTPUT_FH
# Output time of writing out forecast files in hours. 
# Output frequency with the second element -1.
#
# FHROT:
# Forecast hour at restart
#
# WRITE_DOPOST:
# Flag that determines whether or not to use the inline post feature
# [i.e. calling the Unified Post Processor (UPP) from within the
# weather model].  If this is set to true, the the run_post task will
# be deactivated.
#-----------------------------------------------------------------------
#
DT_ATMOS=""
LAYOUT_X=""
LAYOUT_Y=""
IO_LAYOUT_X="1"
IO_LAYOUT_Y="1"
BLOCKSIZE=""
FH_DFI_RADAR="-20000000000"
NFHOUT="1"
NFHMAX_HF="60"
NFHOUT_HF="1"
NSOUT="-1"
NSOUT_MIN="0"
OUTPUT_FH="1 -1"
FHROT="0"
WRITE_DOPOST="FALSE"
#
#-----------------------------------------------------------------------
#
# Set write-component (quilting) parameters. 
#
# QUILTING:
# Flag that determines whether or not to use the write component for 
# writing output files to disk.
#
# PRINT_ESMF:
# Flag for whether or not to output extra (debugging) information from
# ESMF routines.  Must be "TRUE" or "FALSE".  Note that the write
# component uses ESMF library routines to interpolate from the native
# forecast model grid to the user-specified output grid (which is defined 
# in the model configuration file MODEL_CONFIG_FN in the forecast's run 
# directory).
#
# WRTCMP_write_groups:
# The number of write groups (i.e. groups of MPI tasks) to use in the
# write component.
#
# WRTCMP_write_tasks_per_group:
# The number of MPI tasks to allocate for each write group.
#
# WRTCMP_output_file:
# The output file format.
#
# WRTCMP_ouptup_grid:
# Output grid (regional_latlon, rotated_latlon, lambert_conformal); the
# grid-specific parameters are set in 'ush/set_predef_grid_params.sh'.
#
# (1) regional_latlon
# lon_lwr_left, lat_lwr_left, lon_upr_rght, lat_upr_rght, dlon, dlat
#
# (2) rotated_latlon
# cen_lon, cen_lat
# lon_lwr_left, lat_lwr_left, lon_upr_rght, lat_upr_rght, dlon, dlat
#
# (3) lambert_conformal
# cen_lon, cen_lat, stdlat1, stdlat2, nx, ny
# lon_lwr_left, lat_lwr_left, dx, dy
#
#-----------------------------------------------------------------------
#
QUILTING="TRUE"
PRINT_ESMF="FALSE"

WRTCMP_write_groups="1"
WRTCMP_write_tasks_per_group="20"
WRTCMP_output_file="netcdf"
WRTCMP_zstandard_level="0"
WRTCMP_ideflate="0"
WRTCMP_quantize_mode="quantize_bitround"
WRTCMP_quantize_nsd="0"

WRTCMP_output_grid=""
WRTCMP_cen_lon=""
WRTCMP_cen_lat=""
WRTCMP_lon_lwr_left=""
WRTCMP_lat_lwr_left=""
WRTCMP_lon_upr_rght=""
WRTCMP_lat_upr_rght=""
WRTCMP_dlon=""
WRTCMP_dlat=""
WRTCMP_stdlat1=""
WRTCMP_stdlat2=""
WRTCMP_nx=""
WRTCMP_ny=""
WRTCMP_dx=""
WRTCMP_dy=""
#
#-----------------------------------------------------------------------
#
# Set PREDEF_GRID_NAME.  This parameter specifies a predefined regional
# grid, as follows:
#
# * If PREDEF_GRID_NAME is set to a valid predefined grid name, the grid 
#   generation method GRID_GEN_METHOD, the (native) grid parameters, and 
#   the write-component grid parameters are set to predefined values for 
#   the specified grid, overwriting any settings of these parameters in 
#   the user-specified experiment configuration file.  In addition, if 
#   the time step DT_ATMOS and the computational parameters LAYOUT_X, 
#   LAYOUT_Y, and BLOCKSIZE are not specified in that configuration file, 
#   they are also set to predefined values for the specified grid.
#
# * If PREDEF_GRID_NAME is set to an empty string, it implies the user
#   is providing the native grid parameters in the user-specified 
#   experiment configuration file (EXPT_CONFIG_FN).  In this case, the 
#   grid generation method GRID_GEN_METHOD, the native grid parameters, 
#   and the write-component grid parameters as well as the time step 
#   forecast model's main time step DT_ATMOS and the computational 
#   parameters LAYOUT_X, LAYOUT_Y, and BLOCKSIZE must be set in that 
#   configuration file; otherwise, the values of all of these parameters 
#   in this default experiment configuration file will be used.
#
# Setting PREDEF_GRID_NAME provides a convenient method of specifying a
# commonly used set of grid-dependent parameters.  The predefined grid 
# parameters are specified in the script 
#
#   $HOMErrfs/ush/set_predef_grid_params.sh
#
#-----------------------------------------------------------------------
#
PREDEF_GRID_NAME=""
#
#-----------------------------------------------------------------------
#
# Set PREEXISTING_DIR_METHOD.  This variable determines the method to use
# use to deal with preexisting directories [e.g ones generated by previous
# calls to the experiment generation script using the same experiment name
# (EXPT_SUBDIR) as the current experiment].  This variable must be set to
# one of "delete", "upgrade", "rename", and "quit".  The resulting behavior
# for each of these values is as follows:
#
# * "delete":
#   The preexisting directory is deleted and a new directory (having the
#   same name as the original preexisting directory) is created.
#
# * "upgrade":
#   save a copy and then upgrade the preexisting $EXPDIR directory
#   keep intact for other preexisting directories
#
# * "rename":
#   The preexisting directory is renamed and a new directory (having the
#   same name as the original preexisting directory) is created.  The new
#   name of the preexisting directory consists of its original name and
#   the suffix "_oldNNN", where NNN is a 3-digit integer chosen to make
#   the new name unique.
#
# * "quit":
#   The preexisting directory is left unchanged, but execution of the
#   currently running script is terminated.  In this case, the preexisting
#   directory must be dealt with manually before rerunning the script.
#
#-----------------------------------------------------------------------
#
PREEXISTING_DIR_METHOD="delete"
#
#-----------------------------------------------------------------------
#
# VERBOSE: 
# This is a flag that determines whether or not the experiment generation 
# and workflow task scripts tend to be print out more informational
# messages.
#
# SAVE_CYCLE_LOG:
# This is a flag that determines whether or not save the information 
# related to data assimilation cycling, such as background used in each 
# cycle
#
#-----------------------------------------------------------------------
#
VERBOSE="TRUE"
SAVE_CYCLE_LOG="TRUE"
#
#-----------------------------------------------------------------------
#
# Set flags (and related directories) that determine whether the grid, 
# orography, and/or surface climatology file generation tasks should be
# run.  Note that these are all cycle-independent tasks, i.e. if they are
# to be run, they do so only once at the beginning of the workflow before
# any cycles are run.  Definitions:
#
# RUN_TASK_MAKE_GRID:
# Flag that determines whether the grid file generation task is to be run.
# If this is set to "TRUE", the grid generation task is run and new grid
# files are generated.  If it is set to "FALSE", then the scripts look 
# for pregenerated grid files in the directory specified by GRID_DIR (see
# below).
#
# GRID_DIR:
# The directory in which to look for pregenerated grid files if 
# RUN_TASK_MAKE_GRID is set to "FALSE".
# 
# RUN_TASK_MAKE_OROG:
# Same as RUN_TASK_MAKE_GRID but for the orography generation task.
#
# OROG_DIR:
# Same as GRID_DIR but for the orogrpahy generation task.
# 
# RUN_TASK_MAKE_SFC_CLIMO:
# Same as RUN_TASK_MAKE_GRID but for the surface climatology generation
# task.
#
# SFC_CLIMO_DIR:
# Same as GRID_DIR but for the surface climatology generation task.
#
# RUN_TASK_RUN_PRDGEN:
# Flag that determines whether the product generation task is to run.
#
# RUN_TASK_ADD_AEROSOL:
# Flag that determines whether the task for adding dusk in the GEFS 
# aerosol data to LBCs task is to run.
#
# IS_RTMA:
# If true, some ICs,LBCs,GSI rocoto tasks will be turned off
#
# FG_ROOTDIR:
# First Guess Root Directory, APP will find corresponding first guess
# fields from this directory. RRFS will find FG under NWGES_BASEDIR,
# but we needs to explicitly specify where to find FG for RTMA.
# So this parameter only matters for RTMA
#
# RTMA_OBS_FEED:
# "" or "GSL":  RTMA's observations follow the GSL naming convention
#       "NCO":  RTMA's observations follow the NCO naming convention
#
# PYTHON_GRAPHICS_YML_FN:
# The name of the yml file under ${PYTHON_GRAPHICS_DIR}/image_lists
# to be used by current application
#
#-----------------------------------------------------------------------
#
RUN_TASK_MAKE_GRID="FALSE"
GRID_DIR=""

RUN_TASK_MAKE_OROG="FALSE"
OROG_DIR=""

RUN_TASK_MAKE_SFC_CLIMO="FALSE"
SFC_CLIMO_DIR=""

RUN_TASK_RUN_PRDGEN="TRUE"
RUN_TASK_ADD_AEROSOL="FALSE"
#
NCORES_PER_NODE=24 #Jet default value
IS_RTMA="FALSE"
FG_ROOTDIR=""
RTMA_OBS_FEED=""
PYTHON_GRAPHICS_YML_FN="rrfs_subset.yml"
#
#-----------------------------------------------------------------------
#
# Set the array parameter containing the names of all the fields that the
# MAKE_SFC_CLIMO_TN task generates on the native FV3-LAM grid.
#
#-----------------------------------------------------------------------
#
SFC_CLIMO_FIELDS=( \
"facsf" \
"maximum_snow_albedo" \
"slope_type" \
"snowfree_albedo" \
"soil_type" \
"substrate_temperature" \
"vegetation_greenness" \
"vegetation_type" \
)
#
#-----------------------------------------------------------------------
#
# Set parameters associated with the fixed (i.e. static) files.
#
# FIXgsm:
# System directory in which the majority of fixed (i.e. time-independent) 
# files that are needed to run the FV3-LAM model are located
#
# FIXprdgen:
# directory where prdgen fix files are located
#
# TOPO_DIR:
# The location on disk of the static input files used by the make_orog
# task (orog.x and shave.x). Can be the same as FIXgsm.
#
# SFC_CLIMO_INPUT_DIR:
# The location on disk of the static surface climatology input fields, 
# used by sfc_climo_gen. These files are only used if 
# RUN_TASK_MAKE_SFC_CLIMO=TRUE
#
# FIX_GSI:
# System directory in which the fixed files that are needed to run 
# the GSI are located
#
# FIX_UPP:
# System directory in which the fixed files that are needed to run 
# the UPP are located
#
# FIX_CRTM:
# System directory in which the CRTM coefficient files are located 
#
# FIX_SMOKE_DUST
# directory in which the smoke and dust fix files are located
#
# FIX_BUFRSND
# directory in which the bufrsnd fix files are located
#
# FNGLAC, ..., FNMSKH:
# Names of (some of the) global data files that are assumed to exist in 
# a system directory specified (this directory is machine-dependent; 
# the experiment generation scripts will set it and store it in the 
# variable FIXgsm).  These file names also appear directly in the forecast 
# model's input namelist file.
#
# FIXgsm_FILES_TO_COPY_TO_FIXam:
# If not running in NCO mode, this array contains the names of the files
# to copy from the FIXgsm system directory to the FIXam directory under
# the experiment directory.  Note that the last element has a dummy value.
# This last element will get reset by the workflow generation scripts to
# the name of the ozone production/loss file to copy from FIXgsm.  The
# name of this file depends on the ozone parameterization being used, 
# and that in turn depends on the CCPP physics suite specified for the 
# experiment.  Thus, the CCPP physics suite XML must first be read in to
# determine the ozone parameterizaton and then the name of the ozone 
# production/loss file.  These steps are carried out elsewhere (in one 
# of the workflow generation scripts/functions).
#
# FV3_NML_VARNAME_TO_FIXam_FILES_MAPPING:
# This array is used to set some of the namelist variables in the forecast 
# model's namelist file that represent the relative or absolute paths of 
# various fixed files (the first column of the array, where columns are 
# delineated by the pipe symbol "|") to the full paths to these files in 
# the FIXam directory derived from the corresponding workflow variables 
# containing file names (the second column of the array).
#
# FV3_NML_VARNAME_TO_SFC_CLIMO_FIELD_MAPPING:
# This array is used to set some of the namelist variables in the forecast 
# model's namelist file that represent the relative or absolute paths of 
# various fixed files (the first column of the array, where columns are 
# delineated by the pipe symbol "|") to the full paths to surface climatology 
# files (on the native FV3-LAM grid) in the FIXLAM directory derived from 
# the corresponding surface climatology fields (the second column of the 
# array).
#
# CYCLEDIR_LINKS_TO_FIXam_FILES_MAPPING:
# This array specifies the mapping to use between the symlinks that need
# to be created in each cycle directory (these are the "files" that FV3
# looks for) and their targets in the FIXam directory.  The first column
# of the array specifies the symlink to be created, and the second column
# specifies its target file in FIXam (where columns are delineated by the
# pipe symbol "|").
# 
# VCOORD_FILE:
# File name to set the vertical coordinate in make_ics and make_lbcs
#
#-----------------------------------------------------------------------
#
# Because the default values are dependent on the platform, we set these
# to a null string which will then be overwritten in setup.sh unless the
# user has specified a different value in config.sh
FIXgsm=""
FIXprdgen=""
TOPO_DIR=""
SFC_CLIMO_INPUT_DIR=""
FIX_GSI=""
FIX_UPP=""
FIX_CRTM=""
FIX_UPP_CRTM=""
FIX_SMOKE_DUST=""
FIX_BUFRSND=""

FNGLAC="global_glacier.2x2.grb"
FNMXIC="global_maxice.2x2.grb"
FNTSFC="RTGSST.1982.2012.monthly.clim.grb"
FNSNOC="global_snoclim.1.875.grb"
FNZORC="igbp"
FNAISC="CFSR.SEAICE.1982.2012.monthly.clim.grb"
FNSMCC="global_soilmgldas.t126.384.190.grb"
FNMSKH="seaice_newland.grb"

FIXgsm_FILES_TO_COPY_TO_FIXam=( \
"$FNGLAC" \
"$FNMXIC" \
"$FNTSFC" \
"$FNSNOC" \
"$FNAISC" \
"$FNSMCC" \
"$FNMSKH" \
"global_climaeropac_global.txt" \
"fix_co2_proj/global_co2historicaldata_2010.txt" \
"fix_co2_proj/global_co2historicaldata_2011.txt" \
"fix_co2_proj/global_co2historicaldata_2012.txt" \
"fix_co2_proj/global_co2historicaldata_2013.txt" \
"fix_co2_proj/global_co2historicaldata_2014.txt" \
"fix_co2_proj/global_co2historicaldata_2015.txt" \
"fix_co2_proj/global_co2historicaldata_2016.txt" \
"fix_co2_proj/global_co2historicaldata_2017.txt" \
"fix_co2_proj/global_co2historicaldata_2018.txt" \
"fix_co2_proj/global_co2historicaldata_2019.txt" \
"fix_co2_proj/global_co2historicaldata_2020.txt" \
"fix_co2_proj/global_co2historicaldata_2021.txt" \
"fix_co2_proj/global_co2historicaldata_2022.txt" \
"fix_co2_proj/global_co2historicaldata_2023.txt" \
"fix_co2_proj/global_co2historicaldata_2024.txt" \
"global_co2historicaldata_glob.txt" \
"co2monthlycyc.txt" \
"global_h2o_pltc.f77" \
"global_hyblev.l65.txt" \
"global_zorclim.1x1.grb" \
"global_sfc_emissivity_idx.txt" \
"global_solarconstant_noaa_an.txt" \
"replace_with_FIXgsm_ozone_prodloss_filename" \
)

#
# It is possible to remove this as a workflow variable and make it only
# a local one since it is used in only one script.
#
FV3_NML_VARNAME_TO_FIXam_FILES_MAPPING=( \
"FNGLAC | $FNGLAC" \
"FNMXIC | $FNMXIC" \
"FNTSFC | $FNTSFC" \
"FNSNOC | $FNSNOC" \
"FNAISC | $FNAISC" \
"FNSMCC | $FNSMCC" \
"FNMSKH | $FNMSKH" \
)
#"FNZORC | $FNZORC" \

FV3_NML_VARNAME_TO_SFC_CLIMO_FIELD_MAPPING=( \
"FNALBC  | snowfree_albedo" \
"FNALBC2 | facsf" \
"FNTG3C  | substrate_temperature" \
"FNVEGC  | vegetation_greenness" \
"FNVETC  | vegetation_type" \
"FNSOTC  | soil_type" \
"FNVMNC  | vegetation_greenness" \
"FNVMXC  | vegetation_greenness" \
"FNSLPC  | slope_type" \
"FNABSC  | maximum_snow_albedo" \
)

CYCLEDIR_LINKS_TO_FIXam_FILES_MAPPING=( \
"aerosol.dat                | global_climaeropac_global.txt" \
"co2historicaldata_2010.txt | fix_co2_proj/global_co2historicaldata_2010.txt" \
"co2historicaldata_2011.txt | fix_co2_proj/global_co2historicaldata_2011.txt" \
"co2historicaldata_2012.txt | fix_co2_proj/global_co2historicaldata_2012.txt" \
"co2historicaldata_2013.txt | fix_co2_proj/global_co2historicaldata_2013.txt" \
"co2historicaldata_2014.txt | fix_co2_proj/global_co2historicaldata_2014.txt" \
"co2historicaldata_2015.txt | fix_co2_proj/global_co2historicaldata_2015.txt" \
"co2historicaldata_2016.txt | fix_co2_proj/global_co2historicaldata_2016.txt" \
"co2historicaldata_2017.txt | fix_co2_proj/global_co2historicaldata_2017.txt" \
"co2historicaldata_2018.txt | fix_co2_proj/global_co2historicaldata_2018.txt" \
"co2historicaldata_2019.txt | fix_co2_proj/global_co2historicaldata_2019.txt" \
"co2historicaldata_2020.txt | fix_co2_proj/global_co2historicaldata_2020.txt" \
"co2historicaldata_2021.txt | fix_co2_proj/global_co2historicaldata_2021.txt" \
"co2historicaldata_2022.txt | fix_co2_proj/global_co2historicaldata_2022.txt" \
"co2historicaldata_2023.txt | fix_co2_proj/global_co2historicaldata_2023.txt" \
"co2historicaldata_2024.txt | fix_co2_proj/global_co2historicaldata_2024.txt" \
"co2historicaldata_glob.txt | global_co2historicaldata_glob.txt" \
"co2monthlycyc.txt          | co2monthlycyc.txt" \
"global_h2oprdlos.f77       | global_h2o_pltc.f77" \
"global_zorclim.1x1.grb     | global_zorclim.1x1.grb" \
"sfc_emissivity_idx.txt     | global_sfc_emissivity_idx.txt" \
"solarconstant_noaa_an.txt  | global_solarconstant_noaa_an.txt" \
"global_o3prdlos.f77        | " \
)

VCOORD_FILE="global_hyblev_fcst_rrfsL65.txt"

#
#-----------------------------------------------------------------------
#
# Set the names of the various workflow tasks.  Then, for each task, set
# the parameters to pass to the job scheduler (e.g. slurm) that will submit
# a job for each task to be run.  These parameters include the number of
# nodes to use to run the job, the MPI processes per node, the maximum
# walltime to allow for the job to complete, and the maximum number of
# times to attempt to run each task.
#
#-----------------------------------------------------------------------
#
# Task names.
#
MAKE_GRID_TN="make_grid"
MAKE_OROG_TN="make_orog"
MAKE_SFC_CLIMO_TN="make_sfc_climo"
GET_EXTRN_ICS_TN="get_extrn_ics"
GET_EXTRN_LBCS_TN="get_extrn_lbcs"
GET_EXTRN_LBCS_LONG_TN="get_extrn_lbcs_long"
GET_GEFS_LBCS_TN="get_gefs_lbcs"
MAKE_ICS_TN="make_ics"
BLEND_ICS_TN="blend_ics"
MAKE_LBCS_TN="make_lbcs"
RUN_FCST_TN="run_fcst"
RUN_POST_TN="run_post"
RUN_PRDGEN_TN="run_prdgen"
RUN_BUFRSND_TN="run_bufrsnd"

ANALYSIS_GSI_TN="analysis_gsi_input"
ANALYSIS_GSIDIAG_TN="analysis_gsi_diag"
ANALYSIS_SD_GSI_TN="analysis_sd_gsi_input"
POSTANAL_TN="postanal_input"
OBSERVER_GSI_ENSMEAN_TN="observer_gsi_ensmean"
OBSERVER_GSI_TN="observer_gsi"
PREP_START_TN="prep_start"
PREP_CYC_SPINUP_TN="prep_cyc_spinup"
PREP_CYC_PROD_TN="prep_cyc_prod"
PREP_CYC_ENSMEAN_TN="prep_cyc_ensmean"
PREP_CYC_TN="prep_cyc"
CALC_ENSMEAN_TN="calc_ensmean"
PROCESS_RADAR_REF_TN="process_radarref"
PROCESS_LIGHTNING_TN="process_lightning"
RADAR_REF_THINNING="1"
PROCESS_BUFR_TN="process_bufr"
PROCESS_SMOKE_TN="process_smoke"
PROCESS_PM_TN="process_pm"
RADAR_REFL2TTEN_TN="radar_refl2tten"
CLDANL_NONVAR_TN="cldanl_nonvar"
SAVE_RESTART_TN="save_restart"
SAVE_DA_OUTPUT_TN="save_da_output"
JEDI_ENVAR_IODA_TN="jedi_envar_ioda"
IODA_PREPBUFR_TN="ioda_prepbufr"
PROCESS_GLMFED_TN="process_glmfed"
ADD_AEROSOL_TN="add_aerosol"
#
# Number of nodes.
#
NNODES_MAKE_GRID="1"
NNODES_MAKE_OROG="1"
NNODES_MAKE_SFC_CLIMO="2"
NNODES_GET_EXTRN_ICS="1"
NNODES_GET_EXTRN_LBCS="1"
NNODES_MAKE_ICS="4"
NNODES_BLEND_ICS="1"
NNODES_MAKE_LBCS="4"
NNODES_RUN_PREPSTART="1"
NNODES_RUN_FCST=""  # This is calculated in the workflow generation scripts, so no need to set here.
NNODES_RUN_POST="2"
NNODES_RUN_PRDGEN="1"
NNODES_RUN_ANALYSIS="16"
NNODES_RUN_GSIDIAG="1"
NNODES_RUN_POSTANAL="1"
NNODES_RUN_ENKF="90"
NNODES_RUN_RECENTER="6"
NNODES_PROC_RADAR="2"
NNODES_PROC_LIGHTNING="1"
NNODES_PROC_GLMFED="1"
NNODES_PROC_BUFR="1"
NNODES_PROC_SMOKE="1"
NNODES_PROC_PM="1"
NNODES_RUN_REF2TTEN="1"
NNODES_RUN_NONVARCLDANL="1"
NNODES_RUN_GRAPHICS="1"
NNODES_RUN_ENSPOST="1"
NNODES_RUN_BUFRSND="1"
NNODES_SAVE_RESTART="1"
NNODES_RUN_JEDIENVAR_IODA="1"
NNODES_RUN_IODA_PREPBUFR="1"
NNODES_ADD_AEROSOL="1"
#
# Number of cores.
#
NCORES_RUN_ANALYSIS="4"
NCORES_RUN_OBSERVER="4"
NCORES_RUN_ENKF="4"
NATIVE_RUN_FCST="--cpus-per-task 2 --exclusive"
NATIVE_RUN_ANALYSIS="--cpus-per-task 2 --exclusive"
NATIVE_RUN_ENKF="--cpus-per-task 4 --exclusive"
#
# Number of MPI processes per node.
#
PPN_MAKE_GRID="24"
PPN_MAKE_OROG="24"
PPN_MAKE_SFC_CLIMO="24"
PPN_GET_EXTRN_ICS="1"
PPN_GET_EXTRN_LBCS="1"
PPN_MAKE_ICS="12"
PPN_BLEND_ICS="8"
PPN_MAKE_LBCS="12"
PPN_RUN_PREPSTART="1"
PPN_RUN_FCST="24"  # This may have to be changed depending on the number of threads used.
PPN_RUN_POST="24"
PPN_RUN_PRDGEN="1"
PPN_RUN_ANALYSIS="24"
PPN_RUN_GSIDIAG="24"
PPN_RUN_POSTANAL="1"
PPN_RUN_ENKF="1"
PPN_RUN_RECENTER="20"
PPN_PROC_RADAR="24"
PPN_PROC_LIGHTNING="1"
PPN_PROC_GLMFED="1"
PPN_PROC_BUFR="1"
PPN_PROC_SMOKE="1"
PPN_PROC_PM="1"
PPN_RUN_REF2TTEN="1"
PPN_RUN_NONVARCLDANL="1"
PPN_RUN_GRAPHICS="12"
PPN_RUN_ENSPOST="1"
PPN_RUN_BUFRSND="28"
PPN_SAVE_RESTART="1"
PPN_RUN_JEDIENVAR_IODA="1"
PPN_RUN_IODA_PREPBUFR="1"
PPN_ADD_AEROSOL="9"
#
# Number of TPP for WCOSS2.
#
TPP_MAKE_ICS="1"
TPP_MAKE_LBCS="2"
TPP_RUN_ANALYSIS="1"
TPP_RUN_ENKF="1"
TPP_RUN_FCST="1"
TPP_RUN_POST="1"
TPP_RUN_BUFRSND="1"
#
# Walltimes.
#
WTIME_MAKE_GRID="00:20:00"
WTIME_MAKE_OROG="00:40:00"
WTIME_MAKE_SFC_CLIMO="00:20:00"
WTIME_GET_EXTRN_ICS="00:45:00"
WTIME_GET_EXTRN_LBCS="00:45:00"
WTIME_MAKE_ICS="00:30:00"
WTIME_BLEND_ICS="00:30:00"
WTIME_MAKE_LBCS="01:30:00"
WTIME_RUN_PREPSTART="00:10:00"
WTIME_RUN_PREPSTART_ENSMEAN="00:10:00"
WTIME_RUN_FCST="00:30:00"
WTIME_RUN_FCST_LONG="04:30:00"
WTIME_RUN_FCST_SPINUP="00:30:00"
WTIME_RUN_POST="00:15:00"
WTIME_RUN_PRDGEN="00:40:00"
WTIME_RUN_ANALYSIS="00:30:00"
WTIME_RUN_GSIDIAG="00:15:00"
WTIME_RUN_POSTANAL="00:30:00"
WTIME_RUN_ENKF="01:00:00"
WTIME_RUN_RECENTER="01:00:00"
WTIME_PROC_RADAR="00:25:00"
WTIME_PROC_LIGHTNING="00:25:00"
WTIME_PROC_GLMFED="00:25:00"
WTIME_PROC_BUFR="00:25:00"
WTIME_PROC_SMOKE="00:25:00"
WTIME_PROC_PM="00:25:00"
WTIME_RUN_REF2TTEN="00:20:00"
WTIME_RUN_NONVARCLDANL="00:20:00"
WTIME_RUN_BUFRSND="00:45:00"
WTIME_SAVE_RESTART="00:15:00"
WTIME_RUN_ENSPOST="00:30:00"
WTIME_RUN_JEDIENVAR_IODA="00:30:00"
WTIME_RUN_IODA_PREPBUFR="00:20:00"
WTIME_ADD_AEROSOL="00:30:00"
#
# Start times.
#
START_TIME_SPINUP="01:10:00"
START_TIME_PROD="02:20:00"
START_TIME_CONVENTIONAL_SPINUP="00:40:00"
START_TIME_BLENDING="01:00:00"
START_TIME_LATE_ANALYSIS="01:40:00"
START_TIME_CONVENTIONAL="00:40:00"
START_TIME_IODA_PREPBUFR="00:40:00"
START_TIME_NSSLMOSIAC="00:45:00"
START_TIME_LIGHTNINGNC="00:45:00"
START_TIME_GLMFED="00:45:00"
START_TIME_PROCSMOKE="00:45:00"
START_TIME_PROCPM="00:45:00"
#
# Memory.
#
MEMO_RUN_PROCESSBUFR="20G"
MEMO_RUN_REF2TTEN="20G"
MEMO_RUN_NONVARCLDANL="20G"
MEMO_RUN_PREPSTART="24G"
MEMO_RUN_PRDGEN="24G"
MEMO_RUN_JEDIENVAR_IODA="20G"
MEMO_RUN_IODA_PREPBUFR="20G"
MEMO_PREP_CYC="40G"
MEMO_SAVE_RESTART="40G"
MEMO_SAVE_INPUT="40G"
MEMO_PROC_SMOKE="40G"
MEMO_PROC_GLMFED="70G"
MEMO_PROC_PM="40G"
MEMO_SAVE_DA_OUTPUT="40G"
MEMO_ADD_AEROSOL="70G"
#
# Maximum number of attempts.
#
MAXTRIES_MAKE_GRID="2"
MAXTRIES_MAKE_OROG="2"
MAXTRIES_MAKE_SFC_CLIMO="2"
MAXTRIES_GET_EXTRN_ICS="2"
MAXTRIES_GET_EXTRN_LBCS="2"
MAXTRIES_MAKE_ICS="2"
MAXTRIES_BLEND_ICS="2"
MAXTRIES_MAKE_LBCS="2"
MAXTRIES_RUN_PREPSTART="1"
MAXTRIES_RUN_FCST="1"
MAXTRIES_ANALYSIS_GSI="1"
MAXTRIES_POSTANAL="1"
MAXTRIES_ANALYSIS_ENKF="1"
MAXTRIES_RUN_POST="2"
MAXTRIES_RUN_PRDGEN="1"
MAXTRIES_RUN_ANALYSIS="1"
MAXTRIES_RUN_POSTANAL="1"
MAXTRIES_RECENTER="1"
MAXTRIES_PROCESS_RADARREF="1"
MAXTRIES_PROCESS_LIGHTNING="1"
MAXTRIES_PROC_GLMFED="1"
MAXTRIES_PROCESS_BUFR="1"
MAXTRIES_PROCESS_SMOKE="1"
MAXTRIES_PROCESS_PM="1"
MAXTRIES_RADAR_REF2TTEN="1"
MAXTRIES_CLDANL_NONVAR="1"
MAXTRIES_SAVE_RESTART="1"
MAXTRIES_SAVE_DA_OUTPUT="1"
MAXTRIES_JEDI_ENVAR_IODA="1"
MAXTRIES_IODA_PREPBUFR="1"
MAXTRIES_ADD_AEROSOL="1"
#
#-----------------------------------------------------------------------
#
# Set additional output grids for wgrib2 remapping, if any 
# Space-separated list of strings, e.g., ( "130" "242" "clue" )
# Default is no additional grids
#
# Current options as of 23 Apr 2021:
#  "130"   (CONUS 13.5 km)
#  "200"   (Puerto Rico 16 km)
#  "221"   (North America 32 km)
#  "242"   (Alaska 11.25 km)
#  "243"   (Pacific 0.4-deg)
#  "clue"  (NSSL/SPC 3-km CLUE grid for 2020/2021)
#  "hrrr"  (HRRR 3-km CONUS grid)
#  "hrrre" (HRRRE 3-km CONUS grid)
#  "rrfsak" (RRFS 3-km Alaska grid)
#  "hrrrak" (HRRR 3-km Alaska grid)
#
#-----------------------------------------------------------------------
#
ADDNL_OUTPUT_GRIDS=()
#
#-----------------------------------------------------------------------
#
# Set parameters associated with defining a customized post configuration 
# file.
#
# USE_CUSTOM_POST_CONFIG_FILE:
# Flag that determines whether a user-provided custom configuration file
# should be used for post-processing the model data. If this is set to
# "TRUE", then the workflow will use the custom post-processing (UPP) 
# configuration file specified in CUSTOM_POST_CONFIG_FP. Otherwise, a 
# default configuration file provided in the EMC_post repository will be 
# used.
#
# CUSTOM_POST_CONFIG_FP:
# The full path to the custom post flat file, including filename, to be 
# used for post-processing. This is only used if CUSTOM_POST_CONFIG_FILE
# is set to "TRUE".
#
# CUSTOM_POST_PARAMS_FP:
# The full path to the custom post params file, including filename, to be 
# used for post-processing. This is only used if CUSTOM_POST_CONFIG_FILE
# is set to "TRUE".
#
# POST_FULL_MODEL_NAME
# The full module name required by UPP and set in the itag file
#
# POST_SUB_MODEL_NAME
# The SUB module name required by UPP and set in the itag file
#
# TESTBED_FIELDS_FN
# The file which lists grib2 fields to be extracted to bgsfc for testbed
# Empty string means no need to generate bgsfc for testbed
#
#-----------------------------------------------------------------------
#
USE_CUSTOM_POST_CONFIG_FILE="FALSE"
CUSTOM_POST_CONFIG_FP=""
CUSTOM_POST_PARAMS_FP=""
POST_FULL_MODEL_NAME="FV3R"
POST_SUB_MODEL_NAME="FV3R"
TESTBED_FIELDS_FN=""
TESTBED_FIELDS_FN2=""
#
#-----------------------------------------------------------------------
#
# Set the tiles (or subdomains) for creating graphics in a Rocoto metatask.
# Do not include references to the grids that are produced in separate grib
# files (set with ADDNL_OUTPUT_GRIDS above). Those will be added in setup.sh
#
# TILE_LABELS
# A space separated list (string is fine, no need for array) of the labels
# applied to the groupings of tiles to be run as a single batch jobs. For
# example, you may label the set of tiles SE,NE,SC,NC,SW,NW as "regions", 
# and the full input domain as "full" if you wanted those to run in two 
# domains. The length must match the length of TILE_SETS.
#
# TILE_SETS
# A space separated list of tile groupings to plot. Space-separated sets
# indicate which ones will be grouped in a single batch job, comma sepated 
# items are the tiles to be plotted in that batch job. For example:
#    TILE_SETS="full SW,SC,SE NW,NC,NE"
#    TILE_LABELS="full southern_regions northern_regions"
# would plot maps for the full domain in a batch job separately from the
# southern regions, using a third batch job for the northern regions. The
# space-separated list must match the length of TILE_LABELS.
#
#-----------------------------------------------------------------------
#
TILE_LABELS="full"
TILE_SETS="full"
#
#-----------------------------------------------------------------------
#
# Set parameters associated with running ensembles.
#
# DO_ENSEMBLE:
# Flag that determines whether to run a set of ensemble forecasts (for
# each set of specified cycles). If this is set to "TRUE", NUM_ENS_MEMBERS
# forecasts are run for each cycle, each with a different set of stochastic 
# seed values.  Otherwise, a single forecast is run for each cycle.
#
# NUM_ENS_MEMBERS:
# The number of ensemble members to run if DO_ENSEMBLE is set to "TRUE".
# This variable also controls the naming of the ensemble member directories.  
# For example, if this is set to "8", the member directories will be named 
# mem1, mem2, ..., mem8.  If it is set to "08" (note the leading zero), 
# the member directories will be named mem01, mem02, ..., mem08.  Note, 
# however, that after reading in the number of characters in this string
# (in order to determine how many leading zeros, if any, should be placed
# in the names of the member directories), the workflow generation scripts
# strip away those leading zeros.  Thus, in the variable definitions file 
# (GLOBAL_VAR_DEFNS_FN), this variable appear with its leading zeros 
# stripped.  This variable is not used if DO_ENSEMBLE is not set to "TRUE".
# 
# DO_ENSCONTROL: 
# In ensemble mode, whether or not to run member 1 as control member
#
# DO_GSIOBSERVER:
# Decide whether or not to run GSI observer
#
# DO_ENKFUPDATE:
# Decide whether or not to run EnKF update for the ensemble members
#
# DO_ENKF_RADAR_REF:
# Decide whether or not to run Radar Reflectivity EnKF update for the 
# ensemble members
#
# DO_ENVAR_RADAR_REF:
# Decide whether or not to run Radar Reflectivity hybrid analysis
#
# DO_ENVAR_RADAR_REF_ONCE:
# Decide whether or not to run Radar Reflectivity hybrid analysis 
# simultaneously with other observations
#
# DO_RECENTER:
# Decide whether or not to run recenter for the ensemble members
#
# DO_SAVE_DA_OUTPUT:
# Decide whether or not to run save_da_output after the DA analysis  
#
# DO_GSIDIAG_OFFLINE:
# Decide whether or not to run GSI diag generation outside of the GSI task  
#
# DO_ENS_GRAPHICS:
# Flag to turn on/off ensemble graphics. Turns OFF deterministic
# graphics.
#
# DO_ENSPOST:
# Flag to turn on/off python ensemble postprocessing for WPC testbeds.
#
# DO_ENSINIT:
# Decide whether or not to do ensemble initialization by running 1 
# timestep ensemble forecast and recentering on the deterministic 
# analysis
#
# DO_ENSFCST:
# Flag that determines whether to run ensemble free forecasts (for
# each set of specified cycles).  If this is set to "TRUE", 
# NUM_ENS_MEMBERS_FCST forecasts are run for each specified cycle, 
# each with a different set of stochastic seed values. 
#
# NUM_ENS_MEMBERS_FCST:
# The number of ensemble members to run forecast if DO_ENSFCST is set 
# to "TRUE". This variable also controls the naming of the ensemble 
# member directories. For example, if this is set to "8", the member 
# directories will be named mem1, mem2, ..., mem8. If it is set to "08" 
# (note the leading zero), the member directories will be named mem01, 
# mem02, ..., mem08. Note, however, that after reading in the number of 
# characters in this string (in order to determine how many leading 
# zeros, if any, should be placed in the names of the member directories), 
# the workflow generation scripts strip away those leading zeros. Thus, 
# in the variable definitions file (GLOBAL_VAR_DEFNS_FN), this variable 
# appear with its leading zeros stripped. This variable is not used if 
# DO_ENSEMBLE is not set to "TRUE".
# 
# DO_ENS_RADDA:
# It decides whether to include radiance DA in EnKF or not. Note that 
# when one sets 'DO_ENS_RADDA="TRUE"', the radiance DA must be true, 
# i.e., 'DO_RADDA="TRUE"'. This is because the radiance DA in EnKF 
# relies the radiance procedures in the GSI-observer, which is mainly 
# controled by DO_RADDA.
#
# DO_ENS_BLENDING:
# Flag that can enable two things:
#	1) large-scale blending during initialization.
#	2) activate cold2warm start only (replaces ensinit step).
# When this is activated there are two other flags that are relevant:
#	1) BLEND
#	2) USE_HOST_ENKF
#
# BLEND: Only relevant when DO_ENS_BLENDING=TRUE. Flag to perform large scale
# blending during initialization. If this is set to "TRUE", then the RRFS
# EnKF will be blended with the external model ICS using the Raymond filter
# (a low-pass, sixth-order implicit tangent filter).
# TRUE:  Blend RRFS and GDAS EnKF
# FALSE: Don't blend, activate cold2warm start only, and use either GDAS or
#        RRFS; default
#
# USE_HOST_ENKF: Only relevant when DO_ENS_BLENDING=TRUE and BLEND=FALSE.
# Flag for which EnKF to use during cold2warm start conversion.
# TRUE:  Final EnKF will be GDAS (no blending); default
# FALSE: Final EnKF will be RRFS (no blending)
#
#-----------------------------------------------------------------------
#
DO_ENSEMBLE="FALSE"
NUM_ENS_MEMBERS="1"
DO_ENSFCST="FALSE"
DO_ENSFCST_MULPHY="FALSE"
NUM_ENS_MEMBERS_FCST="0"
DO_ENSCONTROL="FALSE"
DO_GSIOBSERVER="FALSE"
DO_ENKFUPDATE="FALSE"
DO_ENKF_RADAR_REF="FALSE"
DO_ENVAR_RADAR_REF="FALSE"
DO_ENVAR_RADAR_REF_ONCE="FALSE"
DO_RECENTER="FALSE"
DO_ENS_GRAPHICS="FALSE"
DO_ENSPOST="FALSE"
DO_ENSINIT="FALSE"
DO_SAVE_DA_OUTPUT="FALSE"
DO_GSIDIAG_OFFLINE="FALSE"
DO_RADMON="FALSE"
DO_ENS_RADDA="FALSE"
DO_ENS_BLENDING="FALSE"
ENS_BLENDING_LENGTHSCALE="960" # (Lx) in kilometers
BLEND="FALSE"
USE_HOST_ENKF="TRUE"
#
#-----------------------------------------------------------------------
#
# Set parameters associated with running data assimilation. 
#
# DO_DACYCLE:
# Flag that determines whether to run a data assimilation cycle.
#
# DO_SURFACE_CYCLE:
# Flag that determines whether to continue cycle surface fields.
#
# SURFACE_CYCLE_DELAY_HRS:
# The surface cycle usually happens in cold start cycle. But there is
# a need to delay surface cycle to the warm start cycle following the
# cold start cycle. This one sets how many hours we want the surface
# cycle being delayed.
#
# DO_SOIL_ADJUST:
# Flag that determines whether to adjust soil T and Q based on
# the lowest level T/Q analysis increments.
#
# DO_UPDATE_BC:
# Flag that determines whether to update boundary conditions based on 
# the analysis results
#
# DO_RADDA:
# Flag that determines whether to assimilate satellite radiance data
#
# DO_BUFRSND:
# Decide whether or not to run EMC BUFR sounding
#
# USE_RRFSE_ENS:
# Use rrfse ensemble for hybrid analysis
#
# DO_SMOKE_DUST:
# Flag turn on smoke and dust for RRFS-SD
#
# EBB_DCYCLE:
# 1: for retro, 2: for forecast
#
# USE_CLM:
# Use CLM mode in the model
#
# DO_NON_DA_RUN:
# Flag that determines whether to run non-DA case.
#
#-----------------------------------------------------------------------
#
DO_DACYCLE="FALSE"
DO_SURFACE_CYCLE="FALSE"
SURFACE_CYCLE_DELAY_HRS="1"
DO_SOIL_ADJUST="FALSE"
DO_UPDATE_BC="FALSE"
DO_RADDA="FALSE"
DO_BUFRSND="FALSE"
USE_RRFSE_ENS="FALSE"
DO_SMOKE_DUST="FALSE"
EBB_DCYCLE="2"
DO_PM_DA="FALSE"
USE_CLM="FALSE"
DO_NON_DA_RUN="FALSE"
#
#-----------------------------------------------------------------------
#
# Set parameters associated with running retrospective experiments.
#
# DO_RETRO:
# Flag turn on the retrospective experiments.
#
# DO_SPINUP:
# Flag turn on the spin-up cycle.
#
# LBCS_ICS_ONLY:
# Flag turn on the runs prepare boundary and cold start initial 
# conditions in retrospective experiments.
#
# DO_POST_SPINUP:
# Flag turn on the UPP for spin-up cycle.
#
# DO_POST_PROD:
# Flag turn on the UPP for prod cycle.
#
# DO_PARALLEL_PRDGEN:
# Flag turn on parallel wgrib2 runs in prdgen .
#
# DO_SAVE_INPUT:
# Decide whether or not to save input along with saving restart files  
#
#-----------------------------------------------------------------------
#
DO_RETRO="FALSE"
DO_SPINUP="FALSE"
LBCS_ICS_ONLY="FALSE"
DO_POST_SPINUP="FALSE"
DO_POST_PROD="TRUE"
DO_PARALLEL_PRDGEN="FALSE"
DO_SAVE_INPUT="FALSE"
#
#-----------------------------------------------------------------------
#
# Set default stochastic physics options
# For detailed documentation of these parameters, see:
# https://stochastic-physics.readthedocs.io/en/ufs_public_release/namelist_options.html
#
#-----------------------------------------------------------------------
#
DO_SHUM="FALSE"
DO_SPPT="FALSE"
DO_SKEB="FALSE"
ISEED_SPPT="1"
ISEED_SHUM="2"
ISEED_SKEB="3"
NEW_LSCALE="TRUE"
SHUM_MAG="0.006" #Variable "shum" in input.nml
SHUM_LSCALE="150000"
SHUM_TSCALE="21600" #Variable "shum_tau" in input.nml
SHUM_INT="3600" #Variable "shumint" in input.nml
SPPT_MAG="0.7" #Variable "sppt" in input.nml
SPPT_LOGIT="TRUE"
SPPT_LSCALE="150000"
SPPT_TSCALE="21600" #Variable "sppt_tau" in input.nml
SPPT_INT="3600" #Variable "spptint" in input.nml
SPPT_SFCLIMIT="TRUE"
SKEB_MAG="0.5" #Variable "skeb" in input.nml
SKEB_LSCALE="150000"
SKEB_TSCALE="21600" #Variable "skeb_tau" in input.nml
SKEB_INT="3600" #Variable "skebint" in input.nml
SKEBNORM="1"
SKEB_VDOF="10"
USE_ZMTNBLCK="FALSE"
#
#-----------------------------------------------------------------------
#
# Set default SPP stochastic physics options. Each SPP option is an array,  
# applicable (in order) to the scheme/parameter listed in SPP_VAR_LIST. 
# Enter each value of the array in config.sh as shown below without commas
# or single quotes (e.g., SPP_VAR_LIST=( "pbl" "sfc" "mp" "rad" "gwd" ). 
# Both commas and single quotes will be added by Jinja when creating the
# namelist.
#
# Note that SPP is currently only available for specific physics schemes 
# used in the RAP/HRRR physics suite.  Users need to be aware of which SDF
# is chosen when turning this option on. 
#
# Patterns evolve and are applied at each time step.
#
#-----------------------------------------------------------------------
#
DO_SPP="FALSE"
SPP_VAR_LIST=( "pbl" "sfc" "mp" "rad" "gwd" ) 
SPP_MAG_LIST=( "0.2" "0.2" "0.75" "0.2" "0.2" ) #Variable "spp_prt_list" in input.nml
SPP_LSCALE=( "150000.0" "150000.0" "150000.0" "150000.0" "150000.0" )
SPP_TSCALE=( "21600.0" "21600.0" "21600.0" "21600.0" "21600.0" ) #Variable "spp_tau" in input.nml
SPP_SIGTOP1=( "0.1" "0.1" "0.1" "0.1" "0.1")
SPP_SIGTOP2=( "0.025" "0.025" "0.025" "0.025" "0.025" )
SPP_STDDEV_CUTOFF=( "1.5" "1.5" "2.5" "1.5" "1.5" ) 
ISEED_SPP=( "4" "5" "6" "7" "8" )
LNDPINT="3600"
SPPINT="3600"
#
#-----------------------------------------------------------------------
#
# Turn on SPP in Noah or RUC LSM (support for Noah MP is in progress).
# Please be aware of the SDF that you choose if you wish to turn on LSM
# SPP.
#
# SPP in LSM schemes is handled in the &nam_sfcperts namelist block 
# instead of in &nam_sppperts, where all other SPP is implemented.
#
# The default perturbation frequency is determined by the fhcyc namelist 
# entry.  Since that parameter is set to zero in the SRW App, use 
# LSM_SPP_EACH_STEP to perturb every time step. 
#
# Perturbations to soil moisture content (SMC) are only applied at the  
# first time step.
#
# LSM perturbations include SMC - soil moisture content (volume fraction),
# VGF - vegetation fraction, ALB - albedo, SAL - salinity, 
# EMI - emissivity, ZOL - surface roughness (cm), and STC - soil temperature.
#
# Only five perturbations at a time can be applied currently, but all seven
# are shown below.  In addition, only one unique iseed value is allowed 
# at the moment, and is used for each pattern.
#
DO_LSM_SPP="FALSE" #If true, sets lndp_type=2
LSM_SPP_TSCALE=( "21600" "21600" "21600" "21600" "21600" )
LSM_SPP_LSCALE=( "150000" "150000" "150000" "150000" "150000" )
ISEED_LSM_SPP=( "9" )
LSM_SPP_VAR_LIST=( "smc" "vgf" "alb" "sal" "emi" "zol" "stc" )
LSM_SPP_MAG_LIST=( "0.2" "0.001" "0.001" "0.001" "0.001" "0.001" "0.2" )
LSM_SPP_EACH_STEP="TRUE" #Sets lndp_each_step=.true.
#
#-----------------------------------------------------------------------
# 
# HALO_BLEND:
# Number of rows into the computational domain that should be blended 
# with the LBCs.  To shut halo blending off, this can be set to zero.
#
#-----------------------------------------------------------------------
#
HALO_BLEND=10
#
#-----------------------------------------------------------------------
# 
# PRINT_DIFF_PGR:
# Option to turn on/off pressure tendency diagnostic
#
#-----------------------------------------------------------------------
#
PRINT_DIFF_PGR=FALSE
#
#-----------------------------------------------------------------------
#
# USE_FVCOM:
# Flag set to update surface conditions in FV3-LAM with fields generated
# from the Finite Volume Community Ocean Model (FVCOM). This will
# replace lake/sea surface temperature, ice surface temperature, and ice
# placement. FVCOM data must already be interpolated to the desired
# FV3-LAM grid. This flag will be used in make_ics to modify sfc_data.nc
# after chgres_cube is run by running the routine process_FVCOM.exe
#
# PREP_FVCOM:
# Flag set to interpolate FVCOM data to the desired FV3-LAM grid.
#
# FVCOM_DIR:
# User defined directory where FVCOM data already interpolated to FV3-LAM
# grid is located. File name in this path should be "fvcom.nc" to allow
#
# FVCOM_FILE:
# Name of file located in FVCOM_DIR that has FVCOM data interpolated to 
# FV3-LAM grid. This file will be copied later to a new location and name
# changed to fvcom.nc
#
#------------------------------------------------------------------------
#
USE_FVCOM="FALSE"
PREP_FVCOM="FALSE"
FVCOM_DIR="/user/defined/dir/to/fvcom/data"
FVCOM_FILE="fvcom.nc"
#
#-----------------------------------------------------------------------
#
# Set parameters associated with aerosol LBCs.
#
# COMINgefs:
# Path to GEFS aerosol data files
# Typical path: COMINgefs/gefs.YYYYMMDD/HH/chem/sfcsig/
# Typical file name: geaer.t00z.atmf000.nemsio
#
# GEFS_AEROSOL_FILE_PREFIX:
# Prefix of GEFS aerosol data files (default: geaer)
#
# GEFS_AEROSOL_FILE_FMT:
# File format of GEFS aerosol data (default: nemsio)
#
# GEFS_AEROSOL_INTVL_HRS:
# The interval (in integer hous) of the GEFS aerosol data files
#
# GEFS_AEROSOL_FILE_CYC:
# Cycle of GEFS aerosol data files (HH in the above file path).
# This is useful in case that limited cycle data are available. If this 
# is not set, the current cycle (cyc) will be used for this variable.
#
#-----------------------------------------------------------------------
#
COMINgefs=""
GEFS_AEROSOL_FILE_PREFIX="geaer"
GEFS_AEROSOL_FILE_FMT="nemsio"
GEFS_AEROSOL_INTVL_HRS="3"
GEFS_AEROSOL_FILE_CYC="00"
#
#-----------------------------------------------------------------------
#
# COMPILER:
# Type of compiler invoked during the build step. 
#
#------------------------------------------------------------------------
#
COMPILER="intel"
#
#-----------------------------------------------------------------------
#
# GWD_HRRRsuite_BASEDIR:
# Temporary workflow variable specifies the base directory in which to 
# look for certain fixed orography statistics files needed only by the 
# gravity wave drag parameterization in the FV3_HRRR physics suite. This 
# variable is added in order to avoid including hard-coded paths in the 
# workflow scripts.  Currently, the workflow simply copies the necessary 
# files from a subdirectory under this directory (named according to the 
# specified predefined grid) to the orography directory (OROG_DIR) under 
# the experiment directory.  
#
# Note that this variable is only used when using the FV3_HRRR physics 
# suite.  It should be removed from the workflow once there is a script 
# or code available that generates these files for any grid.
#
#-----------------------------------------------------------------------
#
GWD_HRRRsuite_BASEDIR=""
#
#-----------------------------------------------------------------------
#
# Parameters for JEDI options
#
# DO_JEDI_ENVAR_IODA:
# Flag turn on the JEDI-IODA converters for EnVAR.  It requires GSI 
# to produce NetCDF diag files
#-----------------------------------------------------------------------
#
DO_JEDI_ENVAR_IODA="FALSE"
#
#-----------------------------------------------------------------------
#
# Parameters for IODA options
#
# DO_IODA_PREPBUFR:
# Flag turn on the IODA converters for conventional observations in prepbufr files.
#-----------------------------------------------------------------------
#
DO_IODA_PREPBUFR="FALSE"
#
#-----------------------------------------------------------------------
#
# Parameters for analysis options
#
# DO_NONVAR_CLDANAL: 
# Flag turn on the non-var cloud analysis.
#
# DO_REFL2TTEN: 
# Flag turn on the radar reflectivity to temperature tendenecy.
#
# DO_NLDN_LGHT
# Flag turn on processing NLDN NetCDF lightning data
# DO_GLM_FED_DA
# Flag turn on processing gridded GLM lightning data
# GLMFED_DATA_MODE
# Incoming lightning data format: FULL (full-disk), TILES, or PROD (tiles
# with different naming convention)      
# PREP_MODEL_FOR_FED
# For the ensemble workflow: add flash_extent_density field to ensemble
# member RESTART files so control member EnVar can use as BEC
#
#-----------------------------------------------------------------------
#
DO_NONVAR_CLDANAL="FALSE"
DO_REFL2TTEN="FALSE"
DO_NLDN_LGHT="FALSE"
DO_GLM_FED_DA="FALSE"
GLMFED_DATA_MODE="FULL"
PREP_MODEL_FOR_FED="FALSE"
DO_SMOKE_DUST="FALSE"
EBB_DCYCLE="2"
DO_PM_DA="FALSE"
#
#-----------------------------------------------------------------------
#
# Parameters for observation preprocess.
#
# RADARREFL_MINS:
# minute from the hour that the NSSL mosaic files will be searched for 
# data preprocess
#
# RADARREFL_TIMELEVEL:
# time level (minute) from the hour that the NSSL mosaic files will be 
# generated 
#
#-----------------------------------------------------------------------
#
RADARREFL_MINS=(0 1 2 3)
RADARREFL_TIMELEVEL=(0)
#
#-----------------------------------------------------------------------
#
# Parameters for cleaning the real-time and retrospective runs.
#
# CLEAN_OLDPROD_HRS:
# the product under com directory from cycles older than 
# (current cycle - this hour) will be cleaned 
#
# CLEAN_OLDLOG_HRS:
# the log files under com directory from cycles older than 
# (current cycle - this hour) will be cleaned 
#
# CLEAN_OLDRUN_HRS:
# the run directory under tmpnwprd directory from cycles older than 
# (current cycle - this hour) will be cleaned 
#
# CLEAN_OLDFCST_HRS:
# the fv3lam forecast netcdf files forecast run directory from cycles 
# older than (current cycle - this hour) will be cleaned 
#
# CLEAN_OLDSTMP_HRS
# the postprd GRIB-2 files from cycles older than 
# (current cycle - this hour) will be cleaned 
#-----------------------------------------------------------------------
#
CLEAN_OLDPROD_HRS="72"
CLEAN_OLDLOG_HRS="72"
CLEAN_OLDRUN_HRS="48"
CLEAN_OLDFCST_HRS="24"
CLEAN_OLDSTMPPOST_HRS="24"
CLEAN_NWGES_HRS="72"

