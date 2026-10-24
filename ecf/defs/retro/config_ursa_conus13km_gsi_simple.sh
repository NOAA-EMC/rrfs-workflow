#!/bin/bash
#
# Sample settings for a simplified RRFS_CONUS_13km retro on Ursa: deterministic 3DVar cycling
# only, with the ensemble for the hybrid analysis read from a staged one rather than produced by
# this suite.
#
# It is config_ursa_conus13km.sh with the "Simplified workflow" block below added and
# the EnKF and ensemble forecast switched off; everything above that block is the same, so change
# the paths and account in the first blocks to your own as usual. It follows the Rocoto workflow's
# ush/sample_configs/RRFS_v1.2/config_rrfs_c_13km_det_retro_simple_tuv_dbz_gsi.sh as closely as
# the two workflows allow; the block below says where they differ.
#
# This is the ecflow equivalent of the Rocoto workflow's ush/config.sh, for the parts we control.
# It is sourced by ush/retro/setup_retro_links.sh, ecf/defs/retro/make_rrfs_retro_def.sh,
# ush/prod_clone/make_retro_def.sh and ush/retro/start_retro.sh, so edit values here instead of
# passing them on every command line. Anything already set in the environment wins, so one-off runs
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
MACHINE=${MACHINE:-URSA}

# Keep each DA experiment's ecFlow suites, work files, COM output, and archive separate. Use a
# separate checkout for each experiment because setup_retro_links.sh writes generated config there.
EXPT_ID=${EXPT_ID:-det_c13_3dvar_gsi_ecflow_test}
RRFS_SUITE=${RRFS_SUITE:-${EXPT_ID}}
PRODCLONE_SUITE=${PRODCLONE_SUITE:-${RRFS_SUITE}_prod_clone}

# ---------------------------------------------------------------------------------------------
# Where the workflow writes
# ---------------------------------------------------------------------------------------------
# Everything this experiment produces hangs off its own base directory. Override RETRO_WORK_BASE
# when a run needs a different filesystem or layout.
RETRO_WORK_ROOT=${RETRO_WORK_ROOT:-/scratch4/NCEPDEV/fv3-cam/${USER}/ecflow_rrfs}
RETRO_WORK_BASE=${RETRO_WORK_BASE:-${RETRO_WORK_ROOT}/${EXPT_ID}}

# ecflow job files and their output (the server creates the task directories underneath)
ECF_HOME=${ECF_HOME:-${RETRO_WORK_BASE}/submit}
OUTPUTDIR=${OUTPUTDIR:-${RETRO_WORK_BASE}/output}
# COM output. envir-p1.h appends the user, package slot, suite name, and com directory.
DEV_PTMP=${DEV_PTMP:-${RETRO_WORK_BASE}/ptmp}
# job working directories (DATAROOT)
DEV_DATAROOT=${DEV_DATAROOT:-${RETRO_WORK_BASE}/stmp}

# ---------------------------------------------------------------------------------------------
# Slurm
# ---------------------------------------------------------------------------------------------
PROJ=${PROJ:-fv3-cam}                     # account
QUEUE=${QUEUE:-batch}                     # QOS
PARTITION=${PARTITION:-u1-compute}
# NCO keeps the production job sizes; EMC selects the smaller dev resources and the 52-node
# forecast layouts, which is what fits Ursa's 75-node per-job limit.
RESOURCE_CONFIG=${RESOURCE_CONFIG:-EMC}

# ---------------------------------------------------------------------------------------------
# ecflow
# ---------------------------------------------------------------------------------------------
ECFLOW_VER=${ECFLOW_VER:-5.11.4}
ECFLOW_HOST=${ECFLOW_HOST:-uecflow01}     # host running the server (head.h reads it as ECF_LOGHOST)

# ---------------------------------------------------------------------------------------------
# Input data
# ---------------------------------------------------------------------------------------------
# fix tree; setup_retro_links.sh links <repo>/fix to it
FIX_RRFS_DIR=${FIX_RRFS_DIR:-/scratch4/NCEPDEV/fv3-cam/Shun.Liu/fix_nco_wcoss}
# dev-sci's shared fix tree; the domain files (ecf/defs/retro/domains) link other grids' fix files
# from it
FIX_RRFS_SHARED=${FIX_RRFS_SHARED:-/scratch4/BMC/rtrr/FIX_RRFS}
# staged upstream data in NCO COM/DCOM layout (see make_links.sh in that directory)
RETRO_DATA_ROOT=${RETRO_DATA_ROOT:-/scratch4/BMC/zrtrr/Samuel.Degelia/RRFS_RETRO_DATA_NCO}
# Coarser domains (strip when merging to the nco branch): the model domain. RRFS_NA_3km
# is the operational v1 domain and changes nothing; any other value needs
# ecf/defs/retro/domains/<DOMAIN>.sh with its grid, fix files and job sizes.
DOMAIN=${DOMAIN:-RRFS_CONUS_13km}

