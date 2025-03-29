#!/usr/bin/env bash
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# shellcheck disable=SC1091
source "${run_dir}/detect_machine.sh"

case ${MACHINE} in
  wcoss2)
    EXEC_DIR=/to/be/added
    ;;
  hera)
    EXEC_DIR=/scratch1/BMC/wrfruc/gge/Miniforge3/envs/bokeh/bin
    ;;
  jet)
    EXEC_DIR=/lfs6/BMC/wrfruc/gge/Miniforge3/envs/bokeh/bin
    ;;
  orion)
    EXEC_DIR=/work/noaa/zrtrr/gge/Miniforge3/envs/bokeh/bin
    ;;
  hercules)
    EXEC_DIR=/work/noaa/zrtrr/gge/hercules/Miniforge3/envs/bokeh/bin
    ;;
  gaea)
    if [[ -d /gpfs/f5 ]]; then
      EXEC_DIR=/to/be/added
    elif [[ -d /gpfs/f6 ]]; then
      EXEC_DIR=/gpfs/f6/bil-fire10-oar/world-shared/gge/Miniforge3/envs/bokeh/bin
    else
      echo "unsupported gaea cluster: ${MACHINE}"
      exit 1
    fi
    ;;
  *)
    EXEC_DIR=/unknown/location
    echo "platform not supported: ${MACHINE}"
    exit 1
    ;;
esac
"${EXEC_DIR}/flake8" "$@"
