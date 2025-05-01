#!/bin/bash
#--------------------------------------------------------------------------------------
# run_bufr2ioda.sh
# This driver script will:
# - generate config files from templates for each BUFR file
# - use bufr2ioda python scripts or executable and produce output IODA files
# usage:
#       run_bufr2ioda.sh YYYYMMDDHH $DMPDIR /path/to/templates $COM_OBS
#
#--------------------------------------------------------------------------------------
if [[ $# -ne 6 ]] ; then
    echo "usage:"
    echo "      $0 YYYYMMDDHH gdas|gfs /path/to/files.bufr_d/ /path/to/templates /path/to/output.ioda/"
    exit 1
fi

# some of these need exported to be picked up by the python script below
# input parameters
CDATE=${CDATE:-$1}
export DUMP=${RUN:-$2}
export DMPDIR=${DMPDIR:-$3}
config_template_dir=${config_template_dir:-$4}
export COM_OBS=${COM_OBS:-$5}
export DIR_ROOT=${DIR_ROOT:-$6}

# derived parameters
export PDY=${CDATE:0:8}
export cyc=${CDATE:8:2}

# get gdasapp root directory
#readonly DIR_ROOT=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/../../.." && pwd -P)
USH_IODA=${DIR_ROOT}/rrfs-test/IODA/python
BUFRJSONGEN=${USH_IODA}/gen_bufr2ioda_json.py

# create output directory if it doesn't exist
if ! mkdir -p "${COM_OBS}"; then
    echo "cannot make ${COM_OBS}"
    exit 1
fi

# add to pythonpath the necessary libraries
PYIODALIB=$(echo "${DIR_ROOT}"/build/lib/python3.*)
export PYTHONPATH=${PYIODALIB}:${PYTHONPATH}

#----- python and json -----
# first specify what observation types will be processed by a script
#BUFR_py="msonet_prepbufr"
BUFR_py="gsrcsr"

for obtype in ${BUFR_py}; do
  # this loop assumes that there is a python script and template with the same name
  echo "Processing ${obtype}..."

  # first generate a JSON from the template
  ${BUFRJSONGEN} -t "${config_template_dir}/bufr2ioda_${obtype}.json" -o "${COM_OBS}/${obtype}_${PDY}${cyc}.json"

  # now use the converter script for the ob type
  python "${USH_IODA}/bufr2ioda_${obtype}.py"  -c "${COM_OBS}/${obtype}_${PDY}${cyc}.json"

  # check if converter was successful
  # shellcheck disable=SC2181
  if [ $? == 0 ]; then
    # remove JSON file
    rm -rf "${COM_OBS}/${obtype}_${PDY}${cyc}.json"
  else
    # warn and keep the JSON file
    echo "Problem running converter script for ${obtype}"
  fi
done
