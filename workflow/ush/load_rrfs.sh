#!/bin/bash
# shellcheck disable=SC1091

# Check if the script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Usage: source ${0}"
  exit 1
fi

### scripts continues here...
wushdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${wushdir}/detect_machine.sh"

module purge
module use "${wushdir}/../../modulefiles"
module load "rrfs/${MACHINE}"
module list
