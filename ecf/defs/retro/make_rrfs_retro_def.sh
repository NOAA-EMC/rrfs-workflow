#!/bin/bash
#
# Make a developer copy of an RRFS suite definition for the machine in retro/config.sh (MACHINE):
# its locations, its job submission commands, and, for a retro (RETRO=YES), triggers that step
# through past dates instead of following the clock. The task tree is unchanged.
#
# Usage: [VAR=value ...] ./make_rrfs_retro_def.sh [output_def]
# Any of the settings in retro/config.sh can be overridden from the environment.
#
set -eu

defs_dir=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
out_def=${1:-${defs_dir}/rrfs_retro.def}

# Settings live in retro/config.sh next to this script; environment variables still win.
# shellcheck source=/dev/null
. "${defs_dir}/load_config.sh"
case ${MACHINE} in
  URSA|WCOSS2) ;;
  *) echo "MACHINE=${MACHINE} is not supported; the retro suite runs on URSA and WCOSS2" >&2; exit 1 ;;
esac

# Derived from the settings above
PACKAGEHOME=${PACKAGEHOME:-$(cd "${defs_dir}/../../.." && pwd)}
c=${RETRO_DATA_ROOT}/com
DEV_COMPATH=${DEV_COMPATH:-$c/gfs:$c/gefs:$c/obsproc:$c/nsst:$c/nosofs:$c/hrrr:$c/rap}
DCOMROOT=${DCOMROOT:-${RETRO_DATA_ROOT}/dcom}

