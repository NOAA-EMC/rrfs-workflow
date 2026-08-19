#!/bin/bash
# Script obtains big cycle (00, 06, 12, 18) family definitions for RRFS
# and compiles these into a single definition file.

# get existing definitions for each cycle from ecflow
#
# Usage:
#   ./make_new_def_file.sh decflow01
#
if [ -z "$1" ]; then
  echo "Usage: $0 <ECF_HOST>"
  exit 1
fi

echo "Getting definitions from ecflow server..."
for cyc in {00,06,12,18}; do
  ecflow_client --host=$1 --port=14142 --get=/para/primary/$cyc/rrfs/v1.0 > ${cyc}_rrfs
done

newdefn="rrfs_nco_para.def"

echo "Building 00 cycle info..."
cat extern.list > $newdefn
cat <<EOF >> $newdefn


suite para
  family primary
    family 00
      family rrfs
        edit PACKAGEHOME '/lfs/h1/ops/%ENVIR%/packages/rrfs.%rrfs_ver%'
        edit PROJ 'RRFS'
        edit ECF_FILES '%PACKAGEHOME%/ecf/scripts'
        edit ECF_TRIES '3'
        limit rrfs_submission 50
EOF
sed "s/^/      /g" 00_rrfs >> $newdefn

echo "Building 06 cycle info..."
cat << EOF >> $newdefn
      endfamily # rrfs
    endfamily # 00
    family 06 
      family rrfs
        edit PACKAGEHOME '/lfs/h1/ops/%ENVIR%/packages/rrfs.%rrfs_ver%'
        edit PROJ 'RRFS'
        edit ECF_FILES '%PACKAGEHOME%/ecf/scripts'
        edit ECF_TRIES '3'
        limit rrfs_submission 50
EOF
sed "s/^/      /g" 06_rrfs >> $newdefn

echo "Building 12 cycle info..."
cat << EOF >> $newdefn
      endfamily # rrfs
    endfamily # 06
    family 12 
      family rrfs
        edit PACKAGEHOME '/lfs/h1/ops/%ENVIR%/packages/rrfs.%rrfs_ver%'
        edit PROJ 'RRFS'
        edit ECF_FILES '%PACKAGEHOME%/ecf/scripts'
        edit ECF_TRIES '3'
        limit rrfs_submission 50
EOF
sed "s/^/      /g" 12_rrfs >> $newdefn

echo "Building 18 cycle info..."
cat << EOF >> $newdefn
      endfamily # rrfs
    endfamily # 12
    family 18 
      family rrfs
        edit PACKAGEHOME '/lfs/h1/ops/%ENVIR%/packages/rrfs.%rrfs_ver%'
        edit PROJ 'RRFS'
        edit ECF_FILES '%PACKAGEHOME%/ecf/scripts'
        edit ECF_TRIES '3'
        limit rrfs_submission 50
EOF
sed "s/^/      /g" 18_rrfs >> $newdefn


cat << EOF >> $newdefn
      endfamily # rrfs
    endfamily # 18
  endfamily #primary
endsuite
EOF

echo "Adding defstatus completes..."
sed -i '/family v1\.0/a\          defstatus complete' $newdefn

echo "Cleaning up..."
for cyc in {00,06,12,18}; do
  rm -rf ${cyc}_rrfs
done
echo "Done."
