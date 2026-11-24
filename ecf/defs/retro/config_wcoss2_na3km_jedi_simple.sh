#!/bin/bash
#
# Simple deterministic JEDI retro on WCOSS2.
#
# Link or copy this configuration to ecf/defs/retro/config.sh and adjust paths and server.
#
# This is the ecflow equivalent of the Rocoto workflow's ush/config.sh, for the parts we control.
# It is sourced by ush/retro/setup_retro_links.sh, ecf/defs/retro/make_rrfs_retro_def.sh,
# ush/prod_clone/make_retro_def.sh and ush/retro/start_retro.sh, so edit values here instead of
# passing them on every command line. Most settings honor environment overrides, so one-off runs
# can still say e.g.
#
#   RETRO_START=20240510 ./make_rrfs_retro_def.sh
#
# What is NOT here, because the suite reads it at run time rather than at generation time:
#   fix/workflow/<WGF>/workflow.conf   job resources (NNODES_*, PPN_*, TPP_*) and science switches;
#                                      setup_ecf_links.sh copies the _prod or _dev version per
#                                      RESOURCE_CONFIG and applies the machine and retro overrides
#   versions/run.ver                   software versions used by the job cards
#
# ---------------------------------------------------------------------------------------------
# Machine
# ---------------------------------------------------------------------------------------------
# Sets how jobs are submitted and which machine-specific job settings setup_retro_links.sh applies.
# URSA or WCOSS2.
MACHINE=${MACHINE:-WCOSS2}

# ---------------------------------------------------------------------------------------------
# Where the workflow writes
# ---------------------------------------------------------------------------------------------
# Give this experiment its own suite, work area, and archive directory. NA 3 km output can
# require tens of TB per week; the default ptmp location has a purge policy.
EXPT_ID=${EXPT_ID:-det_na3km_3dvar_jedi_simple}
RRFS_SUITE=${RRFS_SUITE:-${EXPT_ID}}
PRODCLONE_SUITE=${PRODCLONE_SUITE:-${RRFS_SUITE}_prod_clone}

# Keep model COM output under ptmp and job working files under stmp.
RETRO_WORK_ROOT=${RETRO_WORK_ROOT:-/lfs/h2/emc/ptmp/${USER}/ecflow_rrfs}
RETRO_WORK_BASE=${RETRO_WORK_BASE:-${RETRO_WORK_ROOT}/${EXPT_ID}}

# ecflow job files and their output (the server creates the task directories underneath)
# Keep the shared server workspace and checkpoints on persistent noscrub storage.
# The ecFlow software module also uses ECF_ROOT, so ECF_DATA_ROOT identifies our workspace.
export ECF_DATA_ROOT=${ECF_DATA_ROOT:-/lfs/h2/emc/da/noscrub/${USER}/ecflow}
export ECF_ROOT=${ECF_DATA_ROOT}
export ECF_HOME=${ECF_HOME:-${ECF_DATA_ROOT}/submit}
export ECF_OUTPUTDIR=${ECF_OUTPUTDIR:-${ECF_DATA_ROOT}/output}
export ECF_COMDIR=${ECF_COMDIR:-${ECF_HOME}}
export LFS_OUTPUTDIR=${LFS_OUTPUTDIR:-${ECF_HOME}}
# Separate experiment output beneath the shared output directory.
OUTPUTDIR=${OUTPUTDIR:-${ECF_OUTPUTDIR}/${EXPT_ID}}
# COM output is rooted under this experiment's work base; the user and suite are appended.
DEV_PTMP=${DEV_PTMP:-${RETRO_WORK_BASE}/ptmp}
# job working directories (DATAROOT). In stmp rather than under RETRO_WORK_BASE, which is in
# ptmp: a job's working directory is scratch for as long as that job runs, which is what stmp is
# for, and it keeps the COM output and the working directories on separate filesystems the way
# the Rocoto retros do (their STMP and PTMP).
RETRO_STMP_ROOT=${RETRO_STMP_ROOT:-/lfs/h2/emc/stmp/${USER}/ecflow_rrfs}
DEV_DATAROOT=${DEV_DATAROOT:-${RETRO_STMP_ROOT}/${EXPT_ID}}

# ---------------------------------------------------------------------------------------------
# PBS
# ---------------------------------------------------------------------------------------------
PROJ=${PROJ:-RRFS}                        # the cards add -DEV: "-A RRFS-DEV"
QUEUE=${QUEUE:-dev}
QUEUE_ARCH=${QUEUE_ARCH:-dev_transfer} # HPSS transfers use the WCOSS2 transfer queue
# NCO keeps the production job sizes (115-node forecasts); EMC selects the smaller dev resources
# and 52-node forecast layouts that EMC's WCOSS2 parallels run.
RESOURCE_CONFIG=${RESOURCE_CONFIG:-EMC}

