#!/usr/bin/env python
import matplotlib.pyplot as plt
import netCDF4 as nc
import numpy as np
from matplotlib.path import Path
from scipy.spatial import Delaunay
from timeit import default_timer as timer
import argparse
import warnings
import matplotlib
import os
import cartopy
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import matplotlib.ticker as mticker
from cartopy.mpl.gridliner import LONGITUDE_FORMATTER, LATITUDE_FORMATTER
from operator import itemgetter
import shapely.speedups

shapely.speedups.enable()

"""
This program determines if observations are in/outside of a convex hull
computed via a lat/lon grid file (see note below about the grid file).
A convex hull is the smallest convex shape (or polygon) that can enclose a set
of points in a plane (or in higher dimensions). Imagine stretching a rubber band
around the outermost points in a set; the shape that the rubber band forms is
the convex hull. So, if there are any concave points between vertices,
then there would be whitespace between the red and blue box. I've shrunk the
convex hull such that there wouldn't be such whitespace which, of course,
in tern means that it is going to be not an exact match of the domain grid
(e.g., near corners). This can be tuned via the "hull_shrink_factor".
"""

# Disable warnings
warnings.filterwarnings('ignore')

# Set matplotlib backend
matplotlib.use('agg')

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


def alpha_shape(points, alpha, only_outer=True):
    """
    Solution from Iddo Hanniel (https://stackoverflow.com/questions/50549128/boundary-enclosing-a-given-set-of-points)
    Compute the alpha shape (concave hull) of a set of points
    :param points: np.array of shape (n,2) points.
    :param alpha: alpha value.
    :param only_outer: boolean value to specify if we keep only the outer border
    or also inner edges.
    :return: set of (i,j) pairs representing edges of the alpha-shape. (i,j) are
    the indices in the points array.
    """
    assert points.shape[0] > 3, "Need at least four points"

    def add_edge(edges, i, j):
        """
        Add an edge between the i-th and j-th points,
        if not in the list already
        """
        if (i, j) in edges or (j, i) in edges:
            # already added
            assert (j, i) in edges, "Can't go twice over same directed edge right?"
            if only_outer:
                # if both neighboring triangles are in shape, it's not a boundary edge
                edges.remove((j, i))
            return
        edges.add((i, j))

    points = points.data
    tri = Delaunay(points)
    edges = set()
    # Loop over triangles:
    # ia, ib, ic = indices of corner points of the triangle
    # for ia, ib, ic in tri.vertices: #only work with python version from RDASApp/module/EVA
    for ia, ib, ic in tri.simplices:
        pa = points[ia]
        pb = points[ib]
        pc = points[ic]
        # Computing radius of triangle circumcircle
        # www.mathalino.com/reviewer/derivation-of-formulas/derivation-of-formula-for-radius-of-circumcircle
        a = np.sqrt((pa[0] - pb[0]) ** 2 + (pa[1] - pb[1]) ** 2)
        b = np.sqrt((pb[0] - pc[0]) ** 2 + (pb[1] - pc[1]) ** 2)
        c = np.sqrt((pc[0] - pa[0]) ** 2 + (pc[1] - pa[1]) ** 2)
        s = (a + b + c) / 2.0
        area = np.sqrt(s * (s - a) * (s - b) * (s - c))
        circum_r = a * b * c / (4.0 * area)
        if circum_r < alpha:
            add_edge(edges, ia, ib)
            add_edge(edges, ib, ic)
            add_edge(edges, ic, ia)
    return edges


def find_edges_with(i, edge_set):
    i_first = [j for (x, j) in edge_set if x == i]
    i_second = [j for (j, x) in edge_set if x == i]
    return i_first, i_second


def stitch_boundaries(edges):
    """
    Sort the edges computed by alpha_shape
    """
    edge_set = edges.copy()
    boundary_lst = []
    while len(edge_set) > 0:
        boundary = []
        edge0 = edge_set.pop()
        boundary.append(edge0)
        last_edge = edge0
        while len(edge_set) > 0:
            i, j = last_edge
            j_first, j_second = find_edges_with(j, edge_set)
            if j_first:
                edge_set.remove((j, j_first[0]))
                edge_with_j = (j, j_first[0])
                boundary.append(edge_with_j)
                last_edge = edge_with_j
            elif j_second:
                edge_set.remove((j_second[0], j))
                edge_with_j = (j, j_second[0])  # flip edge rep
                boundary.append(edge_with_j)
                last_edge = edge_with_j

            if edge0[0] == last_edge[1]:
                break

        boundary_lst.append(boundary)
    return boundary_lst


