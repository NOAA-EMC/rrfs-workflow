#!/bin/bash
# shellcheck disable=all
# Check if the script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Usage: source ${0}"
  exit 1
fi

### scripts continues here...
ushdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# shellcheck disable=SC1091
source "${ushdir}/detect_machine.sh"

case ${MACHINE} in
  wcoss2)
    BASEDIR=/to/be/added
    ;;
  hera)
    BASEDIR=/scratch3/BMC/wrfruc/hera/Miniforge3
    ;;
  ursa)
    BASEDIR=/scratch3/BMC/wrfruc/gge/Miniforge3
    ;;
  derecho)
    BASEDIR=/glade/work/geguo/Miniforge3
    ;;
  jet)
    BASEDIR=/lfs6/BMC/wrfruc/gge/Miniforge3
    ;;
  orion)
    BASEDIR=/work/noaa/zrtrr/gge/Miniforge3
    ;;
  hercules)
    BASEDIR=/work/noaa/zrtrr/gge/hercules/Miniforge3
    ;;
  gaeac?)
    if [[ -d /gpfs/f5 ]]; then
      BASEDIR=/to/be/added
    elif [[ -d /gpfs/f6 ]]; then
      BASEDIR=/gpfs/f6/bil-fire10-oar/world-shared/gge/Miniforge3
    else
      echo "unsupported gaea cluster: ${MACHINE}"
    fi
    ;;
  *)
    BASEDIR=/unknown/location
    echo "platform not supported: ${MACHINE}"
    ;;
esac
eval "$($BASEDIR/bin/micromamba shell hook --shell bash)"
micromamba activate ${BASEDIR}/envs/bokeh
alias conda=micromamba
