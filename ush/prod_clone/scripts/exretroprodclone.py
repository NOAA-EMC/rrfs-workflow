#!/usr/bin/env python3
"""Retro stand-in for exupdateprodclonestatuses.py (used on Ursa).

In real time, /prod_clone mirrors the operational upstream jobs (GFS, GEFS, obsproc, ...) by copying
their states from the production ecflow checkpoint. For a retro there is no production suite, so this
script does two things each time it runs (once a minute from jretroprodclone.ecf, or by hand):

  1. Marks each /prod_clone task complete once its upstream files exist in the retro COM tree for the
     date of its primary family (the PDY variable on /prod_clone/primary/HH).
  2. Steps the RRFS suite through the retro period: when /<RRFS_SUITE>/primary/HH/rrfs/<ver> is
     complete, it sets PDY on the next primary family (in both suites) and requeues it. Families are
     released one at a time (00, 06, 12, 18, then 00 of the next day), because each family's first
     cycles depend on the restarts of the family before it.

Settings (environment):
  ECF_HOST, ECF_PORT      ecflow server
  RETRO_COMROOT           COM tree with the staged data, e.g. .../RRFS_RETRO_DATA_NCO/com
  RETRO_START, RETRO_END  first and last retro day (YYYYMMDD)
  RETRO_STATE             JSON file recording the last released family
  RRFS_SUITE, RRFS_VER    RRFS suite name and version family (default: para, v1.0)
  PRODCLONE_SUITE         default: prod_clone
  GFS_LAST_FHR            last GFS lead time staged (default 90); later leads check this one instead
  GEFS_LAST_FHR           last GEFS lead time staged (default 60)
  ALWAYS_COMPLETE         comma-separated upstream systems with no staged data, completed without a
                          file check so dependent jobs don't wait forever (default: nosofs)
  RRFS_STATUS_DIR         where to write the status files each pass (default: alongside the state
                          file); set to NONE to skip. See ush/ursa/rrfsstat.
  SKIP_FIRST_DAY          YES (default) completes the cycles on the first retro day that would warm
                          start from restarts nothing has produced yet; see skip_first_day() below
  DET_COLD_HR             first deterministic production cycle with a spinup behind it (default 09)
  ENKF_COLD_HR            first EnKF cycle with a cold start behind it (default 07)
"""

import datetime
import json
import os
import re
import subprocess
import sys

import ecflow

COMROOT = os.environ["RETRO_COMROOT"]
RETRO_START = os.environ["RETRO_START"]
RETRO_END = os.environ["RETRO_END"]
STATE_FILE = os.environ["RETRO_STATE"]
RRFS_SUITE = os.getenv("RRFS_SUITE", "para")
RRFS_VER = os.getenv("RRFS_VER", "v1.0")
PRODCLONE_SUITE = os.getenv("PRODCLONE_SUITE", "prod_clone")
GFS_LAST_FHR = int(os.getenv("GFS_LAST_FHR", "90"))
GEFS_LAST_FHR = int(os.getenv("GEFS_LAST_FHR", "60"))
ALWAYS_COMPLETE = [s for s in os.getenv("ALWAYS_COMPLETE", "nosofs").split(",") if s]
STATUS_DIR = os.getenv("RRFS_STATUS_DIR", os.path.dirname(os.path.abspath(STATE_FILE)))
SKIP_FIRST_DAY = os.getenv("SKIP_FIRST_DAY", "YES").upper() == "YES"
DET_COLD_HR = int(os.getenv("DET_COLD_HR", "9"))
ENKF_COLD_HR = int(os.getenv("ENKF_COLD_HR", "7"))
# the suite cold-starts through these, so they run on the first day like any other day
COLD_START_TASKS = ("make_ics", "blend_ics", "make_lbcs")

FAMILIES = ["00", "06", "12", "18"]
COMPLETE = ecflow.State.complete


