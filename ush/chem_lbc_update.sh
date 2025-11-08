#!/usr/bin/env bash
# Configure appropriate chemistry settings for the ic or lbc task
#
# shellcheck disable=SC2154,SC2153

if true; then
   for lbc in lbc.*.nc; do
     if ncdump -hv lbc_SMKF "${lbc}" 1>/dev/null; then
        ncrename -v lbc_SMKF,lbc_smoke_fine "${lbc}"
     fi

     if ncdump -hv lbc_MASSDEN "${lbc}" 1>/dev/null; then
        ncrename -v lbc_MASSDEN,lbc_smoke_fine  "${lbc}"
     fi

     if ncdump -hv lbc_DSTF "${lbc}" 1>/dev/null; then
        ncrename -v lbc_DSTF,lbc_dust_fine "${lbc}"
     fi

     if ncdump -hv lbc_DSTC "${lbc}" 1>/dev/null; then
        ncrename -v lbc_DSTC,lbc_dust_coarse "${lbc}"
     fi
   done
fi
