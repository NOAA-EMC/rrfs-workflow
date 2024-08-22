#!/usr/bin/env bash
#
util_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
agent_dir="${util_dir}/../fix/.agent"
source ${util_dir}/detect_machine.sh 

case ${MACHINE} in
  hera)
    FIX_RRFS_LOCATION=/scratch2/BMC/rtrr/FIX_RRFS2
    ;;
  jet)
    FIX_RRFS_LOCATION=/lfs5/BMC/nrtrr/FIX_RRFS2
    ;;
  orion|hercules)
    FIX_RRFS_LOCATION=/work/noaa/zrtrr/FIX_RRFS2
    ;;
  *)
    FIX_RRFS_LOCATION=/unknown/location
    echo "platform not supported: ${MACHINE}"
    ;;
esac
mkdir -p ${util_dir}/../fix

filetype=$(file $agent_dir)
if [[ ! "$filetype" == *"symbolic link"* ]]; then
  rm -rf ${agent_dir}
fi
ln -snf ${FIX_RRFS_LOCATION} ${agent_dir}

touch ${util_dir}/../fix/INIT_DONE
