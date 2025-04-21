#!/usr/bin/env bash
# tweaks for non-NCO experiments
# This script will NOT be needed by NCO
# shellcheck disable=SC1091
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
#
#source ${EXPDIR}/exp.setup
# tweaks for non-NCO runs
COMMAND=$1  #get the J-JOB name
HOMErrfs=$2  #get the system location
task_id=${COMMAND#*_} # remove the "JRRFS_" part
export task_id=${task_id,,} #to lower case
source "${HOMErrfs}/workflow/ush/detect_machine.sh"
echo "run on ${MACHINE}"
#
export NTASKS=${SLURM_NTASKS}
export NODES=${SLURM_JOB_NUM_NODES}
export PPN=${SLURM_TASKS_PER_NODE%%(*} # remove the (x6) part of 20(x6)
ulimit -s unlimited
ulimit -v unlimited
ulimit -a
#
echo "load rrfs-workflow modules by default"
set +x # suppress messy output in the module load process
source /etc/profile
module use "${HOMErrfs}/modulefiles"
# load corresponding modules for different tasks
case ${task_id} in
  ioda_bufr)
    module purge
    module use "${HOMErrfs}/sorc/RDASApp/modulefiles"
    module load "RDAS/${MACHINE}.intel"
    module load py-matplotlib py-cartopy py-netcdf4
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOMErrfs}/sorc/RDASApp/build/lib64
    ;;
  ungrib)
    module purge
    module load "rrfs/${MACHINE}.intel"
    module load wgrib2/2.0.8
    ;;
  jedivar|getkf*)
    module purge
    module use "${HOMErrfs}/sorc/RDASApp/modulefiles"
    module load "RDAS/${MACHINE}.intel"
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOMErrfs}/sorc/RDASApp/build/lib64
    ;;
  mpassit)
    module purge
    module use "${HOMErrfs}/sorc/MPASSIT/modulefiles"
    module load "build.${MACHINE}.intel"
    ;;
  upp)
    module purge
    module use "${HOMErrfs}/sorc/UPP/modulefiles"
    module load "${MACHINE}"
    ;;
  *)
    module purge
    module load "rrfs/${MACHINE}.intel"
    ;;
esac
module load "prod_util/${MACHINE}"
module list
set -x
# check whether prod_util is correctly loaded
if [[ "${NDATE}" == "" ]]; then
  echo "FATAL ERROR: ${NDATE} is not defined; prod_util is not loaded!"
  exit 1
fi

umask 022
# run J-job or sideload non-NCO tasks
case ${task_id} in
  clean)
    case ${MACHINE} in
      gaea|orion|hercules)
        set +x
        module load python
        set -x
        ;;
    esac
    "${HOMErrfs}/workflow/sideload/clean.py"
    ;;
  graphics|misc)
    "${HOMErrfs}/workflow/sideload/${task_id}.sh"
    ;;
  *)
    "${HOMErrfs}/jobs/${COMMAND}"
    ;;
esac
