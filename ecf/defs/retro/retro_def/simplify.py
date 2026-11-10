"""Tasks a retro does not run, and the cold starts that replace the spin-up cycles.

Each skip gives the tasks "defstatus complete", which ecflow treats as finished without
submitting it, and rewrites every trigger that named them so the order of what is left is
unchanged (skip.py; its docstring explains the two ways a reference can be rewritten and when
each applies).
"""

import sys

from .deftree import indent_of
from .skip import skip_tasks

# Steps inside a cycle that a simplified retro leaves out (the FALSE switches in the Rocoto
# workflow's ush/config.sh): the RUN_ switch in retro/config.sh, and the task names it covers
SIMPLIFIED_STEPS = (
    ("RUN_NONVARCLD", r"jrrfs_(det|enkf)_analysis_nonvarcld[a-z0-9_]*"),
    ("RUN_UPDATE_BC", r"jrrfs_det_update_lbc_soil[a-z0-9_]*"),
    ("RUN_GSIDIAG", r"jrrfs_det_analysis_gsi_diag[a-z0-9_]*"),
    ("RUN_LIGHTNING", r"jrrfs_(det|enkf)_process_lightning[a-z0-9_]*"),
    ("RUN_RADAR", r"jrrfs_(det|enkf)_process_radar[a-z0-9_]*"),
    ("RUN_POST", r"jrrfs_det_(post|prdgen)[a-z0-9_]*"),
)


def skip_groups(d, cfg):
    """Whole workflow groups (RUN_ENKF, RUN_ENSF, RUN_FIREWX). The group's tasks are completed
    rather than its family, because a family's defstatus does not reach its children: with only
    the family stamped, the det analysis trigger that names
    <cycle>/enkf/forecast/jrrfs_enkf_save_restart_f1_done would wait for a task that never runs.
    Their references are dropped rather than inlined, since the det cycle should not inherit the
    dependencies of a group that is not running at all."""
    for wgf in ("enkf", "ensf", "firewx"):
        var = f"RUN_{wgf.upper()}"
        if cfg.is_false(var):
            skip_tasks(d, f"{wgf} ({var}=FALSE)", paths=[f"/{wgf}/"], mode="ignore")


def skip_task_types(d, cfg):
    """Task types rather than whole groups (RUN_GEMPAK, RUN_BUFRSND, RUN_SMOKE). The pattern
    allows words between the workflow group and the task name, so process_smoke matches as well
    as gempak and bufrsnd; it still matches exactly the same gempak and bufrsnd tasks."""
    for tsk in ("gempak", "bufrsnd", "smoke"):
        var = f"RUN_{tsk.upper()}"
        if cfg.is_false(var):
            skip_tasks(d, f"{tsk} ({var}=FALSE)", names=[rf"jrrfs_[a-z]+_[a-z_]*{tsk}[a-z0-9_]*"])


def skip_simplified_steps(d, cfg):
    """Steps inside a cycle that a simplified retro leaves out (SIMPLIFIED_STEPS).
    setup_retro_links.sh turns the matching workflow.conf switch off at the same time, so the job
    that is skipped here is also told not to expect its output. Each sits in the middle of a
    chain, so whatever waited on it is given its dependencies instead: without that, completing
    the cloud analysis would let the forecast start as soon as the cycle opened, since that
    analysis is the only thing its trigger names."""
    for var, names in SIMPLIFIED_STEPS:
        if cfg.is_false(var):
            skip_tasks(d, f"{var}=FALSE", names=[names])


def skip_hour0_subhourly(d, domain_dt):
    """FV3 writes the hour-0 entry of output_fh at its first time step only at the 36 s NA step;
    with a longer step it writes no hour-0 file, so the f000_00_36 post and prdgen tasks have
    nothing to work on. Complete them rather than renaming their FHR: the file is absent, not
    differently named. The 15, 30 and 45 minute sub-hourly outputs are unaffected and still run.
    Dropped rather than inlined: the hour-0 file is absent, so the product generation that reads
    it must not be made to wait on the post manager event that would have released it."""
    if domain_dt != 36:
        skip_tasks(d, f"hour-0 sub-hourly (DT_ATMOS={domain_dt})", mode="ignore",
                   names=[r"jrrfs_det_(post|prdgen)_f000_00_36(_long)?"])


