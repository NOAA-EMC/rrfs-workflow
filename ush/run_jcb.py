#!/usr/bin/env python3
import sys
import yaml
import re
from datetime import datetime, timedelta
from jcb import render
from wxflow import parse_j2yaml
from collections.abc import Mapping, Sequence
from pathlib import Path
import os

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
            new = f"./{target}"
            in_engine["obsfile"] = new
            # Write back the engine in case these were None earlier
            if "engine" not in obsdatain:
                obsdatain["engine"] = in_engine
            obs_space["obsdatain"] = obsdatain
            # Optional debug:
            # print(f"[patch] {obs_space.get('name')} : {old} -> {new}")

    return cfg_plain

def to_plain(obj):
    # Common pattern in wxflow/JCB style objects
    for attr in ("to_dict", "as_dict", "dict"):
        if hasattr(obj, attr) and callable(getattr(obj, attr)):
            return to_plain(getattr(obj, attr)())

    # dict-like
    if isinstance(obj, Mapping):
        return {str(k): to_plain(v) for k, v in obj.items()}

    # list-like (but not strings/bytes)
    if isinstance(obj, Sequence) and not isinstance(obj, (str, bytes, bytearray)):
        return [to_plain(v) for v in obj]

    # pathlib, numpy scalars, etc.
    if isinstance(obj, Path):
        return str(obj)
    try:
        import numpy as np
        if isinstance(obj, np.generic):
            return obj.item()
    except Exception:
        pass

    return obj

def parse_gsd_sfcobs_uselist(path):
    station_accepts = {
        "wind": {},
        "airTemperature": {},
        "specificHumidity": {},
    }

    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";"):
                continue

            parts = line.split()
            if len(parts) < 5:
                continue

            station = str(parts[0])
            try:
                good_w = int(parts[1])
                good_t = int(parts[2])
                good_td = int(parts[3])
            except ValueError:
                continue

            provider = parts[4][:8] # must use 8char string as in obs file!

            if good_w == 1:
                station_accepts["wind"].setdefault(provider, []).append(station)
            if good_t == 1:
                station_accepts["airTemperature"].setdefault(provider, []).append(station)
            if good_td == 1:
                station_accepts["specificHumidity"].setdefault(provider, []).append(station)

    def grouped(d):
        return [
            {"provider": provider, "stations": sorted(stations)}
            for provider, stations in sorted(d.items())
        ]

    return {
        "wind": grouped(station_accepts["wind"]),
        "airTemperature": grouped(station_accepts["airTemperature"]),
        "specificHumidity": grouped(station_accepts["specificHumidity"]),
    }

def parse_gsd_sfcobs_provider(path):
    allsprvs = []
    subproviders = []

    with open(path, "r") as f:
        for line in f:
            raw = line.rstrip("\n")
            stripped = raw.strip()

            if not stripped:
                continue
            if stripped.startswith("*"):
                continue
            if stripped.lower().startswith("use list"):
                continue

            provider = raw[0:8].strip()
            subprovider = raw[8:16].strip()

            if not provider or not subprovider:
                continue

            if subprovider == "allsprvs":
                allsprvs.append(provider)
            else:
                subproviders.append({
                    "provider": provider,
                    "subprovider": subprovider,
                })

    return sorted(allsprvs), subproviders

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

    uselist_path = task_config.get("mesonet_gsd_sfcobs_uselist")
    provider_path = task_config.get("mesonet_gsd_sfcobs_provider")
    msonet_station_accepts_winds = []
    msonet_station_accepts_airTemperature = []
    msonet_station_accepts_specificHumidity = []
    msonet_provider_accepts_allsprvs = []
    msonet_provider_accepts_subproviders = []

    print("uselist_path:", uselist_path)
    print("exists:", os.path.exists(uselist_path) if uselist_path else "N/A")

    if uselist_path:
        msonet_station_accepts = parse_gsd_sfcobs_uselist(uselist_path)

        msonet_station_accepts_winds = msonet_station_accepts["wind"]
        msonet_station_accepts_airTemperature = msonet_station_accepts["airTemperature"]
        msonet_station_accepts_specificHumidity = msonet_station_accepts["specificHumidity"]

        task_config["msonet_station_accepts_winds"] = msonet_station_accepts_winds
        task_config["msonet_station_accepts_airTemperature"] = msonet_station_accepts_airTemperature
        task_config["msonet_station_accepts_specificHumidity"] = msonet_station_accepts_specificHumidity

    print("provider_path:", provider_path)
    print("exists:", os.path.exists(provider_path) if provider_path else "N/A")

    if provider_path:
       (msonet_provider_accepts_allsprvs, msonet_provider_accepts_subproviders) = parse_gsd_sfcobs_provider(provider_path)

    jcb_config = parse_j2yaml(jcb_config, task_config)
    jcb_config["msonet_station_accepts_winds"] = msonet_station_accepts_winds
    jcb_config["msonet_station_accepts_airTemperature"] = msonet_station_accepts_airTemperature
    jcb_config["msonet_station_accepts_specificHumidity"] = msonet_station_accepts_specificHumidity
    jcb_config["msonet_provider_accepts_allsprvs"] = msonet_provider_accepts_allsprvs
    jcb_config["msonet_provider_accepts_subproviders"] = msonet_provider_accepts_subproviders

    # Per-cycle updates
    cycle_config = update_cycle_times(jcb_config, cycle_str)

    # Render (returns wxflow/JCB wrapper objects)
    rendered = render(cycle_config)
    rendered_plain = to_plain(rendered)

    # Dump to plain YAML text, then load back to plain dicts/lists
    yaml_text = yaml.safe_dump(rendered_plain, default_flow_style=False, sort_keys=False)
    cfg_plain = yaml.safe_load(yaml_text)

    # If solver, structurally patch obsfiles to observer rundir jdiag
    if "solver" in jedi_yaml:
        ctest_yaml = jedi_yaml[:-5]  # strip ".yaml"
        cfg_plain = patch_solver_struct(cfg_plain, ctest_yaml)

    # Write clean YAML
    with open(jedi_yaml, "w") as f:
        yaml.safe_dump(cfg_plain, f, default_flow_style=False, sort_keys=False)

    print(f"Wrote {jedi_yaml} for cycle {cycle_str}")