awk \
    -v q="'" \
    -v machine="${MACHINE}" \
    -v ph="${PACKAGEHOME}" \
    -v eh="${ECF_HOME}" \
    -v od="${OUTPUTDIR}" \
    -v proj="${PROJ}" \
    -v queue="${QUEUE}" \
    -v part="${PARTITION:-}" \
    -v ptmp="${DEV_PTMP}" \
    -v droot="${DEV_DATAROOT}" \
    -v ev="${ECFLOW_VER}" \
    -v envir="${ENVIR}" \
    -v rver="${RRFS_VER}" \
    -v site="${MACHINE_SITE}" \
    -v eh_host="${ECFLOW_HOST}" \
    -v compath="${DEV_COMPATH}" \
    -v dcom="${DCOMROOT}" \
    -v retro="${RETRO}" \
    -v fixjedi="${FIX_RRFS_JEDI}" '
  function ed(name, value) { print ind "edit " name " " q value q }
  # suite-wide settings go right after the suite line
  $1 == "suite" && !done {
    print; ind = "  "; done = 1
    ed("MACHINE", machine)
    if (machine == "URSA") ed("PARTITION", part)
    ed("DEV_PTMP", ptmp)
    ed("DEV_DATAROOT", droot)
    ed("DEV_COMPATH", compath)
    ed("DCOMROOT", dcom)
    ed("RETRO", retro)
    if (fixjedi != "") ed("FIX_RRFS_JEDI", fixjedi)
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
    # no product alerts from a retro; the WCOSS2 fake dbn_alert fails on any file it cannot find,
    # such as the NA subset that prdgen alerts on but a CONUS domain never writes
    ed("SENDDBN", "NO")
    ed("SENDDBN_NTC", "NO")
    ed("ECF_HOME", eh)
    # job logs next to the job files; the NCO dev ecflow servers set ECF_OUT to ~/ecflow, where the
    # per-family log directories do not exist, so no job could write its output
    ed("ECF_OUT", eh)
    ed("ECF_INCLUDE", ph "/ecf/include")
    if (machine == "WCOSS2") {
      # The cards carry the #PBS job sizes. -o puts the output where ecflow looks for it, since the
      # cards only say -j oe. Coarser domains (strip when merging to the nco branch): QSUB_OVERRIDES
      # carries per-task job sizes for other domains; qsub options win over the #PBS lines too.
      ed("QSUB_OVERRIDES", "")
      ed("ECF_JOB_CMD", "qsub -o %ECF_JOBOUT% %QSUB_OVERRIDES% %ECF_JOB% 1> %ECF_JOB%.sub 2>&1")
      ed("ECF_KILL_CMD", "qdel %ECF_RID% 1> %ECF_JOB%.kill 2>&1")
      ed("ECF_STATUS_CMD", "qstat -f %ECF_RID% 1> %ECF_JOB%.stat 2>&1")
    }
    if (machine == "URSA") {
      # sbatch would otherwise also read the #PBS lines (e.g. "-q" as the partition).
      # Coarser domains (strip when merging to the nco branch): SBATCH_OVERRIDES carries
      # per-task job sizes for other domains, since sbatch options win over the #SBATCH lines in cards.
      ed("SBATCH_OVERRIDES", "")
      ed("ECF_JOB_CMD", "sbatch --ignore-pbs %SBATCH_OVERRIDES% %ECF_JOB% 1> %ECF_JOB%.sub 2>&1")
      ed("ECF_KILL_CMD", "scancel %ECF_RID% 1> %ECF_JOB%.kill 2>&1")
      ed("ECF_STATUS_CMD", "squeue -j %ECF_RID% 1> %ECF_JOB%.stat 2>&1")
    }
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
  # the para definition'"'"'s WCOSS2 path; the one from retro/config.sh is set at the top instead
  $1 == "edit" && $2 == "FIX_RRFS_JEDI" { next }
  { print }
' "${defs_dir}/../${BASE_DEF}" > "${out_def}"

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

  # Fire weather reads the long forecast's post for its initial and boundary conditions, so the two
  # settings cannot disagree. Say so here rather than let 464 fire weather tasks a day fail on a
  # natlev file the suite was told not to make.
  if [ "${DO_LONG_FORECAST:-TRUE}" = "FALSE" ] && [ "${RUN_FIREWX:-TRUE}" != "FALSE" ]; then
    echo "ERROR: DO_LONG_FORECAST=FALSE needs RUN_FIREWX=FALSE." >&2
    echo "       Fire weather takes its ICs and LBCs from the 84 h forecast's post." >&2
    exit 1
  fi

  # FV3 writes the hour-0 entry of output_fh at its first time step only at the 36 s NA step; with a
  # longer step it writes no hour-0 file, so the f000_00_36 post and prdgen tasks have nothing to work
  # on. Complete them rather than renaming their FHR: the file is absent, not differently named. The
  # 15, 30 and 45 minute sub-hourly outputs are unaffected and still run. DT_ATMOS lives inside the
  # domain file's domain_workflow_conf(), so read the value out of the file rather than sourcing it.
  domain_dt=36
  if [ -f "${defs_dir}/domains/${DOMAIN}.sh" ]; then
    domain_dt=$(grep -oE "^ *export DT_ATMOS='[0-9]+'" "${defs_dir}/domains/${DOMAIN}.sh" \
                  | grep -oE "[0-9]+" | tail -1)
    domain_dt=${domain_dt:-36}
  fi
  if [ "${domain_dt}" != "36" ] && [ "${RUN_FIREWX:-TRUE}" != "FALSE" ]; then
    echo "ERROR: DT_ATMOS=${domain_dt} (${DOMAIN}) needs RUN_FIREWX=FALSE." >&2
    echo "       Fire weather starts from the parent's hour-0 natlev file, which only the 36 s step writes." >&2
    exit 1
  fi
  # Whether jobs keep their stmp working directories. Two suite variables decide it and KEEPDATA in
  # retro/config.sh sets both. KEEPDATA is read by each job, for its own directory; the base
  # definition sets YES at every place it appears, so rewrite the value rather than the lines.
  # KEEP_TMP is read by jrrfs_clean, for the hour's shared directories at the end of each cycle; the
  # base definition leaves it to the job card's default, NO, so add it at the top.
  if [ -n "${KEEPDATA:-}" ]; then
    nkeep=$(grep -cE "^ *edit KEEPDATA " "${out_def}")
    sed -i -E "s/^( *)edit KEEPDATA '[A-Za-z]+'/\1edit KEEPDATA '${KEEPDATA}'/" "${out_def}"
    sed -i "/^suite /a\\  edit KEEP_TMP '${KEEPDATA}'" "${out_def}"
    echo "  KEEPDATA: ${nkeep} setting(s) rewritten to '${KEEPDATA}', and KEEP_TMP set to match"
  fi

  # Which analyses run, det and EnKF: the route DA_SYSTEM does not select is marked complete,
  # never submitted
  case "${DA_SYSTEM:-GSI}" in
    GSI|gsi)   da_system_jedi=0 ;;
    JEDI|jedi) da_system_jedi=1 ;;
    *) echo "ERROR: DA_SYSTEM must be GSI or JEDI, not '${DA_SYSTEM}'." >&2; exit 1 ;;
  esac
  sed -i -E "s/^( *)edit DA_SYSTEM_JEDI '[01]'/\1edit DA_SYSTEM_JEDI '${da_system_jedi}'/" "${out_def}"
  echo "  DA_SYSTEM: ${DA_SYSTEM:-GSI} (DA_SYSTEM_JEDI=${da_system_jedi})"

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
  # The prep_cyc tasks wait only for the previous forecast (or, at 03z/15z cold starts, their own
  # initial conditions), then copy boundaries from the family's 00/06/12/18z make_lbcs; in real time
  # those finish hours earlier. Without the clock the preps start alongside the make_lbcs jobs and
  # can copy a half-written set (2024050801 enkf mem023 found f002 but not f001).
  python3 - "${out_def}" <<'EOF'
