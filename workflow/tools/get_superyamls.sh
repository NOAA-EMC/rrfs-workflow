#!/usr/bin/env bash
#
# shellcheck disable=SC1091
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
parm_dir="${run_dir}/../../parm"

domain=${1:-"conus3km"}

cd "${parm_dir}" || exit 1
source "${run_dir}/load_pyDAmonitor.sh"
../workflow/rocoto_funcs/smart_superyaml.py  ..  jedivar  "${domain}"
../workflow/rocoto_funcs/smart_superyaml.py  ..  getkf    "${domain}"
echo "jedivar.yam and getkf.yaml are now available under parm/"
pwd
ls -lrth {jedivar,getkf}.yaml
