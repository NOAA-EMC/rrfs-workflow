"""Suite variables and job submission: where the retro runs and how its jobs are sized."""

import fnmatch
import re
import sys

from .core import indent_of


def _edit(indent, name, value):
    return f"{indent}edit {name} '{value}'"


def set_suite_settings(d, cfg, packagehome):
    """Put the machine's locations, accounts and job commands at the top of the suite, and
    rewrite the few that the NCO definition sets again further down."""
    machine = cfg["MACHINE"]
    rdr = cfg["RETRO_DATA_ROOT"]
    c = f"{rdr}/com"
    queue = cfg["QUEUE"]
    suite_vars = [
        ("MACHINE", machine),
        ("RRFS_SUITE", cfg["RRFS_SUITE"]),
        ("PRODCLONE_SUITE", cfg["PRODCLONE_SUITE"]),
    ]
    if machine == "URSA":
        suite_vars.append(("PARTITION", cfg.get("PARTITION")))
    suite_vars += [
        ("DEV_PTMP", cfg["DEV_PTMP"]),
        ("DEV_DATAROOT", cfg["DEV_DATAROOT"]),
        ("DEV_COMPATH", cfg.get("DEV_COMPATH", f"{c}/gfs:{c}/gefs:{c}/obsproc:{c}/nsst:{c}/nosofs:{c}/hrrr:{c}/rap")),
        ("DCOMROOT", cfg.get("DCOMROOT", f"{rdr}/dcom")),
    ]
    if cfg.get("ARCHIVEDIR"):
        suite_vars.append(("ARCHIVEDIR", cfg.get("ARCHIVEDIR")))
    # RETRO=YES turns on the retro workarounds in the ex-scripts (ecf/include/head.h)
    suite_vars.append(("RETRO", "YES"))
    if cfg["FIX_RRFS_JEDI"]:
        suite_vars.append(("FIX_RRFS_JEDI", cfg["FIX_RRFS_JEDI"]))
    # set here, and again wherever the NCO definition sets them further down, since those WCOSS2
    # locations and queues would override the suite-level values
    overrides = {
        "PACKAGEHOME": packagehome,
        "PROJ": cfg["PROJ"],
        "QUEUE": queue,
        "QUEUE_ARCH": cfg.get("QUEUE_ARCH", queue),
        "OUTPUTDIR": cfg["OUTPUTDIR"],
    }
    suite_vars += [
        ("ecflow_ver", cfg["ECFLOW_VER"]),
        ("ECF_LOGHOST", cfg["ECFLOW_HOST"]),
        ("ENVIR", cfg["ENVIR"]),
        ("rrfs_ver", cfg["RRFS_VER"]),
        ("MACHINE_SITE", cfg["MACHINE_SITE"]),
        ("NET", "rrfs"),
        ("RUN", "rrfs"),
        ("PACKAGEHOME", packagehome),
        ("FIXrrfs", cfg["RETRO_FIX_DIR"]),
        ("PROJ", overrides["PROJ"]),
        ("PROJENVIR", "DEV"),
        ("QUEUE", overrides["QUEUE"]),
        ("QUEUE_ARCH", overrides["QUEUE_ARCH"]),
        ("OUTPUTDIR", overrides["OUTPUTDIR"]),
        # no product alerts from a retro; the WCOSS2 fake dbn_alert fails on any file it cannot find,
        # such as the NA subset that prdgen alerts on but a CONUS domain never writes
        ("SENDDBN", "NO"),
        ("SENDDBN_NTC", "NO"),
        ("ECF_HOME", cfg["ECF_HOME"]),
        # job logs next to the job files; the NCO dev ecflow servers set ECF_OUT to ~/ecflow, where the
        # per-family log directories do not exist, so no job could write its output
        ("ECF_OUT", cfg["ECF_HOME"]),
        ("ECF_INCLUDE", f"{packagehome}/ecf/include"),
    ]
    if machine == "WCOSS2":
        # The cards carry the #PBS job sizes. -o puts the output where ecflow looks for it, since the
        # cards only say -j oe. Coarser domains (strip when merging to the nco branch): QSUB_OVERRIDES
        # carries per-task job sizes for other domains; qsub options win over the #PBS lines too.
        suite_vars += [
            ("QSUB_OVERRIDES", ""),
            ("ECF_JOB_CMD", "qsub -o %ECF_JOBOUT% %QSUB_OVERRIDES% %ECF_JOB% 1> %ECF_JOB%.sub 2>&1"),
            ("ECF_KILL_CMD", "qdel %ECF_RID% 1> %ECF_JOB%.kill 2>&1"),
            ("ECF_STATUS_CMD", "qstat -f %ECF_RID% 1> %ECF_JOB%.stat 2>&1"),
        ]
    if machine == "URSA":
        # sbatch would otherwise also read the #PBS lines (e.g. "-q" as the partition).
        # Coarser domains (strip when merging to the nco branch): SBATCH_OVERRIDES carries
        # per-task job sizes for other domains, since sbatch options win over the #SBATCH lines in cards.
        suite_vars += [
            ("SBATCH_OVERRIDES", ""),
            ("ECF_JOB_CMD", "sbatch --ignore-pbs %SBATCH_OVERRIDES% %ECF_JOB% 1> %ECF_JOB%.sub 2>&1"),
            ("ECF_KILL_CMD", "scancel %ECF_RID% 1> %ECF_JOB%.kill 2>&1"),
            ("ECF_STATUS_CMD", "squeue -j %ECF_RID% 1> %ECF_JOB%.stat 2>&1"),
        ]

    suite_done = False
    for i, line in enumerate(d.lines):
        words = line.split()
        if words[:1] == ["suite"] and not suite_done:
            suite_done = True
            d.replace_line(i, f"suite {cfg['RRFS_SUITE']}")
            d.insert_after(i, *(_edit("  ", k, v) for k, v in suite_vars))
        elif words[:1] == ["edit"] and len(words) > 1 and words[1] in overrides:
            d.replace_line(i, _edit(indent_of(line), words[1], overrides[words[1]]))
        elif words[:2] == ["edit", "FIX_RRFS_JEDI"]:
            # the para definition's WCOSS2 path; the one from retro/config.sh is set at the top instead
            d.delete_line(i)
    d.commit()


