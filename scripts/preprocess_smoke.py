#########################################################################
#                                                                       #
# Python script for fire emissions preprocessing from RAVE FRP and FRE  #
# (Li et al.,2022). Written by Johana Romero-Alvarez and Haiqin Li      #
# based on Kai Wang and Jianping Huang prototype                        #
#                                                                       #
#########################################################################

import sys
import xarray as xr
import datetime as dt
from datetime import date, time,timedelta
import pandas as pd
import numpy as np
import ESMF
from netCDF4 import Dataset
import os

#import fix files
staticdir = sys.argv[1]
ravedir = sys.argv[2]
newges_dir = sys.argv[3]
predef_grid = sys.argv[4]

#constants emissions estimation
beta= 0.38 # based on Wooster et al. 2005

#units conversion
to_s=3.6e3
fkg_to_ug=1e9
fg_to_ug=1e6

#Emission factors based on SERA US Forest Service
EF_FLM = dict({'frst':19,'hwd':9.4,'mxd':14.6,'shrb':9.3,'shrb_grs':10.7,'grs':13.3})
EF_SML = dict({'frst':28,'hwd':37.7,'mxd':17.6,'shrb':36.6,'shrb_grs':36.7,'grs':38.4})

#list of variables to interpolate
vars_emis = ["FRP_MEAN","FRP_SD","FRE","PM2.5"]

#pass env vars from  workflow
current_day = os.environ.get("CDATE")
nwges_dir = os.environ.get("NWGES_DIR")

#Fixed files directories
normal_template_file = staticdir+'/pypost_conus_basic_template.grib2'
veg_map = staticdir+'/veg_map.nc'
grid_in=  staticdir+'/grid_in.nc'
weightfile= staticdir+'/weight_file.nc'
grid_out  = staticdir+'/ds_out_base.nc'
dummy_hr_rave= staticdir+'/dummy_hr_rave.nc'
RAVE=ravedir
intp_dir=newges_dir
rave_to_intp= predef_grid+"_intp_"
filename =weightfile

#Set predefined grid
if predef_grid=='RRFS_NA_3km':
   cols,rows=2700,3950
else:
   cols,rows=1092,1820
print('PREDEF GRID',predef_grid,'cols,rows',cols,rows)

#Functions
#Create date range
def date_range(current_day):
   print('Searching for interpolated RAVE for',current_day)
   fcst_YYYYMMDDHH=dt.datetime.strptime(current_day, "%Y%m%d%H")
   previous_day=fcst_YYYYMMDDHH - timedelta(days = 1)
   date_list=pd.date_range(previous_day,periods=24,freq="H")
   fcst_dates=date_list.strftime("%Y%m%d%H")
   rave_to_intp= predef_grid+"_intp_"
   print('Current day', fcst_YYYYMMDDHH,'Persistance',previous_day)
   return fcst_dates

#Check if interoplated RAVE is available for the previous 24 hours. Create dummy RAVE if given hours are not available
def check_for_intp_rave(intp_dir,fcst_dates,rave_to_intp):
   os.chdir(intp_dir)
   sorted_obj = sorted(os.listdir(intp_dir))
   intp_avail_hours=[]
   intp_non_avail_hours=[]
   for d in range(len(fcst_dates)):
      if rave_to_intp+fcst_dates[d]+'00_'+fcst_dates[d]+'00.nc' in sorted_obj:
         print('RAVE interpolated available for',rave_to_intp+fcst_dates[d]+'00_'+fcst_dates[d]+'00.nc')
         intp_avail_hours.append(fcst_dates[d])
      else:
         print('Create interpolated RAVE for',rave_to_intp+fcst_dates[d]+'00_'+fcst_dates[d]+'00.nc')
         intp_non_avail_hours.append(fcst_dates[d])
   print('Avail_intp_hours',intp_avail_hours,'Non_avail_intp_hours',intp_non_avail_hours)
   return intp_avail_hours,intp_non_avail_hours

