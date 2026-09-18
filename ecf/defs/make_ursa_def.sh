#!/bin/bash
#
# Make an Ursa copy of an RRFS suite definition that submits jobs with Slurm.
# The task tree is unchanged; only suite-wide variables are replaced or added.
#
# Usage: [VAR=value ...] ./make_ursa_def.sh [output_def]
# Any of the settings below can be overridden from the environment.
#
set -eu

defs_dir=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
out_def=${1:-${defs_dir}/rrfs_ursa.def}

# Settings live in ursa_config.sh next to this script; environment variables still win.
# shellcheck source=/dev/null
. "${defs_dir}/ursa_config.sh"

# Derived from the settings above
PACKAGEHOME=${PACKAGEHOME:-$(cd "${defs_dir}/../.." && pwd)}
c=${RETRO_DATA_ROOT}/com
DEV_COMPATH=${DEV_COMPATH:-$c/gfs:$c/gefs:$c/obsproc:$c/nsst:$c/nosofs:$c/hrrr:$c/rap}
DCOMROOT=${DCOMROOT:-${RETRO_DATA_ROOT}/dcom}

awk -v q="'" -v ph="${PACKAGEHOME}" -v eh="${ECF_HOME}" -v od="${OUTPUTDIR}" \
    -v proj="${PROJ}" -v queue="${QUEUE}" -v part="${PARTITION}" \
    -v ptmp="${DEV_PTMP}" -v droot="${DEV_DATAROOT}" -v ev="${ECFLOW_VER}" \
    -v envir="${ENVIR}" -v rver="${RRFS_VER}" -v site="${MACHINE_SITE}" -v eh_host="${ECFLOW_HOST}" \
    -v compath="${DEV_COMPATH}" -v dcom="${DCOMROOT}" '
  function ed(name, value) { print ind "edit " name " " q value q }
  # suite-wide settings go right after the suite line
  $1 == "suite" && !done {
    print; ind = "  "; done = 1
    ed("MACHINE", "URSA")
    ed("PARTITION", part)
    ed("DEV_PTMP", ptmp)
    ed("DEV_DATAROOT", droot)
    ed("DEV_COMPATH", compath)
    ed("DCOMROOT", dcom)
    ed("ecflow_ver", ev)
    ed("ECF_LOGHOST", eh_host)
    ed("ENVIR", envir)
    ed("rrfs_ver", rver)
    ed("MACHINE_SITE", site)
    ed("NET", "rrfs")
    ed("RUN", "rrfs")
    ed("PACKAGEHOME", ph)
    ed("PROJ", proj)
    ed("PROJENVIR", "DEV")
    ed("QUEUE", queue)
    ed("QUEUE_ARCH", queue)
    ed("OUTPUTDIR", od)
    ed("ECF_HOME", eh)
    ed("ECF_INCLUDE", ph "/ecf/include")
    # sbatch would otherwise also read the #PBS lines (e.g. "-q" as the partition)
    ed("ECF_JOB_CMD", "sbatch --ignore-pbs %ECF_JOB% 1> %ECF_JOB%.sub 2>&1")
    ed("ECF_KILL_CMD", "scancel %ECF_RID% 1> %ECF_JOB%.kill 2>&1")
    ed("ECF_STATUS_CMD", "squeue -j %ECF_RID% 1> %ECF_JOB%.stat 2>&1")
    next
  }
  # WCOSS2 locations and queues set further down would override the suite-level values
  $1 == "edit" && ($2 == "PACKAGEHOME" || $2 == "PROJ" || $2 == "QUEUE" || $2 == "QUEUE_ARCH" || $2 == "OUTPUTDIR") {
    ind = substr($0, 1, index($0, "edit") - 1)
    if ($2 == "PACKAGEHOME") ed("PACKAGEHOME", ph)
    if ($2 == "PROJ")        ed("PROJ", proj)
    if ($2 == "QUEUE")       ed("QUEUE", queue)
    if ($2 == "QUEUE_ARCH")  ed("QUEUE_ARCH", queue)
    if ($2 == "OUTPUTDIR")   ed("OUTPUTDIR", od)
    next
  }
  { print }
' "${defs_dir}/${BASE_DEF}" > "${out_def}"

# For retros, make every clock-time condition in the triggers always true; the dependencies on other
# tasks and on /prod_clone stay, and the retro prod_clone steps the dates (ush/prod_clone/make_retro_def.sh)
if [ "${RETRO}" = "YES" ]; then
  sed -i -E 's/:TIME *(>=|>) *[0-9]{4}/:TIME >= 0000/g; s/:TIME *(<=|<) *[0-9]{4}/:TIME < 2400/g' "${out_def}"
fi

echo "Wrote ${out_def} from ${BASE_DEF}"
echo "  PACKAGEHOME=${PACKAGEHOME}"
echo "  ECF_HOME=${ECF_HOME}  (create it before loading the suite)"
echo "  PROJ=${PROJ} QUEUE=${QUEUE} PARTITION=${PARTITION}"
echo "  DEV_PTMP=${DEV_PTMP}"
echo "  DEV_DATAROOT=${DEV_DATAROOT}"
echo "  RETRO_DATA_ROOT=${RETRO_DATA_ROOT}"
