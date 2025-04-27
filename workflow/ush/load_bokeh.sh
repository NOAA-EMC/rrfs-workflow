#!/bin/bash
#
# Check if the script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Usage: source ${0}"
  exit 1
fi

### scripts continues here...
ushdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# shellcheck disable=SC1091
source "${ushdir}/detect_machine.sh"

module purge
module use "${ushdir}/../../modulefiles"
if [[ "${MACHINE}" == "gaea" ]]; then
  if [[ -d /gpfs/f5 ]]; then
    module load "BOKEH/${MACHINE}C5"
  elif [[ -d /gpfs/f6 ]]; then
    module load "BOKEH/${MACHINE}C6"
  else
    echo "not supported gaea cluster: ${MACHINE}"
  fi
else
  module load "BOKEH/${MACHINE}"
fi
