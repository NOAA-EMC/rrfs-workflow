# envir-p1.h
export job=${job:-${PBS_JOBNAME:-$SLURM_JOB_NAME}}
export jobid=${jobid:-$job.${PBS_JOBID:-$SLURM_JOB_ID}}

export RUN_ENVIR=nco
export envir=%ENVIR%
export MACHINE_SITE=%MACHINE_SITE%
export RUN=%RUN%

if [ -n "%SENDCANNEDDBN:%" ]; then export SENDCANNEDDBN=${SENDCANNEDDBN:-%SENDCANNEDDBN:%}; fi
export SENDCANNEDDBN=${SENDCANNEDDBN:-"NO"}

if [[ "$envir" == prod && "$SENDDBN" == YES ]]; then
    export eval=%EVAL:NO%
    if [ $eval == YES ]; then export SIPHONROOT=${UTILROOT}/para_dbn
    else export SIPHONROOT=/lfs/h1/ops/prod/dbnet_siphon
    fi
    if [ "$PARATEST" == YES ]; then export SIPHONROOT=${UTILROOT}/fakedbn; export NODBNFCHK=YES; fi
else
    export SIPHONROOT=${UTILROOT}/fakedbn
fi
export SIPHONROOT=${UTILROOT}/fakedbn
export DBNROOT=$SIPHONROOT

if [[ ! " prod para test " =~ " ${envir} " && " ops.prod ops.para " =~ " $(whoami) " ]]; then err_exit "ENVIR must be prod, para, or test [envir-p1.h]"; fi

# Developer configuration. DEV_PTMP and DEV_DATAROOT can be set in the suite (e.g. on Ursa);
# the defaults are the WCOSS2 locations.
PTMP=%DEV_PTMP:/lfs/h3/emc/lam/noscrub/ecflow/ptmp%
model=rrfs
PSLOT=ecflow_rrfs
export COMROOT=${PTMP}/${USER}/${PSLOT}/para/com
# DEV_COMPATH adds upstream COM directories to search, e.g. staged retro data on Ursa
DEV_COMPATH="%DEV_COMPATH:%"
export COMPATH=${COMROOT}/${model}${DEV_COMPATH:+:${DEV_COMPATH}}
if [ -n "%PDY:%" ]; then
  export PDY=${PDY:-%PDY:%}
else
  export PDY=$($NDATE | cut -c1-8)
fi
export CDATE=${PDY}%CYC:%
export COMrrfs=$(compath.py rrfs/${rrfs_ver})
export COMOUT_PREP="$(compath.py obsproc/v1.2)"

export DATAROOT=%DEV_DATAROOT:/lfs/h3/emc/lam/noscrub/ecflow/stmp/${USER}/${model}/${PSLOT}%
#### export umbrella_fsm_data=${DATAROOT}/rrfs_fsm_${PDY}${cyc}_${rrfs_ver}/${WGF}
#if [ "${CYCLE_TYPE}" = "spinup" ]; then
#  export umbrella_init_data="${DATAROOT}/${PDY}/${RUN}_init_spinup_${cyc}_${rrfs_ver}/${WGF}"
#else
#  export umbrella_init_data="${DATAROOT}/${PDY}/${RUN}_init_${cyc}_${rrfs_ver}/${WGF}"
#fi
mkdir -p ${DATAROOT} # ${COMrrfs}

