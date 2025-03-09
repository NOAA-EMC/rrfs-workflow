#!/usr/bin/env bash
# tweaks for non-NCO experiments
# This script will NOT be needed by NCO
#
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
#
#source ${EXPDIR}/exp.setup
# tweaks for non-NCO runs
COMMAND=$1  #get the J-JOB name
HOMErrfs=$2  #get the system location
task_id=${COMMAND#*_} # remove the "JRRFS_" part
export task_id=${task_id,,} #to lower case
source ${HOMErrfs}/workflow/ush/detect_machine.sh
echo "run on ${MACHINE}"
#
export NTASKS=${SLURM_NTASKS}
export NODES=${SLURM_JOB_NUM_NODES}
export PPN=${SLURM_TASKS_PER_NODE%%(*} # remove the (x6) part of 20(x6)
#
echo "load rrfs-workflow modules by default"
set +x # suppress messy output in the module load process
source /etc/profile
module use ${HOMErrfs}/modulefiles
# load corresponding modules for different tasks
case ${task_id} in
  jedivar|getkf*|ioda_bufr)
    module purge
    module use ${HOMErrfs}/sorc/RDASApp/modulefiles
    module load RDAS/${MACHINE}.intel
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOMErrfs}/sorc/RDASApp/build/lib64
    ;;
  mpassit)
    module purge
    module use ${HOMErrfs}/sorc/MPASSIT/modulefiles
    module load build.${MACHINE}.intel
    module load prod_util/${MACHINE}
    ;;
  upp)
    module purge
    module load prod_util/${MACHINE}
    module use ${HOMErrfs}/sorc/UPP/modulefiles
    module load ${MACHINE}
    ;;
  *)
    module purge
    module load rrfs/${MACHINE}.intel
    module load prod_util/${MACHINE}
    ;;
esac
module list
set -x

# run J-job or sideload non-NCO tasks
case ${task_id} in
  clean)
    ${HOMErrfs}/workflow/sideload/clean.py
    ;;
  graphics|dummy)
    ${HOMErrfs}/workflow/sideload/${task_id}.sh
    ;;
  *)
    ${HOMErrfs}/jobs/${COMMAND}
    ;;
esac
