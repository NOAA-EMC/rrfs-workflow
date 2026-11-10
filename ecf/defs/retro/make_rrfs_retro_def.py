#!/usr/bin/env python3
"""Make a developer copy of an RRFS suite definition for the machine in retro/config.sh (MACHINE):
its locations, its job submission commands, and, for a retro (RETRO=YES), triggers that step
through past dates instead of following the clock. The task tree is unchanged.

Usage: [VAR=value ...] ./make_rrfs_retro_def.py [output_def]
Any of the settings in retro/config.sh can be overridden from the environment.

main() below is the list of changes made to the NCO definition, in order; each is a function in
the retro_def package, which describes why it is needed. To add one, write a function that takes
the definition (a retro_def.deftree.Def) and the settings it needs, and call it from main().
"""

import argparse
import os
import re
import sys

from retro_def import chains, ordering, settings, simplify
from retro_def.config import load_config, package_home
from retro_def.deftree import Def

DEFS_DIR = os.path.dirname(os.path.realpath(__file__))


def domain_dt_atmos(domain):
    """The domain's model time step. DT_ATMOS lives inside the domain file's
    domain_workflow_conf(), so read the value out of the file rather than sourcing it."""
    path = os.path.join(DEFS_DIR, "domains", f"{domain}.sh")
    found = re.findall(r"^ *export DT_ATMOS='([0-9]+)'", open(path).read(), re.M) if os.path.isfile(path) else []
    return int(found[-1]) if found else 36


