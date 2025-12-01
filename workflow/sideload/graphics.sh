#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034,SC2154,SC2153
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
date
#
export task_id=${task_id:-'graphics'}
mkdir -p "${DATA}/nclprd"

fhr=${FHR:-0}  # use this line or the next line
#fhr=$((10#${FHR:-0})) # remove leading zeros
area=${AERA:-full}
grafdir=/lfs5/BMC/nrtrr/FIX_RRFS2/exec/pygraf
YYJJJHH=$(date +%y%j%H -d "${CDATE:0:8} ${CDAE:8:2}")

cd "${grafdir}" || exit 1
set +x # supress messy module load information
source pre.sh
module use /lfs5/BMC/nrtrr/FIX_RRFS2/modulefiles
module load prod_util/2.1.1
set -x
# can pygraf handle fhr in 3 digits, e.g. 000, 100?
python create_graphics.py \
  maps \
  --all_leads \
  -d "${COMINrrfs}/${RUN}.${PDY}/${cyc}/upp" \
  -f "${fhr}" \
  --file_type prs \
  --file_tmpl "${YYJJJHH}0000{FCST_TIME:02d}" \
  --images "${grafdir}/image_lists/hrrr_subset.yml hourly" \
  -m "${NET}" \
  -n "${SLURM_CPUS_ON_NODE:-12}" \
  -o "${DATA}" \
  -s "${CDATE}" \
  --tiles "${AREA}" \
  -z "${DATA}/nclprd"
export err=$?; err_chk
# link results to ${COMOUT}
ln -snf "${DATA}" "${COMOUT}"

exit 0
