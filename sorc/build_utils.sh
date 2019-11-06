#!/bin/sh
set -eux

export USE_PREINST_LIBS="true"

#------------------------------------
# END USER DEFINED STUFF
#------------------------------------

build_dir=`pwd`
logs_dir=$build_dir/logs
if [ ! -d $logs_dir  ]; then
  echo "Creating logs folder"
  mkdir $logs_dir
fi

#------------------------------------
# INCLUDE PARTIAL BUILD 
#------------------------------------

. ./partial_build.sh

UFS_UTILS_DEV=$build_dir/UFS_UTILS_develop/sorc
UFS_UTILS_CHGRES_GRIB2=$build_dir/UFS_UTILS_chgres_grib2/sorc

#------------------------------------
# build chgres
#------------------------------------
$Build_chgres && {
echo " .... Chgres build not currently supported .... "
#echo " .... Building chgres .... "
#./build_chgres.sh > $logs_dir/build_chgres.log 2>&1
}

#------------------------------------
# build chgres_cube
#------------------------------------
$Build_chgres_cube && {
echo " .... Building chgres_cube .... "
cd $UFS_UTILS_CHGRES_GRIB2
./build_chgres_cube.sh > $logs_dir/build_chgres_cube.log 2>&1
}

#------------------------------------
# build orog
#------------------------------------
$Build_orog && {
echo " .... Building orog .... "
cd $UFS_UTILS_DEV
./build_orog.sh > $logs_dir/build_orog.log 2>&1
}

#------------------------------------
# build fre-nctools
#------------------------------------
$Build_nctools && {
echo " .... Building fre-nctools .... "
cd $UFS_UTILS_DEV
./build_fre-nctools.sh > $logs_dir/build_fre-nctools.log 2>&1
}

#------------------------------------
# build sfc_climo_gen
#------------------------------------
$Build_sfc_climo_gen && {
echo " .... Building sfc_climo_gen .... "
cd $UFS_UTILS_DEV
./build_sfc_climo_gen.sh > $logs_dir/build_sfc_climo_gen.log 2>&1
}

#------------------------------------
# build regional_grid
#------------------------------------
$Build_regional_grid && {
echo " .... Building regional_grid .... "
cd $build_dir
./build_regional_grid.sh > $logs_dir/build_regional_grid.log 2>&1
}

cd $build_dir

echo 'Building utils done'
