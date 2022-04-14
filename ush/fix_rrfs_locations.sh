#!/bin/sh
#
# FIX_RRFS locaitons at different HPC platforms
#
if [[ -d /dcom && -d /hwrf ]] ; then
    PLATFORM=wcoss
    FIX_RRFS_LOCATION="/gpfs/dell6/emc/modeling/noscrub/emc.campara/FIX_RRFS"
elif [[ -d /cm ]] ; then
    PLATFORM=wcoss_c
    FIX_RRFS_LOCATION="/gpfs/dell6/emc/modeling/noscrub/emc.campara/FIX_RRFS"
elif [[ -d /ioddev_dell ]]; then
    PLATFORM=wcoss_dell_p3
    FIX_RRFS_LOCATION="/gpfs/dell6/emc/modeling/noscrub/emc.campara/FIX_RRFS"
elif [[ -d /scratch1 ]] ; then
    PLATFORM=hera
    FIX_RRFS_LOCATION="/scratch2/BMC/rtrr/FIX_RRFS"
elif [[ -d /carddata ]] ; then
    PLATFORM=s4
    FIX_RRFS_LOCATION="/to/do"
elif [[ -d /jetmon ]] ; then
    PLATFORM=jet
    FIX_RRFS_LOCATION="/lfs4/BMC/nrtrr/FIX_RRFS"
elif [[ -d /glade ]] ; then
    PLATFORM=cheyenne
    FIX_RRFS_LOCATION="/glade/p/ral/jntp/FIX_RRFS"
elif [[ -d /sw/gaea ]] ; then
    PLATFORM=gaea
    FIX_RRFS_LOCATION="/to/do"
elif [[ -d /work ]]; then
    PLATFORM=orion
    FIX_RRFS_LOCATION="/work/noaa/rtrr/FIX_RRFS"
else
    PLATFORM=unknow
    FIX_RRFS_LOCATION="/this/is/an/unknow/platform"
fi
