import ecflow
import os

# Updated connection details for WCOSS2
HOST = "ddecflow02"
PORT = 32035
# Your specific suite path
FAMILY_PATH = "/para/primary/00/rrfs/v1.0/00z/enkf/forecast"

def force_complete_if_finished():
    try:
        ci = ecflow.Client(HOST, PORT)
        ci.sync_local() # Pull latest status from server
        
        server_defs = ci.get_defs()
        if server_defs is None:
            print("Error: Could not retrieve definitions from server.")
            return

        # 1. Check member range 1 to 30
        all_finished = True
        missing_tasks = []
        
        for i in range(1, 31):
            # Formats number as 001, 002, ... 030
            task_name = f"jrrfs_enkf_save_restart_mem{i:03d}_f2"
            task_path = f"{FAMILY_PATH}/{task_name}"
            
            node = server_defs.find_abs_node(task_path)
            
            if node is None:
                print(f"Warning: Task not found: {task_path}")
                all_finished = False
                missing_tasks.append(task_name)
                continue
            
            # Check if the individual task is actually 'complete'
            if str(node.get_state()) != "complete":
                all_finished = False
                print(f"Member {i:03d} is still {node.get_state()}")

        # 2. If all 30 are done, force the parent "forecast" family to complete
        if all_finished:
            print(f"Success: All 30 members are complete. Forcing {FAMILY_PATH} to complete...")
            #ci.alter(FAMILY_PATH, "force", "complete")
            ci.force_state_recursive(FAMILY_PATH, ecflow.State.complete)
            print("Status updated in ecFlow.")
        else:
            print(f"Action: No change made. Some members are still running or aborted.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    force_complete_if_finished()
