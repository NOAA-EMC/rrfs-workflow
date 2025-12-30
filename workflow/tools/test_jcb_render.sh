#!/bin/bash
# offline JCB testing for different workflow scenarios
# shellcheck disable=all
# Check if the script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Usage: source ${0}"
  exit 1
fi

### scripts continues here...
tooldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
JCBPATH=${tooldir}/../../sorc/RDASApp/sorc/jcb/src
export PYTHONPATH="${JCBPATH}:${PYTHONPATH}"

export PARMrrfs=${tooldir}/../../parm
export analysisDate="2024-05-06T02:00:00Z"
export beginDate="2024-05-06T00:00:00Z"
export HYB_WGT_STATIC="0.5"
export HYB_WGT_ENS="0.5"

export GSIBEC_X=999
export GSIBEC_Y=999
export GSIBEC_NLAT=999
export GSIBEC_NLON=999
export GSIBEC_LAT_START=999
export GSIBEC_LAT_END=999
export GSIBEC_LON_START=999
export GSIBEC_LON_END=999
export GSIBEC_NORTH_POLE_LAT=999
export GSIBEC_NORTH_POLE_LON=999
export EMPTY_OBS_SPACE_ACTION="skip output"

# if false, assemble all observers
export USE_CONV_SAT_INFO=true

# jedivar.yaml, getkf.yaml
#export DO_RADAR_REF=true

# jedivar.yaml: test pure 3dvar or pure 3denvar
#export HYB_WGT_STATIC="0"
#export HYB_WGT_ENS="1"  

# jedivar.yaml, init.nc instead of mpasout.nc
#export start_type="cold"  # warm

# getkf.yaml, different "driver"
#export GETKF_TYPE="solver"  # observer,  post

echo "ush/jcb_render.py <jedivar.yaml|getkf.yaml>"
