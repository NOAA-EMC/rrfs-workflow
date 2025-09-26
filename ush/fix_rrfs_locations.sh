#!/bin/bash
#
# FIX_RRFS locaitons at different HPC platforms
#

set -x
hostnamestr=$(hostname -f)

MACHINE_ID=unknown
if [[ "${hostnamestr}" == *"hfe"* ]]; then
   MACHINE_ID=hera
   PLATFORM=hera
   FIX_RRFS_LOCATION="/scratch4/BMC/rtrr/FIX_RRFS"
elif [[ "${hostnamestr}" == *"gaea"* ]]; then
   MACHINE_ID=gaea
   PLATFORM=gaea
  if [[ -d /gpfs/f5 && -d /ncrc ]]; then
    FIX_RRFS_LOCATION=/gpfs/f5/gsl-glo/world-shared/role.rrfsfix/FIX_RRFS
  elif [[ -d /gpfs/f6 && -d /ncrc ]]; then
    FIX_RRFS_LOCATION=/gpfs/f6/bil-fire10-oar/world-shared/role.rrfsfix/FIX_RRFS
  fi
elif [[ "${hostnamestr}" == *"ufe"* ]]; then
   MACHINE_ID=ursa
   PLATFORM=ursa
   FIX_RRFS_LOCATION="/scratch4/BMC/rtrr/FIX_RRFS"
elif [[ -d /lfs/h2 ]] ; then
    PLATFORM=wcoss2
    FIX_RRFS_LOCATION="/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS"
elif [[ -d /jetmon ]] ; then
    PLATFORM=jet
    FIX_RRFS_LOCATION="/lfs5/BMC/nrtrr/FIX_RRFS"
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
