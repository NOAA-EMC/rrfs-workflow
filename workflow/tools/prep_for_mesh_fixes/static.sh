#!/usr/bin/env bash
#
# shellcheck disable=all
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${run_dir}/../detect_machine.sh"
HOMErrfs="${run_dir}/../../.."

case ${MACHINE} in
  wcoss2)
    config_geog_data_path=/to/be/added
    ;;
  hera|ursa)
    config_geog_data_path=/scratch3/BMC/wrfruc/mpas/WPS_GEOG/
    ;;
  jet)
    config_geog_data_path=/mnt/lfs5/BMC/wrfruc/HRRRv5/geog/
    ;;
  orion|hercules)
    config_geog_data_path=/work/noaa/zrtrr/WPS_GEOG
    ;;
  derecho)
    config_geog_data_path=/glade/work/geguo/WPS_GEOG
    ;;
  gaeac?)
    if [[ -d /gpfs/f5 ]]; then
      config_geog_data_path=/to/be/added
    elif [[ -d /gpfs/f6 ]]; then
      config_geog_data_path=/gpfs/f6/arfs-gsl/world-shared/WPS_GEOG/
    else
      echo "unsupported gaea cluster: ${MACHINE}"
    fi
    ;;
  *)
    config_geog_data_path=/to/be/added
    echo "platform not supported: ${MACHINE}"
    ;;
esac

PHYSICS_SUITE=hrrrv5  # modify if using other suites

cp ${run_dir}/streams.init_atmosphere.static ${HOMErrfs}/parm/streams.init_atmosphere
cp ${run_dir}/namelist.init_atmosphere.static ${HOMErrfs}/parm/${PHYSICS_SUITE}/namelist.init_atmosphere
sed -i -e "s#@config_geog_data_path@#${config_geog_data_path}#" ${HOMErrfs}/parm/${PHYSICS_SUITE}/namelist.init_atmosphere 
sed -i -e 's#${cpreq} "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.static.nc" static.nc#${cpreq} "${FIXrrfs}/${MESH_NAME}/${MESH_NAME}.grid.nc" grid.nc#' ${HOMErrfs}/scripts/exrrfs_ic.sh

echo -e "\n !! Done !! Changes have been made for generating static.nc and ugwp_oro_data.nc"
echo "Go to expdir, run 'bkg_rrun 202405060000' to get to the completion of the 'ic' task"
echo "Or use git checkout to revert the above changes"