#Check if raw RAVE in intp_non_avail_hours is available to interpolate
def check_for_raw_rave(RAVE,intp_non_avail_hours):
   os.chdir(RAVE)
   raw_rave="Hourly_Emissions_3km_"
   updated_rave="RAVE-HrlyEmiss-3km_v1r0_blend_s"
   sorted_obj = sorted(os.listdir(RAVE))
   rave_avail=[]
   rave_avail_hours=[]
   rave_nonavail_hours_test=[]
   for d in range(len(intp_non_avail_hours)):
      if raw_rave+intp_non_avail_hours[d]+'00_'+intp_non_avail_hours[d]+'00.nc' in sorted_obj:
         print('Raw RAVE available for interpolation',raw_rave+intp_non_avail_hours[d]+'00_'+intp_non_avail_hours[d]+'00.nc')
         rave_avail.append(raw_rave+intp_non_avail_hours[d]+'00_'+intp_non_avail_hours[d]+'00.nc')
         rave_avail_hours.append(intp_non_avail_hours[d])
      else:
         print('Raw RAVE non_available for interpolation',raw_rave+intp_non_avail_hours[d]+'00_'+intp_non_avail_hours[d]+'00.nc')
         rave_nonavail_hours_test.append(intp_non_avail_hours[d])
   print("Raw RAVE available",rave_avail_hours, "rave_nonavail_hours_test",rave_nonavail_hours_test)
   return rave_avail,rave_avail_hours,rave_nonavail_hours_test

#Create source and target fields
def creates_st_fields(grid_in,grid_out):
   os.chdir(intp_dir)
   #source RAW emission grid file
   ds_in=xr.open_dataset(grid_in)
   #target (3-km) grid file
   ds_out = xr.open_dataset(grid_out)
   #source center lat/lon
   src_latt = ds_in['grid_latt']
   #target center lat/lon
   tgt_latt = ds_out['grid_latt']
   tgt_lont = ds_out['grid_lont']
   #grid shapes
   src_shape = src_latt.shape
   tgt_shape = tgt_latt.shape
   #build the ESMF grid coordinates
   srcgrid = ESMF.Grid(np.array(src_shape), staggerloc=[ESMF.StaggerLoc.CENTER, ESMF.StaggerLoc.CORNER],coord_sys=ESMF.CoordSys.SPH_DEG)
   tgtgrid = ESMF.Grid(np.array(tgt_shape), staggerloc=[ESMF.StaggerLoc.CENTER, ESMF.StaggerLoc.CORNER],coord_sys=ESMF.CoordSys.SPH_DEG)
   #read in the pre-generated weight file
   tgt_area=ds_out['area']
   #dummy source and target fields
   srcfield = ESMF.Field(srcgrid, name='test',staggerloc=ESMF.StaggerLoc.CENTER)
   tgtfield = ESMF.Field(tgtgrid, name='test',staggerloc=ESMF.StaggerLoc.CENTER)
   print('Grid in and out files available. Generating target and source fields')
   return srcfield,tgtfield,tgt_latt,tgt_lont,srcgrid,tgtgrid,src_latt,tgt_area

