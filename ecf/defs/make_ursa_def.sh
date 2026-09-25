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
if [ ! -f "${defs_dir}/ursa_config.sh" ]; then
  echo "ecf/defs/ursa_config.sh not found." >&2
  echo "Link or copy the sample for your domain, e.g." >&2
  echo "  ln -s ursa_config_na3km.sh ecf/defs/ursa_config.sh" >&2
  exit 1
fi
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
  # The clock also ordered each cycle's work: preclean at :00 wipes the cycle's working directories,
  # then fire weather (:15), the EnKF (:22) and the ensemble forecast (:30) start. Only det waits for
  # preclean explicitly, so with the clock gone the others would race it and lose their directories.
  # Make them wait for preclean too, which is the ordering the clock gave them.
  python3 - "${out_def}" <<'EOF'
import re, sys
path = sys.argv[1]
lines = open(path).read().split("\n")
out, stack, i = [], [], 0
while i < len(lines):
    line = lines[i]; t = line.strip()
    if t.startswith("family "):
        name = t.split()[1]
        if stack and re.fullmatch(r"\d\dz", stack[-1]) and name in ("enkf", "ensf", "firewx"):
            out.append(line)
            indent = line[:len(line) - len(line.lstrip())] + "  "
            # the family's own attributes run until its first child or endfamily
            j = i + 1
            while j < len(lines) and not re.match(r"\s*(family|task|endfamily)\b", lines[j]):
                j += 1
            attrs = lines[i + 1:j]
            k = next((n for n, a in enumerate(attrs) if a.strip().startswith("trigger ")), None)
            if k is None:
                attrs.insert(0, indent + "trigger preclean == complete")
            else:
                expr = attrs[k].strip()[len("trigger "):]
                attrs[k] = indent + f"trigger ( {expr} ) and preclean == complete"
            out.extend(attrs)
            stack.append(name)
            i = j
            continue
        stack.append(name)
    elif t.startswith("endfamily") and stack:
        stack.pop()
    out.append(line)
    i += 1
open(path, "w").write("\n".join(out))
EOF
  # cycle_end is the suite's developer retro driver (ecf/scripts/cycle_end.ecf): it bumps PDY and
  # force-requeues the cycle families, which would fight the retro prod_clone that drives the dates
  # here. defstatus complete keeps it from ever running, including after a family is requeued.
  sed -i -E 's/^( *)task cycle_end$/&\n\1  defstatus complete/' "${out_def}"

  # Workflow groups switched off in ursa_config.sh (RUN_ENKF, RUN_ENSF, RUN_FIREWX): the same
  # mechanism as cycle_end above, applied to the whole family.
  for wgf in enkf ensf firewx; do
    run_var=RUN_$(echo "${wgf}" | tr '[:lower:]' '[:upper:]')
    [ "${!run_var:-TRUE}" = "FALSE" ] || continue
    sed -i -E "s/^( *)family ${wgf}\$/&\n\1  defstatus complete/" "${out_def}"
    echo "  ${wgf}: families set to defstatus complete (${run_var}=FALSE)"
  done
  # A manager task that waits on the whole forecast family is fragile once anything is requeued:
  # the family reads active while other tasks in it run, so the manager can start before the
  # forecast does, and it reads queued while the saves it releases wait, which deadlocks it.
  # Point those triggers at the forecast task itself.
  python3 - "${out_def}" <<'EOF'
import re, sys
path = sys.argv[1]
lines = open(path).read().split("\n")
# first pass: the forecast task in each cycle's <wgf>/forecast family
fcst, cyc, wgf, in_forecast = {}, None, None, False
for line in lines:
    t = line.strip()
    m = re.match(r"family (\d\dz)$", t)
    if m: cyc = m.group(1)
    m = re.match(r"family (det|enkf|ensf|firewx)\s*$", t)
    if m: wgf = m.group(1)
    if re.match(r"family forecast\s*$", t): in_forecast = True
    elif t.startswith("family "): in_forecast = False
    if in_forecast and t.startswith("task "):
        name = t.split()[1]
        if re.fullmatch(rf"jrrfs_{wgf}_forecast(_spinup|_long|_ensinit)?(_mem001)?", name):
            fcst.setdefault((cyc, wgf), name)
# second pass: rewrite the manager triggers that name the family
cyc = wgf = None
out, n = [], 0
for line in lines:
    t = line.strip()
    m = re.match(r"family (\d\dz)$", t)
    if m: cyc = m.group(1)
    m = re.match(r"family (det|enkf|ensf|firewx)\s*$", t)
    if m: wgf = m.group(1)
    if t.startswith("trigger ") and re.search(r"\.\./forecast\s*==", t):
        task = fcst.get((cyc, wgf))
        if task:
            line = re.sub(r"\.\./forecast(\s*==)", rf"../forecast/{task}\1", line)
            n += 1
    out.append(line)
open(path, "w").write("\n".join(out))
print(f"{n} manager trigger(s) pointed at the forecast task")
EOF
  # The cold-start prep (03z/15z prep_cyc_spinup) waits only for its own initial conditions; in real
  # time the family's boundaries (made at 00z/12z) finish hours earlier. Without the clock a fast
  # make_ics beats them, and on the first day there are no older boundaries to fall back on.
  python3 - "${out_def}" <<'EOF'
import re, sys
path = sys.argv[1]
lines = open(path).read().split("\n")
fam = None
for i, line in enumerate(lines):
    m = re.match(r"\s*family (\d\d)\s*$", line)
    if m: fam = m.group(1)
    if line.strip() == "task jrrfs_det_prep_cyc_spinup" and fam and i + 1 < len(lines) \
            and lines[i + 1].strip() == "trigger ../ics==complete":
        lines[i + 1] += f" and ../../../{fam}z/det/ics==complete"
open(path, "w").write("\n".join(lines))
EOF
fi

echo "Wrote ${out_def} from ${BASE_DEF}"
echo "  PACKAGEHOME=${PACKAGEHOME}"
echo "  ECF_HOME=${ECF_HOME}  (create it before loading the suite)"
echo "  PROJ=${PROJ} QUEUE=${QUEUE} PARTITION=${PARTITION}"
echo "  DEV_PTMP=${DEV_PTMP}"
echo "  DEV_DATAROOT=${DEV_DATAROOT}"
echo "  RETRO_DATA_ROOT=${RETRO_DATA_ROOT}"
