#!/bin/bash
#
# Sample settings for an RRFS_CONUS_3km retro on WCOSS2.
#
# It is retro_config_wcoss2_na3km.sh with DOMAIN (and RUN_SMOKE) set, which in turn is
# the Ursa sample (retro_config_ursa_na3km.sh) with WCOSS2 locations, account and server; the
# retro period and suite settings below the input data block are the same. Link or copy it to
# ecf/defs/retro_config.sh and change the paths and server in the first blocks to your own.
#
# This is the ecflow equivalent of the Rocoto workflow's ush/config.sh, for the parts we control.
# It is sourced by ush/retro/setup_retro_links.sh, ecf/defs/make_rrfs_retro_def.sh,
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
MACHINE=${MACHINE:-WCOSS2}

# ---------------------------------------------------------------------------------------------
# Where the workflow writes
# ---------------------------------------------------------------------------------------------
# Everything this run produces hangs off one base directory.
# A week of NA 3 km output is tens of TB, so the default is ptmp; note its purge policy.
RETRO_WORK_BASE=${RETRO_WORK_BASE:-/lfs/h2/emc/ptmp/${USER}/ecflow_rrfs}

# ecflow job files and their output (the server creates the task directories underneath)
ECF_HOME=${ECF_HOME:-${RETRO_WORK_BASE}/submit}
OUTPUTDIR=${OUTPUTDIR:-${RETRO_WORK_BASE}/output}
# COM output. envir-p1.h builds COMROOT as ${DEV_PTMP}/${USER}/ecflow_rrfs/para/com, so this is a
# base directory and the user and suite names are appended to it.
DEV_PTMP=${DEV_PTMP:-${RETRO_WORK_BASE}/ptmp}
# job working directories (DATAROOT)
DEV_DATAROOT=${DEV_DATAROOT:-${RETRO_WORK_BASE}/stmp}

# ---------------------------------------------------------------------------------------------
# PBS
# ---------------------------------------------------------------------------------------------
PROJ=${PROJ:-RRFS}                        # the cards add -DEV: "-A RRFS-DEV"
QUEUE=${QUEUE:-dev}
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
ECFLOW_HOST=${ECFLOW_HOST:-cdecflow01}    # host running the server (head.h reads it as ECF_LOGHOST)

# ---------------------------------------------------------------------------------------------
# Input data
# ---------------------------------------------------------------------------------------------
# fix tree; setup_retro_links.sh links <repo>/fix to it. The production package's tree has the
# workflow.conf_dev and _prod files the retro needs; NCO may remove a version once the next is
# installed, so update the version here (or link a copy of your own) when the links break.
FIX_RRFS_DIR=${FIX_RRFS_DIR:-/lfs/h1/ops/prod/packages/rrfs.v1.0.26/fix}
# dev-sci's shared fix tree; the domain files (ecf/defs/domains) link other grids' fix files
# from it
FIX_RRFS_SHARED=${FIX_RRFS_SHARED:-/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS}
# staged upstream data in NCO COM/DCOM layout (see make_links.sh in that directory)
RETRO_DATA_ROOT=${RETRO_DATA_ROOT:-/lfs/h2/emc/lam/noscrub/samuel.degelia/RRFS_RETRO_DATA_NCO}
# Coarser domains (strip when merging to the nco branch): the model domain. RRFS_NA_3km
# is the operational v1 domain and changes nothing; any other value needs
# ecf/defs/domains/<DOMAIN>.sh with its grid, fix files and job sizes.
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

# Two task types no retro needs; off as on Ursa. Both may work on WCOSS2, where operations runs them.
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
# The 85 boundary jobs at each long cycle are left alone: the hourly cycles in the family share
# them, so the safe cut needs the forecast length rather than the task name.
DO_LONG_FORECAST=${DO_LONG_FORECAST:-TRUE}

# Whether each job keeps its working directory under stmp. The base NCO definition sets YES at all
# eight places, which on Ursa filled a 244 TiB project quota in ten days and stopped all three
# suites: with YES, exrrfs_clean.sh does not delete the shared umbrella directories but *renames*
# them (rrfs_forecast_12_v1.0 -> rrfs_forecast_<pid>_12_v1.0), so nothing is ever reclaimed.
# NO costs no debugging, because head.h traps ERR and EXIT and exits before the J-job reaches its
# cleanup line, so a job that fails keeps its working directory either way. Set YES only when you
# want the directories of jobs that *succeeded*.
KEEPDATA=${KEEPDATA:-NO}

# suite definition to copy, relative to ecf/defs
BASE_DEF=${BASE_DEF:-nco_para/rrfs_nco_para.def}
RRFS_SUITE=${RRFS_SUITE:-para}            # suite name in the generated definition
RRFS_VER=${RRFS_VER:-v1.0}
ENVIR=${ENVIR:-prod}
MACHINE_SITE=${MACHINE_SITE:-development}