#Define output and variable meta data
def create_emiss_file(fout):
    fout.createDimension('t',None)
    fout.createDimension('lat',cols)
    fout.createDimension('lon',rows)
    setattr(fout,'PRODUCT_ALGORITHM_VERSION','Beta')
    setattr(fout,'TIME_RANGE','1 hour')
    setattr(fout,'RangeBeginningDate)',rave_name[21:25]+'-'+rave_name[25:27]+'-'+rave_name[27:29])
    setattr(fout,'RangeBeginningTime\(UTC-hour\)',rave_name[29:31])
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
def generate_EFs(veg_map,EF_FLM,EF_SML):
   LU_map=(veg_map)
   nc_land= xr.open_dataset(LU_map)
   vtype= nc_land['vtype'][0,:,:]
   vtype_val=vtype.values
   #Processing EF
   arr_parent_EFs=np.zeros((cols, rows))
   for i in range(cols):
      for j in range(rows):
         efs=vtype_val[i][j]
         if efs == 1 or efs == 2: #needle and bradleaf
            EF_12= (0.75*EF_FLM['frst'])+(0.25*EF_SML['frst'])
            arr_parent_EFs[i][j] = EF_12
         elif efs == 3 or efs == 4: #deciduos
            EF_34= (0.80*EF_FLM['hwd'])+(0.20*EF_SML['hwd'])
            arr_parent_EFs[i][j] = EF_34
         elif efs == 5: # mixed
            EF_5= (0.85*EF_FLM['mxd'])+(0.15*EF_SML['mxd'])
            arr_parent_EFs[i][j] = EF_5
         elif efs == 6 or efs == 7: #Shrublands
            EF_6= (0.95*EF_FLM['shrb'])+(0.05*EF_SML['shrb'])
            arr_parent_EFs[i][j] = EF_6
         elif efs == 8: #woody savannas
            EF_7= (0.95*EF_FLM['shrb_grs'])+(0.05*EF_SML['shrb_grs'])
            arr_parent_EFs[i][j] = EF_7
         elif efs == 9 or efs == 10: #savannas & grasslandas
            EF_8= (0.95*EF_FLM['grs'])+(0.05*EF_SML['grs'])
            arr_parent_EFs[i][j] = EF_8
         elif efs == 12 or efs == 14 : #cropland and natural veg.
            EF_9= (0.95*EF_FLM['grs'])+(0.05*EF_SML['grs'])
            arr_parent_EFs[i][j] = EF_9
         else:
            EF_rest= 0
            arr_parent_EFs[i][j] = EF_rest
   return arr_parent_EFs

#create a dummy hr rave interpolated file for rave_non_avail_hours and when regridder fails
def create_dummy(intp_dir,dummy_hr_rave,generate_hr_dummy,rave_avail,rave_nonavail_hours_test,rave_to_intp):
   os.chdir(intp_dir)
   if generate_hr_dummy==True:
      for i in rave_avail:
         print('Producing RAVE dummy files for all hrs:',i)
         dummy_rave=xr.open_dataset(dummy_hr_rave)
         missing_rave=xr.zeros_like(dummy_rave)
         missing_rave.attrs['RangeBeginningDate']=i[0:4]+'-'+i[4:6]+'-'+i[6:8]
         missing_rave.attrs['RangeBeginningTime\(UTC-hour\)']= i[8:10]
         missing_rave.to_netcdf(rave_to_intp+i[21:49],unlimited_dims={'t':True})
   else:
      for i in rave_nonavail_hours_test:
         print('Producing RAVE dummy files for:',i)
         dummy_rave=xr.open_dataset(dummy_hr_rave)
         missing_rave=xr.zeros_like(dummy_rave)
         missing_rave.attrs['RangeBeginningDate']=i[0:4]+'-'+i[4:6]+'-'+i[6:8]
         missing_rave.attrs['RangeBeginningTime\(UTC-hour\)']= i[8:10]
         missing_rave.to_netcdf(rave_to_intp+i+'00_'+i+'00.nc',unlimited_dims={'t':True})


#Sort raw RAVE, create source and target filelds, and compute emissions factors
fcst_dates=date_range(current_day)
intp_avail_hours,intp_non_avail_hours=check_for_intp_rave(intp_dir,fcst_dates,rave_to_intp)
rave_avail,rave_avail_hours,rave_nonavail_hours_test=check_for_raw_rave(RAVE,intp_non_avail_hours)
srcfield,tgtfield,tgt_latt,tgt_lont,srcgrid,tgtgrid,src_latt,tgt_area=creates_st_fields(grid_in,grid_out)
arr_parent_EFs=generate_EFs(veg_map,EF_FLM,EF_SML)
#generate regridder
try:
   print('GENERATING REGRIDDER')
   regridder = ESMF.RegridFromFile(srcfield, tgtfield,filename)
   print('REGRIDDER FINISHED')
