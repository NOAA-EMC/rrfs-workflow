#!/bin/bash
#
# Put a staged EnKF ensemble where the deterministic hybrid analysis looks for it, so a retro can
# run 3DVar on its own without the EnKF side of the suite (RUN_ENKF=FALSE).
#
# Usage: ush/retro/link_staged_enkf.sh [--check]
#   --check  report what is there and link nothing
#
# exrrfs_analysis_gsi.sh reads the ensemble from this run's own COM tree, at
#   <COMrrfs>/enkfrrfs.<PDY>/<HH>/m<NNN>/forecast/RESTART/<valid>.fv_core.res.tile1.nc
# while the ensembles staged for the Rocoto retros (RRFSE_NWGES in their ush/config.sh) are laid
# out as
#   <RRFSE_NWGES>/<PDY><HH>/mem<NNNN>/fcst_fv3lam/RESTART/<valid>.fv_core.res.tile1.nc
# with the same file names underneath. One link per member and cycle is therefore enough, and no
# job has to be told about it. Nothing in the suite writes enkfrrfs directories when the EnKF is
# off, so the links are the only thing in them.
#
# Note how the analysis treats a gap: if it cannot find all NUM_ENS_MEMBERS members for any of the
# three cycles before the current one, it falls back to the GDAS ensemble and says so in its log
# rather than failing. A missing day would quietly change the DA instead of stopping the retro, so
# this script counts what it links and refuses to leave a cycle short.
#
set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
check_only=NO
case ${1:-} in
  --check) check_only=YES ;;
  -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
esac

# shellcheck source=/dev/null
. "${repo}/ecf/defs/retro/load_config.sh"
: "${RRFSE_NWGES:?retro/config.sh must set RRFSE_NWGES, the staged ensemble to link}"
[ -d "${RRFSE_NWGES}" ] || { echo "FATAL: no such directory: ${RRFSE_NWGES}" >&2; exit 1; }
members=${NUM_ENS_MEMBERS:-30}

# envir-p1.h builds this from DEV_PTMP; see its COMROOT line. The suite directory is "para"
# whatever the suite is called, because that is what envir-p1.h writes.
com=${DEV_PTMP}/${USER}/ecflow_rrfs/para/com/rrfs/${RRFS_VER:-v1.0}

# The analysis at the first cycle of the retro looks back up to three hours, so link the end of
# the day before as well where the stage has it. It is not required: a first cycle that cannot
# find an ensemble falls back to GDAS, which is what the first day of a retro does anyway.
start=$(date -u -d "${RETRO_START} 00:00:00 UTC -1 day" +%Y%m%d)
echo "staged ensemble: ${RRFSE_NWGES}"
echo "linked into:     ${com}"
echo "period:          ${start} to ${RETRO_END}, ${members} members"

linked=0 missing=0 missing_before=0 short_cycles=()
day=${start}
while [ "${day}" -le "${RETRO_END}" ]; do
  for hh in $(seq -w 0 23); do
    # The restart a cycle's forecast leaves is valid at the next hour, which is how it is named.
    # UTC before the offset, or date reads the "+1" as a time zone and the hour never advances.
    valid=$(date -u -d "${day} ${hh}:00:00 UTC +1 hour" +%Y%m%d.%H0000)
    found=0
    for m in $(seq 1 "${members}"); do
      src=$(printf '%s/%s%s/mem%04d/fcst_fv3lam' "${RRFSE_NWGES}" "${day}" "${hh}" "${m}")
      if [ ! -r "${src}/RESTART/${valid}.fv_core.res.tile1.nc" ]; then
        # the day before RETRO_START is a bonus, so count its gaps apart from the retro's own
        if [ "${day}" -lt "${RETRO_START}" ]; then
          missing_before=$((missing_before + 1))
        else
          missing=$((missing + 1))
        fi
        continue
      fi
      found=$((found + 1))
      [ "${check_only}" = YES ] && continue
      dst=$(printf '%s/enkfrrfs.%s/%s/m%03d' "${com}" "${day}" "${hh}" "${m}")
      mkdir -p "${dst}"
      ln -snf "${src}" "${dst}/forecast"
      linked=$((linked + 1))
    done
    if [ "${found}" -ne "${members}" ] && [ "${day}" -ge "${RETRO_START}" ]; then
      short_cycles+=("${day}${hh} (${found})")
    fi
  done
  day=$(date -u -d "${day} +1 day" +%Y%m%d)
done

if [ "${check_only}" = YES ]; then
  echo "check only: ${missing} member cycle(s) missing in ${RETRO_START}-${RETRO_END}"
else
  echo "${linked} member cycle(s) linked, ${missing} missing in ${RETRO_START}-${RETRO_END}"
fi
if [ "${missing_before}" -gt 0 ]; then
  echo "${missing_before} more missing on ${start}, the day before, which the retro can do without"
fi
if [ ${#short_cycles[@]} -gt 0 ]; then
  echo "FATAL: these cycles have fewer than ${members} members, which would send the analysis" >&2
  echo "       back to the GDAS ensemble without failing:" >&2
  printf '         %s\n' "${short_cycles[@]}" >&2
  exit 1
fi
