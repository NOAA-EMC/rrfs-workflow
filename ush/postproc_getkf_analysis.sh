#!/bin/bash
###
### Utility for finishing a GETKF ensemble member's analysis after JEDI has
### written it directly into the background file (write-into-existing-files).
### JEDI aliases the analyzed A-grid wind to ua_anl/va_anl and leaves every
### other analyzed variable in place under its normal name; the D-grid u/v
### wind (never touched by JEDI) still needs to be updated to match. This
### script does that with rdas_ua2u.x's --in_anl mode:
###   1. Compute the A-grid wind increment as (ua_anl-ua, va_anl-va)
###   2. Convert it to a D-grid (u/v) increment
###   3. Add that increment to the background u/v already in the file
###   4. Remove ua_anl/va_anl (--remove_anl_winds), now that they are no
###      longer needed
### The net effect: anlfile goes from "background with an aliased analysis
### wind" to a complete, restart-ready analysis.
###

set -eux

gridfile=${1}
anlfile=${2}
EXECdir=${3}
APRUN_UA=${4}
pgmout=${5}

if [ ! -f "${anlfile}" ]; then
  echo "ERROR: analysis file not found: ${anlfile}"
  exit 1
fi
if [ ! -f "${gridfile}" ]; then
  echo "ERROR: grid spec file not found: ${gridfile}"
  exit 1
fi

pgm="rdas_ua2u.x"
ua2u_exec="${EXECdir}/bin/${pgm}"
cp "${ua2u_exec}" "./${pgm}"

${APRUN_UA} ./${pgm} ua_update_u \
  --in_grid="${gridfile}" \
  --in_anl="${anlfile}" \
  --remove_anl_winds \
  >>"${pgmout}" 2>errfile
mv errfile errfile_ua2u

if [ ! -s "${anlfile}" ]; then
  echo "ERROR: ${anlfile} missing or empty after rdas_ua2u.x"
  exit 6
fi
