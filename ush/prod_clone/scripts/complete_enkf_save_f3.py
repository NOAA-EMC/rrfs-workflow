import ecflow
import os

# Connection details for WCOSS2
HOST = "ddecflow02"
PORT = 32035

# List of major primary cycles to check
MAJOR_CYCLES = ["00", "06", "12", "18"]

def force_complete_major_cycles():
    try:
        ci = ecflow.Client(HOST, PORT)
        ci.sync_local() # Pull latest status from server

        server_defs = ci.get_defs()
        if server_defs is None:
            print("Error: Could not retrieve definitions from server.")
            return

        for cyc in MAJOR_CYCLES:
            # Dynamically build path: e.g., /para/primary/00/rrfs/v1.0/00z/enkf/forecast
            family_path = f"/para/primary/{cyc}/rrfs/v1.0/{cyc}z/enkf/forecast"
            
            print(f"\n--- Checking EnKF Members for {cyc}z ---")

            all_finished = True
            missing_count = 0

            # 1. Check member range 1 to 30
            for i in range(1, 31):
                task_name = f"jrrfs_enkf_save_restart_mem{i:03d}_f2"
                task_path = f"{family_path}/{task_name}"

                node = server_defs.find_abs_node(task_path)

                if node is None:
                    all_finished = False
                    missing_count += 1
                    continue

                if str(node.get_state()) != "complete":
                    all_finished = False
                    missing_count += 1
                    # Optional: Print lagging members for debugging
                    if missing_count <= 3:
                        print(f"  > Member {i:03d} is {node.get_state()}")

            # 2. If all 30 are done, force the parent family to complete
            if all_finished:
                parent_node = server_defs.find_abs_node(family_path)
                
                # Check if it actually needs forcing (not already green)
                if parent_node and str(parent_node.get_state()) != "complete":
                    print(f"Success: All 30 members (_f2) complete. Forcing {family_path}...")
                    ci.force_state_recursive(family_path, ecflow.State.complete)
                else:
                    print(f"Status: {cyc}z is already complete or not found.")
            else:
                print(f"Action: {cyc}z has {missing_count} member(s) incomplete. No change.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    force_complete_major_cycles()
