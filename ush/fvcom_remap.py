import sys
import numpy as np
from netCDF4 import Dataset
import math
import scipy.interpolate as interp
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

brdr=0.05
missing_value = -99.9999

# get input file
argvs = sys.argv
ncfile_fvcom_eri  = argvs[1]
ncfile_fvcom_mhs  = argvs[2]
ncfile_fvcom_sup  = argvs[3]
ncfile_fvcom_ont  = argvs[4]
predef_grid_name  = argvs[5]

# Set dimensions for CONUS and NA 3-km grids
if predef_grid_name == 'RRFS_CONUS_3km':
  x1 = 674
  x2 = 955
  y1 = 1039
  y2 = 1490
elif predef_grid_name == 'RRFS_NA_3km':
  x1 = 960
  x2 = 1240
  y1 = 2490
  y2 = 2960

# read "containar" file
ncfile='./out_fv3grid.nc'
fh = Dataset(ncfile, mode='a')

lakemask = fh.variables['glmask'][:]
erimask = fh.variables['erimask'][:]
ontmask = fh.variables['ontmask'][:]
supmask = fh.variables['supmask'][:]
mhsmask = fh.variables['mhsmask'][:]
twsfc      = fh.variables['twsfc'][:]#.reshape((1,399,500))
tisfc      = fh.variables['tisfc'][:]#.reshape((1,399,500))
aicec      = fh.variables['aice'][:]#.reshape((1,399,500))
vicec      = fh.variables['vice'][:]#.reshape((1,399,500))
tsfc      = fh.variables['tsfc'][:]#.reshape((1,399,500))
lon      = fh.variables['geolon'][:]
lat      = fh.variables['geolat'][:]
time      = fh.variables['time'][:]

# read FVCOM outputs
try: # check if erie outputs exist
	fh_fvcom_eri     = Dataset(ncfile_fvcom_eri,mode='r')
	lon_fvcom_eri    = fh_fvcom_eri.variables['lon'][:]
	lat_fvcom_eri    = fh_fvcom_eri.variables['lat'][:]
	temp_fvcom_eri   = fh_fvcom_eri.variables['temp'][:]
	eri_exist = True
except:
	lon_fvcom_eri    = np.array([missing_value])
	lat_fvcom_eri    = np.array([missing_value])
	temp_fvcom_eri   = np.ones((len(time),1,1))*missing_value
	tice_fvcom_eri   = np.ones((len(time),1))*missing_value
	aice_fvcom_eri   = np.ones((len(time),1))*missing_value
	vice_fvcom_eri   = np.ones((len(time),1))*missing_value
	eri_exist = False
if ( eri_exist ): # check if ice outputs exist
	try: 
		tice_fvcom_eri   = fh_fvcom_eri.variables['tsfc'][:]
		aice_fvcom_eri   = fh_fvcom_eri.variables['aice'][:]
		vice_fvcom_eri   = fh_fvcom_eri.variables['vice'][:]
	except:
		tice_fvcom_eri   = np.zeros((len(time),len(lon_fvcom_eri)))
		aice_fvcom_eri   = np.zeros((len(time),len(lon_fvcom_eri)))
		vice_fvcom_eri   = np.zeros((len(time),len(lon_fvcom_eri)))

try: # check if mich-huron outputs exist
	fh_fvcom_mhs     = Dataset(ncfile_fvcom_mhs,mode='r')
	lon_fvcom_mhs    = fh_fvcom_mhs.variables['lon'][:]
	lat_fvcom_mhs    = fh_fvcom_mhs.variables['lat'][:]
	temp_fvcom_mhs   = fh_fvcom_mhs.variables['temp'][:]
	mhs_exist = True
except:
	lon_fvcom_mhs    = np.array([missing_value])
	lat_fvcom_mhs    = np.array([missing_value])
	temp_fvcom_mhs   = np.ones((len(time),1,1))*missing_value
	tice_fvcom_mhs   = np.ones((len(time),1))*missing_value
	aice_fvcom_mhs   = np.ones((len(time),1))*missing_value
	vice_fvcom_mhs   = np.ones((len(time),1))*missing_value
	mhs_exist = False 
if ( mhs_exist ): # check if ice outputs exist
	try: 
		tice_fvcom_mhs   = fh_fvcom_mhs.variables['tsfc'][:]
		aice_fvcom_mhs   = fh_fvcom_mhs.variables['aice'][:]
		vice_fvcom_mhs   = fh_fvcom_mhs.variables['vice'][:]
	except:
		tice_fvcom_mhs   = np.zeros((len(time),len(lon_fvcom_mhs)))
		aice_fvcom_mhs   = np.zeros((len(time),len(lon_fvcom_mhs)))
		vice_fvcom_mhs   = np.zeros((len(time),len(lon_fvcom_mhs)))

