#!/bin/bash
#
# Make an Ursa retro copy of the prod_clone suite (ecf/defs.def). The upstream mirror tasks become
# ecflow dummy tasks (never submitted), and jupdateprodclonestatuses is replaced by jretroprodclone,
# which completes them from staged files and steps the RRFS suite through the retro period.
#
# Usage: [VAR=value ...] ./make_retro_def.sh [output_def]
# Any of the settings below can be overridden from the environment.
#
set -eu

clone_dir=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
out_def=${1:-${clone_dir}/ecf/defs_retro.def}

# Settings live in ecf/defs/ursa_config.sh; environment variables still win.
PACKAGEHOME=${PACKAGEHOME:-$(cd "${clone_dir}/../.." && pwd)}
# shellcheck source=/dev/null
if [ ! -f "${PACKAGEHOME}/ecf/defs/ursa_config.sh" ]; then
  echo "ecf/defs/ursa_config.sh not found." >&2
  echo "Link or copy the sample for your domain, e.g." >&2
  echo "  ln -s ursa_config_na3km.sh ecf/defs/ursa_config.sh" >&2
  exit 1
fi
. "${PACKAGEHOME}/ecf/defs/ursa_config.sh"

awk -v q="'" -v ph="${PACKAGEHOME}" -v eh="${ECF_HOME}" -v com="${RETRO_DATA_ROOT}/com" \
    -v start="${RETRO_START}" -v end="${RETRO_END}" -v suite="${RRFS_SUITE}" -v ev="${ECFLOW_VER}" '
  function ed(name, value) { print "  edit " name " " q value q }
  $1 == "suite" {
    print
    ed("ECF_HOME", eh)
    ed("PACKAGEHOME", ph)
    ed("ECF_FILES", ph "/ush/prod_clone/ecf")
    ed("ENVIR", "prod")
    ed("MACHINE_SITE", "development")
    ed("ecflow_ver", ev)
    ed("RETRO_COMROOT", com)
    ed("RETRO_START", start)
    ed("RETRO_END", end)
    ed("RRFS_SUITE", suite)
    ed("ALWAYS_COMPLETE", "nosofs")
    print ""
    # the poller runs on the ecflow host every minute; submitting it through Slurm would be 1440 jobs a day
    print "  task jretroprodclone"
    print "    edit ECF_JOB_CMD " q "bash %ECF_JOB% 1> %ECF_JOBOUT% 2>&1 &" q
    print "    edit ECF_KILL_CMD " q "kill -15 %ECF_RID% 1> %ECF_JOB%.kill 2>&1" q
    print "    cron 00:00 23:59 00:01"
    skip_top = 1
    next
  }
  # drop the WCOSS2 settings and the real-time status task (up to the primary family)
  skip_top && /^ *family primary/ {
    skip_top = 0
    print ""
    print
    # the upstream mirror tasks have no scripts; the poller sets their states
    print "    edit ECF_DUMMY_TASK " q q
    next
  }
  skip_top { next }
  { print }
' "${clone_dir}/ecf/defs.def" > "${out_def}"

echo "Wrote ${out_def}"
echo "  PACKAGEHOME=${PACKAGEHOME}"
echo "  ECF_HOME=${ECF_HOME}"
echo "  RETRO_COMROOT=${RETRO_DATA_ROOT}/com"
echo "  retro ${RETRO_START} to ${RETRO_END}, stepping suite /${RRFS_SUITE}"
