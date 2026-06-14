#!/usr/bin/env bash
# shellcheck disable=SC2016
rundir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
mkdir -p "${rundir}/yaml" "${rundir}/tmp"
cd "${rundir}/tmp" || exit 1

ln -snf ../../parm/jedivar.yaml .
ln -snf ../../parm/jedivar.yaml jedivar.pass2.yaml
ln -snf ../../parm/getkf.yaml .
ln -snf ../../parm/bec_bump.yaml .
ln -snf ../../parm/bec_diffusion.yaml .
ln -snf ../../ush/yaml_finalize .
ln -snf ../../ush/yamltools4rrfs.py .
ln -snf ../../ush/hifiyaml4rrfs.py .
ln -snf ../../fix/jedi/convinfo.rrfs convinfo
ln -snf ../../fix/jedi/satinfo.rrfs satinfo

export ANALYSIS_DATE="2024-05-06T02:00:00Z"
export BEGIN_DATE="2024-05-06T00:00:00Z"
export HYB_WGT_STATIC=0.5
export HYB_WGT_ENS=0.5
export START_TYPE=cold  # cold, warm
export GETKF_TYPE=observer # observer, solver, post
export USE_CONV_SAT_INFO=false   # false, true
export STATIC_BEC_MODEL=GSIBEC  # GSIBEC, BUMPBEC
export EMPTY_OBS_SPACE_ACTION="skip output"  # skip output,  create output
export ANALYSIS_VARIABLES=0  # "", 0, 5, 12, or a list of variables
export DO_RADAR_REF=false  # false, true

#----------------------------------------------------------
#  jedivar.yaml
#----------------------------------------------------------
./yaml_finalize jedivar.yaml  "${rundir}"/yaml/jedivar_cold.yaml

export START_TYPE=warm  # cold, warm
./yaml_finalize jedivar.yaml  "${rundir}"/yaml/jedivar_warm.yaml

# change static BEC to BUMPBEC
export STATIC_BEC_MODEL=BUMPBEC
./yaml_finalize jedivar.yaml  "${rundir}"/yaml/jedivar_bumpbec.yaml

# change back to use the default GSIBEC 
export STATIC_BEC_MODEL=GSIBEC

# change to pure 3DVAR
export HYB_WGT_STATIC=1.0
export HYB_WGT_ENS=0.0
./yaml_finalize jedivar.yaml  "${rundir}"/yaml/3dvar.yaml

# change to pure 3DENVAR
export HYB_WGT_STATIC=0.0
export HYB_WGT_ENS=1.0
./yaml_finalize jedivar.yaml  "${rundir}"/yaml/3denvar.yaml

# change back to default hybrid setting
export HYB_WGT_STATIC=0.5
export HYB_WGT_ENS=0.5

# pass2 to do reflectivity DA only
export ANALYSIS_VARIABLES=12
./yaml_finalize jedivar.pass2.yaml  "${rundir}"/yaml/jedivar.pass2.yaml

# customize ANALYSIS_VARIABLES
export ANALYSIS_VARIABLES="water_vapor_mixing_ratio_wrt_moist_air, air_temperature"
./yaml_finalize jedivar.yaml  "${rundir}"/yaml/jedivar_ana_vars.yaml

# change back to default 5
export ANALYSIS_VARIABLES=5

#----------------------------------------------------------
#  getkf.yaml
#  compare the generate yamls with the original getkf.yaml
#----------------------------------------------------------
# test getkf solver
export GETKF_TYPE=solver
./yaml_finalize getkf.yaml  "${rundir}"/yaml/getkf_solver.yaml

# test getkf post
export GETKF_TYPE=post
./yaml_finalize getkf.yaml  "${rundir}"/yaml/getkf_post.yaml

# test getkf observer
export GETKF_TYPE=observer
./yaml_finalize getkf.yaml  "${rundir}"/yaml/getkf_observer.yaml

# customize ANALYSIS_VARIABLES
export ANALYSIS_VARIABLES=12
./yaml_finalize getkf.yaml  "${rundir}"/yaml/getkf_observer_12_vars.yaml

export ANALYSIS_VARIABLES="water_vapor_mixing_ratio_wrt_moist_air, air_temperature"
./yaml_finalize getkf.yaml  "${rundir}"/yaml/getkf_observer_ana_vars.yaml

#----------------------------------------------------------
#  use convinfo and satinfo to manage observers 
#----------------------------------------------------------
export USE_CONV_SAT_INFO=true
./yaml_finalize jedivar.yaml  "${rundir}"/yaml/jedivar_conv_sat_info.yaml
./yaml_finalize getkf.yaml  "${rundir}"/yaml/getkf_conv_sat_info.yaml
