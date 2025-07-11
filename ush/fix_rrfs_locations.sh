#!/bin/bash
#
# FIX_RRFS locaitons at different HPC platforms
#

set -x
hostnamestr=$(hostname -f)

MACHINE_ID=unknown
if [[ "${hostnamestr}" == *"hfe"* ]]; then
   MACHINE_ID=hera
fi
if [[ "${hostnamestr}" == *"gaea"* ]]; then
   MACHINE_ID=gaea
fi
if [[ "${hostnamestr}" == *"ufe"* ]]; then
   MACHINE_ID=gaea
fi

if [[ -d /lfs/h2 ]] ; then
    PLATFORM=wcoss2
    FIX_RRFS_LOCATION="/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS"
elif [[ -d /scratch3 ]] && [[ "${MACHINE_ID}" == "ursa" ]]; then
    # We are on NOAA Ursa
    PLATFORM=ursa
    FIX_RRFS_LOCATION="/scratch4/BMC/rtrr/FIX_RRFS"
elif [[ -d /gpfs/f5 && -d /ncrc ]]; then
    # We are on GAEA
    PLATFORM=gaeac5
    FIX_RRFS_LOCATION="/gpfs/f5/gsl-glo/world-shared/role.rrfsfix/FIX_RRFS"
elif [[ -d /gpfs/f6 && -d /ncrc ]]; then
    # We are on GAEA
    PLATFORM=gaeac6
    FIX_RRFS_LOCATION="/gpfs/f6/bil-fire10-oar/world-shared/role.rrfsfix/FIX_RRFS"
elif [[ -d /scratch4 ]] && [[ "${MACHINE_ID}" == "hera" ]]; then
    PLATFORM=hera
    FIX_RRFS_LOCATION="/scratch4/BMC/rtrr/FIX_RRFS"
elif [[ -d /jetmon ]] ; then
    PLATFORM=jet
    FIX_RRFS_LOCATION="/lfs4/BMC/nrtrr/FIX_RRFS"
elif [[ -d /work ]]; then
    FIX_RRFS_LOCATION="/work/noaa/rtrr/FIX_RRFS"
    hoststr=$(hostname)
    if [[ "$hoststr" == "hercules"* ]]; then                                                                                                                           
      PLATFORM=hercules
    else
      PLATFORM=orion
    fi
else
    PLATFORM=unknown
    FIX_RRFS_LOCATION="/this/is/an/unknown/platform"
fi
