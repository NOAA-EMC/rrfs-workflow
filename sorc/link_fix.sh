#!/bin/sh
set -xeu

source ./machine-setup.sh > /dev/null 2>&1

LINK="cp -rp"

pwd=$(pwd -P)

if [[ ${target} == "wcoss_dell_p3" || ${target} == "wcoss" ||  ${target} == "wcoss_cray" ]]; then
    FIX_DIR="/gpfs/dell2/emc/modeling/noscrub/emc.campara/fix_fv3cam"
elif [ ${target} == "hera" ]; then
    FIX_DIR="/scratch2/NCEPDEV/fv3-cam/emc.campara/fix_fv3cam"
elif [ ${target} == "jet" ]; then
    FIX_DIR="/scratch4/NCEPDEV/global/save/glopara/git/fv3gfs/fix"
else
    echo "Unknown site " ${target}
    exit 1
fi

mkdir -p ${pwd}/../fix
cd ${pwd}/../fix                ||exit 8
for dir in fix_am fix_nest fix_sar ; do
    [[ -d $dir ]] && rm -rf $dir
done

${LINK} $FIX_DIR/* .

exit
