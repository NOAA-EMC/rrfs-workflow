#!/bin/bash
#
set -eux
#####################################################################################
#
# This utility is to replace configuration template with production settings before running ecflow workflow
# Requirement:
#       Export HOMErrfs, WGF and DATA from J-Job
#       Loading prod_util module
# Usage:
#       sh ${HOMErrfs}/ush/rrfs_nco_config.sh
#
#####################################################################################

#####################################################################################
# No need to modify any line below
#####################################################################################

# Target files to modify
export NET="${NET:-rrfs}"
File_to_modify_source="var_defns.sh"
export GLOBAL_VAR_DEFNS_FP=${File_to_modify_source}
case "${WGF}" in
  "det")
    export RUN="rrfs"
    ;;
  "enkf")
    export RUN="enkfrrfs"
    ;;
  "ensf")
    export RUN="refs"
    ;;
  "firewx")
    export RUN="firewx"
    ;;
esac

# Source run.ver
source "$HOMErrfs/versions/run.ver" || { echo "Failed to source run.ver"; exit 1; }

# Replace special characters
HOMErrfs=$(printf '%q' "$HOMErrfs")

# Dynamically generate target files
cd "$DATA" || { echo "Failed to change directory to $DATA"; exit 1; }

for file_in in ${File_to_modify_source}; do
  cpreq "$HOMErrfs/parm/config/${WGF}/${file_in}.template" .
  file_src="${file_in}.template"
  file_tmp=$(mktemp -p .) || { echo "Failed to create temporary file"; exit 1; }
  cp "$file_src" "$file_tmp" || { echo "Failed to copy $file_src to $file_tmp"; exit 1; }
  sed -i -e "s|@HOMErrfs@|${HOMErrfs}|g"             "$file_tmp"
  mv "$file_tmp" "$file_in" || { echo "Failed to move $file_tmp to $file_in"; exit 1; }
  chmod u+x $file_in
done
