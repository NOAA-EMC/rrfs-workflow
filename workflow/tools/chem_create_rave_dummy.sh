#!/usr/bin/env bash
#
# copy this file to the run directory of the prep_chem task, where you can find RAVE emission files,
# run it and then copy the created RAVE.dummy.nc file to ${COMINrrfs} or an archive location
#
# shellcheck disable=SC2012
#
# make sure the nco module can be loaded
#   if one has difficulties to load nco by default,
#   'source rrfs-workflow/workflow/tools/load_rrfs.sh' first
module load nco

dummyRAVE="RAVE.dummy.nc"
dummyRAVEtemplate=$(ls *RAVE-??????????.nc | head -n 1)
echo "create RAVE_dummy.nc using: ${dummyRAVEtemplate}"
cp "${dummyRAVEtemplate}" "${dummyRAVE}"
ncap2 -O -s 'e_bb_in_smoke_fine=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
ncap2 -O -s 'e_bb_in_smoke_coarse=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
ncap2 -O -s 'e_bb_in_smoke_so2=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
ncap2 -O -s 'e_bb_in_smoke_ch4=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
ncap2 -O -s 'e_bb_in_smoke_nh3=0.*e_bb_in_smoke_fine' "${dummyRAVE}" "${dummyRAVE}"
ncap2 -O -s 'frp_in=0.*frp_in' "${dummyRAVE}" "${dummyRAVE}"
ncap2 -O -s 'fre_in=0.*fre_in' "${dummyRAVE}" "${dummyRAVE}"
echo "Done:"
ls -lrth "${dummyRAVE}"
echo -e '\nrename the above file to "RAVE.dummy.${MESH_NAME}.nc", where ${MESH_NAME} can be conus3km, conus12km, etc'
