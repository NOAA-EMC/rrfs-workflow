#!/usr/bin/env bash
#
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
agent_dir="${run_dir}/../../fix/.agent"
source ${run_dir}/detect_machine.sh 

case ${MACHINE} in
  wcoss2)
    FIX_RRFS_LOCATION=/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS2
    ;;
  hera)
    FIX_RRFS_LOCATION=/scratch2/BMC/rtrr/FIX_RRFS2
    ;;
  jet)
    FIX_RRFS_LOCATION=/lfs5/BMC/nrtrr/FIX_RRFS2
    ;;
  orion|hercules)
    FIX_RRFS_LOCATION=/work/noaa/zrtrr/FIX_RRFS2
    ;;
  gaea)
    if [[ -d /gpfs/f5 ]]; then
      FIX_RRFS_LOCATION=/gpfs/f5/gsl-glo/world-shared/role.rrfsfix/FIX_RRFS2
    elif [[ -d /gpfs/f6 ]]; then
      FIX_RRFS_LOCATION=/gpfs/f6/bil-fire10-oar/world-shared/role.rrfsfix/FIX_RRFS2
    else
      echo "unsupported gaea cluster: ${MACHINE}"
    fi
    ;;
  *)
    FIX_RRFS_LOCATION=/unknown/location
    echo "platform not supported: ${MACHINE}"
    ;;
esac
mkdir -p ${run_dir}/../../fix

filetype=$(file $agent_dir)
if [[ ! "$filetype" == *"symbolic link"* ]]; then
  rm -rf ${agent_dir}
fi
ln -snf ${FIX_RRFS_LOCATION} ${agent_dir}

touch ${run_dir}/../../fix/INIT_DONE
