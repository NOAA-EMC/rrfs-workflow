#!/bin/bash
# shellcheck disable=all

# Check if the script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Usage: source ${0}"
  exit 1
fi

### scripts continues here...
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
module use ${basedir}/modulefiles
module load qrocoto

source "${basedir}/detect_machine.sh"
case ${MACHINE} in
  wcoss2)
    ROCOTOMODDIR=/to/be/added
    ;;
  hera)
    ROCOTOMODDIR=/scratch4/BMC/zrtrr/gge/rocoto_hera/modulefiles
    ;;
  ursa)
    ROCOTOMODDIR=/scratch4/BMC/zrtrr/gge/rocoto/modulefiles
    ;;
  derecho)
    ROCOTOMODDIR=/glade/work/geguo/rocoto/modulefiles
    ;;
  jet)
    ROCOTOMODDIR=/lfs5/BMC/nrtrr/gge/rocoto/modulefiles
    ;;
  orion)
    ROCOTOMODDIR=/work/noaa/zrtrr/gge/rocoto/modulefiles
    ;;
  hercules)
    ROCOTOMODDIR=/work/noaa/zrtrr/gge/hercules/rocoto/modulefiles
    ;;
  gaeac?)
    if [[ -d /gpfs/f5 ]]; then
      ROCOTOMODDIR=/to/be/added
    elif [[ -d /gpfs/f6 ]]; then
      ROCOTOMODDIR=/gpfs/f6/arfs-gsl/world-shared/gge/rocoto/modulefiles
    else
      echo "unsupported gaea cluster: ${MACHINE}"
    fi
    ;;
  *)
    ROCOTOMODDIR=/unknown/location
    echo "platform not supported: ${MACHINE}"
    ;;
esac
module use ${ROCOTOMODDIR}
module load rocoto/1.3.7g