def skip_subhourly_posts(d, cfg):
    """Keep quarter-hour post jobs only when the retro requests them; hourly post outputs remain
    active."""
    if cfg.is_false("RUN_SUBHOURLY_POST"):
        skip_tasks(d, "sub-hourly posts (RUN_SUBHOURLY_POST=FALSE)", mode="ignore",
                   names=[r"jrrfs_det_post_f[0-9]{3}_(15|30|45)_00(_long)?"])


def skip_long_forecast(d, cfg):
    """The whole 84 h forecast chain (DO_LONG_FORECAST): the forecast, its restarts, and the post
    and product generation that read its output. Every one of those task names ends in _long, or
    in _long_<hour> for the restarts."""
    if cfg.is_false("DO_LONG_FORECAST"):
        skip_tasks(d, "long forecast (DO_LONG_FORECAST=FALSE)", names=[r"jrrfs_det_[a-z0-9_]*_long(_[0-9]+)?"])


def truncate_forecasts(d, fcst_len, fcst_len_long):
    """Shorter forecasts (FCST_LEN_HRS for the hourly cycles, FCST_LEN_HRS_LONG for 00, 06, 12
    and 18z). setup_retro_links.sh puts the same two numbers in workflow.conf; here everything
    past the end of the forecast comes out of the definition. That includes the post manager,
    which scans a list of output files fixed at 0-84 (or 0-18) hours and err_exits 900 s after
    the last one it finds: an aborted task would leave the cycle short of complete, which is what
    the retro driver waits for before stepping to the next date. With the manager gone,
    post_manager points the surviving post tasks at the forecast task instead of at its events."""
    if fcst_len == 18 and fcst_len_long == 84:
        return
    names = []
    for length, last, suffix in ((fcst_len, 18, ""), (fcst_len_long, 84, "_long")):
        names += [rf"jrrfs_det_(post|prdgen)_f{h:03d}_(00|15|30|45)_(00|36){suffix}"
                  for h in range(length + 1, last + 1)]
        # the sub-hourly output of the last hour is past the end of the forecast as well
        names.append(rf"jrrfs_det_(post|prdgen)_f{length:03d}_(15|30|45)_00{suffix}")
    # restart hours past the end of the long forecast; the hourly cycles save 1, 2 and 3, which
    # the minimum length in check_settings keeps
    names += [f"jrrfs_det_save_restart_long_{h}" for h in (1, 2, 3, 6) if h > fcst_len_long]
    names.append("jrrfs_det_post_manager")
    skip_tasks(d, f"past the end of the forecast ({fcst_len} h, {fcst_len_long} h at 00/06/12/18z)", names=names)


def trim_lbcs(d, fcst_len, fcst_len_long):
    """Boundary conditions past the last hour any cycle in the family reaches. The 00, 06, 12 and
    18z ics families make one file per hour for the whole family, so the last one needed is the
    end of the long forecast, or of the 05z cycle's forecast if that reaches further. Group N of
    the BCGRPNUM groups makes hour N, so the groups above that hour have nothing left to make. The
    first group stays whatever happens: it is the one that stages the external model files the
    others read, and it still makes hour N + BCGRPNUM for each surviving group, since BOUNDARY_LEN
    is left at its operational value (see setup_retro_links.sh for why)."""
    lbc_last = max(fcst_len + 5, fcst_len_long)
    if lbc_last < 84:
        skip_tasks(d, f"boundaries past hour {lbc_last}",
                   names=[f"jrrfs_det_make_lbcs_{h:02d}" for h in range(lbc_last + 1, 85)])


def skip_extra_tasks(d, cfg):
    """Anything else this retro leaves out: SKIP_TASKS, a space-separated list of task-name
    patterns."""
    if cfg.get("SKIP_TASKS"):
        skip_tasks(d, "SKIP_TASKS", names=cfg.get("SKIP_TASKS").split())


