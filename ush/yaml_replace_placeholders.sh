#!/usr/bin/env bash
# generate the JEDI yaml file using the jedivar.yaml from the parm/ directory
#
cp -p ${PARMrrfs}/jedivar.yaml .

# Use ana.nc for cold start.
if [[ "${start_type}" == "cold" ]]; then
  analysisFile="ana.nc"
else
  analysisFile="mpasin.nc"
fi


sed -i \
    -e "s/@analysisFile@/${analysisFile}/" \
    -e "s/@analysisDate@/${analysisDate}/" \
    -e "s/@beginDate@/${beginDate}/" \
    ./jedivar.yaml
