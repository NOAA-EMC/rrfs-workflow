###################################################
#                                                 #
# RRFS-SD smoke preprocessing                     #
#                                                 #
###################################################

import sys
import xarray as xr
import datetime as dt
from datetime import date, time,timedelta
import pandas as pd
import numpy as np
import ESMF
from netCDF4 import Dataset
import os
import shutil

# fix files
staticdir = sys.argv[1]
ravedir = sys.argv[2]
newges_dir = sys.argv[3]
predef_grid = sys.argv[4]
#Constants
beta= 0.38
#units conversion
to_s=3.6e3
fkg_to_ug=1e9
fg_to_ug=1e6

#Emission factors
EF_FLM = dict({'frst':19,'hwd':9.4,'mxd':14.6,'shrb':9.3,'shrb_grs':10.7,'grs':13.3})
EF_SML = dict({'frst':28,'hwd':37.7,'mxd':17.6,'shrb':36.6,'shrb_grs':36.7,'grs':38.4})

#Bring/create env vars from  workflow
current_day = os.environ.get("CDATE")
nwges_dir = os.environ.get("NWGES_DIR")

#Fixed files directories
normal_template_file = staticdir+'/pypost_conus_basic_template.grib2'
veg_map =   staticdir+'/veg_map.nc'
grid_in=    staticdir+'/grid_in_new_dom.nc'
weightfile= staticdir+'/CONUS_G2_3km_weight_file.nc'
grid_out  = staticdir+'/ds_out_base.nc'
dummy_hr_rave=staticdir+'/dummy_hr_rave.nc'

#Create date range
print('Searching for interpolated RAVE for',current_day)
fcst_YYYYMMDDHH=dt.datetime.strptime(current_day, "%Y%m%d%H")
previous_day=fcst_YYYYMMDDHH - timedelta(days = 1)
date_list=pd.date_range(previous_day,periods=24,freq="H")
fcst_dates=date_list.strftime("%Y%m%d%H")
rave_to_intp= predef_grid+"_intp_"
#rave_to_intp="CONUS_3km_intp_"
print('fcst_YYYYMMDDHH', fcst_YYYYMMDDHH, previous_day, fcst_dates[5])

#Check if interoplated RAVE is available for the previous 24 hours. Create dummy RAVE if given hours are not available
RAVE=ravedir
intp_dir=newges_dir

os.chdir(intp_dir)
sorted_obj = sorted(os.listdir(intp_dir))
intp_avail_hours=[]
intp_non_avail_hours=[]
for d in range(len(fcst_dates)):
    #print(d)
    if rave_to_intp+fcst_dates[d]+'00_'+fcst_dates[d]+'00.nc' in sorted_obj:
       print('RAVE interpolated available for',rave_to_intp+fcst_dates[d]+'00_'+fcst_dates[d]+'00.nc')
       intp_avail_hours.append(fcst_dates[d])
    else:
       print('Create interpolated RAVE for',rave_to_intp+fcst_dates[d]+'00_'+fcst_dates[d]+'00.nc') 
       intp_non_avail_hours.append(fcst_dates[d])
print('Avail_intp_hours',intp_avail_hours,'Non_avail_intp_hours',intp_non_avail_hours)

#Check if raw RAVE in intp_non_avail_hours is available to interpolate
os.chdir(RAVE)
raw_rave="Hourly_Emissions_3km_"
sorted_obj = sorted(os.listdir(RAVE))

rave_avail=[]
rave_avail_hours=[]
rave_nonavail_hours_test=[]
for d in range(len(intp_non_avail_hours)):
#    print(d)
    if raw_rave+intp_non_avail_hours[d]+'00_'+intp_non_avail_hours[d]+'00.nc' in sorted_obj:
       print('Raw RAVE available for interpolation',raw_rave+intp_non_avail_hours[d]+'00_'+intp_non_avail_hours[d]+'00.nc')
       rave_avail.append(raw_rave+intp_non_avail_hours[d]+'00_'+intp_non_avail_hours[d]+'00.nc')
       rave_avail_hours.append(intp_non_avail_hours[d]) 
    else:
       print('Raw RAVE non_available for interpolation',raw_rave+intp_non_avail_hours[d]+'00_'+intp_non_avail_hours[d]+'00.nc')
       rave_nonavail_hours_test.append(intp_non_avail_hours[d])
