#!/usr/bin/env bash
# tweaks for non-NCO experiments
# This script will NOT be needed by NCO
#
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
#
source ${EXPDIR}/exp.setup
# tweaks for non-NCO runs
COMMAND=$1  #get the J-JOB name
task_id=${COMMAND#*_} # remove the "JRRFS_" part
export task_id=${task_id,,} #to lower case
export rrfs_ver=${VERSION}
if [[ -z "${ENS_INDEX}" ]] && [[ ! "${task_id}" == "ens_da"   ]]; then
  export RUN='rrfs'
  export DATA=${DATAROOT}/${NET}/${rrfs_ver}/${RUN}.${PDY}/${cyc}/${task_id}
  if [[ "${task_id}" == "ungrib"  ]]; then
    export DATA=${DATAROOT}/${NET}/${rrfs_ver}/${RUN}.${PDY}/${cyc}/${task_id}_${TYPE}
  fi
else # ensrrfs
  export RUN='ensrrfs'
  if [[ "${task_id}" == "ens_da"  ]]; then
    export DATA=${DATAROOT}/${NET}/${rrfs_ver}/${RUN}.${PDY}/${cyc}/${task_id}
  else
    export DATA=${DATAROOT}/${NET}/${rrfs_ver}/${RUN}.${PDY}/${cyc}/mem${ENS_INDEX}/${task_id}
  fi
fi
export cpreq="ln -snf" #use soft link instead of copy for non-NCO experiments
export COMOUT="${COMROOT}/${NET}/${rrfs_ver}/${RUN}.${PDY}/${cyc}" # task_id not included as compath.py may not be able to find this subdirectory
export COMINrrfs="${COMROOT}/${NET}/${rrfs_ver}" # we may need to use data from previous cycles
export NTASKS=${SLURM_NTASKS}
#
echo "load rrfs-workflow modules by default"
set +x # supress messy output in the module load process
source /etc/profile
module use ${HOMErrfs}/modulefiles
# load corresponding modules for different tasks
case ${task_id} in
  da|ens_da|ioda_bufr)
    module purge
    module use ${HOMErrfs}/sorc/RDASApp/modulefiles
    module load RDAS/${MACHINE}.intel
    ;;
  mpassit)
    module purge
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
  clean|graphics|dummy)
    ${HOMErrfs}/workflow/sideload/${task_id}.sh
    ;;
  *)
    ${HOMErrfs}/jobs/${COMMAND}
    ;;
esac
