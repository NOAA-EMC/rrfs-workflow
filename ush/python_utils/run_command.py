#!/usr/bin/env python3

import subprocess
import sys

def run_command(cmd):
    """
    Run system command synchronously in the foreground.
    
    Args:
        cmd: command string to execute
    Returns:
        Tuple of (exit code, std_out, std_err)
    """
    # 1. 'set -x' behavior: print the command to stderr so it's visible in logs
    print(f"+ {cmd}", file=sys.stderr, flush=True)

    # 2. Use .run() instead of .Popen()
    # This is a blocking call (foreground). Python waits here until cmd finishes.
    # We set capture_output=True to get the strings back, 
    # but note: this buffers output until the end.
    result = subprocess.run(
        cmd,
        shell=True,
        text=True,
        capture_output=True  # Automatically handles PIPE for stdout and stderr
    )

    # 3. Immediately print the captured output to the job log 
    # so it's not "lost" if the script continues.
    if result.stdout:
        print(result.stdout, end='', flush=True)
    if result.stderr:
        print(result.stderr, file=sys.stderr, end='', flush=True)

    return (result.returncode, result.stdout.rstrip("\n"), result.stderr.rstrip("\n"))
