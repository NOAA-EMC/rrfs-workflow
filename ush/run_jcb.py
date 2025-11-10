#!/usr/bin/env python3
import sys
import yaml
import re
from datetime import datetime, timedelta
from jcb import render
from wxflow import parse_j2yaml

def update_cycle_times(config, cycle_str):
    cycle_time = datetime.strptime(cycle_str, "%Y%m%d%H")
    hour = cycle_time.hour

    # Common formats
    iso_str = cycle_time.strftime("%Y-%m-%dT%H:%M:%SZ")
    prefix_str = cycle_time.strftime("%Y%m%d.%H%M%S.")

    # Extract numeric value from window_length (default to 6 if missing)
    window_len_str = config.get("window_length", "PT6H")
    match = re.search(r"PT(\d+)H", window_len_str)
    window_len_hrs = int(match.group(1)) if match else 6

    # Divide by 2 for symmetric window around the cycle
    half_window = window_len_hrs / 2

    # Example: window_begin is 3h before cycle
    config["window_begin"] = (cycle_time - timedelta(hours=half_window)).strftime("%Y-%m-%dT%H:%M:%SZ")
    config["window_end"] = (cycle_time + timedelta(hours=half_window)).strftime("%Y-%m-%dT%H:%M:%SZ")

    return config

def patch_solver_struct(cfg_plain, ctest_yaml):
    """
    For solver yamls: rewrite each observer's
    obs space.obsdatain.engine.obsfile to point to the *observer* rundir jdiag.
    Pairs within the same obs space to avoid cross-contamination.
    """
    # Handle both dict and list shapes defensively
    observations = cfg_plain.get("observations", {})
    if isinstance(observations, dict):
        observer_blocks = observations.get("observers", [])
    elif isinstance(observations, list):
        observer_blocks = []
        for grp in observations:
            if isinstance(grp, dict):
                observer_blocks.extend(grp.get("observers", []))
    else:
        return cfg_plain

    observer_rundir = ctest_yaml.replace("solver", "observer")

    for ob in observer_blocks:
        if not isinstance(ob, dict):
            continue
        obs_space  = ob.get("obs space", {})
        if not isinstance(obs_space, dict):
            continue

        obsdatain  = obs_space.get("obsdatain", {}) or {}
        obsdataout = obs_space.get("obsdataout", {}) or {}
        in_engine  = obsdatain.get("engine", {}) or {}
        out_engine = obsdataout.get("engine", {}) or {}

        # Determine the jdiag target for THIS obs space
        if isinstance(out_engine, dict) and "obsfile" in out_engine:
            target = out_engine["obsfile"]
        else:
            # Fallback if no obsdataout engine present: derive from obs space name
            name = obs_space.get("name", "unknown")
            target = f"jdiag_{name}.nc"

        # Only rewrite if there's an obsfile to replace (string)
        old = in_engine.get("obsfile")
        if isinstance(old, str):
            new = f"../rundir-{observer_rundir}/{target}"
            in_engine["obsfile"] = new
            # Write back the engine in case these were None earlier
            if "engine" not in obsdatain:
                obsdatain["engine"] = in_engine
            obs_space["obsdatain"] = obsdatain
            # Optional debug:
            # print(f"[patch] {obs_space.get('name')} : {old} -> {new}")

    return cfg_plain

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: run.py YYYYMMDDHH jcb_config jedi_yaml")
        print("jcb_config: jcb-jedivar.yaml")
        print("jedi_yaml: jedivar.yaml")
        sys.exit(1)

    cycle_str  = sys.argv[1]
    jcb_config   = sys.argv[2]
    jedi_yaml   = sys.argv[3]

    # Load template and expand j2
    with open(jcb_config, "r") as f:
        task_config = yaml.safe_load(f)
    jcb_config = parse_j2yaml(jcb_config, task_config)

    # Per-cycle updates
    cycle_config = update_cycle_times(jcb_config, cycle_str)

    # Render (returns wxflow/JCB wrapper objects)
    rendered = render(cycle_config)

    # Dump to plain YAML text, then load back to plain dicts/lists
    yaml_text = yaml.safe_dump(rendered, default_flow_style=False, sort_keys=False)
    cfg_plain = yaml.safe_load(yaml_text)

    # If solver, structurally patch obsfiles to observer rundir jdiag
    if "solver" in jedi_yaml:
        ctest_yaml = jedi_yaml[:-5]  # strip ".yaml"
        cfg_plain = patch_solver_struct(cfg_plain, ctest_yaml)

    # Write clean YAML
    with open(jedi_yaml, "w") as f:
        yaml.safe_dump(cfg_plain, f, default_flow_style=False, sort_keys=False)

    print(f"Wrote {jedi_yaml} for cycle {cycle_str}")