print("Raw RAVE available",rave_avail_hours, "rave_nonavail_hours_test",rave_nonavail_hours_test)

#rave_non_avail_hours= [x for x in fcst_dates if x not in rave_avail_hours] 
#print("Raw RAVE non available",rave_non_avail_hours)

#Interpolate raw rave_avail_hours
os.chdir(intp_dir)
print('INTERPOLATION SCRIPT', os.getcwd())

#source RAW emission grid file
ds_in=xr.open_dataset(grid_in)

#target (3-km) grid file
ds_out = xr.open_dataset(grid_out)
tgt_area=ds_out['area']

#source center lat/lon
src_latt = ds_in['grid_latt']
src_lont = ds_in['grid_lont']
#source corner lat/lon
src_lat  = ds_in['grid_lat']
src_lon  = ds_in['grid_lon']

#target center lat/lon
tgt_latt = ds_out['grid_latt']
tgt_lont = ds_out['grid_lont']
#target center lat/lon
tgt_lat  = ds_out['grid_lat']
tgt_lon  = ds_out['grid_lon']

#grid shapes
src_shape = src_latt.shape
tgt_shape = tgt_latt.shape
print('SHAPE',src_shape)

#build the ESMF grid coordinates
srcgrid = ESMF.Grid(np.array(src_shape), staggerloc=[ESMF.StaggerLoc.CENTER, ESMF.StaggerLoc.CORNER],coord_sys=ESMF.CoordSys.SPH_DEG)
tgtgrid = ESMF.Grid(np.array(tgt_shape), staggerloc=[ESMF.StaggerLoc.CENTER, ESMF.StaggerLoc.CORNER],coord_sys=ESMF.CoordSys.SPH_DEG)

#pointers to source and target center grid coordinates
src_cen_lon = srcgrid.get_coords(0, staggerloc=ESMF.StaggerLoc.CENTER)
src_cen_lat = srcgrid.get_coords(1, staggerloc=ESMF.StaggerLoc.CENTER)

tgt_cen_lon = tgtgrid.get_coords(0, staggerloc=ESMF.StaggerLoc.CENTER)
tgt_cen_lat = tgtgrid.get_coords(1, staggerloc=ESMF.StaggerLoc.CENTER)

#pass the actual center grid coordinates to pointers
src_cen_lon[...] = src_lont
src_cen_lat[...] = src_latt

tgt_cen_lon[...] = tgt_lont
tgt_cen_lat[...] = tgt_latt

#read in the pre-generated weight file to speed up regridding
filename =weightfile 

#dummy source and target fields
srcfield = ESMF.Field(srcgrid, name='test')
tgtfield = ESMF.Field(tgtgrid, name='test')

#generate regridder
print('GENERATING REGRIDDER')
regridder = ESMF.RegridFromFile(srcfield, tgtfield,filename)

#Functions to define output variable meta data
def Store_time_by_Level(fout,varname,var,long_name,yr,mm,dd,cyc):
     if varname=='time':
      var_out = fout.createVariable(varname, 'f4', ('t'))
      var_out.long_name = long_name
      var_out.standard_name = long_name
      fout.variables[varname][:]=var
      var_out.calendar = 'gregorian'
      var_out.axis='t'
      var_out.time_increment='010000'
def Store_latlon_by_Level(fout,varname,var,long_name,units,dim,fval,sfactor):
    if dim=='2D':
       var_out = fout.createVariable(varname,   'f4', ('lat','lon'))
       var_out.units=units
       var_out.long_name=long_name
       var_out.standard_name=varname
       fout.variables[varname][:]=var
       var_out.FillValue=fval
       var_out.coordinates='geolat geolon'
