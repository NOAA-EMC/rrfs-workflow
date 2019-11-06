#! /usr/bin/env bash
set -eux

source ./machine-setup.sh > /dev/null 2>&1
cwd=`pwd`

USE_PREINST_LIBS=${USE_PREINST_LIBS:-"true"}
if [ $USE_PREINST_LIBS = true ]; then
  export MOD_PATH=/scratch3/NCEPDEV/nwprod/lib/modulefiles
else
  export MOD_PATH=${cwd}/lib/modulefiles
fi

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

if [ $target = hera ]; then target=hera.intel ; fi

cd regional_forecast.fd/
FV3=$( pwd -P )/FV3
CCPP=${CCPP:-"false"}
cd tests/
if [ $CCPP  = true ] || [ $CCPP = TRUE ] ; then
  ./compile.sh "$FV3" "$target" "NCEP64LEV=Y HYDRO=N 32BIT=Y CCPP=Y STATIC=Y SUITES=FV3_GFS_2017_gfdlmp_regional" 1
else
  ./compile.sh "$FV3" "$target" "NCEP64LEV=Y HYDRO=N 32BIT=Y" 1
fi
##mv -f fv3_1.exe ../NEMS/exe/fv3_gfs_nh.prod.32bit.x
mv -f fv3_1.exe ../NEMS/exe/NEMS.x
