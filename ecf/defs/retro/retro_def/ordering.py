"""Retro triggers: step through past dates instead of following the clock.

In real time the clock orders much of each cycle's work. A retro makes every clock condition
always true (the retro prod_clone steps the dates, ush/prod_clone/make_retro_def.sh), so each
step here puts back, as a trigger, an ordering the clock used to give.
"""

import re
import sys

from .core import CYCLE_NAME, Prim, indent_of, leaves, parse_expr, unparse


def remove_clock_conditions(d):
    """Make every clock-time condition in the triggers always true; the dependencies on other
    tasks and on /prod_clone stay."""
    d.sub(r":TIME *(>=|>) *[0-9]{4}", ":TIME >= 0000")
    d.sub(r":TIME *(<=|<) *[0-9]{4}", ":TIME < 2400")


def wait_for_preclean(d):
    """The clock also ordered each cycle's work: preclean at :00 wipes the cycle's working
    directories, then fire weather (:15), the EnKF (:22) and the ensemble forecast (:30) start.
    Only det waits for preclean explicitly, so with the clock gone the others would race it and
    lose their directories. Make them wait for preclean too, which is the ordering the clock
    gave them."""
    for fam in d.find("family", name="enkf|ensf|firewx"):
        if fam.parent.kind == "family" and CYCLE_NAME.fullmatch(fam.parent.name):
            d.and_trigger(fam, "preclean == complete")
    d.commit()


def disable_cycle_end(d):
    """cycle_end is the suite's developer retro driver (ecf/scripts/cycle_end.ecf): it bumps PDY
    and force-requeues the cycle families, which would fight the retro prod_clone that drives the
    dates here. defstatus complete keeps it from ever running, including after a family is
    requeued."""
    for task in d.find("task", name="cycle_end"):
        d.add_attr(task, "defstatus complete")
    d.commit()


def point_managers_at_forecast(d):
    """A manager task that waits on the whole forecast family is fragile once anything is
    requeued: the family reads active while other tasks in it run, so the manager can start
    before the forecast does, and it reads queued while the saves it releases wait, which
    deadlocks it. Point those triggers at the forecast task itself."""
    fcst = {}
    for task in d.find("task"):
        grp = task.group
        if task.parent.name == "forecast" and grp and \
                re.fullmatch(rf"jrrfs_{grp}_forecast(_spinup|_long|_ensinit)?(_mem001)?", task.name):
            fcst.setdefault((task.cycle, grp), task.name)
    n = 0
    for node in d.nodes.values():
        name = fcst.get((node.cycle, node.group))
        if not name:
            continue
        for i in d.attr_lines(node, "trigger"):
            if re.search(r"\.\./forecast\s*==", d.line(i)):
                d.replace_line(i, re.sub(r"\.\./forecast(\s*==)", rf"../forecast/{name}\1", d.line(i)))
                n += 1
    d.commit()
    print(f"{n} manager trigger(s) pointed at the forecast task")


def prep_waits_for_lbcs(d):
    """The prep_cyc tasks wait only for the previous forecast (or, at 03z/15z cold starts, their
    own initial conditions), then copy boundaries from the family's 00/06/12/18z make_lbcs; in
    real time those finish hours earlier. Without the clock the preps start alongside the
    make_lbcs jobs and can copy a half-written set (2024050801 enkf mem023 found f002 but not
    f001)."""
    for task in d.find("task", name=r"jrrfs_(det|enkf)_prep_cyc(_spinup|_mem\d+)?"):
        if d.trigger_line(task) is not None:
            grp = task.name.split("_")[1]
            d.and_trigger(task, f"../../../{task.six_hourly}z/{grp}/ics==complete")
    d.commit()


def _keep_newest_background(node):
    """Drop the older-cycle alternatives of OR groups in which every branch waits on an EnKF or
    deterministic forecast; the workflow lists the newest background first."""
    if isinstance(node, Prim):
        return node, 0
    op, children = node
    rewritten, removed = [], 0
    for child in children:
        child, count = _keep_newest_background(child)
        rewritten.append(child)
        removed += count
    if op == "or" and len(rewritten) > 1 and all(
            any(re.search(r"/(?:det|enkf)/forecast(?:/|\s*==)", p.text) and re.search(r"==\s*complete$", p.text)
                for p in leaves(branch))
            for branch in rewritten):
        return rewritten[0], removed + len(rewritten) - 1
    return (op, rewritten), removed


def use_newest_background_only(d, suite, prod_start_hours):
    """Retro jobs must use the immediately previous cycle's background. Production OR branches
    allow prep and analysis to proceed from older restarts when the latest cycle is late; keep
    only the newest. Then add the waits the older restarts stood in for without a trigger
    alternative: blend_ics on its member's previous-cycle restart, the det production start hours
    on the spin-up cycle's restart, and the det analysis on the previous gsi_diag, which rewrites
    the radstat the next analysis copies, so a race changes the radiance bias."""
    changed = removed = 0
    for task in d.find("task", name=r"jrrfs_(?:det|enkf)_prep_cyc(?:_spinup|_ensmean|_mem\d+)?|"
                                    r"jrrfs_det_analysis_(?:gsi|jedi)(?:_spinup)?"):
        for i in d.attr_lines(task, "trigger"):
            node, count = _keep_newest_background(parse_expr(d.line(i).strip()[len("trigger "):], "/"))
            if count:
                d.replace_line(i, f"{indent_of(d.line(i))}trigger {unparse(node)}")
                changed += 1
                removed += count
    print(f"  strict backgrounds: {removed} older-cycle trigger alternative(s) removed "
          f"from {changed} prep/analysis trigger(s)")

    waits = 0
    for task in d.find("task"):
        prev = (task.cycle - 1) % 24 if task.cycle is not None else None
        if prev is None:
            continue
        prev_cycle = f"/{suite}/primary/{prev // 6 * 6:02d}/rrfs/v1.0/{prev:02d}z"
        member = re.fullmatch(r"jrrfs_enkf_blend_ics_mem(\d+)", task.name)
        if member:
            restart = f"{prev_cycle}/enkf/forecast/jrrfs_enkf_save_restart_mem{member.group(1)}_f1"
        elif task.name == "jrrfs_det_prep_cyc" and task.cycle in prod_start_hours:
            restart = f"{prev_cycle}/det/forecast/jrrfs_det_save_restart_spinup_f001"
        elif task.name == "jrrfs_det_analysis_gsi":
            restart = f"{prev_cycle}/det/analysis/jrrfs_det_analysis_gsi_diag"
        else:
            continue
        if restart in d.nodes:
            for i in d.attr_lines(task, "trigger"):
                d.replace_line(i, f"{d.line(i)} and {restart}==complete")
                waits += 1
    d.commit()
    print(f"  strict backgrounds: {waits} blend_ics, det production start and det analysis trigger(s) "
          "wait on a previous-cycle task")


def add_archive_tasks(d):
    """Keep the archive step in retro definitions only. Each deterministic cycle gets one task
    after its det family is complete, so no partial cycle COM directory is written to HPSS."""
    cycles = d.find("family", name=CYCLE_NAME.pattern)
    if not cycles:
        sys.exit("ERROR: no hourly cycle families found for archive task insertion")
    for cyc in cycles:
        ind = indent_of(d.lines[cyc.start]) + "  "
        d.insert_before(cyc.end - 1,
                        f"{ind}family archive",
                        f"{ind}  trigger det == complete",
                        f"{ind}  task jrrfs_archive_retro",
                        f"{ind}endfamily")
    d.commit()
    print(f"  archive: {len(cycles)} deterministic cycle task(s) added")
