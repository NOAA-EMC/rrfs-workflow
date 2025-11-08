#!/usr/bin/env bash
#
# copy this file to the directory where you can find a RAVE emission file
# run it and then copy the RAVE_dummy.nc file to ${COMINrrfs} or an archive location
#
# shellcheck disable=SC2012
dummyRAVEtemplate=$(ls "${RAVE_OUTPUTDIR}/${MESH_NAME}*" | head -n 1)
echo "Dummy RAVE file doesn't exist, but creating one using: ${dummyRAVEtemplate}"
cp "${dummyRAVEtemplate}" RAVE_dummy.nc
ncap2 -O -s 'e_bb_in_smoke_fine=0.*e_bb_in_smoke_fine' RAVE_dummy.nc RAVE_dummy.nc
ncap2 -O -s 'e_bb_in_smoke_coarse=0.*e_bb_in_smoke_fine' RAVE_dummy.nc RAVE_dummy.nc
ncap2 -O -s 'e_bb_in_smoke_so2=0.*e_bb_in_smoke_fine' RAVE_dummy.nc RAVE_dummy.nc
ncap2 -O -s 'e_bb_in_smoke_ch4=0.*e_bb_in_smoke_fine' RAVE_dummy.nc RAVE_dummy.nc
ncap2 -O -s 'e_bb_in_smoke_nh3=0.*e_bb_in_smoke_fine' RAVE_dummy.nc RAVE_dummy.nc
ncap2 -O -s 'frp_in=0.*frp_in' RAVE_dummy.nc RAVE_dummy.nc
ncap2 -O -s 'fre_in=0.*fre_in' RAVE_dummy.nc RAVE_dummy.nc
