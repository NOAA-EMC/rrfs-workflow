#!/usr/bin/env python
import netCDF4 as nc
import numpy as np
from timeit import default_timer as timer
import argparse
import warnings

"""
This program makes a copy of an original IODA file and can add/modify additional
adhoc variables. This program was originally written to add the
MetaData/longitude_latitude_pressure for use in l_closeobs duplicate checking
but others can be added as necessary.
3/4/2025: change all QualityMarker with missing values to 15
"""

# Disable warnings
warnings.filterwarnings('ignore')

# Functions for calculating run times.


def tic():
    return timer()


def toc(tic=tic, label=""):
    toc = timer()
    elapsed = toc - tic
    hrs = int(elapsed // 3600)
    mins = int((elapsed % 3600) // 60)
    secs = int(elapsed % 3600 % 60)
    print(f"{label}({elapsed:.2f}s), {hrs:02}:{mins:02}:{secs:02}")


tic1 = tic()

parser = argparse.ArgumentParser()
parser.add_argument('-o', '--obs', type=str, help='ioda observation file', required=True)
args = parser.parse_args()

# Assign filenames
obs_filename = args.obs

obs_ds = nc.Dataset(obs_filename, 'r')

# Extract observation latitudes and longitudes
obs_lat = obs_ds.groups['MetaData'].variables['latitude'][:]
obs_lon = obs_ds.groups['MetaData'].variables['longitude'][:]
obs_lon = np.where(obs_lon < 0, obs_lon + 360, obs_lon)
obs_prs = obs_ds.groups['MetaData'].variables['pressure'][:]

# Create a new NetCDF file to store the selected data using the more efficient method
if '.nc' in obs_filename:
    outfile = obs_filename.replace('.nc', '_llp.nc')
else:
    outfile = obs_filename.replace('.nc4', '_llp.nc4')
fout = nc.Dataset(outfile, 'w')

# Create dimensions and variables in the new file
fout.createDimension('Location', len(obs_lat))
fout.createVariable('Location', 'int64', 'Location')
fout.variables['Location'][:] = 0
for attr in obs_ds.variables['Location'].ncattrs():  # Attributes for Location variable
    fout.variables['Location'].setncattr(attr, obs_ds.variables['Location'].getncattr(attr))

# Copy all non-grouped attributes into the new file
for attr in obs_ds.ncattrs():  # Attributes for the main file
    fout.setncattr(attr, obs_ds.getncattr(attr))

# Copy all groups and variables into the new file, keeping only the variables in range
groups = obs_ds.groups
for group in groups:
    if group == "QualityMarker":
        qc_group = True
    else:
        qc_group = False
    g = fout.createGroup(group)
    for var in obs_ds.groups[group].variables:
        invar = obs_ds.groups[group].variables[var]
        try:  # Non-string variables
            vartype = invar.dtype
            fill = invar.getncattr('_FillValue')
            g.createVariable(var, vartype, 'Location', fill_value=fill)
        except (AttributeError, KeyError):  # String variables
            g.createVariable(var, 'str', 'Location')
        #
        if qc_group and vartype == "int32":
            np_invar = np.array(invar)
            np_invar[(np_invar < 0) | (np_invar > 15)] = 15
            g.variables[var][:] = np_invar.astype(invar.dtype)
        else:
            if var in ['latitude', 'longitude']:
                g.variables[var][:] = invar[:][:].data
            else:
                g.variables[var][:] = invar[:][:]
        # Copy attributes for this variable
        for attr in invar.ncattrs():
            if '_FillValue' in attr:
                continue
            g.variables[var].setncattr(attr, invar.getncattr(attr))

# Generate longitude_latitude_pressure location strings (for dup checking)
longitude_latitude_pressure = [f"{lon}_{lat}_{pres}" for lon, lat, pres in zip(obs_lon, obs_lat, obs_prs)]
longitude_latitude_pressure = np.array(longitude_latitude_pressure)

# Add the longitude_latitude_pressure variable to the file
var = "longitude_latitude_pressure"
data = longitude_latitude_pressure
metadata_group = fout.groups['MetaData']
metadata_group.createVariable(f"{var}", 'str', 'Location', fill_value=fill)
metadata_group.variables[f"{var}"][:] = data

# Close the datasets
obs_ds.close()
fout.close()
toc(tic1, label="Time to create new obs file: ")
