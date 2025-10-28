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