def Store_by_Level(fout,varname,long_name,units,dim,fval,sfactor):
    if dim=='3D':
       var_out = fout.createVariable(varname,   'f4', ('t','lat','lon'))
       var_out.units=units
       var_out.long_name = long_name
       var_out.standard_name=long_name
       var_out.FillValue=fval
       var_out.coordinates='t geolat geolon'

#Open LU map and extract land categories
LU_map=(veg_map)
nc_land= xr.open_dataset(LU_map)
vtype= nc_land['vtype'][0,:,:]
vtype_val=vtype.values

#Processing EF
cols=1092
rows=1820
arr_parent_EFs=np.zeros((cols, rows))
for i in range(cols):
        for j in range(rows):
            efs=vtype_val[i][j]
#            print((efs))
            if efs == 1 or efs == 2:
               EF_12= (0.75*EF_FLM['frst'])+(0.25*EF_SML['frst'])
               #print(EF_12)
               arr_parent_EFs[i][j] = EF_12
            elif efs == 3 or efs == 4:
               EF_34= (0.80*EF_FLM['hwd'])+(0.20*EF_SML['hwd'])
               arr_parent_EFs[i][j] = EF_34
            elif efs == 5:
               EF_5= (0.85*EF_FLM['mxd'])+(0.15*EF_SML['mxd'])
               arr_parent_EFs[i][j] = EF_5
            elif efs == 6 or efs == 7:
               EF_6= (0.95*EF_FLM['shrb'])+(0.05*EF_SML['shrb'])
               arr_parent_EFs[i][j] = EF_6
            elif efs == 8:
               EF_7= (0.95*EF_FLM['shrb_grs'])+(0.05*EF_SML['shrb_grs'])
               arr_parent_EFs[i][j] = EF_7
            elif efs == 9 or efs == 10:
               EF_8= (0.95*EF_FLM['grs'])+(0.05*EF_SML['grs'])
               arr_parent_EFs[i][j] = EF_8
            elif efs == 12 or efs == 13 or efs == 14 :
               EF_9= (0.95*EF_FLM['grs'])+(0.05*EF_SML['grs'])
               arr_parent_EFs[i][j] = EF_9
            else:
               #print('NADA')
               EF_rest= 0
               arr_parent_EFs[i][j] = EF_rest

#variable list
vars_emis = ["PM2.5","FRP_MEAN","FRP_SD","FRE"]

#open raw RAVE available for interpolation 
for f in range(len(rave_avail)):
#    print(f)
    os.chdir(RAVE)
    if rave_avail[f] in sorted_obj:
       print(rave_avail[f])
       rave_name=rave_avail[f]
       ds_togrid=xr.open_dataset(rave_avail[f])
       print('DS to GRID',ds_togrid)
       area=ds_togrid['area']   #source area (km^-2)
       QA=ds_togrid['QA']       #QC flags for fire emis
       FRE_threshold= ds_togrid['FRE']
       os.chdir(intp_dir)
       fout=Dataset(rave_to_intp+rave_name[21:33]+'_'+rave_name[21:33]+'.nc','w')
       fout.createDimension('t',None) 
       fout.createDimension('lat',1092)
       fout.createDimension('lon',1820)
       setattr(fout,'PRODUCT_ALGORITHM_VERSION','Beta')
       setattr(fout,'TIME_RANGE','1 hour')
       setattr(fout,'RangeBeginningDate)',rave_name[21:25]+'-'+rave_name[25:27]+'-'+rave_name[27:29])
       setattr(fout,'RangeBeginningTime\(UTC-hour\)',rave_name[29:31])
       setattr(fout,'WestBoundingCoordinate\(degree\)','227.506f')
       setattr(fout,'EastBoundingCoordinate\(degree\)','297.434f')
       setattr(fout,'NorthBoundingCoordinate\(degree\)','52.058f')
       setattr(fout,'SouthBoundingCoordinate\(degree\)','22.136f')
       Store_latlon_by_Level(fout,'geolat',tgt_latt,'cell center latitude','degrees_north','2D','-9999.f','1.f')
       Store_latlon_by_Level(fout,'geolon',tgt_lont,'cell center longitude','degrees_east','2D','-9999.f','1.f')
       for svar in vars_emis:
           print(svar)
           srcfield = ESMF.Field(srcgrid, name=svar)
           tgtfield = ESMF.Field(tgtgrid, name=svar)
           if svar=='FRP_MEAN':
              Store_by_Level(fout,'frp_avg_hr','Mean Fire Radiative Power','MW','3D','0.f','1.f')
           elif svar=='FRE':
              Store_by_Level(fout,'ebb_smoke_hr','Fire Radiative Energy','ug m-2 s-1','3D','0.f','1.f')
           elif svar=='FRP_SD':
              Store_by_Level(fout,'frp_std_hr','Standar Deviation of Fire Radiative Energy','MW','3D','0.f','1.f')
           elif svar=='PM2.5':
              Store_by_Level(fout,'ebu_oc','PM2.5 emissions','ug m-2 h-1','3D','0.f','1.f')
           else :
              Store_by_Level(fout,svar,svar+' Biomass Emissions','kg m-2 h-1','3D','0.f','1.f')
