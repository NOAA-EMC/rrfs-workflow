#!/bin/bash

# prior to running this script
# generate ecf files using below script:
# $PACKAGEHOME/ecf/setup_ecf_links.sh

if [ $# -ne 1 ]; then 
    echo "Provide one argument."
    echo ""
    echo "usage:"
    echo "       $0 DIR_TO_ECF_SCRIPTS"
    echo "example:"
    echo "       ./make_nco_links.sh /lfs/h1/ops/para/packages/rrfs.v1.0.0/ecf/scripts"
else
    cd $1
    mkdir det
    ln -sf ../init/det/ ./det/init
    ln -sf ../ics/det/ ./det/ics
    ln -sf ../prep/det/ ./det/prep
    ln -sf ../analysis/det/ ./det/analysis
    ln -sf ../forecast/det/ ./det/forecast
    ln -sf ../post/det/ ./det/post
    ln -sf ../product/det/ ./det/prdgen
    mkdir enkf
    ln -sf ../ics/enkf/ ./enkf/ics
    ln -sf ../init/enkf/ ./enkf/init
    ln -sf ../prep/enkf/ ./enkf/prep
    ln -sf ../analysis/enkf ./enkf/analysis
    ln -sf ../forecast/enkf ./enkf/forecast
    mkdir ensf
    ln -sf ../ics/ensf ./ensf/ics
    ln -sf ../prep/ensf ./ensf/prep
    ln -sf ../analysis/ensf ./ensf/analysis
    ln -sf ../forecast/ensf ./ensf/forecast
    ln -sf ../post/ensf ./ensf/post
    ln -sf ../product/ensf ./ensf/prdgen
    mkdir firewx
    ln -sf ../ics/firewx ./firewx/ics
    ln -sf ../forecast/firewx ./firewx/forecast
    ln -sf ../post/firewx ./firewx/post
    ln -sf ../product/firewx ./firewx/prdgen
fi
