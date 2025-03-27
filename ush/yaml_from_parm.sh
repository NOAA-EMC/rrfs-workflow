#!/usr/bin/env bash
# generate the JEDI yaml files using templates from the parm/ directory
#
if [[ "$1" == "jedivar" ]]; then
  sed -e "s/@analysisDate@/${analysisDate}/" -e "s/@beginDate@/${beginDate}/" \
      -e "s/@HYB_WGT_STATIC@/${HYB_WGT_STATIC}/" -e "s/@HYB_WGT_ENS@/${HYB_WGT_ENS}/" \
      ${PARMrrfs}/jedivar.yaml > jedivar.yaml
  if [[ "${HYB_WGT_ENS}" == "0" ]] || [[ "${HYB_WGT_ENS}" == "0.0" ]]; then # pure 3DVAR
    sed -i '88,113d' ./jedivar.yaml
  elif [[ "${HYB_WGT_STATIC}" == "0" ]] || [[ "${HYB_WGT_STATIC}" == "0.0" ]] ; then # pure 3DEnVar
    sed -i '46,87d' ./jedivar.yaml
  fi
  if [[ ${start_type} == "cold" ]]; then
      sed -i '7s/mpasin/ana/' jedivar.yaml
  fi
  template="jedivar.yaml"

else
  sed -e "s/@analysisDate@/${analysisDate}/" -e "s/@beginDate@/${beginDate}/" \
    ${PARMrrfs}/getkf_${TYPE}.yaml > getkf.yaml
  if [[ ${start_type} == "cold" ]]; then
      sed -i '13s/ens/ana/' getkf.yaml
  fi
  template="getkf.yaml"
fi

#
#  Generate the final YAML configuration file based on convinfo and available ioda files
#
${cpreq} ${EXPDIR}/config/convinfo .
${USHrrfs}/yaml_finalize ${template}
