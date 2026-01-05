#!/usr/bin/env bash
# tweaks for non-NCO experiments
# This script will NOT be needed by NCO
# shellcheck disable=SC1090,SC1091,SC2154,SC2155
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
#
COMPILER=${COMPILER:-intel}
# tweaks for non-NCO runs
COMMAND=$1  #get the J-JOB name
task_id=${COMMAND#*_} # remove the "JRRFS_" part
export task_id=${task_id,,} #to lower case
echo "run on ${MACHINE}"
if [[ -n "${SLURM_JOB_ID}" ]]; then # slurm
  export NTASKS=${SLURM_NTASKS}
  export NODES=${SLURM_JOB_NUM_NODES}
  export PPN=${SLURM_TASKS_PER_NODE%%(*} # remove the (x6) part of 20(x6)
elif [[ -n "${PBS_NODEFILE}" ]]; then # PBS
  export NTASKS=$(wc -l < "${PBS_NODEFILE}")
  export NODES=$(sort -u "${PBS_NODEFILE}" | wc -l)
  export PPN=$(grep -c "$(head -1 "${PBS_NODEFILE}")" "${PBS_NODEFILE}" )
  if [[ ${MACHINE,,} == "wcoss2" ]]; then # special needs at wcoss2
    source "${HOMErrfs}/versions/run.ver"
    export STRIDE=$((128 / PPN))
    export MPI_RUN_CMD="mpiexec -n $NTASKS -ppn $PPN --cpu-bind core --depth $STRIDE --label --line-buffer"
  fi
else
  echo "Info: Not slurm nor PBS"
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
  ioda_bufr|ioda_airnow)
    module purge
    module use "${HOMErrfs}/sorc/RDASApp/modulefiles"
    module load "RDAS/${MACHINE}.${COMPILER}"
    if [[ ${MACHINE} == "wcoss2" ]]; then
      # spack-stack does not include these python modules on wcoss2
      # so we use a workaround of loading an existing python virtual environment
      module unload python cray-python
      source "${py_virtualenv}"
    else
      module load py-jinja2 py-matplotlib py-cartopy py-netcdf4
    fi
    export LD_LIBRARY_PATH=${HOMErrfs}/sorc/RDASApp/build/lib64:${LD_LIBRARY_PATH}
    ;;
  ungrib)
    module purge
    module load "rrfs/${MACHINE}.${COMPILER}"
    module load wgrib2
    ;;
  prep_ic)
    module purge
    module load "rrfs/${MACHINE}.${COMPILER}"
    module load nco
    ;;
  jedivar|hofx|getkf*)
    module purge
    module use "${HOMErrfs}/sorc/RDASApp/modulefiles"
    module load "RDAS/${MACHINE}.${COMPILER}"
    module load nco
    export LD_LIBRARY_PATH=${HOMErrfs}/sorc/RDASApp/build/lib64:${LD_LIBRARY_PATH}
    ;;
  ioda_mrms_refl)
    module purge
    module use "${HOMErrfs}/sorc/RDASApp/modulefiles"
    module load "RDAS/${MACHINE}.${COMPILER}"
    export LD_LIBRARY_PATH=${HOMErrfs}/sorc/RDASApp/build/lib64:${LD_LIBRARY_PATH}
    ;;
  nonvar_bufrobs|nonvar_reflobs|nonvar_cldana)
    module purge
    module use "${HOMErrfs}/sorc/RRFS_UTILS/modulefiles"
    module load "build_${MACHINE}_${COMPILER}"
    ;;
  mpassit)
    module purge
    module use "${HOMErrfs}/sorc/MPASSIT/modulefiles"
    module load "build.${MACHINE}.${COMPILER}"
    ;;
  upp)
    module purge
    module use "${HOMErrfs}/sorc/UPP/modulefiles"
    if [[ ${MACHINE} == "wcoss2" ]]; then
      # need to unset module versions sourced earlier and load a couple more
      source "${HOMErrfs}/versions/unset.ver"
      module load "${MACHINE}_${COMPILER}"
      module load libjpeg/9c
      module load libfabric/1.20.1
    else
      module load "${MACHINE}_${COMPILER}"
    fi
    ;;
  recenter)
    module purge
    module use "${HOMErrfs}/sorc/RRFS_UTILS/modulefiles"
    module load "build_${MACHINE}_${COMPILER}"
    module load "rrfs/${MACHINE}.${COMPILER}"
    ;;
  ensmean)
    module purge
    module load "rrfs/${MACHINE}.${COMPILER}"
    module load nco
    ;;
  *)
    module purge
    module load "rrfs/${MACHINE}.${COMPILER}"
    module load nco
    ;;
esac
if [[ ${MACHINE} == "wcoss2" ]]; then
  module load cray-pals/1.3.2 # for mpiexec command
fi
module load prod_util
module list
set -x
# workaround for err_exit, https://github.com/NOAA-EMC/NCEPLIBS-prod_util/pull/73
export PATH=${HOMErrfs}/sorc/_workaround_:${PATH}

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
      ursa|gaeac?|orion|hercules)
        set +x
        module load python
        set -x
        ;;
    esac
    if [[ "${CLEAN_MODE}" == "1"  ]]; then
      "${HOMErrfs}/workflow/sideload/clean.py"
    elif [[ "${CLEAN_MODE}" == "2"  ]]; then
      "${HOMErrfs}/workflow/sideload/purge_stmp.sh"
    else
      echo -e "CLEAN_MODE is not 1 nor 2, no cleaning.\nEXIT NORMALLY!"
      exit 0
    fi
    ;;
  graphics|misc)
    "${HOMErrfs}/workflow/sideload/${task_id}.sh"
    ;;
  *)
    "${HOMErrfs}/jobs/${COMMAND}"
    ;;
esac