def skip_older_restart_saves(d):
    """With older-cycle trigger alternatives removed (ordering.use_newest_background_only), these
    restart saves are not needed by a retro. Keep the task nodes visible as set-aside, and rewrite
    references so they cannot enable fallback."""
    skip_tasks(d, "older-cycle restart saves (retro)", mode="ignore",
               names=[r"jrrfs_det_save_restart_(f[23]|long_[23])",
                      r"jrrfs_enkf_save_restart_(mem[0-9]+_f[23]|f[23]_done)"])


def remove_spinup(d):
    """The deterministic spin-up cycles (DO_SPINUP). Operations cold starts at 03z and 15z into a
    1 h spin-up forecast and runs spin-up alongside production until 09z and 21z; a retro that
    only wants a cycling deterministic run can drop all of it. Nothing in the production chain
    waits on a spin-up task, so their references are dropped rather than inlined. The production
    cycle at the cold-start hour then has to cold start itself; see change_cold_start_hours."""
    # The EnKF spin-up recenter is the exception: it reads the det analysis, which is then the
    # production cycle's, so its det terms move to the production tasks
    d.sub(r"(det/[a-z]*/jrrfs_det_[a-z0-9_]*)_spinup", r"\1", line_filter="jrrfs_enkf_prep_cyc_spinup_mem")
    skip_tasks(d, "spin-up cycles (DO_SPINUP=FALSE)", mode="ignore", names=[r"jrrfs_det_[a-z0-9_]*spinup[a-z0-9_]*"])


def change_cold_start_hours(d, hours, offset, clone):
    """Cold start the deterministic production cycles at DET_COLD_START_HRS, from the GFS cycle
    EXTRN_MDL_ICS_OFFSET_HRS earlier. exrrfs_prep_cyc.sh cold starts when DO_SPINUP is FALSE and
    the hour is in CYCL_HRS_PRODSTART, so each cold-start prep_cyc is pointed at the make_ics task
    in its own ics family instead of at the cycle before it. Operations cold starts only in the
    03z and 15z spin-up, so other cold start hours (the Rocoto retros' 00z and 12z) are given a
    make_ics of their own; the make_ics tasks at hours that no longer cold start are switched
    off. Each hour minus offset must be a GFS cycle (checked in check_settings)."""
    n = 0
    for task in d.find("task", name="jrrfs_det_prep_cyc"):
        if task.cycle in hours and d.trigger_line(task) is not None:
            # its own ics family for the cold start fields, and the family's 00, 06, 12 or 18z one
            # for the boundaries, which the replaced trigger also waited on
            d.set_trigger(task, f"../ics==complete and ../../../{task.six_hourly}z/det/ics==complete")
            n += 1
    d.commit()
    print(f"  cold start: {n} prep_cyc task(s) pointed at their own ics family")

    def gfs(cyc):
        return (f"/{clone}/primary/{(cyc - offset) % 24:02d}/gfs/v16.3/gfs/atmos/post/"
                f"jgfs_atmos_post_f{offset:03d}==complete")

    have = {t.cycle for t in d.find("task", name="jrrfs_det_make_ics")}
    for task in d.find("task", name="jrrfs_det_make_ics"):
        if task.cycle in hours and d.trigger_line(task) is not None:
            d.set_trigger(task, gfs(task.cycle))
    added = 0
    for ics in d.find("family", name="ics"):
        cyc = ics.cycle
        if ics.group == "det" and cyc in hours and cyc not in have:
            # after the ics family's own attributes, before its first child
            ind = indent_of(d.lines[ics.start])
            at = ics.children[0].start if ics.children else ics.end - 1
            d.insert_before(at, f"{ind}  task jrrfs_det_make_ics", f"{ind}    trigger {gfs(cyc)}")
            have.add(cyc)
            added += 1
    missing = [h for h in hours if h not in have]
    if missing:
        sys.exit(f"ERROR: no det ics family at cold start hour(s) {missing}")
    d.commit()
    print(f"  cold start: make_ics added at {added} hour(s), reading GFS f{offset:03d}")

    stale = sorted(have - set(hours))
    if stale:
        skip_tasks(d, "make_ics outside DET_COLD_START_HRS", mode="ignore",
                   paths=["/(" + "|".join(f"{h:02d}z" for h in stale) + ")/det/ics/jrrfs_det_make_ics$"])