#              #converted source data from kg to kg/km^2 (need fluxes instead of mass for regridding)
           src_rate = ds_togrid[svar].fillna(0)/area
           #apply QC flags
           src_QA=xr.where(((QA>1)&(FRE_threshold>1000)),src_rate,0.0)
           #print(src_QA)
           srcfield.data[...] = src_QA[0,:,:]
           #print(srcfield.data)
           #generate the regridded fields (target)
           tgtfield = regridder(srcfield, tgtfield)
           if svar=='FRP_MEAN':
              tgt_rate = tgtfield.data*(tgt_area*1.e-6)
              fout.variables['frp_avg_hr'][0,:,:] = tgt_rate
           elif svar=='FRE':
              tgt_rate = tgtfield.data*(tgt_area*1.e-6)
              tgt_rate = tgt_rate*arr_parent_EFs*beta
              tgt_rate = (tgt_rate*fg_to_ug)/to_s
              tgt_rate = tgt_rate/tgt_area
              tgt_rate =xr.DataArray(tgt_rate)
              fout.variables['ebb_smoke_hr'][0,:,:] = tgt_rate
           elif svar=='FRP_SD':
              tgt_rate = tgtfield.data*(tgt_area*1.e-6)
              fout.variables['frp_std_hr'][0,:,:] = tgt_rate
           elif svar=='PM2.5':
              tgt_rate = tgtfield.data*1.e-6#/3600 #unit conversion from kg/km^2 to kg/m^2/s
              tgt_rate = (tgt_rate*fkg_to_ug)/(to_s*tgt_area)
              #print(tgt_rate)
              fout.variables['ebu_oc'][0,:,:] = tgt_rate
           else :
              tgt_rate = tgtfield.data*1.e-6#/3600 #unit conversion from kg/km^2 to kg/m^2/s
              #print(tgt_rate)
              fout.variables[svar][0,:,:] = tgt_rate
       ds_togrid.close()
       fout.close()

#create a dummy hr rave interpolated file for rave_non_avail_hours
os.chdir(intp_dir)
for i in rave_nonavail_hours_test:
     print('Producing raw RAVE dummy files for:',i)
     dummy_rave=xr.open_dataset(dummy_hr_rave)
     missing_rave=xr.zeros_like(dummy_rave)
     missing_rave.attrs['RangeBeginningDate']=i[0:4]+'-'+i[4:6]+'-'+i[6:8]
     missing_rave.attrs['RangeBeginningTime\(UTC-hour\)']= i[8:10]
     missing_rave.to_netcdf(rave_to_intp+i+'00_'+i+'00.nc',unlimited_dims={'t':True})

