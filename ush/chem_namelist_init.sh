#!/usr/bin/env bash
# Configure appropriate chemistry settings for the ic or lbc task
#
# shellcheck disable=SC2154,SC2153

cat "${PARMrrfs}/chemistry/namelist.init_atmosphere" >> namelist.init_atmosphere
#
# Now adjust the configure options based on activated CHEM_GROUPS
if [[ "${USE_EXTERNAL_CHEM^^}" == "TRUE" ]]; then
  if [[ "${CHEM_GROUPS}" == *smoke* ]]; then
    sed -i "s/config_smoke_scheme\s*=\s*'off'/config_smoke_scheme = 'on'/g" namelist.init_atmosphere
  fi
  if [[ "${CHEM_GROUPS}" == *dust* ]]; then
     sed -i "s/config_dust_scheme\s*=\s*'off'/config_dust_scheme = 'on'/g" namelist.init_atmosphere
  fi
fi