# ---------------------------------------------------------------------------------------------
# ecflow
# ---------------------------------------------------------------------------------------------
# Start the server with NCO's server_check.sh, run on (ssh to) an ecflow host of whichever machine
# is currently the development one: cdecflow01/02 for Cactus, ddecflow01/02 for Dogwood. After a
# production switch the other machine's hosts refuse the login. Its port is your uid + 2000.
# ECFLOW_VER must be a version "module avail ecflow" lists, since every job loads it.
ECFLOW_VER=${ECFLOW_VER:-5.6.0.14}
ECFLOW_HOST=${ECFLOW_HOST:-${ECF_HOST:-cdecflow01}}    # host running the server (head.h reads it as ECF_LOGHOST)
export ECF_HOST=${ECFLOW_HOST}

# ---------------------------------------------------------------------------------------------
# Input data
# ---------------------------------------------------------------------------------------------
# fix tree; setup_retro_links.sh links <repo>/fix to it. The production package's tree has the
# workflow.conf_dev and _prod files the retro needs; NCO may remove a version once the next is
# installed, so update the version here (or link a copy of your own) when the links break.
FIX_RRFS_DIR=${FIX_RRFS_DIR:-/lfs/h1/ops/prod/packages/rrfs.v1.0.29/fix}
# dev-sci's shared fix tree; the domain files (ecf/defs/retro/domains) link other grids' fix files
# from it
FIX_RRFS_SHARED=${FIX_RRFS_SHARED:-/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS}
# staged upstream data in NCO COM/DCOM layout (see make_links.sh in that directory)
RETRO_DATA_ROOT=${RETRO_DATA_ROOT:-/lfs/h2/emc/lam/noscrub/samuel.degelia/RRFS_RETRO_DATA_NCO}
DOMAIN=${DOMAIN:-RRFS_NA_3km}

# ---------------------------------------------------------------------------------------------
# Retro period and suite
# ---------------------------------------------------------------------------------------------
# Cycles run at once; increasing beyond 2 could break satbias cycling
# Chains run back to back below 13; 13 or more lets the next chain start alongside the current one
RETRO_START=${RETRO_START:-20240506}      # first retro day, and the day that cold starts
RETRO_END=${RETRO_END:-20240506}          # last retro day
# Debug through the 01z analysis using the 00z cold-start forecast.
RETRO_END_HOUR=${RETRO_END_HOUR:-01}
STOP_AFTER_ANALYSIS=${STOP_AFTER_ANALYSIS:-TRUE}
CYCLE_THROTTLE=${CYCLE_THROTTLE:-1}
# YES relaxes the suite's 399 clock-time triggers so cycles are not gated on the wall clock
RETRO=${RETRO:-YES}

# Which workflow groups to run. FALSE gives that group's families defstatus complete.
# The ensemble forecast recenters on EnKF output; a disabled EnKF can use staged data instead.
# The CONUS 13 km domain cannot run fire weather because it does not write hour-0 natlev output.
RUN_ENKF=${RUN_ENKF:-FALSE}
RUN_ENSF=${RUN_ENSF:-FALSE}
RUN_FIREWX=${RUN_FIREWX:-FALSE}

# Two task types no retro needs; off as on Ursa. Both may work on WCOSS2, where operations
# runs them.
RUN_GEMPAK=${RUN_GEMPAK:-FALSE}
RUN_BUFRSND=${RUN_BUFRSND:-FALSE}
# Smoke and dust need fix/smoke_dust/<grid>/grid_in.nc: available for NA 3 km but
# unavailable for CONUS 13 km, where process_smoke would fail.
RUN_SMOKE=${RUN_SMOKE:-TRUE}

# Controls the 00, 06, 12, and 18z deterministic forecasts; FCST_LEN_HRS_LONG sets their length.
# Fire weather requires these forecasts.
DO_LONG_FORECAST=${DO_LONG_FORECAST:-TRUE}

# Simplified deterministic workflow settings. Disabled tasks pass their dependencies to the
# following tasks; setup_retro_links.sh applies the matching workflow switches.
# Spin-up cycles and their forecasts; without them, cold starts use DET_COLD_START_HRS.
DO_SPINUP=${DO_SPINUP:-FALSE}
DET_COLD_START_HRS=${DET_COLD_START_HRS:-"00 12"}
EXTRN_MDL_ICS_OFFSET_HRS=${EXTRN_MDL_ICS_OFFSET_HRS:-6}
GFS_FILE_FMT_ICS=${GFS_FILE_FMT_ICS:-grib2}
DO_SURFACE_CYCLE=${DO_SURFACE_CYCLE:-TRUE}
# Forecast lengths in hours for hourly and 00, 06, 12, and 18z cycles. Three hours is the
# minimum for warm starts from the previous three cycles.
FCST_LEN_HRS=${FCST_LEN_HRS:-3}
FCST_LEN_HRS_LONG=${FCST_LEN_HRS_LONG:-3}
# Switch individual deterministic cycle steps on or off.
RUN_NONVARCLD=${RUN_NONVARCLD:-FALSE}  # non-variational cloud analysis (DO_NONVAR_CLDANAL)
RUN_UPDATE_BC=${RUN_UPDATE_BC:-FALSE}  # boundary update and soil adjustment (DO_UPDATE_BC)
RUN_GSIDIAG=${RUN_GSIDIAG:-TRUE}  # offline GSI diagnostics (DO_GSIDIAG_OFFLINE)
RUN_LIGHTNING=${RUN_LIGHTNING:-FALSE}  # GLM flash extent density and DA (DO_GLM_FED_DA)
DO_RADDA=${DO_RADDA:-FALSE}  # satellite radiance DA
RUN_RADAR=${RUN_RADAR:-FALSE}  # radar DA
# Match GSI observation selection to radar processing unless the experiment sets OB_TYPE directly.
if [ -z "${OB_TYPE:-}" ]; then
  if [ "${RUN_RADAR}" = "TRUE" ]; then
    OB_TYPE=conv_dbz
  else
    OB_TYPE=conv
  fi
