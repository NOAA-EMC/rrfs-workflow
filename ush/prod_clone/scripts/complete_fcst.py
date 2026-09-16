import ecflow
import os

# Server connection details
HOST = "ddecflow02"
PORT = 32035

# Mapping: Primary Folder -> List of Cycles to check within that folder
primary_to_cycles = {
    "00": ["02z", "04z"],
    "06": ["08z", "10z"],
    "12": ["14z", "16z"],
    "18": ["20z", "22z"]
}

def sync_enkf_forecasts():
    try:
        ci = ecflow.Client(HOST, PORT)
        ci.sync_local()
        server_defs = ci.get_defs()
        
        if server_defs is None:
            print("Error: Could not retrieve definitions.")
            return

        # Loop through each Primary folder
        for primary, cycles in primary_to_cycles.items():
            # Loop through each specific Cycle in that Primary folder
            for cyc in cycles:
                family_path = f"/para/primary/{primary}/rrfs/v1.0/{cyc}/enkf/forecast"
                
                print(f"--- Checking {cyc} (Primary {primary}) ---")

                all_members_finished = True
                
                # Check all 30 members for the _f1 task
                for i in range(1, 31):
                    task_name = f"jrrfs_enkf_save_restart_mem{i:03d}_f1"
                    task_path = f"{family_path}/{task_name}"
                    
                    node = server_defs.find_abs_node(task_path)
                    
                    if node is None:
                        all_members_finished = False
                        continue

                    if str(node.get_state()) != "complete":
                        all_members_finished = False
                        # Optional: break early if one is found incomplete to save time
                        break 

                # If all 30 members are done, force the forecast family to complete
                if all_members_finished:
                    parent_node = server_defs.find_abs_node(family_path)
                    if parent_node and str(parent_node.get_state()) != "complete":
                        print(f"  > All 30 members (_f1) COMPLETE. Forcing {family_path}...")
                        ci.force_state_recursive(family_path, ecflow.State.complete)
                    else:
                        print(f"  > Status: Already complete or path not found.")
                else:
                    print(f"  > Status: Some members still pending.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    sync_enkf_forecasts()
