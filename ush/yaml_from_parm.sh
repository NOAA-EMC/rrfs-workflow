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
  template="jedivar.yaml"

else
  sed -e "s/@analysisDate@/${analysisDate}/" -e "s/@beginDate@/${beginDate}/" \
    ${PARMrrfs}/getkf_${TYPE}.yaml > getkf.yaml
  template="getkf.yaml"
fi
#
# figure out the final observers
#
if [[ ! -s "ioda_adpupa.nc" ]]; then
  OBSERVER_REMOVE="${OBSERVER_REMOVE},t120,q120,ps120,uv220"
  OBSERVER_REMOVE=${OBSERVER_REMOVE#,}  # remove the leading ,
fi
#
if [[ -z "${OBSERVER_USE}" ]]; then
  if [[ ! -z "${OBSERVER_REMOVE}" ]]; then
    ${USHrrfs}/yaml_remove_obs ${template} ${OBSERVER_REMOVE}
  fi
else
  # remove OBSERVER_REMOVE from OBSERVER_USE
  OBSERVER_USE=$(echo "${OBSERVER_USE}" | tr ',' '\n' | grep -vFxf <(echo "${OBSERVER_REMOVE}" | tr ',' '\n') | tr '\n' ',')
  OBSERVER_USE=${OBSERVER_USE#,}  # remove the leading ,
  OBSERVER_USE=${OBSERVER_USE%,}  # remove trailing ,
  #
  ${USHrrfs}/yaml_use_obs ${template} ${OBSERVER_USE}
fi
