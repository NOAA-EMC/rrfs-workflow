#!/usr/bin/env bash
# shellcheck disable=SC2034

case ${MACHINE} in
  wcoss2)
    EXEC_DIR=/to/be/added
    ;;
  hera)
    EXEC_DIR=/scratch3/BMC/wrfruc/hera/Miniforge3/envs/pyDAmonitor/bin
    ;;
  ursa)
    EXEC_DIR=/scratch3/BMC/wrfruc/gge/Miniforge3/envs/pyDAmonitor/bin
    ;;
  orion)
    EXEC_DIR=/work/noaa/zrtrr/gge/Miniforge3/envs/pyDAmonitor/bin
    ;;
  hercules)
    EXEC_DIR=/work/noaa/zrtrr/gge/hercules/Miniforge3/envs/pyDAmonitor/bin
    ;;
  derecho)
    EXEC_DIR=/glade/work/geguo/Miniforge3/envs/pyDAmonitor/bin
    ;;
  gaeac?)
    if [[ -d /gpfs/f5 ]]; then
      EXEC_DIR=/to/be/added
    elif [[ -d /gpfs/f6 ]]; then
      EXEC_DIR=/gpfs/f6/bil-fire10-oar/world-shared/gge/Miniforge3/envs/pyDAmonitor/bin
    elif [[ -d /gpfs/f7 ]]; then
      EXEC_DIR=/gpfs/f7/wrfruc/world-shared/gge/Miniforge3/envs/pyDAmonitor/bin
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
