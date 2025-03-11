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
if [[ ! -s "data/obs/ioda_adpupa.nc" ]]; then
  OBS_TYPE_REMOVE="${OBS_TYPE_REMOVE},t120,q120,ps120,uv220"
  OBS_TYPE_REMOVE=${OBS_TYPE_REMOVE#,}  # remove the leading ,
fi
#
if [[ -z "${OBS_TYPE_USE}" ]]; then
  if [[ ! -z "${OBS_TYPE_REMOVE}" ]]; then
    ${USHrrfs}/yaml_remove_obs ${template} ${OBS_TYPE_REMOVE}
  fi
else
  # remove OBS_TYPE_REMOVE from OBS_TYPE_USE
  OBS_TYPE_USE=$(echo "${OBS_TYPE_USE}" | tr ',' '\n' | grep -vFxf <(echo "${OBS_TYPE_REMOVE}" | tr ',' '\n') | tr '\n' ',')
  OBS_TYPE_USE=${OBS_TYPE_USE#,}  # remove the leading ,
  OBS_TYPE_USE=${OBS_TYPE_USE%,}  # remove trailing ,
  #
  ${USHrrfs}/yaml_use_obs ${template} ${OBS_TYPE_USE}
fi