def rename_suites(d, suite, clone):
    """The NCO base definition keeps its operational suite paths; rewrite only this generated
    retro copy so both experiments can coexist on one ecFlow server."""
    for i, line in enumerate(d.lines):
        new = line.replace("/para/", f"/{suite}/").replace("/prod_clone/", f"/{clone}/")
        if new != line:
            d.replace_line(i, new)
    d.commit()


def set_keepdata(d, keepdata):
    """Whether jobs keep their stmp working directories. Two suite variables decide it and KEEPDATA
    in retro/config.sh sets both. KEEPDATA is read by each job, for its own directory; the base
    definition sets YES at every place it appears, so rewrite the value rather than the lines.
    KEEP_TMP is read by jrrfs_clean, for the hour's shared directories at the end of each cycle;
    the base definition leaves it to the job card's default, NO, so add it at the top."""
    n = d.count(r" *edit KEEPDATA ")
    d.sub(r"^( *)edit KEEPDATA '[A-Za-z]+'", rf"\1edit KEEPDATA '{keepdata}'")
    for i, line in enumerate(d.lines):
        if line.startswith("suite "):
            d.insert_after(i, f"  edit KEEP_TMP '{keepdata}'")
    d.commit()
    print(f"  KEEPDATA: {n} setting(s) rewritten to '{keepdata}', and KEEP_TMP set to match")


def set_da_systems(d, da_system_det, da_system_enkf):
    """Which analyses run: the route DA_SYSTEM_DET (det) or DA_SYSTEM_ENKF (EnKF) does not select
    is marked complete, never submitted, through each task's "complete :DA_*_JEDI" line.
    Each is GSI or JEDI (checked in check_settings)."""
    for var, system, toggle in (("DA_SYSTEM_DET", da_system_det, "DA_DET_JEDI"),
                                ("DA_SYSTEM_ENKF", da_system_enkf, "DA_ENKF_JEDI")):
        jedi = 1 if system.upper() == "JEDI" else 0
        d.sub(rf"^( *)edit {toggle} '[01]'", rf"\1edit {toggle} '{jedi}'")
        print(f"  {var}: {system} ({toggle}={jedi})")


