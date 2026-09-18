#!/bin/bash
#
# Settings for running the rrfs-dev ecflow suite on Ursa, in one place.
#
# This is the ecflow equivalent of the Rocoto workflow's ush/config.sh, for the parts we control.
# It is sourced by ecf/setup_ecf_links.sh, ecf/defs/make_ursa_def.sh and ush/prod_clone/make_retro_def.sh,
# so edit values here instead of passing them on every command line. Anything already set in the
# environment wins, so one-off runs can still say e.g.
#
#   RETRO_START=20240510 ./make_ursa_def.sh
#
# What is NOT here, because the suite reads it at run time rather than at generation time:
#   fix/workflow/<WGF>/workflow.conf   job resources (NNODES_*, PPN_*, TPP_*) and science switches;
#                                      setup_ecf_links.sh copies the _prod or _dev version per
#                                      RESOURCE_CONFIG and applies the Ursa overrides
#   versions/run.ver                   software versions used by the job cards
#
# ---------------------------------------------------------------------------------------------
# Where the workflow writes
# ---------------------------------------------------------------------------------------------
# Everything this run produces hangs off one base directory.
URSA_WORK_BASE=${URSA_WORK_BASE:-/scratch4/NCEPDEV/fv3-cam/${USER}/ecflow_rrfs}

# ecflow job files and their output (the server creates the task directories underneath)
ECF_HOME=${ECF_HOME:-${URSA_WORK_BASE}/submit}
OUTPUTDIR=${OUTPUTDIR:-${URSA_WORK_BASE}/output}
# COM output. envir-p1.h builds COMROOT as ${DEV_PTMP}/${USER}/ecflow_rrfs/para/com, so this is a
# base directory and the user and suite names are appended to it.
DEV_PTMP=${DEV_PTMP:-${URSA_WORK_BASE}/ptmp}
# job working directories (DATAROOT)
DEV_DATAROOT=${DEV_DATAROOT:-${URSA_WORK_BASE}/stmp}

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
# fix tree; setup_ecf_links.sh links <repo>/fix to it
FIX_RRFS_DIR=${FIX_RRFS_DIR:-/scratch4/NCEPDEV/fv3-cam/Shun.Liu/fix_nco_wcoss}
# staged upstream data in NCO COM/DCOM layout (see make_links.sh in that directory)
RETRO_DATA_ROOT=${RETRO_DATA_ROOT:-/scratch4/BMC/zrtrr/Samuel.Degelia/RRFS_RETRO_DATA_NCO}

# ---------------------------------------------------------------------------------------------
# Retro period and suite
# ---------------------------------------------------------------------------------------------
RETRO_START=${RETRO_START:-20240506}      # first retro day, and the day that cold starts
RETRO_END=${RETRO_END:-20240512}          # last retro day
# YES relaxes the suite's 399 clock-time triggers so cycles are not gated on the wall clock
RETRO=${RETRO:-YES}
# suite definition to copy, relative to ecf/defs
BASE_DEF=${BASE_DEF:-nco_para/rrfs_nco_para.def}
RRFS_SUITE=${RRFS_SUITE:-para}            # suite name in the generated definition
RRFS_VER=${RRFS_VER:-v1.0}
ENVIR=${ENVIR:-prod}
MACHINE_SITE=${MACHINE_SITE:-development}
