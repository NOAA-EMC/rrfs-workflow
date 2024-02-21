#!/bin/env python
#
#-----------------------------------------------------------------------
# Python script to determine if the fire weather nest falls inside the
# RRFS grid based on the center latitude and longitude points.
#
# This script is called within the exrrfs_make_grid.sh script.
#
#-----------------------------------------------------------------------

import numpy as np
import math as m
import sys, csv

#---------- Define some functions ----------#

# Check to determine if a point falls inside RRFS-A NA
# Code from lam_domaincheck_esg_c subroutine in LAMDomainCheck.interface.F90
def rrfs_domain_check(lat,lon):
  alpha = 0.183131392268429	# alpha parameter for ESG grid definition
  kappa = -0.265835885178773	# kappa paramater for ESG grid definition
  plat = 55.0			# center point latitude of ESG grid (degrees)
  plon = -112.5			# center point longitude of ESG grid (degrees)
  pazi = 0.0			# azimuth angle for ESG grid definition
  npx = 3950			# number of grid points in x direction
  npy = 2700			# number of grid points in y direction
#  dx = 0.01349			# grid spacing in degrees (3 km grid spacing)
#  dy = 0.01349			# grid spacing in degrees (3 km grid spacing)
  delx = 0.00022629		# grid spacing of supergrid in map units
  dely = 0.00023118		# grid spacing of supergrid in map units
  failure = False		# failure code

  plat = plat * (m.pi / 180.0)	# convert to radians
  plon = plon * (m.pi / 180.0)	# convert to radians
  delx = delx * 2		# multiply by 2 to get actual grid resolution
  dely = dely * 2		# multiply by 2 to get actual grid resolution
  lat = lat * (m.pi / 180.0)	# convert to radians
  lon = lon * (m.pi / 180.0)	# convert to radians

# gtoxm_ak_rr subroutine from Jim Purser's pesg.f90 code

  clat = m.cos(plat)
  slat = m.sin(plat)
  clon = m.cos(plon)
  slon = m.sin(plon)
  cazi = m.cos(pazi)
  sazi = m.sin(pazi)

  azirot = [[cazi,  sazi, 0],
            [-sazi, cazi, 0],
            [0,     0,    1]]
  prot = [[-slon,      clon,       0],
          [-slat*clon, -slat*slon, clat],
          [clat*clon,  clat*slon,  slat]]

  azirot = np.array(azirot)
  prot = np.array(prot)
  prot = np.matmul(prot,azirot)

  sla = m.sin(lat)
  cla = m.cos(lat)
  slo = m.sin(lon)
  clo = m.cos(lon)
  xe = [[cla*clo], 
        [cla*slo],
        [sla]]

  xe = np.array(xe)
  xc = np.matmul(prot,xe)	# Do NOT use the transpose of prot here

  xc = np.array(xc)
  zp = float(xc[2]) + 1.0
  xs = xc[0:2]/zp

  xs = np.array(xs)

  s = kappa * (float(xs[0])*float(xs[0]) + float(xs[1])*float(xs[1]))
  sc = 1.0 - s
  if (abs(s) >= 1.0):
    failure = True
  xt = (2.0 * xs) / sc

  xm = xt	# Define xm, will set correct values below

  if (alpha > 0):
    ra = m.sqrt(alpha)
    razt = ra * xt[0]
    xm[0] = m.atan(razt) / ra
  elif (alpha < 0):
    ra = m.sqrt(-alpha)
    razt = ra * xt[0]
    if (abs(razt) >= 1.0):
      failure = True
    xm[0] = m.atanh(razt) / ra
  else:
    xm[0] = xt[0]

  if (alpha > 0):
    ra = m.sqrt(alpha)
    razt = ra * xt[1]
    xm[1] = m.atan(razt) / ra
  elif (alpha < 0):
    ra = m.sqrt(-alpha)
    razt = ra * xt[1]
    if (abs(razt) >= 1.0):
      failure = True
    xm[1] = m.atanh(razt) / ra
  else:
    xm[1] = xt[1]

  xm[0] = xm[0]/delx
  xm[1] = xm[1]/dely
  print((xm))

# use xm to determine if point is good or bad
  if ((abs(xm[0])) < (npx/2)) and ((abs(xm[1])) < (npy/2)) and (failure == False):
  # Point is inside the ESG grid
    check = False 
  else:
  # Point is outside the ESG grid
    check = True

  return(check)


#-------------------------- START OF SCRIPT -------------------------#

def main():

# RRFS Fire Weather center lat/lon - input arguments
  centlat = float(sys.argv[1])
  centlon = float(sys.argv[2])

