#!/usr/bin/env bash
# Sample job script with intentional RRFS norm violations for testing.
# --- RRFS001: dot-source ---
. /etc/profile

# --- RRFS002: single bracket ---
if [ -d /tmp ]; then
  echo "exists"
fi

# --- RRFS003: single = in [[ ]] ---
if [[ ${FOO} = bar ]]; then
  echo "match"
fi

# --- RRFS004: -f instead of -s ---
if [[ -f /tmp/input.dat ]]; then
  echo "file found"
fi
