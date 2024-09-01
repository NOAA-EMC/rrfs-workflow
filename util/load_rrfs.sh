#!/bin/sh
#
# Check if the script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Usage: source ${0}"
  exit 1
fi

### scripts continues here...
ushdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source ${ushdir}/detect_machine.sh

module purge
module use ${ushdir}/../modulefiles
module load rrfs/${MACHINE}.intel
module list