# First check if the center lat/lon falls inside the RRFS domain

  check = rrfs_domain_check(centlat,centlon)
  if (check == True):
    print(('WARNING: The center of the RRFS fire weather nest is outside the RRFS domain.  Please choose a different center latitude and longitude.'))
  else:
    print(('The center of the RRFS fire weather nest is inside the RRFS domain.'))

# Now check if all 4 corner points fall inside the RRFS domain
# If the failure check evaluates to true, then the point is bad
  lat_south = centlat - 2.5
  lat_north = centlat + 2.5
  lon_west = centlon - 2.5
  lon_east = centlon + 2.5
  llcrnr_check = False
  lrcrnr_check = False
  ulcrnr_check = False
  urcrnr_check = False

#---- Lower-left corner ----#
  check = rrfs_domain_check(lat_south,lon_west)
  if (check == True):
    llcrnr_check = True
    print(('WARNING: The lower-left corner point of the RRFSFW domain lies outside the RRFS domain.'))
  else:
    print(('The lower-left corner point of the RRFSFW domain lies inside the RRFS domain.'))

#---- Lower-right corner ----#
  check = rrfs_domain_check(lat_south,lon_east)
  if (check == True):
    lrcrnr_check = True
    print(('WARNING: The lower-right corner point of the RRFSFW domain lies outside the RRFS domain.'))
  else:
    print(('The lower-right corner point of the RRFSFW domain lies inside the RRFS domain.'))

#---- Upper-left corner ----#
  check = rrfs_domain_check(lat_north,lon_west)
  if (check == True):
    ulcrnr_check = True
    print(('WARNING: The upper-left corner point of the RRFSFW domain lies outside the RRFS domain.'))
  else:
    print(('The upper-left corner point of the RRFSFW domain lies inside the RRFS domain.'))

#---- Upper-right corner ----#
  check = rrfs_domain_check(lat_north,lon_east)
  if (check == True):
    urcrnr_check = True
    print(('WARNING: The upper-right corner point of the RRFSFW domain lies outside the RRFS domain.'))
  else:
    print(('The upper-right corner point of the RRFSFW domain lies inside the RRFS domain.'))


# If any of the corner points lie outside the RRFS domain, provide more helpful information on how to modify the center latitude and longitude.
  if (check == False):
    print(('The RRFS fire weather nest fits inside the RRFS domain.  Proceed with grid processing!'))

  elif (llcrnr_check == True) and (lrcrnr_check == True) and (ulcrnr_check == True) and (urcrnr_check == True):
    print(('Since all 4 corner points of the RRFS fire weather nest are outside the RRFS domain, there is no specific recommendation for how to modify the center lat/lon.'))
    sys.exit()

#---- Only RRFSFW upper right corner is inside RRFS domain ----#
#---- Shift center lat/lon to the northeast ----#
  elif (llcrnr_check == True) and (lrcrnr_check == True) and (ulcrnr_check == True):
    print(('Recommend shifting the center latitude further north and the center longitude further east.'))
    sys.exit()

#---- Only RRFSFW upper left corner is inside RRFS domain ----#
#---- Shift center lat/lon to the northwest ----#
  elif (llcrnr_check == True) and (lrcrnr_check == True) and (urcrnr_check == True):
    print(('Recommend shifting the center latitude further north and the center longitude further west.'))
    sys.exit()

#---- Only RRFSFW lower right corner is inside RRFS domain ----#
#---- Shift center lat/lon to the southeast ----#
  elif (llcrnr_check == True) and (ulcrnr_check == True) and (urcrnr_check == True):
    print(('Recommend shifting the center latitude further south and the center longitude further east.'))
    sys.exit()

#---- RRFSFW is outside RRFS domain except for lower left corner ----#
#---- Shift center lat/lon to the southwest ----#
  elif (lrcrnr_check == True) and (ulcrnr_check == True) and (urcrnr_check == True):
    print(('Recommend shifting the center latitude further south and the center longitude further west.'))
    sys.exit()

#---- RRFSFW is too far south ----#
  elif (llcrnr_check == True) and (lrcrnr_check == True):
    print(('Recommend shifting the center latitude further north.'))
    sys.exit()

#---- RRFSFW is too far north ----#
  elif (ulcrnr_check == True) and (urcrnr_check == True):
    print(('Recommend shifting the center latitude further south.'))
    sys.exit()

#---- RRFSFW is too far west ----#
  elif (llcrnr_check == True) and (ulcrnr_check == True):
    print(('Recommend shifting the center longitude further east.'))
    sys.exit()

#---- RRFSFW is too far east ----#
  elif (lrcrnr_check == True) and (urcrnr_check == True):
    print(('Recommend shifting the center longitude further west.'))
    sys.exit()


#-----------------------------------------------------------------------

if __name__ == '__main__':
    main()