import re, sys
path = sys.argv[1]
lines = open(path).read().split("\n")
fam = None
for i, line in enumerate(lines):
    m = re.match(r"\s*family (\d\d)\s*$", line)
    if m: fam = m.group(1)
    m = re.fullmatch(r"task jrrfs_(det|enkf)_prep_cyc(_spinup|_mem\d+)?", line.strip())
    if m and fam and i + 1 < len(lines) and lines[i + 1].strip().startswith("trigger "):
        indent = lines[i + 1][:len(lines[i + 1]) - len(lines[i + 1].lstrip())]
        expr = lines[i + 1].strip()[len("trigger "):]
        lines[i + 1] = indent + f"trigger ( {expr} ) and ../../../{fam}z/{m.group(1)}/ics==complete"
open(path, "w").write("\n".join(lines))
EOF

  # ------------------------------------------------------------------------------------------
  # Tasks this retro does not run. Each is given "defstatus complete", which ecflow treats as
  # finished without submitting it, and every trigger that named it is rewritten so the order of
  # what is left is unchanged. ecf/defs/retro/skip_tasks.py does both; its header explains the
  # two ways a reference can be rewritten and when each applies.
  # ------------------------------------------------------------------------------------------
  skip="python3 ${defs_dir}/skip_tasks.py ${out_def} --post-manager"

  # Whole workflow groups (RUN_ENKF, RUN_ENSF, RUN_FIREWX). The group's tasks are completed
  # rather than its family, because a family's defstatus does not reach its children: with only
  # the family stamped, the det analysis trigger that names
  # <cycle>/enkf/forecast/jrrfs_enkf_save_restart_f1_done would wait for a task that never runs.
  # Their references are dropped rather than inlined, since the det cycle should not inherit the
  # dependencies of a group that is not running at all.
  for wgf in enkf ensf firewx; do
    run_var=RUN_$(echo "${wgf}" | tr '[:lower:]' '[:upper:]')
    [ "${!run_var:-TRUE}" = "FALSE" ] || continue
    ${skip} --mode ignore --label "${wgf} (${run_var}=FALSE)" --path "/${wgf}/"
  done

  # Task types rather than whole groups (RUN_GEMPAK, RUN_BUFRSND, RUN_SMOKE). The pattern allows
  # words between the workflow group and the task name, so process_smoke matches as well as
  # gempak and bufrsnd; it still matches exactly the same gempak and bufrsnd tasks.
  for tsk in gempak bufrsnd smoke; do
    run_var=RUN_$(echo "${tsk}" | tr '[:lower:]' '[:upper:]')
    [ "${!run_var:-TRUE}" = "FALSE" ] || continue
    ${skip} --label "${tsk} (${run_var}=FALSE)" --name "jrrfs_[a-z]+_[a-z_]*${tsk}[a-z0-9_]*"
  done

  # Steps inside a cycle that a simplified retro leaves out (the FALSE switches in the Rocoto
  # workflow's ush/config.sh). setup_retro_links.sh turns the matching workflow.conf switch off
  # at the same time, so the job that is skipped here is also told not to expect its output.
  # Each sits in the middle of a chain, so whatever waited on it is given its dependencies
  # instead: without that, completing the cloud analysis would let the forecast start as soon as
  # the cycle opened, since that analysis is the only thing its trigger names.
  skip_step() {  # $1 the RUN_ variable in retro/config.sh, $2 the task names it covers
    [ "${!1:-TRUE}" = "FALSE" ] || return 0
    ${skip} --label "$1=FALSE" --name "$2"
  }
  skip_step RUN_NONVARCLD 'jrrfs_(det|enkf)_analysis_nonvarcld[a-z0-9_]*'
  skip_step RUN_UPDATE_BC 'jrrfs_det_update_lbc_soil[a-z0-9_]*'
  skip_step RUN_GSIDIAG   'jrrfs_det_analysis_gsi_diag[a-z0-9_]*'
  skip_step RUN_LIGHTNING 'jrrfs_(det|enkf)_process_lightning[a-z0-9_]*'
  skip_step RUN_RADAR     'jrrfs_(det|enkf)_process_radar[a-z0-9_]*'
  skip_step RUN_POST      'jrrfs_det_(post|prdgen)[a-z0-9_]*'

  # FV3 writes the hour-0 entry of output_fh at its first time step only at the 36 s NA step; with
  # a longer step it writes no hour-0 file, so the f000_00_36 post and prdgen tasks have nothing to
  # work on. Complete them rather than renaming their FHR: the file is absent, not differently
  # named. The 15, 30 and 45 minute sub-hourly outputs are unaffected and still run.
  # Dropped rather than inlined: the hour-0 file is absent, so the product generation that reads
  # it must not be made to wait on the post manager event that would have released it.
  if [ "${domain_dt}" != "36" ]; then
    ${skip} --mode ignore --label "hour-0 sub-hourly (DT_ATMOS=${domain_dt})" \
            --name 'jrrfs_det_(post|prdgen)_f000_00_36(_long)?'
  fi

  # The whole 84 h forecast chain (DO_LONG_FORECAST): the forecast, its restarts, and the post and
  # product generation that read its output. Every one of those task names ends in _long, or in
  # _long_<hour> for the restarts.
  if [ "${DO_LONG_FORECAST:-TRUE}" = "FALSE" ]; then
    ${skip} --label "long forecast (DO_LONG_FORECAST=FALSE)" \
            --name 'jrrfs_det_[a-z0-9_]*_long(_[0-9]+)?'
  fi

  # Shorter forecasts (FCST_LEN_HRS for the hourly cycles, FCST_LEN_HRS_LONG for 00, 06, 12 and
  # 18z). setup_retro_links.sh puts the same two numbers in workflow.conf; here everything past
  # the end of the forecast comes out of the definition. That includes the post manager, which
  # scans a list of output files fixed at 0-84 (or 0-18) hours and err_exits 900 s after the last
  # one it finds: an aborted task would leave the cycle short of complete, which is what the retro
  # driver waits for before stepping to the next date. With the manager gone, --post-manager
  # points the surviving post tasks at the forecast task instead of at its events.
  fcst_len=${FCST_LEN_HRS:-18}
  fcst_len_long=${FCST_LEN_HRS_LONG:-84}
  if [ "${fcst_len}" -lt 3 ] || [ "${fcst_len_long}" -lt 3 ]; then
    echo "ERROR: FCST_LEN_HRS and FCST_LEN_HRS_LONG must be at least 3." >&2
    echo "       Each cycle warm starts from the hour 1, 2 or 3 restart of one of the three before it." >&2
    exit 1
  fi
  trunc=()
  trunc_hours() {  # $1 the forecast length, $2 the last hour in the definition, $3 name suffix
    local h
    for (( h = $1 + 1; h <= $2; h++ )); do
      trunc+=(--name "jrrfs_det_(post|prdgen)_f$(printf '%03d' ${h})_(00|15|30|45)_(00|36)$3")
    done
    # the sub-hourly output of the last hour is past the end of the forecast as well
    trunc+=(--name "jrrfs_det_(post|prdgen)_f$(printf '%03d' $1)_(15|30|45)_00$3")
  }
  if [ "${fcst_len}" != 18 ] || [ "${fcst_len_long}" != 84 ]; then
    trunc_hours "${fcst_len}" 18 ''
    trunc_hours "${fcst_len_long}" 84 '_long'
    # restart hours past the end of the long forecast; the hourly cycles save 1, 2 and 3, which
    # the minimum length above keeps
    for h in 1 2 3 6; do
      [ "${h}" -gt "${fcst_len_long}" ] && trunc+=(--name "jrrfs_det_save_restart_long_${h}")
    done
    trunc+=(--name 'jrrfs_det_post_manager')
  fi
  if [ ${#trunc[@]} -gt 0 ]; then
    ${skip} --label "past the end of the forecast (${fcst_len} h, ${fcst_len_long} h at 00/06/12/18z)" \
            "${trunc[@]}"
  fi

  # Boundary conditions past the last hour any cycle in the family reaches. The 00, 06, 12 and 18z
  # ics families make one file per hour for the whole family, so the last one needed is the end of
  # the long forecast, or of the 05z cycle's forecast if that reaches further. Group N of the
  # BCGRPNUM groups makes hour N, so the groups above that hour have nothing left to make. The
  # first group stays whatever happens: it is the one that stages the external model files the
  # others read, and it still makes hour N + BCGRPNUM for each surviving group, since BOUNDARY_LEN
  # is left at its operational value (see setup_retro_links.sh for why).
  lbc_last=$(( fcst_len + 5 ))
  [ "${fcst_len_long}" -gt "${lbc_last}" ] && lbc_last=${fcst_len_long}
  if [ "${lbc_last}" -lt 84 ]; then
    lbc_args=()
    for (( h = lbc_last + 1; h <= 84; h++ )); do
      lbc_args+=(--name "jrrfs_det_make_lbcs_$(printf '%02d' ${h})")
    done
    ${skip} --label "boundaries past hour ${lbc_last}" "${lbc_args[@]}"
  fi

  # Anything else this retro leaves out, as a space-separated list of task-name patterns
  if [ -n "${SKIP_TASKS:-}" ]; then
    extra=()
    for pat in ${SKIP_TASKS}; do extra+=(--name "${pat}"); done
    ${skip} --label "SKIP_TASKS" "${extra[@]}"
  fi

  # The deterministic spin-up cycles (DO_SPINUP). Operations cold starts at 03z and 15z into a
  # 1 h spin-up forecast and runs spin-up alongside production until 09z and 21z; a retro that
  # only wants a cycling deterministic run can drop all of it. Nothing in the production chain
  # waits on a spin-up task, so their references are dropped rather than inlined. The production
  # cycle at the cold-start hour then has to cold start itself, which exrrfs_prep_cyc.sh already
  # does when DO_SPINUP is FALSE and the hour is in CYCL_HRS_PRODSTART: the trigger below points
  # it at the make_ics task in its own ics family instead of at the cycle before it.
  if [ "${DO_SPINUP:-TRUE}" = "FALSE" ]; then
    # The EnKF spin-up recenter is the exception: it reads the det analysis, which is then the
    # production cycle's, so its det terms move to the production tasks
    sed -i '/jrrfs_enkf_prep_cyc_spinup_mem/s#\(det/[a-z]*/jrrfs_det_[a-z0-9_]*\)_spinup#\1#g' "${out_def}"
    ${skip} --mode ignore --label "spin-up cycles (DO_SPINUP=FALSE)" \
            --name 'jrrfs_det_[a-z0-9_]*spinup[a-z0-9_]*'
    python3 - "${out_def}" ${DET_COLD_START_HRS:-03 15} <<'EOF'
import re, sys
path, hours = sys.argv[1], [f"{int(h):02d}z" for h in sys.argv[2:]]
lines = open(path).read().split("\n")
fam, cyc, n = None, None, 0
for i, line in enumerate(lines):
    m = re.fullmatch(r"family (\d\d)", line.strip())
    if m:
        fam = m.group(1)
    m = re.fullmatch(r"family (\d\dz)", line.strip())
    if m:
        cyc = m.group(1)
    if line.strip() == "task jrrfs_det_prep_cyc" and cyc in hours:
        for j in range(i + 1, i + 5):
            if lines[j].strip().startswith("trigger "):
                indent = lines[j][:len(lines[j]) - len(lines[j].lstrip())]
                # its own ics family for the cold start fields, and the family's 00, 06, 12 or
                # 18z one for the boundaries, which the replaced trigger also waited on
                lines[j] = (indent + "trigger ../ics==complete and "
                            f"../../../{fam}z/det/ics==complete")
                n += 1
                break
open(path, "w").write("\n".join(lines))
print(f"  cold start: {n} prep_cyc task(s) pointed at their own ics family")
EOF
  fi

  # The previous cycle only. Operations lets prep_cyc and the det analysis start on a restart
  # from two or three cycles back when the last cycle is late, and the ex-scripts then wait a few
  # minutes and fall back to it (or, in the det analysis, to the GDAS ensemble); blend_ics does the
  # same with no trigger at all. A retro should wait instead, so each "or" of cycles in those
  # triggers keeps only the previous cycle's term, and blend_ics waits on its member's previous
  # cycle restart. The det production start hours read the spin-up cycle's restart, so they wait
  # on that too.
  python3 - "${out_def}" "${defs_dir}" ${DET_PROD_START_HRS:-09 21} <<'EOF'
import re, sys
sys.path.insert(0, sys.argv[2])
from skip_tasks import Prim, parse, read_defs, tokenize, unparse
path = sys.argv[1]
lines = open(path).read().split("\n")
nodes = read_defs(lines)
target = re.compile(r"jrrfs_(det_prep_cyc|enkf_prep_cyc_(ensmean|mem\d+)|det_analysis_(gsi|jedi))(_spinup)?")


def hours(node):
    """cycle hours the node references name"""
    if isinstance(node, Prim):
        m = re.search(r"/(\d\d)z/", node.ref or "")
        return {m.group(1)} if m else set()
    if isinstance(node, str):
        return set()
    return set().union(*(hours(p) for p in node[1]))


def previous_only(node, prev):
    if isinstance(node, (Prim, str)):
        return node
    op, parts = node
    parts = [previous_only(p, prev) for p in parts]
    keep = [p for p in parts if hours(p) == {prev}]
    if op == "or" and len(keep) == 1 and all(hours(p) for p in parts):
        return keep[0]
    return (op, parts)


prod_start = [int(h) for h in sys.argv[3:]]
n_or = n_blend = n_spinup = 0
for node in nodes.values():
    cyc = re.findall(r"/(\d\d)z/", node.path + "/")
    if node.kind != "task" or not cyc:
        continue
    prev = (int(cyc[-1]) - 1) % 24
    for i in node.expr_lines:
        text = lines[i].strip()
        if not text.startswith("trigger "):
            continue
        indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
        if target.fullmatch(node.name):
            old = parse(tokenize(text[len("trigger "):]), node.path)
            new = previous_only(old, f"{prev:02d}")
            if unparse(new) != unparse(old):
                lines[i] = indent + "trigger " + unparse(new)
                n_or += 1
        m = re.fullmatch(r"jrrfs_enkf_blend_ics_mem(\d+)", node.name)
        if m:
            restart = re.sub(r"/primary/\d\d/rrfs/v1\.0/\d\dz/.*",
                             f"/primary/{prev // 6 * 6:02d}/rrfs/v1.0/{prev:02d}z/enkf/forecast/"
                             f"jrrfs_enkf_save_restart_mem{m.group(1)}_f1", node.path)
            if restart in nodes:
                lines[i] += f" and {restart}==complete"
                n_blend += 1
        if node.name == "jrrfs_det_prep_cyc" and int(cyc[-1]) in prod_start:
            restart = re.sub(r"/primary/\d\d/rrfs/v1\.0/\d\dz/.*",
                             f"/primary/{prev // 6 * 6:02d}/rrfs/v1.0/{prev:02d}z/det/forecast/"
                             "jrrfs_det_save_restart_spinup_f001", node.path)
            if restart in nodes:
                lines[i] += f" and {restart}==complete"
                n_spinup += 1
open(path, "w").write("\n".join(lines))
print(f"  previous cycle only: {n_or} trigger(s) cut to it, {n_blend} blend_ics and {n_spinup} det "
      "production start prep_cyc task(s) wait on it")
EOF
fi

# Coarser domains (strip when merging to the nco branch): give the tasks the domain's table
# names their job sizes through SBATCH_OVERRIDES on Ursa, or QSUB_OVERRIDES on WCOSS2. The table
# is in sbatch terms; on WCOSS2 --nodes=N becomes N whole 128-core nodes and --time the walltime.
# The node counts carry over because ranks per node come from the domain's PPN_* settings, which
# all fit in a WCOSS2 node; RRFS_NA_3km has none, the cards are sized for it. The JEDI analyses
# come first and on every domain, sized from the JEDI settings in retro/config.sh, so their job
# requests always match the tasks the ex-scripts start.
job_sizes=("jrrfs_det_analysis_jedi*:--nodes=${NNODES_ANALYSIS_JEDI:-16} --time=${WALLTIME_ANALYSIS_JEDI:-00:50:00}")
job_sizes+=("jrrfs_enkf_analysis_jedi*:--nodes=${NNODES_ANALYSIS_ENKF_JEDI:-48} --time=${WALLTIME_ANALYSIS_ENKF_JEDI:-01:00:00}")
# shellcheck source=/dev/null
. "${defs_dir}/domains/${DOMAIN}.sh"
job_sizes+=("${DOMAIN_SBATCH[@]}")
python3 - "${out_def}" "${MACHINE}" "${job_sizes[@]}" <<'EOF'
import fnmatch, re, sys
path, machine = sys.argv[1], sys.argv[2]
table = [a.split(":", 1) for a in sys.argv[3:]]

def qsub_opts(sbatch):
    out = []
    for opt in sbatch.split():
        m = re.fullmatch(r"--nodes=(\d+)", opt)
        if m:
            out.append(f"-l select={m.group(1)}:ncpus=128:mem=500G -l place=vscatter:excl")
            continue
        m = re.fullmatch(r"--time=([\d:]+)", opt)
        if m:
            out.append(f"-l walltime={m.group(1)}")
            continue
        sys.exit(f"no WCOSS2 equivalent for the domain job option {opt}")
    return " ".join(out)

var = "QSUB_OVERRIDES" if machine == "WCOSS2" else "SBATCH_OVERRIDES"
out, n = [], 0
for line in open(path).read().split("\n"):
    out.append(line)
    t = line.split()
    if len(t) >= 2 and t[0] == "task":
        opts = next((o for pat, o in table if fnmatch.fnmatch(t[1], pat)), None)
        if opts:
            if machine == "WCOSS2":
                opts = qsub_opts(opts)
            out.append(line[:len(line) - len(line.lstrip())] + f"  edit {var} '{opts}'")
            n += 1
open(path, "w").write("\n".join(out))
print(f"{n} tasks given job sizes for the domain and the JEDI analyses")
EOF

echo "Wrote ${out_def} from ${BASE_DEF}"
echo "  PACKAGEHOME=${PACKAGEHOME}"
echo "  ECF_HOME=${ECF_HOME}  (create it before loading the suite)"
echo "  MACHINE=${MACHINE} PROJ=${PROJ} QUEUE=${QUEUE} PARTITION=${PARTITION:-}"
echo "  DEV_PTMP=${DEV_PTMP}"
echo "  DEV_DATAROOT=${DEV_DATAROOT}"
echo "  RETRO_DATA_ROOT=${RETRO_DATA_ROOT}"
echo "  DOMAIN=${DOMAIN}"
