#!/usr/bin/env bash
# interplate RRFS NA3km grib2 files to the variation 130 grid at 3km
#
# shellcheck disable=SC2154,SC2153

budget_fields=":(WEASD|APCP|NCPCP|ACPCP|SNOD):"
neighbor_fields=":(NCONCD|NCCICE|SPNCR|CLWMR|CICE|RWMR|SNMR|GRLE|PMTF|PMTC|REFC|CSNOW|CICEP|CFRZR|CRAIN|LAND|ICEC|TMP:surface|VEG|CCOND|SFEXC|MSLMA|PRES:tropopause|LAI|HPBL|HGT:planetary boundary layer):"
grid_specs="lambert:266:25.000000 234.862000:2000:3000.000000 18.281000:1450:3000.000000"

wgrib2 "${GRIBFILE}" -set_bitmap 1 -set_grib_type c3 -new_grid_winds grid \
       -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH"               \
       -new_grid_interpolation bilinear \
       -if "${budget_fields}"   -new_grid_interpolation budget -fi \
       -if "${neighbor_fields}" -new_grid_interpolation neighbor -fi \
       -new_grid "${grid_specs}" "tmp.${GRIBFILE_LOCAL}"

# store vector records together in the sam GRIB2 message as submessages
wgrib2 "tmp.${GRIBFILE_LOCAL}" -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH" -submsg_uv "${GRIBFILE_LOCAL}"
