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
    BASEDIR=/scratch4/BMC/zrtrr/gge/rocoto_hera/modulefiles
    ;;
  ursa)
    BASEDIR=/scratch4/BMC/zrtrr/gge/rocoto/modulefiles
    ;;
  derecho)
    BASEDIR=/glade/work/geguo/rocoto/modulefiles
    ;;
  jet)
    BASEDIR=/lfs5/BMC/nrtrr/gge/rocoto/modulefiles
    ;;
  orion)
    BASEDIR=/work/noaa/zrtrr/gge/rocoto/modulefiles
    ;;
  hercules)
    BASEDIR=/work/noaa/zrtrr/gge/hercules/rocoto/modulefiles
    ;;
  gaeac?)
    if [[ -d /gpfs/f5 ]]; then
      BASEDIR=/to/be/added
    elif [[ -d /gpfs/f6 ]]; then
      BASEDIR=/gpfs/f6/arfs-gsl/world-shared/gge/rocoto/modulefiles
    else
      echo "unsupported gaea cluster: ${MACHINE}"
    fi
    ;;
  *)
    BASEDIR=/unknown/location
    echo "platform not supported: ${MACHINE}"
    ;;
esac
module use ${BASEDIR}
module load rocoto/1.3.7g
