#!/bin/bash
# shellcheck disable=all
# by Guoqing.Ge, May 2019
if (( $# < 1)); then
  echo "Usage: sc <jobid>"
  exit 1
fi

scontrol show -d job $1
