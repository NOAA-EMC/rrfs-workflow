#!/bin/sh
set -xeu

build_dir=`pwd`

CP='cp -rp'

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  echo "Creating ../exec folder"
  mkdir ../exec
fi

#------------------------------------
# INCLUDE PARTIAL BUILD 
#------------------------------------

. ./partial_build.sh

#------------------------------------
# install forecast
#------------------------------------
 ${CP} regional_forecast.fd/NEMS/exe/NEMS.x            ../exec/regional_forecast.x

#------------------------------------
# install post
#------------------------------------
 ${CP} regional_post.fd/exec/ncep_post                 ../exec/regional_post.x

#------------------------------------
# install chgres
#------------------------------------
 ${CP} regional_utils.fd/exec/global_chgres            ../exec/regional_chgres.x

#------------------------------------
# install chgres_cube
#------------------------------------
 ${CP} regional_utils.fd/exec/chgres_cube.exe          ../exec/regional_chgres_cube.x

#------------------------------------
# install orog
#------------------------------------
 ${CP} regional_utils.fd/exec/orog.x                   ../exec/regional_orog.x

#------------------------------------
# install sfc_climo_gen
#------------------------------------
 ${CP} regional_utils.fd/exec/sfc_climo_gen            ../exec/regional_sfc_climo_gen.x

#------------------------------------
# install regional_grid
#------------------------------------
 ${CP} regional_utils.fd/exec/regional_grid            ../exec/regional_grid.x

#------------------------------------
# install fre-nctools
#------------------------------------
 ${CP} regional_utils.fd/exec/make_hgrid               ../exec/regional_make_hgrid.x
#${CP} regional_utils.fd/exec/make_hgrid_parallel      ../exec/regional_make_hgrid_parallel.x
 ${CP} regional_utils.fd/exec/make_solo_mosaic         ../exec/regional_make_solo_mosaic.x
 ${CP} regional_utils.fd/exec/fregrid                  ../exec/regional_fregrid.x
#${CP} regional_utils.fd/exec/fregrid_parallel         ../exec/regional_fregrid_parallel.x
 ${CP} regional_utils.fd/exec/filter_topo              ../exec/regional_filter_topo.x
 ${CP} regional_utils.fd/exec/shave.x                  ../exec/regional_shave.x

#------------------------------------
# install gsi
#------------------------------------
$Build_gsi && {
 ${CP} regional_gsi.fd/exec/global_gsi.x               ../exec/regional_gsi.x
 ${CP} regional_gsi.fd/exec/global_enkf.x              ../exec/regional_enkf.x
 ${CP} regional_gsi.fd/exec/adderrspec.x               ../exec/regional_adderrspec.x
 ${CP} regional_gsi.fd/exec/adjustps.x                 ../exec/regional_adjustps.x
 ${CP} regional_gsi.fd/exec/calc_increment_ens.x       ../exec/regional_calc_increment_ens.x
 ${CP} regional_gsi.fd/exec/calc_increment_serial.x    ../exec/regional_calc_increment_serial.x
 ${CP} regional_gsi.fd/exec/getnstensmeanp.x           ../exec/regional_getnstensmeanp.x
 ${CP} regional_gsi.fd/exec/getsfcensmeanp.x           ../exec/regional_getsfcensmeanp.x
 ${CP} regional_gsi.fd/exec/getsfcnstensupdp.x         ../exec/regional_getsfcnstensupdp.x
 ${CP} regional_gsi.fd/exec/getsigensmeanp_smooth.x    ../exec/regional_getsigensmeanp_smooth.x
 ${CP} regional_gsi.fd/exec/getsigensstatp.x           ../exec/regional_getsigensstatp.x
 ${CP} regional_gsi.fd/exec/gribmean.x                 ../exec/regional_gribmean.x
 ${CP} regional_gsi.fd/exec/nc_diag_cat.x              ../exec/regional_nc_diag_cat.x
 ${CP} regional_gsi.fd/exec/nc_diag_cat_serial.x       ../exec/regional_nc_diag_cat_serial.x
 ${CP} regional_gsi.fd/exec/oznmon_horiz.x             ../exec/regional_oznmon_horiz.x
 ${CP} regional_gsi.fd/exec/oznmon_time.x              ../exec/regional_oznmon_time.x
 ${CP} regional_gsi.fd/exec/radmon_angle.x             ../exec/regional_radmon_angle.x
 ${CP} regional_gsi.fd/exec/radmon_bcoef.x             ../exec/regional_radmon_bcoef.x
 ${CP} regional_gsi.fd/exec/radmon_bcor.x              ../exec/regional_radmon_bcor.x
 ${CP} regional_gsi.fd/exec/radmon_time.x              ../exec/regional_radmon_time.x
 ${CP} regional_gsi.fd/exec/recenternemsiop_hybgain.x  ../exec/regional_recenternemsiop_hybgain.x
 ${CP} regional_gsi.fd/exec/recentersigp.x             ../exec/regional_recentersigp.x
 ${CP} regional_gsi.fd/exec/test_nc_unlimdims.x        ../exec/regional_test_nc_unlimdims.x
}

echo;echo " .... Install system finished .... "

exit 0
