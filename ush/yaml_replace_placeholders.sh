#!/usr/bin/env bash
# shellcheck disable=SC2154
# Expects 'PARMrrfs', 'start_type', 'analysisFile', 'analysisDate',
# 'beginDate', and 'analysisUse' to be set by the caller.
# The previous line disables SC2154 for the entire script.
#
# generate the JEDI yaml file using the jedivar.yaml from the parm/ directory
#
#cp -p "${PARMrrfs}"/jedivar.yaml .
cp -p "${EXPDIR}"/config/jedivar.yaml .

# Use ana.nc for cold start and determine whether to do DA or not.
analysisFile="mpasout.nc"
analysisUse="accept"
if [[ "${start_type}" == "cold" ]]; then
  analysisFile="ana.nc"
  # if flag is explicityly "false", switch to passivate
  if [[ "${COLDSTART_CYCS_DO_DA}" == "false" ]]; then
    analysisUse="passivate"
  fi
fi

sed -i \
    -e "s/@analysisFile@/${analysisFile}/" \
    -e "s/@analysisDate@/${analysisDate}/" \
    -e "s/@beginDate@/${beginDate}/" \
    -e "s/@analysisUse@/${analysisUse}/" \
    ./jedivar.yaml
