
l_both_fv3sar_gfs_ens=.false. #if true, ensemble size is increased with GDAS ensemble (MixEn)
assign_vdl_nml=.false.        #if true, vdl_scale and vloc_varlist are used to set VDL

if [ ${l_both_fv3sar_gfs_ens} = ".true." ]; then
  weight_ens_gfs=0.5
  weight_ens_fv3sar=0.5
fi

if [[ ${ngvarloc} == "1" ]] && [[ ${nsclgrp} == "2" ]]; then
  readin_localization=.false.
  ens_h="328.632,82.1580,82.1580"
  ens_v="-0.30125,-0.30125,0.0"
  ens_h_radardbz="4.10790"
  ens_v_radardbz="-0.30125"
elif [[ ${ngvarloc} == "2" ]] && [[ ${nsclgrp} == "1" ]]; then
  DO_ENVAR_RADAR_REF_ONCE="TRUE"
  readin_localization=.false.
  ens_h="82.1580,4.10790"
  ens_v="-0.30125,-0.30125"
  if [ ${assign_vdl_nml} = ".true." ]; then
    vdl_scale="2,2"
  else
    r_ensloccov4var=0.05
  fi
elif [[ ${ngvarloc} == "2" ]] && [[ ${nsclgrp} == "2" ]]; then
  DO_ENVAR_RADAR_REF_ONCE="TRUE"
  readin_localization=.false.
  if [ ${assign_vdl_nml} = ".true." ]; then
    ens_h="82.1580,16.4316,8.21580,4.10790,2.73860"
    ens_v="-0.30125,-0.30125,-0.30125,-0.30125,0.0"
    vdl_scale="2,2,2,2"
  else
    ens_h="328.632,82.1580,4.10790,4.10790,82.1580"
    ens_v="3,3,-0.30125,-0.30125,0.0"
    r_ensloccov4var=0.05
  fi
fi
