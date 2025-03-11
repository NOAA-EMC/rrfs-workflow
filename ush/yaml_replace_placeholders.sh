#!/usr/bin/env bash
# generate the JEDI yaml file using the jedivar.yaml from the parm/ directory
#
cp -p ${PARMrrfs}/jedivar.yaml .

sed -i \
    -e "s/@analysisDate@/${analysisDate}/" \
    -e "s/@beginDate@/${beginDate}/" \
    ./jedivar.yaml
