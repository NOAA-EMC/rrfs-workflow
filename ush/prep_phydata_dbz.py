#!/usr/bin/env python3
'''
   This script prepares phy_data.nc for ingestion in FV3-JEDI for radar DA
   Two things are done:
      1) Lower bound of refl is set to 0 dBZ
      2) Reverse vertical index so that index 0 corresponds to the model top
'''
import netCDF4 as nc
import numpy as np
import os, sys

file_arg = sys.argv[1]
if file_arg.endswith('_prepdbz'):
    # Caller already produced this file directly (e.g. via `ncks -v ref_f3d`)
    # - operate on it in place instead of copying the whole phy_data.nc again.
    file_prep = file_arg
else:
    file_prep = f'{file_arg}_prepdbz'
    os.system(f'cp {file_arg} {file_prep}')

# Read data
nc_file      = nc.Dataset(file_prep, 'r+')
refl3d  = nc_file.variables['ref_f3d'][:]

# Check if this is already been pre-processed and exit
rmin = np.nanmin(refl3d)
if rmin >= 0.0:
    sys.exit(f'Quitting early... {file_prep} seems to already be prepped.')
    sys.exit(f'    ReflMin = {rmin} dbz')

# Reverse vertical order for JEDI
refl3d_rev = refl3d[:,::-1,:,:]

# Set lower bound to 0 dBZ
neg_dbz = np.where(refl3d_rev<0.0)
refl3d_rev[neg_dbz] = 0.0

# Overwrite file
nc_file.variables['ref_f3d'][:] = refl3d_rev
nc_file.close()
