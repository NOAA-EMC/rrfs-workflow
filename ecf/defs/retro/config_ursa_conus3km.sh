#!/bin/bash
#
# Sample settings for an RRFS_CONUS_3km retro on Ursa.
#
# This is the configuration the CONUS 3 km retro day on this branch was tested with. It
# differs from config_ursa_na3km.sh only in DOMAIN.
# Link or copy it to ecf/defs/retro/config.sh and change the paths and account in the first three
# blocks to your own; everything below them is what the tested run used.
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

# ---------------------------------------------------------------------------------------------
# Where the workflow writes
# ---------------------------------------------------------------------------------------------
# Everything this run produces hangs off one base directory.
RETRO_WORK_BASE=${RETRO_WORK_BASE:-/scratch4/NCEPDEV/fv3-cam/${USER}/ecflow_rrfs}

# ecflow job files and their output (the server creates the task directories underneath)
ECF_HOME=${ECF_HOME:-${RETRO_WORK_BASE}/submit}
OUTPUTDIR=${OUTPUTDIR:-${RETRO_WORK_BASE}/output}
# COM output. envir-p1.h builds COMROOT as ${DEV_PTMP}/${USER}/ecflow_rrfs/para/com, so this is a
# base directory and the user and suite names are appended to it.
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
DOMAIN=${DOMAIN:-RRFS_CONUS_3km}

# ---------------------------------------------------------------------------------------------
# Retro period and suite
# ---------------------------------------------------------------------------------------------
RETRO_START=${RETRO_START:-20240506}      # first retro day, and the day that cold starts
RETRO_END=${RETRO_END:-20240512}          # last retro day
# YES relaxes the suite's 399 clock-time triggers so cycles are not gated on the wall clock
RETRO=${RETRO:-YES}

# Which workflow groups to run. FALSE gives that group's families defstatus complete, so they
# never run and nothing waiting on them blocks. Operations runs all of them.
RUN_ENKF=${RUN_ENKF:-TRUE}
RUN_ENSF=${RUN_ENSF:-TRUE}
RUN_FIREWX=${RUN_FIREWX:-TRUE}

# Two task types no retro needs, off by default on Ursa because neither works here:
#   gempak   exrrfs_gempak.sh launches "mpiexec -configfile", the WCOSS2 cfp idiom, and has no
#            srun arm, so every task exits 255
#   bufrsnd  the station list fix/bufrsnd/<grid>/rrfs_profdat.<NSTAT> exists only for some grids,
#            and on RRFS_NA_3km the 84 h sounding job runs past its 3 h card limit
RUN_GEMPAK=${RUN_GEMPAK:-FALSE}
RUN_BUFRSND=${RUN_BUFRSND:-FALSE}
# Coarser domains (strip when merging to the nco branch): smoke and dust run here, since
# dev-sci provides fix/smoke_dust/RRFS_CONUS_3km.
RUN_SMOKE=${RUN_SMOKE:-TRUE}

# The 84 h deterministic forecast at 00z, 06z, 12z and 18z, with its post, product generation and
# restarts. FALSE leaves the hourly 18 h forecasts alone and is the one setting that shortens a
# retro noticeably: the long forecast is 67 of the 81 minutes on each 6-hourly family's critical
# path, so a 13 km week goes from about 38 h to about 13 h. Operations needs it; a cycling or DA
# retro usually does not. Fire weather takes its initial and boundary conditions from the long
# forecast's post, so RUN_FIREWX must be FALSE as well, and the generator says so if it is not.
# The 85 boundary jobs at each long cycle are left alone, because the hourly cycles in the family
# share them; to cut those as well, shorten the forecast itself with FCST_LEN_HRS and
# FCST_LEN_HRS_LONG (see the simplified samples, config_*_simple.sh).
# JEDI analysis, the Rocoto config.sh "JEDI options". DA_SYSTEM picks which analysis runs, GSI
# (the operational route) or JEDI; the rest are read only when it is JEDI. setup_retro_links.sh
# writes them into det/workflow.conf and make_rrfs_retro_def.sh sizes the job from them.
DA_SYSTEM=${DA_SYSTEM:-GSI}
# JCB templates in parm/jedi that the analysis renders its yaml from, conventional and
# reflectivity. The conventional one decides 3DVar or hybrid; this grid has only the
# 3DVar template so far.
JCB_CONFIG_CONV=${JCB_CONFIG_CONV:-rdas-atmosphere-templates-fv3_c3km.yaml}
JCB_CONFIG_DBZ=${JCB_CONFIG_DBZ-}
# Whether the analysis also runs on cold-start cycles, and whether synthetic radiosonde
# temperature and humidity levels are added the way GSI's sonde_ext does
DO_DACOLD=${DO_DACOLD:-FALSE}
EXT_SONDE=${EXT_SONDE:-FALSE}
# Job size. Nodes x tasks per node must match the template's layout,
# the 40x40 layout in the c3km template: 1600 tasks
NNODES_ANALYSIS_JEDI=${NNODES_ANALYSIS_JEDI:-16}
PPN_ANALYSIS_JEDI=${PPN_ANALYSIS_JEDI:-100}
TPP_ANALYSIS_JEDI=${TPP_ANALYSIS_JEDI:-1}
WALLTIME_ANALYSIS_JEDI=${WALLTIME_ANALYSIS_JEDI:-01:30:00}

DO_LONG_FORECAST=${DO_LONG_FORECAST:-TRUE}

# YES keeps the working directories under stmp after jobs finish (sets KEEPDATA and KEEP_TMP)
KEEPDATA=${KEEPDATA:-NO}

# suite definition to copy, relative to ecf/defs
BASE_DEF=${BASE_DEF:-nco_para/rrfs_nco_para.def}
RRFS_SUITE=${RRFS_SUITE:-para}            # suite name in the generated definition
RRFS_VER=${RRFS_VER:-v1.0}
ENVIR=${ENVIR:-prod}
MACHINE_SITE=${MACHINE_SITE:-development}