try: # check if sup outputs exist
	fh_fvcom_sup     = Dataset(ncfile_fvcom_sup,mode='r')
	lon_fvcom_sup    = fh_fvcom_sup.variables['lon'][:]
	lat_fvcom_sup    = fh_fvcom_sup.variables['lat'][:]
	temp_fvcom_sup   = fh_fvcom_sup.variables['temp'][:]
	sup_exist = True
except:
	lon_fvcom_sup    = np.array([missing_value])
	lat_fvcom_sup    = np.array([missing_value])
	temp_fvcom_sup   = np.ones((len(time),1,1))*missing_value
	tice_fvcom_sup   = np.ones((len(time),1))*missing_value
	aice_fvcom_sup   = np.ones((len(time),1))*missing_value
	vice_fvcom_sup   = np.ones((len(time),1))*missing_value
	sup_exist = False
if ( sup_exist ): # check if ice outputs exist
	try: 
		tice_fvcom_sup   = fh_fvcom_sup.variables['tsfc'][:]
		aice_fvcom_sup   = fh_fvcom_sup.variables['aice'][:]
		vice_fvcom_sup   = fh_fvcom_sup.variables['vice'][:]
	except:
		tice_fvcom_sup   = np.zeros((len(time),len(lon_fvcom_sup)))
		aice_fvcom_sup   = np.zeros((len(time),len(lon_fvcom_sup)))
		vice_fvcom_sup   = np.zeros((len(time),len(lon_fvcom_sup)))

try: # check if ont outputs exist
	fh_fvcom_ont     = Dataset(ncfile_fvcom_ont,mode='r')
	lon_fvcom_ont    = fh_fvcom_ont.variables['lon'][:]
	lat_fvcom_ont    = fh_fvcom_ont.variables['lat'][:]
	temp_fvcom_ont   = fh_fvcom_ont.variables['temp'][:]
	ont_exist = True
except:
	lon_fvcom_ont    = np.array([missing_value])
	lat_fvcom_ont    = np.array([missing_value])
	temp_fvcom_ont   = np.ones((len(time),1,1))*missing_value
	tice_fvcom_ont   = np.ones((len(time),1))*missing_value
	aice_fvcom_ont   = np.ones((len(time),1))*missing_value
	vice_fvcom_ont   = np.ones((len(time),1))*missing_value
	ont_exist = False
if ( ont_exist ): # check if ice outputs exist
	try: 
		tice_fvcom_ont   = fh_fvcom_ont.variables['tsfc'][:]
		aice_fvcom_ont   = fh_fvcom_ont.variables['aice'][:]
		vice_fvcom_ont   = fh_fvcom_ont.variables['vice'][:]
	except:
		tice_fvcom_ont   = np.zeros((len(time),len(lon_fvcom_ont)))
		aice_fvcom_ont   = np.zeros((len(time),len(lon_fvcom_ont)))
		vice_fvcom_ont   = np.zeros((len(time),len(lon_fvcom_ont)))

print(eri_exist, mhs_exist, sup_exist, ont_exist)
print('array shapes')
print(temp_fvcom_eri.shape)
print(temp_fvcom_sup.shape)
print(temp_fvcom_ont.shape)
print(temp_fvcom_mhs.shape)

# concatenate 
lon_fvcom0 = np.concatenate([lon_fvcom_eri,lon_fvcom_mhs,lon_fvcom_sup,lon_fvcom_ont])
lat_fvcom0 = np.concatenate([lat_fvcom_eri,lat_fvcom_mhs,lat_fvcom_sup,lat_fvcom_ont])
temp_fvcom0 = np.concatenate((temp_fvcom_eri,temp_fvcom_mhs,temp_fvcom_sup,temp_fvcom_ont),axis=2)
tice_fvcom0 = np.concatenate((tice_fvcom_eri,tice_fvcom_mhs,tice_fvcom_sup,tice_fvcom_ont),axis=1)
aice_fvcom0 = np.concatenate((aice_fvcom_eri,aice_fvcom_mhs,aice_fvcom_sup,aice_fvcom_ont),axis=1)
vice_fvcom0 = np.concatenate((vice_fvcom_eri,vice_fvcom_mhs,vice_fvcom_sup,vice_fvcom_ont),axis=1)
lon_fvcom = np.ma.masked_where( lon_fvcom0 == missing_value, lon_fvcom0 )
lat_fvcom = np.ma.masked_where( lat_fvcom0 == missing_value, lat_fvcom0 )
temp_fvcom = np.ma.masked_where( temp_fvcom0 == missing_value, temp_fvcom0 )
tice_fvcom = np.ma.masked_where( tice_fvcom0 == missing_value, tice_fvcom0 )
aice_fvcom = np.ma.masked_where( aice_fvcom0 == missing_value, aice_fvcom0 )
vice_fvcom = np.ma.masked_where( vice_fvcom0 == missing_value, vice_fvcom0 )

