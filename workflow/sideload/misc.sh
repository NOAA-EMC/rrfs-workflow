#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
date
echo "This is a misc task!"
exit 0
