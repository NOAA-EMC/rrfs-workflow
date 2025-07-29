#!/usr/bin/env bash
# tweaks for non-NCO experiments
# This script will NOT be needed by NCO
# shellcheck disable=SC1090,SC1091
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
if [[ ${MACHINE} == "wcoss2" ]]; then
  source "${HOMErrfs}/versions/run.ver"
  NTASKS=$( wc -l "$PBS_NODEFILE" | awk '{print $1}' )
  PPN=$( grep -c "$(head -1 "$PBS_NODEFILE")" "$PBS_NODEFILE" )
  export NTASKS
  export PPN
  export NODES=$(( NTASKS / PPN ))
  export STRIDE=$((128 / PPN))
  export MPI_RUN_CMD="mpiexec -n $NTASKS -ppn $PPN --cpu-bind core --depth $STRIDE --label --line-buffer"
else
  export NTASKS=${SLURM_NTASKS}
  export NODES=${SLURM_JOB_NUM_NODES}
  export PPN=${SLURM_TASKS_PER_NODE%%(*} # remove the (x6) part of 20(x6)
fi
#
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
    if [[ ${MACHINE} == "wcoss2" ]]; then
      # spack-stack does not include these python modules on wcoss2
      # so we use a workaround of loading an existing python virtual environment
      module unload python cray-python
      source "${py_virtualenv}"
    else
      module load py-jinja2 py-matplotlib py-cartopy py-netcdf4
    fi
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOMErrfs}/sorc/RDASApp/build/lib64
    ;;
  ungrib)
    module purge
    module load "rrfs/${MACHINE}.intel"
    module load wgrib2/2.0.8
    ;;
  prep_ic)
    module purge
    module load "rrfs/${MACHINE}.intel"
    module load nco
    ;;
  jedivar|getkf*)
    module purge
    module use "${HOMErrfs}/sorc/RDASApp/modulefiles"
    module load "RDAS/${MACHINE}.intel"
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOMErrfs}/sorc/RDASApp/build/lib64
    ;;
  ioda_mrms_refl)
    module purge
    module use "${HOMErrfs}/sorc/RDASApp/modulefiles"
    module load "RDAS/${MACHINE}.intel"
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOMErrfs}/sorc/RDASApp/build/lib64
    ;;
  mpassit)
    module purge
    module use "${HOMErrfs}/sorc/MPASSIT/modulefiles"
    if [[ ${MACHINE} == "ursa" ]]; then
      module load "build.${MACHINE}.intel-llvm"
    else
      module load "build.${MACHINE}.intel"
    fi
    ;;
  upp)
    module purge
    module use "${HOMErrfs}/sorc/UPP/modulefiles"
    if [[ ${MACHINE} == "wcoss2" ]]; then
      # need to unset module versions sourced earlier and load a couple more
      source "${HOMErrfs}/versions/unset.ver"
      module load "${MACHINE}_intel"
      module load libjpeg/9c
      module load libfabric/1.20.1
    else
      module load "${MACHINE}_intel"
    fi
    ;;
  recenter)
    module purge
    module use "${HOMErrfs}/sorc/RRFS_UTILS/modulefiles"
    module load "build_${MACHINE}_intel"
    ;;
  *)
    module purge
    module load "rrfs/${MACHINE}.intel"
    ;;
esac
if [[ ${MACHINE} == "wcoss2" ]]; then
  module load cray-pals/1.3.2 # for mpiexec command
fi
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
      ursa|gaea|orion|hercules)
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
