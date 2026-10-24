#!/bin/bash
#
# Source the retro settings, ecf/defs/retro/config.sh, into the calling script. It is sourced by
# ush/retro/setup_retro_links.sh, make_rrfs_retro_def.sh, ush/prod_clone/make_retro_def.sh and
# ush/retro/start_retro.sh, so they agree on where the file is and what happens when it is missing.
#
# Usage: . load_config.sh
#
# config.sh is git-ignored; link or copy one of the config_<machine>_<domain>.sh samples beside it.

_retro_dir=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
# RETRO_CONFIG selects an experiment config; the default keeps the existing config.sh workflow.
_retro_config=${RETRO_CONFIG:-${_retro_dir}/config.sh}
if [ -f "${_retro_config}" ]; then
  # shellcheck source=/dev/null
  . "${_retro_config}"
else
  echo "Retro config not found: ${_retro_config}" >&2
  # where the file used to live, before the retro settings moved into ecf/defs/retro
  for old in "${_retro_dir}/../retro_config.sh" "${_retro_dir}/../ursa_config.sh"; do
    if [ -e "${old}" ] || [ -L "${old}" ]; then
      echo "$(basename "${old}") in ecf/defs is its old place: move it to ecf/defs/retro/config.sh." >&2
    fi
  done
  echo "Link or copy the sample for your machine and domain, e.g." >&2
  echo "  ln -s config_ursa_na3km.sh ecf/defs/retro/config.sh" >&2
  exit 1
fi
unset _retro_dir _retro_config
# Each run can use its own pair of top-level suites on a shared ecFlow server.
RRFS_SUITE=${RRFS_SUITE:-para}
PRODCLONE_SUITE=${PRODCLONE_SUITE:-prod_clone}
# Keep each suite's generated workflow settings separate, even when RETRO_WORK_BASE is shared.
RETRO_FIX_DIR=${RETRO_FIX_DIR:-${RETRO_WORK_BASE}/fix/${RRFS_SUITE}}
# Settings files from before MACHINE was a setting were all for Ursa
MACHINE=${MACHINE:-URSA}
# The NA sample leaves DOMAIN out; default it here so every script that reads it agrees
DOMAIN=${DOMAIN:-RRFS_NA_3km}
# dev-sci's shared fix tree, where the domain files (ecf/defs/retro/domains) find other grids' fix files
case ${MACHINE} in
  WCOSS2) FIX_RRFS_SHARED=${FIX_RRFS_SHARED:-/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS} ;;
  *)      FIX_RRFS_SHARED=${FIX_RRFS_SHARED:-/scratch4/BMC/rtrr/FIX_RRFS} ;;
esac
# fix/jedi for the JEDI tasks while the package fix tree has none: dev-sci's shared FIX_RRFS/jedi,
# which its Rocoto workflow links in. Empty uses <fix tree>/jedi
case ${MACHINE} in
  WCOSS2) FIX_RRFS_JEDI=${FIX_RRFS_JEDI:-/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS/jedi} ;;
  URSA)   FIX_RRFS_JEDI=${FIX_RRFS_JEDI:-/scratch4/BMC/rtrr/FIX_RRFS/jedi} ;;
  *) echo "MACHINE=${MACHINE} is not supported; the retros run on URSA and WCOSS2" >&2; exit 1 ;;
esac