fi
RUN_POST=${RUN_POST:-TRUE}  # post and products; FALSE for a DA-only run
# The simple retro only needs on-the-hour deterministic post outputs.
RUN_SUBHOURLY_POST=${RUN_SUBHOURLY_POST:-FALSE}
# Archive completed deterministic cycles separately for each experiment.
DO_ARCHIVE_RETRO=${DO_ARCHIVE_RETRO:-TRUE}
# HPSS may require the RDHPCS account spelling rather than the WCOSS2 username.
RDHPCS_USER=${RDHPCS_USER:-Donald.E.Lippi}
ARCHIVE_ROOT=${ARCHIVE_ROOT:-/NCEPDEV/emc-meso/5year/${RDHPCS_USER}/RRFSv1/May2024_retro/v1.2.0}
ARCHIVEDIR=${ARCHIVEDIR:-${ARCHIVE_ROOT}/${EXPT_ID}}
# JEDI analysis, the Rocoto config.sh "JEDI options". DA_SYSTEM_DET picks which det analysis
# runs, GSI (the operational route) or JEDI; the rest are read only when it is JEDI.
# setup_retro_links.sh writes them into det/workflow.conf and make_rrfs_retro_def.sh sizes the
# job from them.
DA_SYSTEM_DET=${DA_SYSTEM_DET:-JEDI}
# JCB templates in parm/jedi select the conventional and reflectivity analyses. The CONUS
# grid also has a hybrid template; the NA 3 km grid currently has a 3DVar template.
JCB_CONFIG_CONV=${JCB_CONFIG_CONV:-rdas-atmosphere-templates-fv3_na3km.yaml}
JCB_CONFIG_DBZ=${JCB_CONFIG_DBZ-}
# Whether the analysis also runs on cold-start cycles, and whether synthetic radiosonde
# temperature and humidity levels are added the way GSI's sonde_ext does
DO_DACOLD=${DO_DACOLD:-FALSE}
EXT_SONDE=${EXT_SONDE:-TRUE}
# JEDI job size: nodes x tasks per node must match the template layout.
# CONUS 13 km uses 14x14 (196 tasks); NA 3 km uses 40x40 (1600 tasks).
NNODES_ANALYSIS_JEDI=${NNODES_ANALYSIS_JEDI:-25}
PPN_ANALYSIS_JEDI=${PPN_ANALYSIS_JEDI:-64}
TPP_ANALYSIS_JEDI=${TPP_ANALYSIS_JEDI:-1}
WALLTIME_ANALYSIS_JEDI=${WALLTIME_ANALYSIS_JEDI:-00:50:00}
# JEDI EnKF. DA_SYSTEM_ENKF picks which EnKF analysis runs, GSI or JEDI (GETKF), independent of
# DA_SYSTEM_DET; the rest are read only when it is JEDI. setup_retro_links.sh writes them into
# enkf/workflow.conf.
DA_SYSTEM_ENKF=${DA_SYSTEM_ENKF:-GSI}
JCB_CONFIG_ENKF=${JCB_CONFIG_ENKF:-rdas-atmosphere-templates-fv3_na3km_getkf.yaml}
NNODES_ANALYSIS_ENKF_JEDI=${NNODES_ANALYSIS_ENKF_JEDI:-48}
PPN_ANALYSIS_ENKF_JEDI=${PPN_ANALYSIS_ENKF_JEDI:-40}
TPP_ANALYSIS_ENKF_JEDI=${TPP_ANALYSIS_ENKF_JEDI:-1}
WALLTIME_ANALYSIS_ENKF_JEDI=${WALLTIME_ANALYSIS_ENKF_JEDI:-01:00:00}

# YES keeps the working directories under stmp after jobs finish (sets KEEPDATA and KEEP_TMP)
KEEPDATA=${KEEPDATA:-YES}

# suite definition to copy, relative to ecf/defs
BASE_DEF=${BASE_DEF:-nco_para/rrfs_nco_para.def}
RRFS_VER=${RRFS_VER:-v1.0}
ENVIR=${ENVIR:-prod}
MACHINE_SITE=${MACHINE_SITE:-development}