# ---------------------------------------------------------------------------------------------
# Retro period and suite
# ---------------------------------------------------------------------------------------------
RETRO_START=${RETRO_START:-20240506}      # first retro day, and the day that cold starts
RETRO_END=${RETRO_END:-20240506}          # last retro day
# YES relaxes the suite's 399 clock-time triggers so cycles are not gated on the wall clock
RETRO=${RETRO:-YES}

# Which workflow groups to run. FALSE gives that group's families defstatus complete, so they
# never run and nothing waiting on them blocks. Operations runs all of them.
# The EnKF is off: this retro reads a staged ensemble instead (RRFSE_NWGES below), which is what
# makes it worth running on its own. The ensemble forecast recenters on EnKF output, so it goes
# with it.
RUN_ENKF=${RUN_ENKF:-FALSE}
RUN_ENSF=${RUN_ENSF:-FALSE}
# Fire weather starts from the parent forecast's hour-0 natlev file, which this domain's 90 s
# step never writes, so it cannot run here; the generator refuses TRUE.
RUN_FIREWX=${RUN_FIREWX:-FALSE}

# Two task types no retro needs, off by default on Ursa because neither works here:
#   gempak   exrrfs_gempak.sh launches "mpiexec -configfile", the WCOSS2 cfp idiom, and has no
#            srun arm, so every task exits 255
#   bufrsnd  the station list fix/bufrsnd/<grid>/rrfs_profdat.<NSTAT> exists only for some grids,
#            and on RRFS_NA_3km the 84 h sounding job runs past its 3 h card limit
RUN_GEMPAK=${RUN_GEMPAK:-FALSE}
RUN_BUFRSND=${RUN_BUFRSND:-FALSE}
# Coarser domains (strip when merging to the nco branch): smoke and dust need
# fix/smoke_dust/<grid>/grid_in.nc, which dev-sci provides for the 3 km grids but not for
# RRFS_CONUS_13km, where process_smoke fails with FileNotFoundError on that file. The default is
# TRUE, so the NA sample is unaffected.
RUN_SMOKE=${RUN_SMOKE:-FALSE}

# The deterministic forecast at 00z, 06z, 12z and 18z (FCST_LEN_HRS_LONG below, 84 h in
# operations), with its post, product generation and restarts. FALSE leaves the hourly forecasts
# (FCST_LEN_HRS) alone. At the operational lengths it is the one setting that shortens a retro
# noticeably, the long forecast being 67 of the 81 minutes on each 6-hourly family's critical
# path; shortening it with FCST_LEN_HRS_LONG instead, as here, buys most of that and keeps the
# four long cycles honest. Fire weather takes its initial and boundary conditions from the long
# forecast's post, so RUN_FIREWX must be FALSE as well, and the generator says so if it is not.
DO_LONG_FORECAST=${DO_LONG_FORECAST:-TRUE}

# ---------------------------------------------------------------------------------------------
# Simplified workflow
# ---------------------------------------------------------------------------------------------
# What follows cuts the suite down to the deterministic cycling run the Rocoto retros call a
# simple configuration (ush/sample_configs/RRFS_v1.2 in the Rocoto workflow).
# ecf/defs/retro/make_rrfs_retro_def.sh takes the tasks out of the suite definition and
# ush/retro/setup_retro_links.sh turns the matching switches off in fix/workflow/det/workflow.conf,
# both from the settings here, so the two halves cannot disagree.
#
# A task switched off here is given "defstatus complete", and every trigger that named it is
# rewritten: a step taken out of the middle of a chain hands on its own dependencies, so what
# followed it keeps its place in the order rather than starting as soon as the cycle opens.

# The deterministic spin-up cycles (03-08z and 15-20z in operations) and their 1 h forecasts.
# With them off, the cold start moves into the production cycle at DET_COLD_START_HRS, which
# exrrfs_prep_cyc.sh and exrrfs_process_radar.sh already do when DO_SPINUP is FALSE.
DO_SPINUP=${DO_SPINUP:-FALSE}
# Which cycles cold start from GFS. They have to be hours that have a make_ics task in the suite,
# which means 03z and 15z: the initial conditions come from the GFS cycle 3 h earlier
# (EXTRN_MDL_ICS_OFFSET_HRS) and only gfs.tHHz.atmf003.nc from the 00, 06, 12 and 18z cycles is
# staged. The Rocoto configurations cold start at 00z and 12z instead, which here would need
# atmf006 and sfcf006 staged from the 18z and 06z GFS and the make_ics task moved into the
# previous primary family, whose date the retro driver has already stepped past.
DET_COLD_START_HRS=${DET_COLD_START_HRS:-"03 15"}

# Forecast length in hours: the hourly cycles, and the 00, 06, 12 and 18z cycles. Operations runs
# 18 and 84. The post, product generation and boundary jobs past the end of the forecast come out
# of the definition, so these are what make a retro day short rather than just lighter. Three
# hours is the minimum: each cycle warm starts from the hour 1, 2 or 3 restart of one of the
# three cycles before it.
FCST_LEN_HRS=${FCST_LEN_HRS:-3}
FCST_LEN_HRS_LONG=${FCST_LEN_HRS_LONG:-12}

