#!/usr/bin/env bash
# generate the JEDI yaml file using the jedivar.yaml from the parm/ directory
#
sed -e "s/@analysisDate@/${analysisDate}/" -e "s/@beginDate@/${beginDate}/" \
    -e "s/@HYB_WGT_STATIC@/${HYB_WGT_STATIC}/" -e "s/@HYB_WGT_ENS@/${HYB_WGT_ENS}/" \
    ${PARMrrfs}/jedivar.yaml > jedivar.yaml
if [[ "${HYB_WGT_ENS}" == "0" ]] || [[ "${HYB_WGT_ENS}" == "0.0" ]]; then # pure 3DVAR
  sed -i '88,113d' ./jedivar.yaml
elif [[ "${HYB_WGT_STATIC}" == "0" ]] || [[ "${HYB_WGT_STATIC}" == "0.0" ]] ; then # pure 3DEnVar
  sed -i '46,87d' ./jedivar.yaml
fi
${USHrrfs}/yaml_remove_obs q133,uv233,t120,q120,ps120,uv220
# comment out the above line and uncomment the follow 3 lines to assimilate radiosonde observations
#if [[ ! -s "ioda_adpupa.nc" ]]; then
#  ${USHrrfs}/yaml_remove_obs t120,q120,ps120,uv220
#fi
