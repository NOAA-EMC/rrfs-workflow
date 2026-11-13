#!/usr/bin/env bash
#
# shellcheck disable=all
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${run_dir}/detect_machine.sh"
HOMErrfs="${run_dir}/../.."


sed -i -e "s#-DREDUCED_SCALARS=ON#-DREDUCED_SCALARS=ON -DCRTM_VERSION=3#" ${HOMErrfs}/sorc/build.rdas
sed -i -e "s#crtm/2.4.0_jedi#crtm/3.1.6_jedi#" ${HOMErrfs}/scripts/exrrfs_jedivar.sh

echo -e "\n !! Done !! build.rdas and exrrfs_jedivar.sh have been updated for CRTMv3"