# Steps inside a cycle, each the ecflow side of one of the FALSE switches in the Rocoto config.sh.
RUN_NONVARCLD=${RUN_NONVARCLD:-FALSE}     # non-variational cloud analysis (DO_NONVAR_CLDANAL)
RUN_UPDATE_BC=${RUN_UPDATE_BC:-FALSE}     # boundary update and soil adjustment (DO_UPDATE_BC)
RUN_GSIDIAG=${RUN_GSIDIAG:-TRUE}          # offline GSI diagnostics (DO_GSIDIAG_OFFLINE)
RUN_LIGHTNING=${RUN_LIGHTNING:-FALSE}     # GLM flash extent density and its DA (DO_GLM_FED_DA)
RUN_RADAR=${RUN_RADAR:-TRUE}              # MRMS reflectivity; this configuration assimilates it
RUN_POST=${RUN_POST:-TRUE}                # post and products; FALSE for a DA-only run
# The simple retro only needs on-the-hour deterministic post outputs.
RUN_SUBHOURLY_POST=${RUN_SUBHOURLY_POST:-FALSE}
# Archive each completed deterministic cycle to HPSS, following the Rocoto retro layout.
DO_ARCHIVE_RETRO=${DO_ARCHIVE_RETRO:-TRUE}
ARCHIVE_ROOT=${ARCHIVE_ROOT:-/NCEPDEV/emc-meso/5year/${USER}/RRFSv1/May2024_retro/v1.2.0}
ARCHIVEDIR=${ARCHIVEDIR:-${ARCHIVE_ROOT}/${EXPT_ID}}
# JEDI analysis, the Rocoto config.sh "JEDI options". DA_SYSTEM picks which analysis runs, GSI
# (the operational route) or JEDI; the rest are read only when it is JEDI. setup_retro_links.sh
# writes them into det/workflow.conf and make_rrfs_retro_def.sh sizes the job from them.
DA_SYSTEM=${DA_SYSTEM:-GSI}
# JCB templates in parm/jedi that the analysis renders its yaml from, conventional and
# reflectivity. The conventional one decides 3DVar or hybrid: for hybrid 3DEnVar with the
# 30 EnKF members use rdas-atmosphere-templates-fv3_c13_hybrid.yaml.
JCB_CONFIG_CONV=${JCB_CONFIG_CONV:-rdas-atmosphere-templates-fv3_c13.yaml}
JCB_CONFIG_DBZ=${JCB_CONFIG_DBZ-rdas-atmosphere-templates-fv3_c13_dbz.yaml}
# Whether the analysis also runs on cold-start cycles, and whether synthetic radiosonde
# temperature and humidity levels are added the way GSI's sonde_ext does
DO_DACOLD=${DO_DACOLD:-FALSE}
EXT_SONDE=${EXT_SONDE:-FALSE}
# Job size. Nodes x tasks per node must match the template's layout,
# the 14x14 layout in the c13 templates: 196 tasks
NNODES_ANALYSIS_JEDI=${NNODES_ANALYSIS_JEDI:-2}
PPN_ANALYSIS_JEDI=${PPN_ANALYSIS_JEDI:-98}
TPP_ANALYSIS_JEDI=${TPP_ANALYSIS_JEDI:-1}
WALLTIME_ANALYSIS_JEDI=${WALLTIME_ANALYSIS_JEDI:-00:50:00}

# Anything else to leave out, as space-separated regular expressions matching whole task names
SKIP_TASKS=${SKIP_TASKS:-}

# The ensemble for the hybrid analysis. With RUN_ENKF=FALSE nothing in this suite makes one, so
# point this at a staged ensemble and run ush/retro/link_staged_enkf.sh, which links it where
# exrrfs_analysis_gsi.sh looks for it. Same meaning and same layout as RRFSE_NWGES in the Rocoto
# configurations. Leave it empty to let the analysis fall back to the 80 GDAS members.
RRFSE_NWGES=${RRFSE_NWGES:-/scratch4/NCEPDEV/fv3-cam/runs_co13km/rrfs.v0.8.6/nwges_enkf}
# How many members link_staged_enkf.sh expects to find. The analysis reads its own copy of this
# from workflow.conf, where it is also 30; a staged ensemble of another size needs both changed.
NUM_ENS_MEMBERS=${NUM_ENS_MEMBERS:-30}

# YES keeps the working directories under stmp after jobs finish (sets KEEPDATA and KEEP_TMP)
KEEPDATA=${KEEPDATA:-YES}

# suite definition to copy, relative to ecf/defs
BASE_DEF=${BASE_DEF:-nco_para/rrfs_nco_para.def}
RRFS_VER=${RRFS_VER:-v1.0}
ENVIR=${ENVIR:-prod}
MACHINE_SITE=${MACHINE_SITE:-development}