except ValueError:
   print('REGRIDDER FAILS USE DUMMY EMISSIONS')
   use_dummy_emiss=True
   generate_hr_dummy=True
else:
   use_dummy_emiss=False
   generate_hr_dummy=False
#process RAVE available for interpolation
sorted_obj = sorted(os.listdir(RAVE))
for f in range(len(rave_avail)):
   os.chdir(RAVE)
   if use_dummy_emiss==False and rave_avail[f] in sorted_obj:
      print('Interpolating:',rave_avail[f])
      rave_name=rave_avail[f]
      ds_togrid=xr.open_dataset(rave_avail[f])
      QA=ds_togrid['QA']       #QC flags for fire emiss
      FRE_threshold= ds_togrid['FRE']
      print('=============before regridding===========','FRP_MEAN')
      print(np.sum(ds_togrid['FRP_MEAN'],axis=(1,2)))
      os.chdir(intp_dir)
      fout=Dataset(rave_to_intp+rave_name[21:33]+'_'+rave_name[21:33]+'.nc','w')
      create_emiss_file(fout)
      Store_latlon_by_Level(fout,'geolat',tgt_latt,'cell center latitude','degrees_north','2D','-9999.f','1.f')
      Store_latlon_by_Level(fout,'geolon',tgt_lont,'cell center longitude','degrees_east','2D','-9999.f','1.f')
      for svar in vars_emis:
         print(svar)
         srcfield = ESMF.Field(srcgrid, name=svar)
         tgtfield = ESMF.Field(tgtgrid, name=svar)
         src_rate = ds_togrid[svar].fillna(0)
         #apply QC flags
         src_QA=xr.where(FRE_threshold>1000,src_rate,0.0)
         src_cut = src_QA[0,:,:]
         src_cut = xr.where(src_latt>7.22291,src_cut,0.0)
         srcfield.data[...] = src_cut
         tgtfield = regridder(srcfield, tgtfield)
         if svar=='FRP_MEAN':
            Store_by_Level(fout,'frp_avg_hr','Mean Fire Radiative Power','MW','3D','0.f','1.f')
            tgt_rate = tgtfield.data
            fout.variables['frp_avg_hr'][0,:,:] = tgt_rate
            print('=============after regridding==========='+svar)
            print(np.sum(tgt_rate))
         elif svar=='FRE':
            Store_by_Level(fout,'ebb_smoke_hr','PM2.5 emissions','ug m-2 h-1','3D','0.f','1.f')
            tgt_rate = tgtfield.data
            tgt_rate = tgt_rate*arr_parent_EFs*beta
            tgt_rate = (tgt_rate*fg_to_ug)/to_s
            tgt_rate = tgt_rate/tgt_area
            tgt_rate =xr.DataArray(tgt_rate)
            fout.variables['ebb_smoke_hr'][0,:,:] = tgt_rate
         elif svar=='FRP_SD':
            Store_by_Level(fout,'frp_std_hr','Standar Deviation of Fire Radiative Energy','MW','3D','0.f','1.f')
            tgt_rate = tgtfield.data
            fout.variables['frp_std_hr'][0,:,:] = tgt_rate
         elif svar=='PM2.5':
            Store_by_Level(fout,'ebu_oc','Particulate matter < 2.5 ug','ug m-2 s-1','3D','0.f','1.f')
            tgt_rate = tgtfield.data/to_s
            fout.variables['ebu_oc'][0,:,:] = tgt_rate
         else :
            tgt_rate = tgtfield.data/to_s
            fout.variables[svar][0,:,:] = tgt_rate
      ds_togrid.close()
      fout.close()
#Create dummy hr files
create_dummy(intp_dir,dummy_hr_rave,generate_hr_dummy,rave_avail,rave_nonavail_hours_test,rave_to_intp)