def upstream_files(relpath, pdy, hh):
    """Files that must exist before the /prod_clone task at primary/<hh>/<relpath> counts as done.

    Returns None for tasks this script doesn't know, and [] for tasks completed without a check.
    """
    if relpath.split("/")[0] in ALWAYS_COMPLETE:
        return []

    m = re.fullmatch(r"gfs/v16\.3/gfs/atmos/post/jgfs_atmos_post_f(\d+)", relpath)
    if m:
        fhr = min(int(m.group(1)), GFS_LAST_FHR)
        return [f"gfs/v16.3/gfs.{pdy}/{hh}/atmos/gfs.t{hh}z.pgrb2.0p25.f{fhr:03d}"]

    # RRFS reads the 9-h GDAS member forecasts (the only ones staged)
    if re.fullmatch(r"gfs/v16\.3/enkfgdas/post/jenkfgdas_post_f\d+", relpath):
        return [f"gfs/v16.3/enkfgdas.{pdy}/{hh}/atmos/mem{m:03d}/gdas.t{hh}z.atmf009.nc"
                for m in range(1, 81)]

    if re.fullmatch(r"gefs/v12\.3/members/d0_16/jgefs_pgrb2abp5_f\d+_done", relpath):
        return [f"gefs/v12.3/gefs.{pdy}/{hh}/atmos/pgrb2{ab}p5/gep{m:02d}.t{hh}z.pgrb2{ab}.0p50.f{GEFS_LAST_FHR:03d}"
                for m in range(1, 31) for ab in "ab"]

    if relpath == "nsst/v1.2/jnsst":
        return [f"nsst/v1.2/nsst.{pdy}/rtgssthr_grb_0.083.grib2"]

    # obsproc cycles inside the family, e.g. obsproc/v1.2/rrfs/03z/prep/jobsproc_rrfs_prep
    m = re.fullmatch(r"obsproc/v1\.2/rrfs/(\d\d)z/(prep|dump)/jobsproc_rrfs_(prep|dump)(_erly)?", relpath)
    if m:
        cyc, kind, early = m.group(1), m.group(2), m.group(4)
        src = "rrfs_e" if early else "rrfs"
        name = "prepbufr.tm00" if kind == "prep" else "satwnd.tm00.bufr_d"
        return [f"obsproc/v1.2/{src}.{pdy}/{src}.t{cyc}z.{name}"]

    return None


def set_variable(ci, path, name, value):
    try:
        ci.alter(path, "change", "variable", name, value)
    except RuntimeError:
        ci.alter(path, "add", "variable", name, value)


def nodes_under(node):
    """Every family and task below node."""
    for child in node.nodes:
        yield child
        if not isinstance(child, ecflow.Task):
            yield from nodes_under(child)


def tasks_under(node):
    for child in node.nodes:
        if isinstance(child, ecflow.Task):
            yield child
        else:
            yield from tasks_under(child)


def family_pdy(node):
    """PDY variable set directly on a node, or None."""
    for v in node.variables:
        if v.name() == "PDY":
            return v.value()
    return None


def next_family(fam, pdy):
    i = FAMILIES.index(fam)
    if i < len(FAMILIES) - 1:
        return FAMILIES[i + 1], pdy
    day = datetime.datetime.strptime(pdy, "%Y%m%d") + datetime.timedelta(days=1)
    return FAMILIES[0], day.strftime("%Y%m%d")


def rrfs_family(fam):
    return f"/{RRFS_SUITE}/primary/{fam}/rrfs/{RRFS_VER}"


def release(ci, fam, pdy):
    """Point both suites' family <fam> at <pdy> and requeue them, held suspended.

    The family stays suspended until main() has had a chance to skip the first day's warm-start
    cycles; otherwise the server submits those tasks before they can be completed.
    """
    clone = f"/{PRODCLONE_SUITE}/primary/{fam}"
    rrfs = f"/{RRFS_SUITE}/primary/{fam}"
    for path in (clone, rrfs):
        set_variable(ci, path, "PDY", pdy)
    fam_path = rrfs_family(fam)
    if pdy != RETRO_START:
        restore_triggers(ci, fam_path)
    # requeue clears the suspended flag on every node below, which would undo anything held
    # on purpose (e.g. the EnKF during a deterministic-only test); remember it and put it back
    ci.sync_local()
    below = list(nodes_under(ci.get_defs().find_abs_node(fam_path)))
    held = [n.get_abs_node_path() for n in below if n.is_suspended()]
    # tasks tagged RETRO_SET_ASIDE were skipped on purpose (e.g. a component left out of a test) and
    # must come back complete, or anything waiting on them waits forever. They are tagged rather
    # than suspended because a suspended task never counts as complete in a trigger.
    set_aside = [n.get_abs_node_path() for n in below
                 if isinstance(n, ecflow.Task) and any(v.name() == "RETRO_SET_ASIDE" for v in n.variables)]
    ci.suspend(fam_path)
    ci.requeue(clone)
    # requeue resets a node to its default status, and the RRFS families are defined with
    # "defstatus complete" (NCO releases them); make them default to queued so they run
    ci.alter(fam_path, "change", "defstatus", "queued")
    ci.requeue(fam_path)
    for path in held:
        ci.suspend(path)
    for path in set_aside:
        ci.force_state(path, COMPLETE)
    if held:
        print(f"kept {len(held)} held node(s) suspended across the requeue"
              + (f", {len(set_aside)} set-aside task(s) complete" if set_aside else ""))
    print(f"released primary/{fam} for {pdy} (held suspended while states are set)")