def shrink_boundary(points, centroid, factor=0.01):
    new_points = []
    for point in points:
        direction = point - centroid
        distance_to_centroid = np.linalg.norm(direction)
        direction_normalized = direction / distance_to_centroid
        new_point = point - factor * direction_normalized * distance_to_centroid
        new_points.append(new_point)
    return np.array(new_points)


tic1 = tic()

# Parse command-line arguments
# Note:
#    The grid file is what contains variables grid_lat/grid_lon
#    OR latCell/lonCell for FV3 and MPAS respectively.
#    Examples can be found in the following rrfs-test cases:
#      - rrfs-data_fv3jedi_2022052619/Data/bkg/fv3_grid_spec.nc
#      - mpas_2024052700/data/restart.2024-05-27_00.00.00.nc
parser = argparse.ArgumentParser()
parser.add_argument('-g', '--grid', type=str, help='grid file', required=True)
parser.add_argument('-o', '--obs', type=str, help='ioda observation file', required=True)
parser.add_argument('-f', '--fig', action='store_true', help='disable figure (default is False)', required=False)
parser.add_argument('-s', '--shrink', type=float, help='hull shrink factor', required=True)
args = parser.parse_args()

# Assign filenames
obs_filename = args.obs
grid_filename = args.grid  # see note above.
make_fig = args.fig
hull_shrink_factor = args.shrink

print(f"Obs file: {obs_filename}")
print(f"Grid file: {grid_filename}")
print(f"Figure flag: {args.fig}")
print(f"Hull shrink factor: {hull_shrink_factor}")

# Plotting options
plot_box_width = 100.  # define size of plot domain (units: lat/lon degrees)
plot_box_height = 50
cen_lat = 34.5
cen_lon = -97.5
# hull_shrink_factor = 0.10  #10% was found to work fairly well.

grid_ds = nc.Dataset(grid_filename, 'r')
obs_ds = nc.Dataset(obs_filename, 'r')

# Extract the grid latitude and longitude
if 'grid_lat' in grid_ds.variables and 'grid_lon' in grid_ds.variables:  # FV3 grid
    grid_lat = grid_ds.variables['grid_lat'][:, :]
    grid_lon = grid_ds.variables['grid_lon'][:, :]
    grid_lat = grid_lat.flatten()
    grid_lon = grid_lon.flatten()
    dycore = "FV3"
elif 'latCell' in grid_ds.variables and 'lonCell' in grid_ds.variables:  # MPAS grid
    grid_lat = np.degrees(grid_ds.variables['latCell'][:])  # Convert radians to degrees
    grid_lon = np.degrees(grid_ds.variables['lonCell'][:])  # Convert radians to degrees
    dycore = "MPAS"
else:
    raise ValueError("Unrecognized grid format: 'grid_lat'/'grid_lon' or 'latCell'/'lonCell' not found.")

print(f"Max/Min grid Lat: {np.max(grid_lat)}, {np.min(grid_lat)}")
print(f"Max/Min grid Lon: {np.max(grid_lon)-360}, {np.min(grid_lon)-360}\n")

# Get the points along the edge of the domain and sort
points = np.vstack([grid_lon, grid_lat]).T
edges = alpha_shape(points, alpha=0.25, only_outer=True)
edges_sorted = stitch_boundaries(edges)

# Now grab the lat/lon points of the boundary (could be improved)
edge_points = []
for idx in edges_sorted[0]:
    ipt = idx[0]
    jpt = idx[1]
    point_1 = points[ipt]
    point_2 = points[jpt]
    edge_points.append(point_1)
    edge_points.append(point_2)
edge_points = np.asarray(edge_points)

# Shrink the hull boundary to avoid problems right at the boundary
centroid = np.nanmean(edge_points, axis=0)
edge_points = shrink_boundary(edge_points, centroid, factor=hull_shrink_factor)

# Create a Path object for the polygon domain
domain_path = Path(edge_points)

# Extract observation latitudes and longitudes
obs_lat = obs_ds.groups['MetaData'].variables['latitude'][:]
obs_lon = obs_ds.groups['MetaData'].variables['longitude'][:]
obs_lon = np.where(obs_lon < 0, obs_lon + 360, obs_lon)

# print(f"Max/Min obs Lat: {np.max(obs_lat)}, {np.min(obs_lat)}")
# print(f"Max/Min obs Lon: {np.max(obs_lon)}, {np.min(obs_lon)}\n")

