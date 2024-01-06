#!/bin/sh
#
# FIX_RRFS locaitons at different HPC platforms
#
if [[ -d /lfs/h2 ]] ; then
    PLATFORM=wcoss2
    FIX_RRFS_LOCATION="/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS"
elif [[ -d /scratch1 ]] ; then
    PLATFORM=hera
    FIX_RRFS_LOCATION="/scratch2/BMC/rtrr/FIX_RRFS"
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
