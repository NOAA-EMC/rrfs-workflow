import ecflow
import os

# Server connection details
HOST = "ddecflow02"
PORT = 32035

# Configuration
PRIMARY_START_HOURS = [0, 6, 12, 18]
EXCLUDED_CYCLES = ["00z", "06z", "12z", "18z"]

def sync_rrfs_suites():
    try:
        # Initialize ecFlow Client
        ci = ecflow.Client(HOST, PORT)
        ci.sync_local()
        server_defs = ci.get_defs()
        
        if server_defs is None:
            print("Error: Could not retrieve definitions from server.")
            return

        # Outer Loop: Primary Folders (00, 06, 12, 18)
        for p in PRIMARY_START_HOURS:
            primary_num = f"{p:02d}"
            
            # Inner Loop: Cycles (P to P+5)
            # Example: If p=0, c goes 0, 1, 2, 3, 4, 5
            for c in range(p, p + 6):
                cycle_name = f"{c:02d}z"
                
                # 1. Skip the big 6-hourly cycles as requested
                if cycle_name in EXCLUDED_CYCLES:
                    continue
                
                # 2. Build the paths
                base_path = f"/para/primary/{primary_num}/rrfs/v1.0/{cycle_name}/det"
                prdgen_task = f"{base_path}/prdgen/jrrfs_det_prdgen_f006_00_00"
                prdgen_fam  = f"{base_path}/prdgen"
                post_fam    = f"{base_path}/post"

                # 3. Check the f006 task status
                node = server_defs.find_abs_node(prdgen_task)
                
                if node is None:
                    # Skip if the cycle isn't loaded in the server
                    continue

                if str(node.get_state()) == "complete":
                    print(f"[{cycle_name}] f006 is COMPLETE. Syncing families...")
                    
                    # 4. Recursive force for both families
                    for fam_path in [prdgen_fam, post_fam]:
                        fam_node = server_defs.find_abs_node(fam_path)
                        # Only force if not already complete
                        if fam_node and str(fam_node.get_state()) != "complete":
                            ci.force_state_recursive(fam_path, ecflow.State.complete)
                            print(f"  > {fam_path} forced to complete.")
                else:
                    # Optional: print status of lagging cycles
                    print(f"[{cycle_name}] f006 is {node.get_state()}. Waiting...")

    except Exception as e:
        print(f"An execution error occurred: {e}")

if __name__ == "__main__":
    sync_rrfs_suites()
