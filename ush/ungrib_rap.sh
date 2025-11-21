#!/usr/bin/env bash
# interplate RAP to Lambert Conformal grid
#
# shellcheck disable=SC2154,SC2153,SC2086

grid_specs_20km="lambert:-97.5:38.5 -133.174:449:20000.0 5.47114:299:20000.0"

${WGRIB2} ${GRIBFILE} -set_bitmap 1 -set_grib_type c3 -new_grid_winds grid \
       -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH"               \
       -new_grid_interpolation neighbor                                  \
       -new_grid ${grid_specs_20km} "tmp.${GRIBFILE_LOCAL}"

# store vector records together in the sam GRIB2 message as submessages
wgrib2 "tmp.${GRIBFILE_LOCAL}" -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH" -submsg_uv "${GRIBFILE_LOCAL}"
