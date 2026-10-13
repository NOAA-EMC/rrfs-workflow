#!/bin/bash
#
# Source the retro settings, ecf/defs/retro_config.sh, into the calling script. It is sourced by
# ush/retro/setup_retro_links.sh, make_rrfs_retro_def.sh, ush/prod_clone/make_retro_def.sh and
# ush/retro/start_retro.sh, so they agree on where the file is and what happens when it is missing.
#
# Usage: . load_retro_config.sh
#
# retro_config.sh is git-ignored; link or copy one of the retro_config_<machine>_<domain>.sh samples
# to it.

_retro_defs_dir=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
if [ -f "${_retro_defs_dir}/retro_config.sh" ]; then
  # shellcheck source=/dev/null
  . "${_retro_defs_dir}/retro_config.sh"
else
  echo "ecf/defs/retro_config.sh not found." >&2
  # the file's name before the retros ran outside Ursa
  if [ -e "${_retro_defs_dir}/ursa_config.sh" ] || [ -L "${_retro_defs_dir}/ursa_config.sh" ]; then
    echo "ecf/defs/ursa_config.sh is its old name: rename it to retro_config.sh." >&2
  fi
  echo "Link or copy the sample for your machine and domain, e.g." >&2
  echo "  ln -s retro_config_ursa_na3km.sh ecf/defs/retro_config.sh" >&2
  exit 1
fi
unset _retro_defs_dir
# Settings files from before MACHINE was a setting were all for Ursa
MACHINE=${MACHINE:-URSA}
# The NA sample leaves DOMAIN out; default it here so every script that reads it agrees
DOMAIN=${DOMAIN:-RRFS_NA_3km}
# dev-sci's shared fix tree, where the domain files (ecf/defs/domains) find other grids' fix files
case ${MACHINE} in
  WCOSS2) FIX_RRFS_SHARED=${FIX_RRFS_SHARED:-/lfs/h2/emc/lam/noscrub/emc.lam/FIX_RRFS} ;;
  *)      FIX_RRFS_SHARED=${FIX_RRFS_SHARED:-/scratch4/BMC/rtrr/FIX_RRFS} ;;
esac
