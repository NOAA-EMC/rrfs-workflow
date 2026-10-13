#!/bin/bash
#
# Set up a retro's fix tree, links and job cards: ecf/setup_ecf_links.sh plus the steps a retro
# needs around it. Settings come from ecf/defs/retro_config.sh; edit that first.
#
# Usage: ush/retro/setup_retro_links.sh
#
# ecf/setup_ecf_links.sh is an operational script that NCO runs too, so the retro-only steps live
# here rather than in it. They keep the order they need there: the fix tree first, because
# setup_ecf_links.sh copies each workflow.conf out of it, and the domain edits last, because the
# EMC resource edits it makes are blanket number substitutions that would otherwise hit them.
#
set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
ecf_dir=${repo}/ecf
# shellcheck source=/dev/null
. "${ecf_dir}/defs/load_retro_config.sh"
: "${FIX_RRFS_DIR:?retro_config.sh must set FIX_RRFS_DIR}"

# cpreq comes from prod_util; on Ursa that is modulefiles/run_ursa.lua (spack-stack). The machine
# decides this rather than retro_config.sh, since the modules are what that machine has.
if [ "${MACHINE}" = "URSA" ]; then
  if ! type module >/dev/null 2>&1; then source /etc/profile; fi
  module use "${repo}/modulefiles"
  module load run_ursa
fi

# Build fix/ as links into the copy of the WCOSS2 fix tree that FIX_RRFS_DIR names.
# workflow/ is a local directory because the workflow.conf step below writes into it.
fix_dir=${repo}/fix
fix_src=${FIX_RRFS_DIR}
mkdir -p "${fix_dir}"
for src in "${fix_src}"/*; do
  name=$(basename "${src}")
  [ "${name}" = "workflow" ] && continue
  ln -snf "${src}" "${fix_dir}/${name}"
done
for wgf in det enkf ensf firewx; do
  mkdir -p "${fix_dir}/workflow/${wgf}"
  ln -sf "${fix_src}/workflow/${wgf}/workflow.conf_prod" "${fix_dir}/workflow/${wgf}/workflow.conf_prod"
  ln -sf "${fix_src}/workflow/${wgf}/workflow.conf_dev" "${fix_dir}/workflow/${wgf}/workflow.conf_dev"
done

# RESOURCE_CONFIG picks the _prod or _dev workflow.conf and the matching job cards
export RESOURCE_CONFIG
(cd "${ecf_dir}" && ./setup_ecf_links.sh)

cd "${fix_dir}/workflow"

# Retros read the staged GFS GRIB2 files for the deterministic boundaries; the netcdf files
# operations uses (hourly out to f102, four cycles a day) are far too large to stage.
if [ "${RETRO:-NO}" = "YES" ]; then
  echo "Retro: deterministic LBCs from GFS grib2, no Great Lakes FVCOM..."
  sed -i "s|^export GFS_FILE_FMT_LBCS=.*|export GFS_FILE_FMT_LBCS='grib2'|" ./det/workflow.conf
  # No Great Lakes FVCOM (nosofs) data is staged for retros, and warm starts abort without it; the
  # Rocoto retros run without it too (PREP_FVCOM=FALSE)
  sed -i "s|^export USE_FVCOM=.*|export USE_FVCOM='FALSE'|; s|^export PREP_FVCOM=.*|export PREP_FVCOM='FALSE'|" ./det/workflow.conf
fi

# The EMC ensf layout (50 x 64 for every member) does not match the per-member stochastic
# physics namelists, which are 40 x 72 for members 1 and 4 and 44 x 72 for 2, 3 and 5, so the
# model aborts with "at least one pe in pelist is not used by any tile". The NCO set agrees with
# them, so take its layout; LAYOUT_X_ENSF_LARGER is the value members 2, 3 and 5 use.
if [ "${RESOURCE_CONFIG:-NCO}" = "EMC" ]; then
  sed -i "s|^export LAYOUT_X_ENSF=.*|export LAYOUT_X_ENSF='40'|; \
          s|^export LAYOUT_X_ENSF_LARGER=.*|export LAYOUT_X_ENSF_LARGER='44'|; \
          s|^export LAYOUT_Y_ENSF=.*|export LAYOUT_Y_ENSF='72'|" ./ensf/workflow.conf
fi

# Ursa nodes have less memory than WCOSS2's, so the forecasts run fewer ranks per node.
if [ "${MACHINE}" = "URSA" ]; then
  echo "Ursa: fewer forecast ranks per node..."
  # An Ursa node has 360 GB for 192 cores, against 500 GB on WCOSS2, so 64 forecast ranks per node
  # leaves the write tasks short and they are OOM-killed. 48 per node restores ~7.5 GB per rank;
  # the rank count itself comes from the layout and does not change (see the ecf cards' --nodes).
  sed -i "s|^export PPN_FORECAST=.*|export PPN_FORECAST='48'|" ./det/workflow.conf
  # Even at 48 per node the production forecast's write ranks run out of memory as output builds up.
  # One write group of 768 instead of three of 192 quarters what each write rank holds and keeps a
  # single output copy in flight; the rank count is unchanged, so the job still fits in 74 nodes.
  sed -i -E "s/^export (WRTCMP_write_groups(_18H|_LONG)?)=.*/export \1='1'/; s/^export (WRTCMP_write_tasks_per_group(_18H|_LONG)?)=.*/export \1='768'/" ./det/workflow.conf
  # An EnKF member spreads the same domain over 704 ranks against 1856 for the deterministic
  # spinup, so each rank holds far more and needs 24 per node (see the member cards' --nodes).
  sed -i "s|^export PPN_FORECAST=.*|export PPN_FORECAST='24'|" ./enkf/workflow.conf
  # A 60 h member OOM-killed a write rank at hour 58 with one group of 128, the same way the
  # deterministic forecast did: the write ranks fill as output accumulates. Doubling the group
  # halves what each one holds. 2880 or 3168 compute plus 256 write at 48 per node is 66 or 72
  # nodes, inside the 75-node cap.
  sed -i "s|^export WRTCMP_write_tasks_per_group_ENSF=.*|export WRTCMP_write_tasks_per_group_ENSF='256'|" ./ensf/workflow.conf
  sed -i "s|^export PPN_FORECAST=.*|export PPN_FORECAST='48'|" ./ensf/workflow.conf
  grep -n "GFS_FILE_FMT\|PPN_FORECAST" ./det/workflow.conf