for nn in range(len(time)):

	print(nn,str(time[nn]))

	twsfc_fvcom = np.array(temp_fvcom[nn,0,:])
	# RRFS grid GL subset
	lon_wrfsubset = lon[x1:x2,y1:y2]
	lat_wrfsubset = lat[x1:x2,y1:y2]
	twsfc_wrf0 = np.array(0. * twsfc[nn,:,:]) # make it all zero. overwritten by interpolated values later. 

	tisfc_fvcom = np.array(tice_fvcom[nn,:])
	# HRRR grid GL subset	
	tisfc_wrf0 = np.array(0. * tisfc[nn,:,:]) # make it all zero. overwritten by interpolated values later.
	tisfc_wrf = np.array(tisfc_wrf0) # GL subset

	aicec_fvcom = np.array(aice_fvcom[nn,:])
	# HRRR grid GL subset
	aicec_wrf0 = np.array(0. * aicec[nn,:,:]) # make it all zero. overwritten by interpolated values later.
	aicec_wrf  = np.array(aicec_wrf0) # GL subset

	vicec_fvcom = np.array(vice_fvcom[nn,:])
        # HRRR grid GL subset
	vicec_wrf0 = np.array(0. * vicec[nn,:,:]) # make it all zero. overwritten by interpolated values later.
	vicec_wrf  = np.array(vicec_wrf0) # GL subset

	twsfc_wrf=interp.griddata((lon_fvcom,lat_fvcom),twsfc_fvcom,(lon_wrfsubset,lat_wrfsubset),method='nearest')#'linear')
	tisfc_wrf=interp.griddata((lon_fvcom,lat_fvcom),tisfc_fvcom,(lon_wrfsubset,lat_wrfsubset),method='nearest')#'linear')
	aicec_wrf=interp.griddata((lon_fvcom,lat_fvcom),aicec_fvcom,(lon_wrfsubset,lat_wrfsubset),method='nearest')#'linear')
	vicec_wrf=interp.griddata((lon_fvcom,lat_fvcom),vicec_fvcom,(lon_wrfsubset,lat_wrfsubset),method='nearest')#'linear')

	twsfc_wrf0[x1:x2,y1:y2]=twsfc_wrf
	tisfc_wrf0[x1:x2,y1:y2]=tisfc_wrf
	aicec_wrf0[x1:x2,y1:y2]=aicec_wrf
	vicec_wrf0[x1:x2,y1:y2]=vicec_wrf
	
	twsfc_wrf0[lakemask==0.] = missing_value
	tisfc_wrf0[lakemask==0.] = missing_value
	aicec_wrf0[lakemask==0.] = missing_value
	vicec_wrf0[lakemask==0.] = missing_value
	if ( not eri_exist): 
		twsfc_wrf0[erimask==1.] =  missing_value
		tisfc_wrf0[erimask==1.] =  missing_value
		aicec_wrf0[erimask==1.] =  missing_value
		vicec_wrf0[erimask==1.] =  missing_value
	if ( not mhs_exist):
		twsfc_wrf0[mhsmask==1.] =  missing_value
		tisfc_wrf0[mhsmask==1.] =  missing_value
		aicec_wrf0[mhsmask==1.] =  missing_value
		vicec_wrf0[mhsmask==1.] =  missing_value
	if ( not sup_exist):
		twsfc_wrf0[supmask==1.] =  missing_value
		tisfc_wrf0[supmask==1.] =  missing_value
		aicec_wrf0[supmask==1.] =  missing_value
		vicec_wrf0[supmask==1.] =  missing_value
	if ( not ont_exist):
		twsfc_wrf0[ontmask==1.] =  missing_value
		tisfc_wrf0[ontmask==1.] =  missing_value
		aicec_wrf0[ontmask==1.] =  missing_value
		vicec_wrf0[ontmask==1.] =  missing_value
 
	twsfc[nn,:,:] = twsfc_wrf0
	tisfc[nn,:,:] = tisfc_wrf0
	aicec[nn,:,:] = aicec_wrf0
	vicec[nn,:,:] = vicec_wrf0
	tsfc[nn,:,:]=twsfc_wrf0*(1.0-aicec_wrf0)+tisfc_wrf0*aicec_wrf0

fh.variables['twsfc'][:]=twsfc
fh.variables['tisfc'][:]=tisfc
fh.variables['aice'][:]=aicec
fh.variables['vice'][:]=vicec
fh.variables['tsfc'][:]=tsfc

fh.close()

if ( eri_exist ):
	fh_fvcom_eri.close()
if ( mhs_exist ):
	fh_fvcom_mhs.close()
if ( sup_exist ):
	fh_fvcom_sup.close()
if ( ont_exist ):
	fh_fvcom_ont.close()

print ('fvcom_remap.py completed successfully')
