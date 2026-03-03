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
    ROCOTOMODULE=/to/be/added
    ;;
  hera)
    ROCOTOMODULE=/scratch4/BMC/zrtrr/gge/rocoto_hera/modulefiles
    ;;
  ursa)
    ROCOTOMODULE=/scratch4/BMC/zrtrr/gge/rocoto/modulefiles
    ;;
  derecho)
    ROCOTOMODULE=/glade/work/geguo/rocoto/modulefiles
    ;;
  jet)
    ROCOTOMODULE=/lfs5/BMC/nrtrr/gge/rocoto/modulefiles
    ;;
  orion)
    ROCOTOMODULE=/work/noaa/zrtrr/gge/rocoto/modulefiles
    ;;
  hercules)
    ROCOTOMODULE=/work/noaa/zrtrr/gge/hercules/rocoto/modulefiles
    ;;
  gaeac?)
    if [[ -d /gpfs/f5 ]]; then
      ROCOTOMODULE=/to/be/added
    elif [[ -d /gpfs/f6 ]]; then
      ROCOTOMODULE=/gpfs/f6/arfs-gsl/world-shared/gge/rocoto/modulefiles
    else
      echo "unsupported gaea cluster: ${MACHINE}"
    fi
    ;;
  *)
    ROCOTOMODULE=/unknown/location
    echo "platform not supported: ${MACHINE}"
    ;;
esac
module use ${ROCOTOMODULE}
module load rocoto/1.3.7g