fi

# A domain other than the operational NA 3 km one (DOMAIN in retro_config.sh).
if [ "${DOMAIN}" != "RRFS_NA_3km" ]; then
  domain_file=${ecf_dir}/defs/domains/${DOMAIN}.sh
  [ -f "${domain_file}" ] || { echo "FATAL: no ${domain_file} for DOMAIN=${DOMAIN}"; exit 1; }
  # shellcheck source=/dev/null
  . "${domain_file}"
  echo "Domain: ${DOMAIN}"
  # its fix directories go in beside the NA ones, so fix/<subdir> becomes a directory of links
  for entry in "${DOMAIN_FIX_LINKS[@]}"; do
    sub=${entry%%:*}
    [ -L "${fix_dir}/${sub}" ] && rm -f "${fix_dir}/${sub}"
    mkdir -p "${fix_dir}/${sub}"
    for src in "${fix_src}/${sub}"/*; do
      ln -snf "${src}" "${fix_dir}/${sub}/$(basename "${src}")"
    done
    ln -snf "${entry#*:}" "${fix_dir}/${sub}/${DOMAIN}"
  done
  for wgf in det enkf ensf; do
    domain_workflow_conf >> "${fix_dir}/workflow/${wgf}/workflow.conf"
    for fl in "${repo}"/parm/config/${wgf}/input.nml*; do
      sed -i -E "s/^( *npx *= *).*/\1${NML_NPX}/; s/^( *npy *= *).*/\1${NML_NPY}/; \
        s/^( *target_lat *= *).*/\1${NML_TARGET_LAT}/; s/^( *target_lon *= *).*/\1${NML_TARGET_LON}/; \
        s/^( *layout *= *).*/\1${NML_LAYOUT}/; ${NML_SED_EXTRA:-}" "${fl}"
    done
  done
fi
