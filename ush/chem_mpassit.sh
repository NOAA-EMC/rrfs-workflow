#!/usr/bin/env bash
# Configure appropriate chemistry settings for the mpassit task
#
# shellcheck disable=SC2154,SC2153

cat "${FIXrrfs}"/chemistry/mpassit/histlist_2d_chem >> histlist_2d
if [[ "${CHEM_GROUPS}" == *dust* ]]; then
  cat "${FIXrrfs}"/chemistry/mpassit/histlist_3d_dust >> histlist_3d
fi
if [[ "${CHEM_GROUPS}" == *smoke* ]]; then
   # TODO, FCST vs. RETRO
   cat "${FIXrrfs}"/chemistry/mpassit/histlist_2d_smoke >> histlist_2d
   cat "${FIXrrfs}"/chemistry/mpassit/histlist_3d_smoke >> histlist_3d
fi
if [[ "${CHEM_GROUPS}" == *pollen* ]]; then
   cat "${FIXrrfs}"/chemistry/mpassit/histlist_3d_pollen >> histlist_3d
 fi
if [[ "${CHEM_GROUPS}" == *anthro* ]]; then
   cat "${FIXrrfs}"/chemistry/mpassit/histlist_3d_anthro >> histlist_3d
fi
# Make sure we didn't create any duplicates
awk '!seen[$0]++' histlist_2d  > temp_histlist_2d && mv temp_histlist_2d histlist_2d
awk '!seen[$0]++' histlist_3d  > temp_histlist_3d && mv temp_histlist_3d histlist_3d
