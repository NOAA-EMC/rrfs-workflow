#!/usr/bin/env bash
# Configure appropriate chemistry settings for the mpassit task
#
# shellcheck disable=SC2154,SC2153

cat "${FIXrrfs}"/chemistry/mpassit/histlist_2d_chem >> histlist_2d
cat "${FIXrrfs}"/chemistry/mpassit/histlist_3d_chem >> histlist_3d
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
if [[ "${CHEM_GROUPS}" == *ssalt* ]]; then
  cat "${FIXrrfs}"/chemistry/mpassit/histlist_3d_ssalt >> histlist_3d
fi
for tracer in ${EXTRA_CHEMICAL_TRACERS//,/ }; do
    # Convert to uppercase
    tracer_upper="${tracer^^}" 
    
    # %s  = string 1 (lowercase)
    # \t  = tab character (x4)
    # %s  = string 2 (uppercase)
    # \n  = newline
    printf "%s\t\t\t\t%s\n" "${tracer}" "${tracer_upper}" >> histlist_3d
done
# Make sure we didn't create any duplicates
awk '!seen[$0]++' histlist_2d  > temp_histlist_2d && mv temp_histlist_2d histlist_2d
awk '!seen[$0]++' histlist_3d  > temp_histlist_3d && mv temp_histlist_3d histlist_3d