# Pair the observation lat/lon as coordinates
obs_coords = np.vstack((obs_lon, obs_lat)).T

# Check if each observation is within the domain
inside_domain = domain_path.contains_points(obs_coords)

# Get indices of observations within the domain
inside_indices = np.where(inside_domain)[0]
toc(tic1, label="Time to find obs within domain: ")

tic2 = tic()
# Create a new NetCDF file to store the selected data using the more efficient method
if '.nc4' in obs_filename:
    outfile = obs_filename.replace('.nc4', '_dc.nc4')
else:
    outfile = obs_filename.replace('.nc', '_dc.nc')
fout = nc.Dataset(outfile, 'w')

# Create dimensions and variables in the new file
location_size = len(inside_indices)
channel_size = obs_ds.dimensions['Channel'].size if 'Channel' in obs_ds.dimensions else 0  # Use the second dimension's size if exists

# Channel variable
if '_FillValue' in obs_ds.variables['Channel'].ncattrs():
    fill_value = obs_ds.variables['Channel'].getncattr('_FillValue')
else:
    fill_value = 2147483647
if 'Channel' not in fout.dimensions and channel_size > 0:
    fout.createDimension('Channel', channel_size)
    fout.createVariable('Channel', 'int32', 'Channel', fill_value=fill_value)
    fout.variables['Channel'][:] = obs_ds.variables['Channel'][:]
    for attr in obs_ds.variables['Channel'].ncattrs():  # Attributes for Location variable
        if attr != '_FillValue':
            fout.variables['Channel'].setncattr(attr, obs_ds.variables['Channel'].getncattr(attr))

# Location variable
if '_FillValue' in obs_ds.variables['Channel'].ncattrs():
    fill_value = obs_ds.variables['Channel'].getncattr('_FillValue')
else:
    fill_value = 2147483647
if 'Location' not in fout.dimensions:
    fout.createDimension('Location', location_size)
    fout.createVariable('Location', 'int32', 'Location', fill_value=fill_value)
    fout.variables['Location'][:] = 0
    for attr in obs_ds.variables['Location'].ncattrs():  # Attributes for Location variable
        if attr != '_FillValue':
            fout.variables['Location'].setncattr(attr, obs_ds.variables['Location'].getncattr(attr))

# Copy all non-grouped attributes into the new file
for attr in obs_ds.ncattrs():  # Attributes for the main file
    fout.setncattr(attr, obs_ds.getncattr(attr))

# Copy all groups and variables into the new file, keeping only the variables in range
groups = obs_ds.groups
for group in groups:
    g = fout.createGroup(group)
    for var in obs_ds.groups[group].variables:
        invar = obs_ds.groups[group].variables[var]
        vartype = invar.dtype
        fill = invar.getncattr('_FillValue')
        dimensions = invar.dimensions

        # Create a new variable with the correct dimensions
        if len(dimensions) == 1:  # One-dimensional variable
            if vartype == 'str':
                g.createVariable(var, 'str', dimensions, fill_value=fill)
            else:
                g.createVariable(var, vartype, dimensions, fill_value=fill)
            # If variable has only dimensions of channel then we do not need to process it
            if g.variables[var].dimensions[0] == 'Channel':
                g.variables[var][:] = invar[:][:]
            else:
                g.variables[var][:] = invar[:][inside_indices]
            # Copy attributes for this variable
            for attr in invar.ncattrs():
                if '_FillValue' in attr:
                    continue
                g.variables[var].setncattr(attr, invar.getncattr(attr))

        elif len(dimensions) == 2:  # Two-dimensional variable
            if vartype == 'str':
                g.createVariable(var, 'str', dimensions, fill_value=fill)
            else:
                g.createVariable(var, vartype, dimensions, fill_value=fill)
            for idy in range(0, len(invar[0, :])):  # new method for slicing very large 2d arrays
                g.variables[var][:, idy] = itemgetter(*inside_indices)(invar[:, idy])

            # Copy attributes for this variable
            for attr in invar.ncattrs():
                if '_FillValue' in attr:
                    continue
                g.variables[var].setncattr(attr, invar.getncattr(attr))

        else:
            raise NotImplementedError("Handling for more than two dimensions not implemented.")