def first_day_skipped(path):
    """True if skip_first_day() completes the node at path (a task, or a family inside a cycle)."""
    m = re.search(rf"/primary/\d\d/rrfs/{re.escape(RRFS_VER)}/(\d\d)z/", path + "/")
    if not m:
        return False
    name = path.rsplit("/", 1)[-1]
    if "spinup" in name or any(k in name for k in COLD_START_TASKS):
        return False
    limit = DET_COLD_HR if "/det/" in path else ENKF_COLD_HR if "/enkf/" in path else 0
    return int(m.group(1)) < limit


def parse_expr(text):
    """Trigger expression -> ("or"|"and", [children]) or ("atom", text); enough for pruning."""
    tokens = [t.strip() for t in re.split(r"(\(|\)|\band\b|\bor\b)", text) if t.strip()]
    pos = 0

    def group(op, sub):
        items = [sub()]
        nonlocal pos
        while pos < len(tokens) and tokens[pos] == op:
            pos += 1
            items.append(sub())
        return items[0] if len(items) == 1 else (op, items)

    def primary():
        nonlocal pos
        tok = tokens[pos]
        pos += 1
        if tok == "(":
            node = group("or", lambda: group("and", primary))
            pos += 1                        # the closing ")"
            return node
        return ("atom", tok)

    node = group("or", lambda: group("and", primary))
    if pos != len(tokens):
        raise ValueError(f"could not parse trigger: {text}")
    return node


def show_expr(node):
    if node[0] == "atom":
        return node[1]
    return f" {node[0]} ".join(show_expr(c) if c[0] == "atom" else f"({show_expr(c)})" for c in node[1])


def prune_fallbacks(node):
    """Drop OR alternatives that wait on a first-day skipped node, if a live alternative remains.

    Returns (node, dead): dead means node can only be satisfied through skipped nodes.
    """
    if node[0] == "atom":
        m = re.match(r"(\S+)\s*==\s*complete$", node[1])
        return node, bool(m and first_day_skipped(m.group(1)))
    kids = [prune_fallbacks(c) for c in node[1]]
    if node[0] == "and":
        return (node[0], [k for k, _ in kids]), any(d for _, d in kids)
    live = [k for k, d in kids if not d]
    if not live:
        return (node[0], [k for k, _ in kids]), True
    return (live[0] if len(live) == 1 else ("or", live)), False


def restore_triggers(ci, fam_path):
    """Put back the triggers skip_first_day() pruned, saved in RETRO_FIRST_DAY_TRIGGER."""
    ci.sync_local()
    restored = 0
    for node in nodes_under(ci.get_defs().find_abs_node(fam_path)):
        saved = [v.value() for v in node.variables if v.name() == "RETRO_FIRST_DAY_TRIGGER"]
        if saved:
            ci.alter(node.get_abs_node_path(), "change", "trigger", saved[0])
            ci.alter(node.get_abs_node_path(), "delete", "variable", "RETRO_FIRST_DAY_TRIGGER")
            restored += 1
    if restored:
        print(f"restored {restored} trigger(s) pruned on the first retro day")


def skip_first_day(ci, defs, fam, pdy):
    """Complete the first day's cycles that have no restarts to warm start from.

    The suite cold-starts itself at 03z/15z (deterministic spinup) and 07z/19z (EnKF), and the
    production cycles pick up from those. On the first retro day the earlier cycles would look for
    restarts nothing has written yet, so they are completed without running. Cold-start, boundary
    and spinup tasks are left alone, because those are what get the retro going.

    The skipped tasks count as complete in the "previous hour or older restart" fallbacks too
    (e.g. 10z det prep: 09z f1 or 08z f2 or 07z f3), which would start the later hours before the
    hour ahead has saved its restart. Those fallback terms are pruned for the day; the original
    trigger is kept in RETRO_FIRST_DAY_TRIGGER and restored when the family is next released.
    """
    if not (SKIP_FIRST_DAY and pdy == RETRO_START):
        return
    skipped = pruned = 0
    for cyc_node in defs.find_abs_node(f"/{RRFS_SUITE}/primary/{fam}/rrfs/{RRFS_VER}").nodes:
        if not re.fullmatch(r"\d\dz", cyc_node.name()):
            continue
        for node in nodes_under(cyc_node):
            path = node.get_abs_node_path()
            if isinstance(node, ecflow.Task) and first_day_skipped(path) and node.get_state() != COMPLETE:
                ci.force_state(path, COMPLETE)
                skipped += 1
            trigger = node.get_trigger()
            if trigger is None or first_day_skipped(path):
                continue
            old = trigger.get_expression()
            parsed = parse_expr(old)
            kept = prune_fallbacks(parsed)[0]
            if kept != parsed:
                set_variable(ci, path, "RETRO_FIRST_DAY_TRIGGER", old)
                ci.alter(path, "change", "trigger", show_expr(kept))
                pruned += 1
    if skipped:
        print(f"first retro day: completed {skipped} warm-start tasks in primary/{fam} without running them")
    if pruned:
        print(f"first retro day: pruned skipped-cycle fallbacks from {pruned} trigger(s) in primary/{fam}")


