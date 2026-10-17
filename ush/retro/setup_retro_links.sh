#!/bin/bash
#
# Set up a retro's fix tree, links and job cards: ecf/setup_ecf_links.sh plus the steps a retro
# needs around it. Settings come from ecf/defs/retro/config.sh; edit that first.
#
# Usage: ush/retro/setup_retro_links.sh
#
# ecf/setup_ecf_links.sh is an operational script that NCO runs too, so the retro-only steps live
# here rather than in it. They keep the order they need there: the fix tree first, because
# setup_ecf_links.sh copies each workflow.conf out of it; then the domain's settings; and the
# settings of a simplified retro last, so that nothing appended after them wins.
#
set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
ecf_dir=${repo}/ecf
# shellcheck source=/dev/null
. "${ecf_dir}/defs/retro/load_config.sh"
: "${FIX_RRFS_DIR:?retro/config.sh must set FIX_RRFS_DIR}"

# cpreq comes from prod_util; on Ursa that is modulefiles/run_ursa.lua (spack-stack). The machine
# decides this rather than retro/config.sh, since the modules are what that machine has.
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

# The domain (DOMAIN in retro/config.sh): its grid, fix files and job sizes.
domain_file=${ecf_dir}/defs/retro/domains/${DOMAIN}.sh
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
  conf_block=$(domain_workflow_conf "${wgf}")
  printf '%s\n' "${conf_block}" >> "${fix_dir}/workflow/${wgf}/workflow.conf"
  # A domain whose values were taken from a package workflow.conf (DOMAIN_PACKAGE_CONF) is checked
  # against it, up to its retro overrides, so a package update that changes one is noticed
  if [ -n "${DOMAIN_PACKAGE_CONF:-}" ]; then
    pkg_conf=${fix_src}/workflow/${wgf}/${DOMAIN_PACKAGE_CONF}
    unquote="s/[[:space:]]+#.*//; s/^['\"]//; s/['\"]$//"
    while IFS= read -r line; do
      [[ ${line} == *"retro overrides"* ]] && break
      [[ ${line} =~ ^\ *export\ ([A-Za-z0-9_]+)=(.*)$ ]] || continue
      name=${BASH_REMATCH[1]}
      ours=$(sed -E "${unquote}" <<< "${BASH_REMATCH[2]}")
      theirs=$(grep -E "^ *export ${name}=" "${pkg_conf}" | tail -1 | sed -E "s/^ *export ${name}=//; ${unquote}")
      if [ "${ours}" != "${theirs}" ]; then
        echo "WARNING: ${DOMAIN}.sh sets ${wgf} ${name}='${ours}', but ${pkg_conf} has '${theirs}'"
      fi
    done <<< "${conf_block}"
  fi
  # a domain without NML_NPX keeps the package namelists' grid
  [ -n "${NML_NPX:-}" ] || continue
  for fl in "${repo}"/parm/config/${wgf}/input.nml*; do
    sed -i -E "s/^( *npx *= *).*/\1${NML_NPX}/; s/^( *npy *= *).*/\1${NML_NPY}/; \
      s/^( *target_lat *= *).*/\1${NML_TARGET_LAT}/; s/^( *target_lon *= *).*/\1${NML_TARGET_LON}/; \
      s/^( *layout *= *).*/\1${NML_LAYOUT}/; ${NML_SED_EXTRA:-}" "${fl}"
  done
done

# ---------------------------------------------------------------------------------------------
# A simplified retro: the same switches the Rocoto workflow's ush/config.sh turns off for a short
# cycling or DA run. ecf/defs/retro/make_rrfs_retro_def.sh reads the same settings out of
# retro/config.sh and takes the matching tasks out of the suite definition; what is set here is
# the half the jobs themselves read.
# ---------------------------------------------------------------------------------------------
python3 - ./det/workflow.conf \
  "${DO_SPINUP:-TRUE}" "${DET_COLD_START_HRS:-03 15}" \
  "${FCST_LEN_HRS:-18}" "${FCST_LEN_HRS_LONG:-84}" \
  "${RUN_LIGHTNING:-TRUE}" "${RUN_GSIDIAG:-TRUE}" "${RUN_UPDATE_BC:-TRUE}" \
  "${RUN_SMOKE:-TRUE}" <<'EOF'