# Add ObsError and fill with anything (prevents zero increments in LETKF)
obsval = obs_ds.groups['ObsValue'].variables['brightnessTemperature']
vartype = obsval.dtype
dimensions = obsval.dimensions
fill = obsval.getncattr('_FillValue')
g = fout.createGroup('ObsError')
g.createVariable('brightnessTemperature', vartype, dimensions, fill_value=fill)
g.variables['brightnessTemperature'][:, :] = 999

# Finally add global attribute with the settings used to run this domain check
fout.setncattr('Orig_obs_file', obs_filename)
fout.setncattr('Grid_file', grid_filename)
fout.setncattr('Shrink_factor', hull_shrink_factor)

# Close the datasets
obs_ds.close()
fout.close()
grid_ds.close()
toc(tic2, label="Time to create new obs file: ")

tic3 = tic()

if not make_fig:
    exit()

print("Generating figure...")

# Now create plot
# Set cartopy shapefile path
platform = os.getenv('HOSTNAME').upper()
if 'ORION' in platform:
    cartopy.config['data_dir'] = '/work/noaa/fv3-cam/sdegelia/cartopy'
elif 'H' in platform:  # Will need to improve this once Hercules is supported
    cartopy.config['data_dir'] = '/home/Donald.E.Lippi/cartopy'

fig = plt.figure(figsize=(7, 4))
m1 = fig.add_subplot(1, 1, 1, projection=ccrs.PlateCarree(central_longitude=0))
# m1 = fig.add_subplot(1, 1, 1, projection=ccrs.LambertConformal())
adjusted_lon = np.where(grid_lon > 180, grid_lon - 360, grid_lon)

# Determine extent for plot domain
half = plot_box_width / 2.
left = cen_lon - half
right = cen_lon + half
half = plot_box_height / 2.
bot = cen_lat - half
top = cen_lat + half

# Set extent for both plots
m1.set_extent([left, right, top, bot])

# Add features to the subplots
m1.add_feature(cfeature.COASTLINE)
m1.add_feature(cfeature.BORDERS)
m1.add_feature(cfeature.STATES)

# Gridlines for the subplots
gl1 = m1.gridlines(crs=ccrs.PlateCarree(), draw_labels=True, linewidth=0.5, color='k', alpha=0.25, linestyle='-')
gl1.xlocator = mticker.FixedLocator([])
gl1.xlocator = mticker.FixedLocator(np.arange(-180., 181., 10.))
gl1.ylocator = mticker.FixedLocator(np.arange(-80., 91., 10.))
gl1.xformatter = LONGITUDE_FORMATTER
gl1.yformatter = LATITUDE_FORMATTER
gl1.xlabel_style = {'size': 5, 'color': 'gray'}
gl1.ylabel_style = {'size': 5, 'color': 'gray'}

# Plot the domain and the observations
# m1.fill(adjusted_lon.flatten(), grid_lat.flatten(), color='b', label='Domain Boundary', zorder=1, transform=ccrs.PlateCarree())
m1.scatter(adjusted_lon.flatten(), grid_lat.flatten(), c='b', s=1, label='Domain Boundary', zorder=2)
m1.plot(edge_points[:, 0], edge_points[:, 1], 'tab:purple', label='Concave Hull', zorder=10, transform=ccrs.PlateCarree())

# Plot included observations
included_lat = obs_lat[inside_indices]
included_lon = obs_lon[inside_indices]
included_count = len(included_lat)
plt.scatter(included_lon, included_lat, c='g', s=2, label=f'Included Observations ({included_count})', zorder=3, transform=ccrs.PlateCarree())

# Plot excluded observations
excluded_indices = np.setdiff1d(np.arange(len(obs_lat)), inside_indices)
excluded_lat = obs_lat[excluded_indices]
excluded_lon = obs_lon[excluded_indices]

excluded_count = len(excluded_lat)
total_count = len(obs_lat)

print(f"Ob counts:")
print(f"  Excluded: {excluded_count}")
print(f"  Included: {included_count}")
print(f"  Total:    {total_count}")
plt.scatter(excluded_lon, excluded_lat, c='r', s=2, label=f'Excluded Observations ({excluded_count})', zorder=4, transform=ccrs.PlateCarree())

plt.xlabel('Longitude')
plt.ylabel('Latitude')
plt.legend(loc='upper right')
plt.title(f'{dycore} Domain and Observations ({hull_shrink_factor*100}%)')
plt.tight_layout()
plt.savefig(f'./domain_check_{dycore}.png')

toc(tic3, label="Time to create figure: ")
toc(tic1, label="Total elapsed time: ")
