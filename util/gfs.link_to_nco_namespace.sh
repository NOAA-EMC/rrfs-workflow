#!/usr/bin/env bash
export TZ="GMT"
set -x
src="/public/data/grids/gfs/0p25deg/grib2"
dst="/lfs5/BMC/nrtrr/NCO_data/gfs"

# the workflow provides the $GRBFILE env variables
fname=${GRBFILE##*/}
yyyy=20${fname:0:2}
ndays=$(( 10#${fname:2:3} - 1 ))
PDY=$(date -d "${ndays} days ${yyyy}-01-01" +"%Y%m%d")
HH=${fname:5:2}
fhr=$(( 10#${fname:7:6} ))
fhr=$(printf "%03d" ${fhr})
fpath=${dst}/gfs.${PDY}/${HH}
mkdir -p ${fpath}
ln -snf ${GRBFILE} ${fpath}/gfs.t${HH}z.pgrb2.0p25.f${fhr}
#ln ${GRBFILE} ${fpath}/gfs.t${HH}z.pgrb2.0p25.f${fhr} #do hard links by the file owner if possible
