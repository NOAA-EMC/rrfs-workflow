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

cp ${run_dir}/streams.init_atmosphere.invariant ${HOMErrfs}/parm/streams.init_atmosphere
cp ${run_dir}/namelist.init_atmosphere.invariant ${HOMErrfs}/parm/${PHYSICS_SUITE}/namelist.init_atmosphere
sed -i -e "s#@config_geog_data_path@#${config_geog_data_path}#" ${HOMErrfs}/parm/${PHYSICS_SUITE}/namelist.init_atmosphere 
#revert the previous change to `scripts/exrrfs_ic.sh`
git checkout ${HOMErrfs}/scripts/exrrfs_ic.sh

echo -e "\n !! Done !! Changes have been made for generating invariant.nc"
echo "Go to expdir, run 'rwind 202405060000 ic; rboot 202405060000 ic' to reboot the 'ic' task"
echo "Or use git checkout to revert the above changes"
