#!/bin/bash
# Regression Test for NCO Implementation Standard Python Linter

set -x

# Control whether to keep the mock data
KEEPDATA="YES"
# Config for testing a mocked version of the target file
MOCK="YES"

# Determine script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINTER_SCRIPT="${SCRIPT_DIR}/linter_nco_implementation_standard.py"
CANNED_DIR="${SCRIPT_DIR}/canned_data"

# Resolve the repository root (3 levels up from .github/workflows/tools/)
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
USH_DIR="${REPO_ROOT}/ush"

# Create the canned_data directory
mkdir -p "$CANNED_DIR"
#### TARGET_FILE="${USH_DIR}/blending_fv3.py"
TARGET_FILE="${CANNED_DIR}/fixed_blending_fv3.py"

if [ "${MOCK}" == "YES" ]; then
  TARGET_FILE="${CANNED_DIR}/mock_blending_fv3.py"
  # Create a mock target file
  cat << 'EOF' > "$TARGET_FILE"
#!/usr/bin/env python3
import sys

def err_check(err):
    if err > 0:
        print(f"An error ocurred in {sys.argv[0]}")
        sys.exit(err)

print("Blending code is executing.")
sys.exit(0)
EOF
fi

# Ensure the target file exists
if [[ ! -f "$TARGET_FILE" ]]; then
    echo "Target file does not exist: $TARGET_FILE"
    exit 1
fi

# Run the linter as normal, passing the target file
python "$LINTER_SCRIPT" "$TARGET_FILE" > linter_out.log 2>&1
linter_status=$?

cat linter_out.log

# Evaluate results standardly based on linter exit status
if [[ $linter_status -eq 0 ]]; then
    echo "SUCCESS: Linter passed with zero violations."
    final_exit=0
else
    echo "VIOLATION/FAILURE: Linter detected violations or execution error."
    final_exit=$linter_status
fi

# Conditional cleanup of the file
if [[ "${KEEPDATA}" == "NO" ]]; then
    echo "KEEPDATA is NO. Removing target file."
    rm -f "$TARGET_FILE"
    # Cleanup log file
    rm -f linter_out.log
else
    echo "KEEPDATA is YES. Retaining target file."
fi

exit $final_exit