def write_status():
    """Refresh the plain-text status files, so progress can be read without the ecflow GUI."""
    if STATUS_DIR.upper() == "NONE":
        return
    rrfsstat = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "ursa", "rrfsstat")
    if not os.path.exists(rrfsstat):
        return
    common = [sys.executable, rrfsstat, "--suite", RRFS_SUITE]
    for args, name in (([], "rrfs_status.txt"),
                       (["-t", "-s", "aborted,active,submitted,queued"], "rrfs_status_tasks.txt")):
        try:
            subprocess.run(common + args + ["-o", os.path.join(STATUS_DIR, name)],
                           check=False, timeout=120)
        except (OSError, subprocess.SubprocessError) as err:
            print(f"WARNING: could not write {name}: {err}")


def prime_clone_history(ci, pdy):
    """Give the previous day's /prod_clone families a date so the first cycles can start.

    The first day's families trigger on upstream jobs from the day before (e.g. the 00z boundary
    tasks wait on /prod_clone/primary/18 GFS post), which the retro never releases. Pointing those
    clone families at the previous day lets mark_upstream() complete them from the staged files.
    """
    prev = (datetime.datetime.strptime(pdy, "%Y%m%d") - datetime.timedelta(days=1)).strftime("%Y%m%d")
    for fam in FAMILIES[1:]:
        path = f"/{PRODCLONE_SUITE}/primary/{fam}"
        set_variable(ci, path, "PDY", prev)
        ci.requeue(path)
    print(f"primed /{PRODCLONE_SUITE}/primary/{{{','.join(FAMILIES[1:])}}} with {prev} (day before the retro)")


def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def save_state(state):
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE_FILE)


def step_dates(ci, defs):
    state = load_state()
    if state is None:
        prime_clone_history(ci, RETRO_START)
        release(ci, FAMILIES[0], RETRO_START)
        save_state({"family": FAMILIES[0], "pdy": RETRO_START})
        return

    fam, pdy = state["family"], state["pdy"]
    node = defs.find_abs_node(f"/{RRFS_SUITE}/primary/{fam}/rrfs/{RRFS_VER}")
    if node is None:
        sys.exit(f"ERROR: /{RRFS_SUITE}/primary/{fam}/rrfs/{RRFS_VER} not found on the server")
    status = node.get_state()
    if status != COMPLETE:
        print(f"primary/{fam} for {pdy} is {status}; waiting")
        return

    nfam, npdy = next_family(fam, pdy)
    if npdy > RETRO_END:
        print(f"retro finished: primary/{fam} for {pdy} was the last family")
        return
    release(ci, nfam, npdy)
    save_state({"family": nfam, "pdy": npdy})


def mark_upstream(ci, defs):
    counts = {"completed": 0, "waiting": 0, "unknown": 0}
    for fam in FAMILIES:
        fam_node = defs.find_abs_node(f"/{PRODCLONE_SUITE}/primary/{fam}")
        if fam_node is None:
            continue
        pdy = family_pdy(fam_node)
        if pdy is None:
            continue  # family not released yet
        prefix = fam_node.get_abs_node_path() + "/"
        for task in tasks_under(fam_node):
            path = task.get_abs_node_path()
            files = upstream_files(path[len(prefix):], pdy, fam)
            if files is None:
                counts["unknown"] += 1
                print(f"WARNING: no file check defined for {path}")
                continue
            if task.get_state() == COMPLETE:
                continue
            missing = [f for f in files if not os.path.exists(os.path.join(COMROOT, f))]
            if missing:
                counts["waiting"] += 1
                print(f"waiting: {path} ({pdy}) needs {missing[0]}" + (f" and {len(missing) - 1} more" if len(missing) > 1 else ""))
            else:
                ci.force_state(path, COMPLETE)
                counts["completed"] += 1
    print("upstream tasks: " + ", ".join(f"{k} {v}" for k, v in counts.items()))


def main():
    ci = ecflow.Client()
    ci.sync_local()
    defs = ci.get_defs()
    step_dates(ci, defs)
    # read the server again so the families released above are checked in this pass
    ci.sync_local()
    defs = ci.get_defs()
    state = load_state()
    if state:
        skip_first_day(ci, defs, state["family"], state["pdy"])
        # release() suspends the family so the skip above wins the race with the scheduler
        fam_path = rrfs_family(state["family"])
        if defs.find_abs_node(fam_path).is_suspended():
            ci.resume(fam_path)
            print(f"resumed {fam_path}")
        ci.sync_local()
        defs = ci.get_defs()
    mark_upstream(ci, defs)
    write_status()


if __name__ == "__main__":
    main()
