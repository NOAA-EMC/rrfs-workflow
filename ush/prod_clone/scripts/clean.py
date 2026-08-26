#!/usr/bin/env python3

import ecflow
import datetime
import os

HOST = "ddecflow02"
PORT = 32035
RRFS_DIR = "/lfs/f2/t2o/ptmp/emc/para/stmp"

# Mapping Parent Family to (Target Child Task, Cleanup Hour Range)
cycles = {
    "00": ("05z", "00 05"),
    "06": ("11z", "06 11"),
    "12": ("17z", "12 17"),
    "18": ("23z", "18 23")
}

def run_cleanup(parent_cyc, hour_range):
    """Executes the specific rm commands for the given cycle range"""
    start, end = hour_range.split()
    print(f"---> Running cleanup for cycle {parent_cyc} (Hours {start} to {end})...")
    
    # Constructing the bash command exactly as you provided
    cleanup_cmd = f"""
    cd {RRFS_DIR} && \
    for cyc in $(seq -w {start} {end}); do \
        rm -fr *_${{cyc}}.*.d* ; \
        rm -fr *_${{cyc}}_v1.0_prod* ; \
    done
    """
    # Execute the command
    os.system(cleanup_cmd)

def check_and_clean(ci, parent, child, hr_range):
    node_path = f"/para/primary/{parent}/rrfs/v1.0/{child}"
    
    try:
        defs = ci.get_defs()
        node = defs.find_abs_node(node_path)
        
        if node is None:
            return f"SKIP: {node_path} not found."

        status = node.get_state()
        is_complete = (status == ecflow.State.complete)
        
        # Parse ecFlow ISO time
        state_change_str = node.get_state_change_time()
        state_change_time = datetime.datetime.strptime(state_change_str, "%Y-%m-%dT%H:%M:%S")
        
        duration = datetime.datetime.now() - state_change_time
        hours_old = duration.total_seconds() / 3600
        
        if is_complete and hours_old >= 6.0:
            print(f"SUCCESS: {node_path} is {hours_old:.2f} hrs old.")
            run_cleanup(parent, hr_range)
            return f"DONE: Cleanup finished for {parent}z."
        else:
            return f"PENDING: {node_path} is {status} (Age: {hours_old:.2f} hrs). No cleanup."

    except Exception as e:
        return f"ERROR: {e}"

# --- Main Execution ---
try:
    client = ecflow.Client(HOST, PORT)
    client.sync_local()
    
    print(f"--- RRFS Cleanup Task ({datetime.datetime.now()}) ---")
    for parent, (child, hr_range) in cycles.items():
        result = check_and_clean(client, parent, child, hr_range)
        print(result)

except Exception as e:
    print(f"Connection Error: {e}")
