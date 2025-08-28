#!/bin/bash
set -xa

#################################################
# Set up model and cycle specific variables
#################################################

export model=`echo $RUN | awk '{print tolower($0)}'`
export GRIB=prslev
export DBN_ALERT_TYPE=RRFS_GEMPAK
FHR=$(echo $FHR | cut -c1-3)
#################################################################
# Execute the script to make conus GEMPAK grids

mkdir -p $DATA/rrfs_conus
cd $DATA/rrfs_conus

if [ -e ${DATA}/poescript ]
then
rm -f ${DATA}/poescript
fi

# Copy model specific GEMPAK tables into working directory
#
cp ${GEMPAK_FIX}/rrfs_ncepgrib129.tbl ncepgrib129.tbl
cp ${GEMPAK_FIX}/rrfs_ncepgrib2.tbl ncepgrib2.tbl
cp ${GEMPAK_FIX}/rrfs_wmogrib2.tbl wmogrib2.tbl
cp ${GEMPAK_FIX}/rrfs_vcrdgrib1.tbl vcrdgrib1.tbl

cd $DATA
export GRIB=prslev
export type=rrfs_conus
echo "$USHrrfs/prdgen_gempak.sh $type $GRIB $FHR" > $DATA/poescript
#################################################################

#################################################################
#

if [ $FHR -ge 01 -a $FHR -le 18 ]
then
mkdir -p $DATA/rrfs_conus_subh
cd $DATA/rrfs_conus_subh

# Copy model specific GEMPAK tables into working directory
#
cp ${GEMPAK_FIX}/rrfs_ncepgrib129.tbl ncepgrib129.tbl
cp ${GEMPAK_FIX}/rrfs_ncepgrib2.tbl ncepgrib2.tbl
cp ${GEMPAK_FIX}/rrfs_wmogrib2.tbl wmogrib2.tbl
cp ${GEMPAK_FIX}/rrfs_vcrdgrib1.tbl vcrdgrib1.tbl

cd $DATA
export GRIB=prslev
export type=rrfs_conus_subh
echo "$USHrrfs/prdgen_gempak.sh $type $GRIB $FHR" >> $DATA/poescript
fi
#################################################################

#################################################################
# Execute the script to make conus GEMPAK grids (Common convection-allowing model fields)
#
# won't work currently as CONUS testbed files lack .idx files
#
#
# mkdir -p $DATA/rrfs_conus_cam
# cd $DATA/rrfs_conus_cam

# Copy model specific GEMPAK tables into working directory
#
# cp ${GEMPAK_FIX}/rrfs_ncepgrib129.tbl ncepgrib129.tbl
# cp ${GEMPAK_FIX}/rrfs_ncepgrib2.tbl ncepgrib2.tbl
# cp ${GEMPAK_FIX}/rrfs_wmogrib2.tbl wmogrib2.tbl
# cp ${GEMPAK_FIX}/rrfs_vcrdgrib1.tbl vcrdgrib1.tbl

# cd $DATA
# export GRIB=testbed
# export type=rrfs_conus_cam
# echo "$USHrrfs/prdgen_gempak.sh $type $GRIB $FHR" >> $DATA/poescript
#################################################################

#################################################################
# Execute the script to make alaska GEMPAK grids
mkdir -p $DATA/rrfs_alaska
cd $DATA/rrfs_alaska

# Copy model specific GEMPAK tables into working directory
#
cp ${GEMPAK_FIX}/rrfs_ncepgrib129.tbl ncepgrib129.tbl
cp ${GEMPAK_FIX}/rrfs_ncepgrib2.tbl ncepgrib2.tbl
cp ${GEMPAK_FIX}/rrfs_wmogrib2.tbl wmogrib2.tbl
cp ${GEMPAK_FIX}/rrfs_vcrdgrib1.tbl vcrdgrib1.tbl

cd $DATA
export GRIB=prslev
export type=rrfs_alaska
echo "$USHrrfs/prdgen_gempak.sh $type $GRIB $FHR" >> $DATA/poescript
#################################################################
# Execute the script to make Puerto Rico GEMPAK grids
mkdir -p $DATA/rrfs_prico
cd $DATA/rrfs_prico

# Copy model specific GEMPAK tables into working directory
#
cp ${GEMPAK_FIX}/rrfs_ncepgrib129.tbl ncepgrib129.tbl
cp ${GEMPAK_FIX}/rrfs_ncepgrib2.tbl ncepgrib2.tbl
cp ${GEMPAK_FIX}/rrfs_wmogrib2.tbl wmogrib2.tbl
cp ${GEMPAK_FIX}/rrfs_vcrdgrib1.tbl vcrdgrib1.tbl

cd $DATA
export GRIB=prslev
export type=rrfs_prico
echo "$USHrrfs/prdgen_gempak.sh $type $GRIB $FHR" >> $DATA/poescript
#################################################################
# Execute the script to make Hawaii GEMPAK grids
mkdir -p $DATA/rrfs_hawaii
cd $DATA/rrfs_hawaii

# Copy model specific GEMPAK tables into working directory
#
cp ${GEMPAK_FIX}/rrfs_ncepgrib129.tbl ncepgrib129.tbl
cp ${GEMPAK_FIX}/rrfs_ncepgrib2.tbl ncepgrib2.tbl
cp ${GEMPAK_FIX}/rrfs_wmogrib2.tbl wmogrib2.tbl
cp ${GEMPAK_FIX}/rrfs_vcrdgrib1.tbl vcrdgrib1.tbl

cd $DATA
export GRIB=prslev
export type=rrfs_hawaii
echo "$USHrrfs/prdgen_gempak.sh $type $GRIB $FHR" >> $DATA/poescript
#################################################################
cat poescript

chmod 775 $DATA/poescript

export CMDFILE=$DATA/poescript
# Execute the script.
mpiexec -cpu-bind core -configfile $CMDFILE
export err=$?; err_chk

date
msg="ENDED NORMALLY."
postmsg "$msg"