def _qsub_opts(sbatch):
    """sbatch job size options in qsub terms; --nodes=N becomes N whole 128-core nodes."""
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


def set_job_sizes(d, cfg):
    """Coarser domains (strip when merging to the nco branch): give the tasks the domain's table
    names their node sizes through SBATCH_OVERRIDES on Ursa, or QSUB_OVERRIDES on WCOSS2. Task
    walltimes come from the retro config so simplified and full runs can set them consistently.
    The table is in sbatch terms; on WCOSS2 --nodes=N becomes N whole 128-core nodes.
    The node counts carry over because ranks per node come from the domain's PPN_* settings, which
    all fit in a WCOSS2 node; RRFS_NA_3km has none, the cards are sized for it. The JEDI analyses
    come first and on every domain, sized from the JEDI settings in retro/config.sh, so their job
    requests always match the tasks the ex-scripts start."""
    det_nodes = cfg.get("NNODES_ANALYSIS_JEDI", "16")
    det_time = cfg.get("WALLTIME_ANALYSIS_JEDI", "00:50:00")
    enkf_nodes = cfg.get("NNODES_ANALYSIS_ENKF_JEDI", "48")
    enkf_time = cfg.get("WALLTIME_ANALYSIS_ENKF_JEDI", "01:00:00")
    sizes = [
        ("jrrfs_det_analysis_jedi*", f"--nodes={det_nodes} --time={det_time}"),
        ("jrrfs_enkf_analysis_jedi*", f"--nodes={enkf_nodes} --time={enkf_time}"),
    ]
    sizes += [tuple(entry.split(":", 1)) for entry in cfg.array("DOMAIN_SBATCH")]
    # Per-task walltimes are configurable without editing the domain's node sizing table.
    walltimes = [
        ("jrrfs_archive_retro", "WALLTIME_ARCHIVE_RETRO"),
        ("jrrfs_clean", "WALLTIME_CLEAN"),
        ("jrrfs_clean_early", "WALLTIME_CLEAN_EARLY"),
        ("jrrfs_det_forecast", "WALLTIME_DET_FORECAST"),
        ("jrrfs_det_forecast_long", "WALLTIME_DET_FORECAST_LONG"),
        ("jrrfs_det_analysis_gsi*", "WALLTIME_DET_ANALYSIS_GSI"),
        ("jrrfs_det_ioda_bufr", "WALLTIME_DET_IODA_BUFR"),
        ("jrrfs_det_make_ics", "WALLTIME_DET_MAKE_ICS"),
        ("jrrfs_det_make_lbcs_*", "WALLTIME_DET_MAKE_LBCS"),
        ("jrrfs_det_post_f*", "WALLTIME_DET_POST"),
        ("jrrfs_det_prdgen_f*", "WALLTIME_DET_PRDGEN"),
        ("jrrfs_det_prep_cyc", "WALLTIME_DET_PREP_CYC"),
        ("jrrfs_det_process_bufr", "WALLTIME_DET_PROCESS_BUFR"),
        ("jrrfs_det_save_restart_f*", "WALLTIME_DET_SAVE_RESTART"),
        ("jrrfs_det_save_restart_long_*", "WALLTIME_DET_SAVE_RESTART_LONG"),
    ]
    walltimes = [(pat, cfg.get(var)) for pat, var in walltimes if cfg.get(var)]
    wcoss2 = cfg["MACHINE"] == "WCOSS2"
    var = "QSUB_OVERRIDES" if wcoss2 else "SBATCH_OVERRIDES"
    n = 0
    for task in d.find("task"):
        opts = next((o for pat, o in sizes if fnmatch.fnmatch(task.name, pat)), "")
        walltime = next((w for pat, w in walltimes if fnmatch.fnmatch(task.name, pat)), "")
        # Keep an explicit domain-specific time, such as the longer GSI spin-up allocation.
        if walltime and not re.search(r"(?:^|\s)--time=", opts):
            opts = (opts + " " if opts else "") + f"--time={walltime}"
        if opts:
            d.add_attr(task, f"edit {var} '{_qsub_opts(opts) if wcoss2 else opts}'")
            n += 1
    d.commit()
    print(f"{n} tasks given job sizes and configured walltimes")
