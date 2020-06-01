#! /usr/bin/env bash
set -eux

. ../ush/source_util_funcs.sh

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

if [ $target = jet ]; then target=jet.intel ; fi

if [ $target = cheyenne ]; then target=cheyenne.intel ; fi

#------------------------------------
# Get from the manage_externals configuration file the relative directo-
# ries in which the UFS utility codes (not including chgres_cube) and 
# the chgres_cube codes get cloned.  Note that these two sets of codes
# are in the same repository but different branches.  These directories
# will be relative to the workflow home directory, which we denote below
# by HOMErrfs.  Then form the absolute paths to these codes.
#------------------------------------
HOMErrfs=$( readlink -f "${cwd}/.." )
mng_extrns_cfg_fn="${HOMErrfs}/Externals.cfg"
property_name="local_path"

# First, consider the UFS utility codes, not including chgres (i.e. we
# do not use any versions of chgres or chgres_cube in this set of codes).
external_name="ufs_weather_model"
forecast_model_dir=$( \
get_manage_externals_config_property \
"${mng_extrns_cfg_fn}" "${external_name}" "${property_name}" ) || \
print_err_msg_exit "\
Call to function get_manage_config_externals_property failed."
forecast_model_dir="${HOMErrfs}/${forecast_model_dir}"

cd ${forecast_model_dir}
FV3=$( pwd -P )/FV3
CCPP=${CCPP:-"false"}
cd tests/
if [ $CCPP  = true ] || [ $CCPP = TRUE ] ; then
#EMC  ./compile.sh "$FV3" "$target" "NCEP64LEV=Y HYDRO=N 32BIT=Y CCPP=Y STATIC=Y SUITES=FV3_GFS_2017_gfdlmp_regional"
  ./compile.sh "$FV3" "$target" "CCPP=Y STATIC=N 32BIT=Y REPRO=Y"
else
  ./compile.sh "$FV3" "$target" "NCEP64LEV=Y HYDRO=N 32BIT=Y" 1
fi
#mv -f fv3.exe ../NEMS/exe/NEMS.x