import re
import sys

(path, spinup, cold_hours, fcst_len, fcst_len_long,
 lightning, gsidiag, update_bc, smoke) = sys.argv[1:10]
cold_hours = cold_hours.split()
fcst_len, fcst_len_long = int(fcst_len), int(fcst_len_long)
text = open(path).read()
changed = []


def scalar(name, value):
    """Rewrite one export NAME='value' line."""
    global text
    text, n = re.subn(r"^export %s=.*$" % name, "export %s='%s'" % (name, value),
                      text, flags=re.M)
    if n:
        changed.append("%s=%s" % (name, value))


def array(name, values):
    """Rewrite one of the multi-line list settings, export NAME=( \\ ... )."""
    global text
    body = "".join("'%s' \\\n" % v for v in values)
    text, n = re.subn(r"^export %s=\( \\\n(?:.*\\\n)*?\)$" % name,
                      "export %s=( \\\n%s)" % (name, body), text, flags=re.M)
    if n:
        changed.append("%s=(%s)" % (name, " ".join(str(v) for v in values)))


if spinup == "FALSE":
    # exrrfs_prep_cyc.sh and exrrfs_process_radar.sh cold start a production cycle whose hour is
    # in CYCL_HRS_PRODSTART when DO_SPINUP is FALSE, which is how the cold start moves out of the
    # spin-up cycle. The hours have to be the ones with a make_ics task in the suite.
    scalar("DO_SPINUP", "FALSE")
    array("CYCL_HRS_PRODSTART", cold_hours)
    # With no spin-up cycle there is no <hour>_spinup EnKF output for the hybrid analysis to
    # prefer, so leave this list matching no hour at all rather than send the analysis looking
    # for a directory that is never written.
    array("CYCL_HRS_PRODSTART_ENS", ["-1", "-1"])

if (fcst_len, fcst_len_long) != (18, 84):
    scalar("FCST_LEN_HRS", fcst_len)
    array("FCST_LEN_HRS_CYCLES",
          [fcst_len_long if h % 6 == 0 else fcst_len for h in range(24)])
    # Boundaries are made once per 6-hourly family and shared by its six cycles, so they have to
    # reach the end of the longest forecast in it: the 00, 06, 12 or 18z one, or the 05z one,
    # whichever ends later. Shortening this also shortens the list of external model files the
    # first boundary group stages for the others, which is why exrrfs_make_lbcs.sh counts that
    # list rather than the operational 97.
    scalar("BOUNDARY_LEN", max(fcst_len_long, fcst_len + 5))

# Steps the suite definition leaves out are switched off here as well wherever a job that does
# run would otherwise look for what they produce: the GSI reads DO_GLM_FED_DA to decide whether
# to take lightning observations.
#
# DO_GSIDIAG_OFFLINE is deliberately not touched by RUN_GSIDIAG. It does not mean "produce
# diagnostics": it says they are produced by the offline job rather than inside the analysis, so
# with the offline task switched off TRUE is still the value that wants nothing extra from the
# analysis. Setting it FALSE turns the inline path on, and that path copies into a satbias
# directory only the offline job's J-job creates, so the analysis aborts at the very end.
if lightning == "FALSE":
    scalar("DO_GLM_FED_DA", "FALSE")
if update_bc == "FALSE":
    scalar("DO_UPDATE_BC", "FALSE")
    scalar("DO_SOIL_ADJUST", "FALSE")
if smoke == "FALSE":
    # the forecast carries the smoke and dust tracers whatever this says, but with no
    # process_smoke task there is nothing to cycle them from
    scalar("DO_SMOKE_DUST", "FALSE")

if changed:
    open(path, "w").write(text)
    print("Simplified workflow: " + ", ".join(changed))
EOF
