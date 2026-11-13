#!/usr/bin/env python
# Copy soil variables from the soil-nudging output into an MPAS file, in place.
# Replacement for `ncks -A -v var1,var2,... src.nc dst.nc` that only rewrites the listed variables of
# the existing file. For the large 3-km CONUS mpasout file the ncks step took far longer than the DA itself.
# usage: append_soil.py src.nc dst.nc var1,var2,...
import sys
import netCDF4 as nc

src_file, dst_file, var_list = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
with nc.Dataset(src_file, 'r') as src, nc.Dataset(dst_file, 'r+') as dst:
    for v in var_list:
        if v not in dst.variables or v not in src.variables:
            sys.exit(f"ERROR: variable {v} missing in {src_file} or {dst_file}")
        if src[v].shape != dst[v].shape:
            sys.exit(f"ERROR: shape mismatch for {v}: {src[v].shape} vs {dst[v].shape}")
    for v in var_list:
        dst[v][:] = src[v][:]
