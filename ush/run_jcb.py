#!/usr/bin/env python3
import sys
import yaml
from datetime import datetime, timedelta
from jcb import render
from wxflow import parse_j2yaml

model = "fv3"
window_length = 4

def update_cycle_times(config, cycle_str):
    cycle_time = datetime.strptime(cycle_str, "%Y%m%d%H")
    hour = cycle_time.hour

    # Common formats
    iso_str = cycle_time.strftime("%Y-%m-%dT%H:%M:%SZ")
    prefix_str = cycle_time.strftime("%Y%m%d.%H%M%S.")

    # Example: window_begin is 3h before cycle
    config["window_begin"] = (cycle_time - timedelta(hours=3)).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Background times
    config["atmosphere_background_time_iso"] = iso_str
    config["atmosphere_background_time_prefix"] = prefix_str

    # Obs naming
    config["atmosphere_obsdatain_suffix"]  = f".{cycle_str}.nc"
    config["atmosphere_obsdataout_suffix"] = f"_{cycle_str}.nc"

    return config

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: run.py YYYYMMDDHH model")
        sys.exit(1)

    cycle_str = sys.argv[1]
    model = sys.argv[2]
    jedi_yaml = f"./jedi_{cycle_str}.yaml"
    jcb_config = f"rdas-atmosphere-templates-{model}.yaml"

    # Load template
    with open(jcb_config, "r") as yaml_file:
        task_config = yaml.safe_load(yaml_file)
    jcb_config = parse_j2yaml(jcb_config, task_config)

    # Update for this cycle
    cycle_config = update_cycle_times(jcb_config, cycle_str)

    # Render JEDI yaml
    jedi_config = render(cycle_config)

    # Write out
    with open(jedi_yaml, "w") as f:
        yaml.dump(jedi_config, f, default_flow_style=False, sort_keys=False)

    print(f"Wrote {jedi_yaml} for cycle {cycle_str}")
