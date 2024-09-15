#!/usr/bin/env bash
export TZ="GMT"
set -x
src="/public/data/grib/ftp_rap_hyb/7/0/105/0_151987_30"
dst="/lfs5/BMC/nrtrr/NCO_data/rap"

# the workflow provides the $GRBFILE env variables
fname=${GRBFILE##*/}
yyyy=20${fname:0:2}
ndays=$(( 10#${fname:2:3} - 1 ))
PDY=$(date -d "${ndays} days ${yyyy}-01-01" +"%Y%m%d")
HH=${fname:5:2}
fhr=$(( 10#${fname:7:6} ))
fhr=$(printf "%02d" ${fhr})
fpath=${dst}/rap.${PDY}
mkdir -p ${fpath}
ln -snf ${GRBFILE} ${fpath}/rap.t${HH}z.wrfnatf${fhr}.grib2
#ln ${GRBFILE} ${fpath}/rap.t${HH}z.wrfnatf${fhr}.grib2 #do hard links by the file owner if possible