def check_settings(cfg):
    """Settings that cannot work together; say so before writing anything."""
    if cfg["MACHINE"] not in ("URSA", "WCOSS2"):
        sys.exit(f"MACHINE={cfg['MACHINE']} is not supported; the retro suite runs on URSA and WCOSS2")
    for name in (cfg["RRFS_SUITE"], cfg["PRODCLONE_SUITE"]):
        if not re.fullmatch(r"[A-Za-z0-9_]+", name):
            sys.exit(f"ERROR: ecFlow suite names may contain only letters, numbers, and underscores: {name}")
    if cfg["RETRO"] != "YES":
        return
    # Fire weather reads the long forecast's post for its initial and boundary conditions, so the
    # two settings cannot disagree. Say so here rather than let 464 fire weather tasks a day fail
    # on a natlev file the suite was told not to make.
    if cfg.is_false("DO_LONG_FORECAST") and not cfg.is_false("RUN_FIREWX"):
        sys.exit("ERROR: DO_LONG_FORECAST=FALSE needs RUN_FIREWX=FALSE.\n"
                 "       Fire weather takes its ICs and LBCs from the 84 h forecast's post.")
    # Fire weather starts from the parent's hour-0 natlev file, which only the 36 s step writes
    # (see simplify.skip_hour0_subhourly)
    dt = domain_dt_atmos(cfg["DOMAIN"])
    if dt != 36 and not cfg.is_false("RUN_FIREWX"):
        sys.exit(f"ERROR: DT_ATMOS={dt} ({cfg['DOMAIN']}) needs RUN_FIREWX=FALSE.\n"
                 "       Fire weather starts from the parent's hour-0 natlev file, which only the 36 s step writes.")
    if cfg.int("FCST_LEN_HRS", 18) < 3 or cfg.int("FCST_LEN_HRS_LONG", 84) < 3:
        sys.exit("ERROR: FCST_LEN_HRS and FCST_LEN_HRS_LONG must be at least 3.\n"
                 "       Each cycle warm starts from the hour 1, 2 or 3 restart of one of the three before it.")
    if cfg.is_true("DO_ARCHIVE_RETRO") and not cfg.get("ARCHIVEDIR"):
        sys.exit("ERROR: DO_ARCHIVE_RETRO=TRUE requires ARCHIVEDIR.")
    for var in ("DA_SYSTEM_DET", "DA_SYSTEM_ENKF"):
        if cfg.get(var, "GSI") not in ("GSI", "gsi", "JEDI", "jedi"):
            sys.exit(f"ERROR: {var} must be GSI or JEDI, not '{cfg.get(var)}'.")
    # each cold start reads the GFS cycle EXTRN_MDL_ICS_OFFSET_HRS earlier
    if cfg.is_false("DO_SPINUP"):
        offset = cfg.int("EXTRN_MDL_ICS_OFFSET_HRS", 3)
        for h in cfg.hours("DET_COLD_START_HRS", "03 15"):
            if (h - offset) % 6:
                sys.exit(f"ERROR: cold start hour {h:02d} minus EXTRN_MDL_ICS_OFFSET_HRS={offset} is not a GFS cycle")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("output_def", nargs="?", default=os.path.join(DEFS_DIR, "rrfs_retro.def"))
    args = ap.parse_args()

    cfg = load_config(DEFS_DIR)
    check_settings(cfg)
    packagehome = package_home(cfg, DEFS_DIR)
    suite = cfg["RRFS_SUITE"]
    clone = cfg["PRODCLONE_SUITE"]
    d = Def.read(os.path.join(DEFS_DIR, "..", cfg["BASE_DEF"]))

    settings.set_suite_settings(d, cfg, packagehome)
    settings.rename_suites(d, suite, clone)

    if cfg["RETRO"] == "YES":
        # the clock, and the orderings it gave
        ordering.remove_clock_conditions(d)
        ordering.wait_for_preclean(d)
        ordering.disable_cycle_end(d)
        if cfg.get("KEEPDATA"):
            settings.set_keepdata(d, cfg.get("KEEPDATA"))
        settings.set_da_systems(d, cfg.get("DA_SYSTEM_DET", "GSI"), cfg.get("DA_SYSTEM_ENKF", "GSI"))
        ordering.point_managers_at_forecast(d)
        ordering.prep_waits_for_lbcs(d)

        # what this retro does not run
        fcst_len = cfg.int("FCST_LEN_HRS", 18)
        fcst_len_long = cfg.int("FCST_LEN_HRS_LONG", 84)
        simplify.skip_groups(d, cfg)
        simplify.skip_task_types(d, cfg)
        simplify.skip_simplified_steps(d, cfg)
        simplify.skip_hour0_subhourly(d, domain_dt_atmos(cfg["DOMAIN"]))
        simplify.skip_subhourly_posts(d, cfg)
        simplify.skip_long_forecast(d, cfg)
        simplify.truncate_forecasts(d, fcst_len, fcst_len_long)
        simplify.trim_lbcs(d, fcst_len, fcst_len_long)
        simplify.skip_extra_tasks(d, cfg)
        if cfg.is_false("DO_SPINUP"):
            simplify.remove_spinup(d)
            simplify.change_cold_start_hours(d, cfg.hours("DET_COLD_START_HRS", "03 15"),
                                             cfg.int("EXTRN_MDL_ICS_OFFSET_HRS", 3), clone)

        # each cycle from the one before it, and nothing else
        ordering.use_newest_background_only(d, suite, cfg.hours("DET_PROD_START_HRS", "09 21"))
        simplify.skip_older_restart_saves(d)
        if cfg.is_true("DO_ARCHIVE_RETRO"):
            ordering.add_archive_tasks(d)

    settings.set_job_sizes(d, cfg)

    # The whole retro in one suite, a family per day and cold-start chain (RETRO_LAYOUT=chains);
    # see retro_def/chains.py. Each chain cold starts, so nothing may link one chain to the next.
    if cfg["RETRO_LAYOUT"] == "chains":
        chains.lay_out_chains(d, suite, clone, cfg["RETRO_START"], cfg["RETRO_END"],
                              cfg.hours("DET_COLD_START_HRS", "03 15"), cfg["DEV_DATAROOT"])

    d.write(args.output_def)
    print(f"Wrote {args.output_def} from {cfg['BASE_DEF']}")
    print(f"  PACKAGEHOME={packagehome}")
    print(f"  ECF_HOME={cfg['ECF_HOME']}  (create it before loading the suite)")
    print(f"  MACHINE={cfg['MACHINE']} PROJ={cfg['PROJ']} QUEUE={cfg['QUEUE']} PARTITION={cfg.get('PARTITION')}")
    print(f"  DEV_PTMP={cfg['DEV_PTMP']}")
    print(f"  DEV_DATAROOT={cfg['DEV_DATAROOT']}")
    print(f"  RETRO_DATA_ROOT={cfg['RETRO_DATA_ROOT']}")
    print(f"  DOMAIN={cfg['DOMAIN']}")
    print(f"  RRFS_SUITE={suite} PRODCLONE_SUITE={clone}")


if __name__ == "__main__":
    main()
