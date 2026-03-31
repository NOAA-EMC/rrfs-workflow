#!/bin/bash
# shellcheck disable=all
pygraf_hash=36841088
#
toolsdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${toolsdir}/../sideload"
if [[ -d pygraf ]]; then
  echo "pygraf/ already cloned, no actions."
else
  which git-lfs 2>/dev/null ||  module load git-lfs
  set -x
  GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/NOAA-GSL/pygraf.git
  cd pygraf
  git checkout "${pygraf_hash}" &> /dev/null
fi
