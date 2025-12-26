
l_both_fv3sar_gfs_ens=.false. #if true, ensemble size is increased with GDAS ensemble (MixEn)
assign_vdl_nml=.false.        #if true, vdl_scale and vloc_varlist are used to set VDL
nsclgrp=1                     #number of scales for scale-dependent localization (SDL)
ngvarloc=1                    #number of scales for variable-dependent localization (VDL)

readin_localization=.false.

##############################
# Conventional variables
# ens_h = "110": equivalent to 401 km GC cutoff
# ens_v = "3":   equivalent to 11 levs GC cutoff
##############################

ens_h="110"
ens_v="3"

#######################
# Radar variables
# ens_h = "4.10790":  equivalent to 15 km GC cutoff
# ens_h = "17.80098": equivalent to 65 km GC cutoff
# ens_v = "-0.30125": equivalent to 1.1log(p) GC cutoff
#######################

#ens_h_radardbz="4.10790" # 3-km domain
ens_h_radardbz="17.80098" # 13-km domain
ens_v_radardbz="-0.30125"


