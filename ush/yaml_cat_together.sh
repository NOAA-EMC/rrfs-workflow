#!/usr/bin/env bash
# generate the JEDI yaml file using the jedivar.yaml from the parm/ directory
#
cp -p ${PARMrrfs}/jedivar.yaml .

if [[ "${HYB_WGT_ENS}" == "0" ]] || [[ "${HYB_WGT_ENS}" == "0.0" ]]; then
    # deletes all lines from "covariance model: ensemble" to "weight:".
    sed -i '/covariance model: ensemble/,/weight:/d' jedivar.yaml
    # deletes the lines "- covariance:" is directly followed by "value: "@HYB_WGT_ENS@""
    sed -i '/- covariance:/ {N; /value: "@HYB_WGT_ENS@"/{d;}}' jedivar.yaml
elif [[ "${HYB_WGT_STATIC}" == "0" ]] || [[ "${HYB_WGT_STATIC}" == "0.0" ]]; then
    # deletes all lines from "covariance model: SABER" to "weight:".
    sed -i '/covariance model: SABER/,/weight:/d' jedivar.yaml
    # deletes the lines "- covariance:" is directly followed by "value: "@HYB_WGT_STATIC@""
    sed -i '/- covariance:/ {N; /value: "@HYB_WGT_STATIC@"/{d;}}' jedivar.yaml
fi

sed -i \
    -e "s/@analysisDate@/${analysisDate}/" \
    -e "s/@beginDate@/${beginDate}/" \
    -e "s/@HYB_WGT_STATIC@/${HYB_WGT_STATIC}/" \
    -e "s/@HYB_WGT_ENS@/${HYB_WGT_ENS}/" \
    -e "s/@length@/${length}/" \
    -e "s/@DISTRIBUTION@/$distribution/" \
    ./jedivar.yaml
