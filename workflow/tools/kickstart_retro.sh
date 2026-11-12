#!/usr/bin/env bash
kickstart_period_det="2024050600-2024050609"
kickstart_period_enkf="2024050609-2024050609"
rap_ic_period="2024050603-2024050603"
SFC_UPDATE_SOURCE_DIR="/gpfs/f6/bil-fire10-oar/world-shared/jjh/rrfsv2/RRFSv2X/L60/20260403/MPAS_RAP"

if (( $# < 1 )); then
  echo "Usage: retro_kickstart.sh <srcfile>"
  exit 1
fi
srcfile=$1
if [[ "${srcfile}" == *det* ]]; then
  sed -e "s/HYB_WGT_ENS=0.5/HYB_WGT_ENS=0.0/" -e "s/HYB_WGT_STATIC=0.5/HYB_WGT_STATIC=1.0/" \
    -e "s/LBC_LENGTH=84/LBC_LENGTH=27/" -e "s/RETRO_PERIOD=\"2024050610-2024051300\"/RETRO_PERIOD=\"${kickstart_period_det}\"/" \
    -e "s/DO_GRAPHICS=true/DO_GRAPHICS=false/" -e "s/DO_PYDAMONITOR=true/DO_PYDAMONITOR=false/" \
    -e "s/DO_CYC=true/DO_CYC=true\nexport DO_POST=false/" -e 's/do arr\[$i\]="03"/do arr[$i]="01"/' \
    -e "s/for i in {0..23..3}/#for i in {0..23..3}/"  -e "s/for i in {0..23..12}/#for i in {0..23..12}/" \
    -e "s/EXP_NAME=RRFSv2/EXP_NAME=RRFSv2_kickstart/"  -e "s/TAG=rrfsv2/TAG=rrfsv2_ks/" \
    -e "s|DO_SPPT=false|DO_SPPT=false\nexport SFC_UPDATE_SOURCE_DIR=${SFC_UPDATE_SOURCE_DIR}|" \
    "${srcfile}" > "${srcfile}_kickstart"

  # generate the rap_ic exp file
  sed -e "s/EXP_NAME=RRFSv2_kickstart/EXP_NAME=RRFSv2_rap_ic/" -e "s/export DO_RADAR_REF=true/export DO_RADAR_REF=false/" \
    -e "s/export LBC_OFFSET=6/export LBC_OFFSET=3/" -e "s/export LBC_LENGTH=27/export LBC_LENGTH=3/" \
    -e "s/DO_IODA=true/DO_IODA=false/" -e "s/export DO_JEDI=true/export DO_JEDI=false\nexport IC_ONLY=true/" \
    -e 's/IC_EXTRN_MDL_NAME="GFS"/IC_EXTRN_MDL_NAME="RAP"/' -e "s/May2024\/GFS/May2024\/rap/" \
    -e "s/RETRO_PERIOD=\"${kickstart_period_det}\"/\"${rap_ic_period}\"/" -e "s/TAG=rrfsv2_ks/TAG=rrfsv2_rap_ic/" \
    "${srcfile}_kickstart" > "${srcfile}_rap_ic"

else  # enkf
  sed -e "s/RETRO_PERIOD=\"2024050610-2024051300\"/RETRO_PERIOD=\"${kickstart_period_enkf}\"/" \
    "${srcfile}" > "${srcfile}_kickstart"
fi
