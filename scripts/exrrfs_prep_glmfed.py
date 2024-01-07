#######################################################################
#                                                                     #
# Pre-process GOES-R GLM gridded Flash Extent Density (FED) data      #
# for use with OU CAPS ensemble assimilation using GSI                #
# (requires 1D arrays of values/lats/lons based on 2D gridded tiles)  #
#                                                                     #
# At the same time, add "fed" variable to control member and ensemble #
#                                         restart phys files          #
#                                                                     #
#                                                                     #
# Amanda Back                                                         #
# 27 Jul 2023                                                         #
#                                                                     #
#######################################################################

import os, glob
import numpy as np
import datetime as dt
import netCDF4 as nc
import time
import pickle


def addmodelfed(restartpath):

  ########################################################################
  #                                                                      #
  # add "fed" variable to control member and ensemble restart phys files #
  #                                                                      #
  ########################################################################

  # specify some variables used to convert graupel
  b = 15.75255713 # flashes/minute
  c = .193891366 # e-9 kg^-1
  d = -1.21524526 # e9 kg
  a = -b*np.tanh(-c*d) # flashes/minute
  fedcutoff = 8 # flashes/minute

  # make variables for names of model files
  corefile = restartpath+'fv_core.res.tile1.nc' # need diff names for ensembles?
  tracerfile = restartpath+'fv_tracer.res.tile1.nc'
  physfile = restartpath+'phy_data.nc'

  # open core file to read in delta pressure, then close
  u = nc.Dataset(corefile,'r')
  delp = u['delp'][0] # delta pressure in Pascals
  u.close()

  # open tracer file to read graupel, then close
  u = nc.Dataset(tracerfile,'r')
  graupel = u['graupel'][0] # units kg/kg 

  # open physics file to write FED
  u = nc.Dataset(physfile,'r+')

  if 'flash_extent_density' in u.variables.keys():
    print('FED field exists! Exiting')
    u.close()
    return()


  # units of [delp/g] = Pa*s^2/m = N*s^2/m^3 = kg/m^2 = dry air mass per m^2 in the cell
  # * by 3000 m * 3000 m = 9e6=.009e9 for air mass in cell, in kg
  # then * by graupel in kg/kg to get total graupel mass in cell
  # and sum over the column for graupel mass in column

  graupel_per_area = np.sum(0.009*delp*graupel/9.8,axis=0)

  # next sum graupel_per_area over 5x5 grids
  xsumming = np.zeros([5,len(graupel_per_area),len(graupel_per_area[0])+4])
  for i in range(5):
     xsumming[i][:,i:i+len(graupel_per_area[0])] = graupel_per_area
  xsum = np.sum(xsumming,axis=0)
  ysumming = np.zeros([5,len(xsum)+4,len(xsum[0])])
  for i in range(5):
     ysumming[i][i:i+len(xsum)] = xsum
  ysum = np.sum(ysumming,axis=0)
  graupel_per_area_5x5 = ysum[2:-2,2:-2]

  # Convert to FED by the formula
  # FED = a + b*tanh(c*(graupel mass - d))
  # for (a,b,c,d) defined at the top of the script
  # at which point the units scaled by 1e9 and 1e-9 wash out
  fed = a+b*np.tanh(c*(graupel_per_area_5x5-d))

  # apply the max FED cutoff defined at the top
  fed = np.min([fed,fedcutoff*np.ones(np.shape(fed))],axis=0)

  # add z- and Time dimensions
  fed = np.array([[fed for i in range(u.dimensions['zaxis_1'].size)]],np.float32)

  # add 4D FED grid to tracer NetCDF and close
  # Time,zaxis_1,yaxis_1,xaxis_1 are dimensions to write
  fed_out = u.createVariable('flash_extent_density',np.float32,('Time','zaxis_1','yaxis_1','xaxis_1'))
  fed_out[:] = fed.astype('float32')
  u.close()
  return()

def process_fulldisk_fed():

  #####################################################################
  #                                                                   #
  # preprocess GLM observations into thinned list of nonzero elements #
  #                                                                   #
  #####################################################################

  # read in environment variables
  inDate   = os.environ.get("CDATE")
  out_path = os.getcwd()
  obs_west = os.environ.get("OBS_WEST")
  obs_east = os.environ.get("OBS_EAST")
  fixdir   = os.environ.get("FIX_GSI")
  fedcutoff = 8

  # format datetime obj
  myDate = dt.datetime(int(inDate[:4]),int(inDate[4:6]),int(inDate[6:8]),int(inDate[8:10]))

  # define some variables
  outFile = out_path+'/fedobs.nc'
  print(outFile)
  obs_paths = [obs_east,obs_west]
  goes_i = [16,18]
  domains = ['east','west']

  # initialize arrays
  out_fed = []
  out_lats = []
  out_lons = []

  for i in range(2):
    p = obs_paths[i]
    d = domains[i]
    gi = goes_i[i]
    # open static lat/lon coordinates
    glmll = nc.Dataset(fixdir+'/glm'+d+'_full_2km_lat_lon.nc','r')
    lat = glmll['lat'][:]
    lon = glmll['lon'][:]
    glmll.close()
    thin_by = np.zeros(np.shape(lat),dtype=np.uint8)
    thin_by[::8,::8] = 1 # this thinning matches how it was done for tiles
    # thin_by[::6,::6] = 1
    lat = np.ndarray.flatten(lat)
    lon = np.ndarray.flatten(lon)
    thin_by = np.ndarray.flatten(thin_by)
    thin_by[np.where(np.ma.getmask(lon)==True)]=0
    lat = lat[np.where(thin_by>0)]
    lon = lon[np.where(thin_by>0)]
    # open obs files and process
    this_glm = np.zeros(len(lat))
    count = 0
    for m in range(1,6):
        this_date = myDate-dt.timedelta(minutes=m)
        jday = (this_date-dt.datetime(this_date.year-1,12,31)).days
        f = glob.glob(p+'/*G%02d_s%04d%03d%02d%02d000*.nc'%(gi,this_date.year,jday,this_date.hour,this_date.minute))
        if len(f)==1: 
          u = nc.Dataset(f[0],'r')
          this_glm = this_glm + np.ndarray.flatten(np.ma.getdata(u['Flash_extent_density'][:]))[np.where(thin_by>0)]
          u.close()
          count = count + 1
    if count>0:
        lat = lat[np.where(this_glm>0)]
        lon = lon[np.where(this_glm>0)]
        this_glm = this_glm[np.where(this_glm>0)]
        this_glm = np.min([this_glm/float(count),fedcutoff*np.ones(np.shape(this_glm))],axis=0) # average and impose cutoff
        out_fed = out_fed + [z for z in this_glm]
        out_lats = out_lats + [z for z in lat]
        out_lons = out_lons + [z for z in lon]
  # write output to NetCDF
  fout = nc.Dataset(outFile, 'w')
  fout.createDimension('ntime', 1)
  fout.createDimension('nobs', len(out_lats))
  fout.createVariable('time', 'f8', 'ntime') #seconds since 2000-01-01 12:00:00
  fout.createVariable('lat', 'f8', 'nobs')
  fout.createVariable('lon', 'f8', 'nobs')
  fout.createVariable('numobs', 'i4', ('ntime'))
  fout.createVariable('value', 'f8', ('nobs'))

  fout.variables['time'][:] = float((myDate-dt.datetime(2000,1,1,12)).total_seconds())
  fout.variables['lat'][:] = out_lats
  fout.variables['lon'][:] = out_lons
  fout.variables['numobs'][:] = len(out_lats)
  fout.variables['value'][:] = out_fed
  fout.close()
  print('FED obs found:',len(out_lats))
  return()

def process_emc_tiles():

  #####################################################################
  #                                                                   #
  # preprocess GLM observations into thinned list of nonzero elements #
  #                                                                   #
  #####################################################################

  # read in environment variables
  inDate   = os.environ.get("CDATE")
  out_path = os.getcwd()
  obs_west = os.environ.get("OBS_WEST")
  obs_east = os.environ.get("OBS_EAST")
  fixdir   = os.environ.get("FIX_GSI")

  # format datetime obj
  myDate = dt.datetime(int(inDate[:4]),int(inDate[4:6]),int(inDate[6:8]),int(inDate[8:10]))

  # open static conversion file from tile to lat/lon coordinate
  glmmaps = pickle.load(open(fixdir+'/glmtiles.pkl','rb'))

  # define some variables
  outFile = out_path+'/fedobs.nc'
  print(outFile)
  obs_paths = [obs_east,obs_west]
  goes_i = ['l','m']
  domains = ['east','west']
  tilenames = ['AA','AB','AC','AD','AF','AG','AH','AI','AK','AL','AM','AN','AO','AP','AQ','AR','AS','AT','AU','AV','AW','AX','AY','AZ','BA','BB']
  tilelocs  = ['NW11','NW12','NE11','NE12','NW14','NW15','NE13','NE14','NW21','NW22','NW23','NE21','NE22','NE23','NW24','NW25','NW26','NE24','NE25','NE26','NW27','NW28','NW29','NE27','NE28','NE29']

  # initialize arrays
  out_fed = []
  out_lats = []
  out_lons = []

  # open tile files and process
  for i in range(2):
    g = goes_i[i]
    p = obs_paths[i]
    d = domains[i]
    for t in range(len(tilenames)):
      lat = glmmaps[tilenames[t]][d]['lat']
      lon = glmmaps[tilenames[t]][d]['lon']
      thin_by = glmmaps[tilenames[t]][d]['thin_by']
      this_glm = np.zeros(len(lat))
      count = 0
      for m in range(5):
        this_date = myDate-dt.timedelta(minutes=m)
        f = p + '/00'+g+'f1_'+tilelocs[t]+'_%04d%02d%02d%02d%02d00'%(this_date.year,this_date.month,this_date.day,this_date.hour,this_date.minute)
        if os.path.exists(f): 
          u = nc.Dataset(f,'r')
          this_glm = this_glm + np.ndarray.flatten(np.ma.getdata(u['Flash_extent_density'][:]))[np.where(thin_by>0)]
          u.close()
          count = count + 1
      if count>0:
        lat = lat[np.where(this_glm>0)]
        lon = lon[np.where(this_glm>0)]
        this_glm = this_glm[np.where(this_glm>0)]
        this_glm = this_glm/5. # average
        out_fed = out_fed + [z for z in this_glm]
        out_lats = out_lats + [z for z in lat]
        out_lons = out_lons + [z for z in lon]
  # write output to NetCDF
  fout = nc.Dataset(outFile, 'w')
  fout.createDimension('ntime', 1)
  fout.createDimension('nobs', len(out_lats))
  fout.createVariable('time', 'f8', 'ntime') #seconds since 2000-01-01 12:00:00
  fout.createVariable('lat', 'f8', 'nobs')
  fout.createVariable('lon', 'f8', 'nobs')
  fout.createVariable('numobs', 'i4', ('ntime'))
  fout.createVariable('value', 'f8', ('nobs'))

  fout.variables['time'][:] = float((myDate-dt.datetime(2000,1,1,12)).total_seconds())
  fout.variables['lat'][:] = out_lats
  fout.variables['lon'][:] = out_lons
  fout.variables['numobs'][:] = len(out_lats)
  fout.variables['value'][:] = out_fed
  fout.close()
  print('FED obs found:',len(out_lats))
  return()

def process_gsl_tiles():

  #####################################################################
  #                                                                   #
  # preprocess GLM observations into thinned list of nonzero elements #
  #                                                                   #
  #####################################################################

  # read in environment variables
  inDate   = os.environ.get("CDATE")
  out_path = os.getcwd()
  obs_west = os.environ.get("OBS_WEST")
  obs_east = os.environ.get("OBS_EAST")
  fixdir   = os.environ.get("FIX_GSI")

  # format datetime obj
  myDate = dt.datetime(int(inDate[:4]),int(inDate[4:6]),int(inDate[6:8]),int(inDate[8:10]))

  # open static conversion file from tile to lat/lon coordinate
  glmmaps = pickle.load(open(fixdir+'/glmtiles.pkl','rb'))

  # define some variables
  outFile = out_path+'/fedobs.nc'
  print(outFile)
  obs_paths = [obs_east,obs_west]
  goes_i = ['S','T']
  domains = ['east','west']
  tilenames = ['AA','AB','AC','AD','AF','AG','AH','AI','AK','AL','AM','AN','AO','AP','AQ','AR','AS','AT','AU','AV','AW','AX','AY','AZ','BA','BB']

  # initialize arrays
  out_fed = []
  out_lats = []
  out_lons = []

  # open tile files and process
  for i in range(2):
    g = goes_i[i]
    p = obs_paths[i]
    d = domains[i]
    for t in tilenames:
      lat = glmmaps[t][d]['lat']
      lon = glmmaps[t][d]['lon']
      thin_by = glmmaps[t][d]['thin_by']
      this_glm = np.zeros(len(lat))
      count = 0
      for m in range(1,6):
        this_date = myDate-dt.timedelta(minutes=m)
        f = p+'/%04d%02d%02d_%02d%02d.TIR'%(this_date.year,this_date.month,this_date.day,this_date.hour,this_date.minute)+g+'00.KNES.P'+t+'.nc'
        if os.path.exists(f): 
          u = nc.Dataset(f,'r')
          this_glm = this_glm + np.ndarray.flatten(np.ma.getdata(u['Flash_extent_density'][:]))[np.where(thin_by>0)]
          u.close()
          count = count + 1
      if count>0:
        lat = lat[np.where(this_glm>0)]
        lon = lon[np.where(this_glm>0)]
        this_glm = this_glm[np.where(this_glm>0)]
        this_glm = this_glm/5. # average
        out_fed = out_fed + [z for z in this_glm]
        out_lats = out_lats + [z for z in lat]
        out_lons = out_lons + [z for z in lon]
  # write output to NetCDF
  fout = nc.Dataset(outFile, 'w')
  fout.createDimension('ntime', 1)
  fout.createDimension('nobs', len(out_lats))
  fout.createVariable('time', 'f8', 'ntime') #seconds since 2000-01-01 12:00:00
  fout.createVariable('lat', 'f8', 'nobs')
  fout.createVariable('lon', 'f8', 'nobs')
  fout.createVariable('numobs', 'i4', ('ntime'))
  fout.createVariable('value', 'f8', ('nobs'))

  fout.variables['time'][:] = float((myDate-dt.datetime(2000,1,1,12)).total_seconds())
  fout.variables['lat'][:] = out_lats
  fout.variables['lon'][:] = out_lons
  fout.variables['numobs'][:] = len(out_lats)
  fout.variables['value'][:] = out_fed
  fout.close()
  print('FED obs found:',len(out_lats))
  return()

if __name__=="__main__":

  mode = os.environ.get("MODE")
  if mode=="FULL":
    process_fulldisk_fed()
  elif mode=="TILES":
    process_gsl_tiles()
  elif mode=="EMC":
    process_emc_tiles()
  else:
    print("Invalid MODE specified. Valid MODES are FULL, TILES, EMC.")
    quit()

  ########################################################
  #                                                      #
  # add model FED to restart and ensemble files in place #
  #                                                      #
  ########################################################
  
  prepmodel = int(os.environ.get("PREP_MODEL"))
  if prepmodel==1:
    # format paths to model data
    cycle_dir = os.environ.get("CYCLE_DIR")
    cycle_type = os.environ.get("CYCLE_TYPE")
    rrfse_dir = os.environ.get("RRFSE_NWGES_BASEDIR")
    num_ens = int(os.environ.get("NUM_ENS_MEMBERS"))
    cycle_len_H = int(os.environ.get("DA_CYCLE_INTERV"))
    print("number of ensembles is ",num_ens)
    print("cycle length is ",cycle_len_H)
    # format datetime obj
    myDate = dt.datetime(int(inDate[:4]),int(inDate[4:6]),int(inDate[6:8]),int(inDate[8:10]))
    myDatemInterv = myDate-dt.timedelta(hours=cycle_len_H)
    myDateStr = '%04d%02d%02d.%02d0000.'%(myDate.year,myDate.month,myDate.day,myDate.hour)
    myDatemIntervStr = '%04d%02d%02d%02d'%(myDatemInterv.year,myDatemInterv.month,myDatemInterv.day,myDatemInterv.hour)

    # add deterministic path
    this_path = cycle_dir+'/fcst_fv3lam/INPUT/'
    if cycle_type=="spinup":
      this_path = cycle_dir+'/fcst_fv3lam_'+cycle_type+'/INPUT/'
    if os.path.exists(this_path+'phy_data.nc'):
      restartpathlist = [this_path]
    else:
      print('No background for assimilation! Exiting.')
      quit()
    for i in range(1,num_ens+1):
      this_path = rrfse_dir+'/'+myDatemIntervStr+'/mem%04d/fcst_fv3lam/RESTART/'%i+myDateStr
      if os.path.exists(this_path+'phy_data.nc'):
        restartpathlist = restartpathlist+[this_path]
      else:
        this_path = rrfse_dir+'/'+myDatemIntervStr+'/mem%04d/fcst_fv3lam_spinup/RESTART/'%i+myDateStr
        if os.path.exists(this_path+'phy_data.nc'):
          restartpathlist = restartpathlist+[this_path]
    print('Ens members found: %d'%(len(restartpathlist)-1))
    for p in restartpathlist:
      try:
        addmodelfed(p)
      except:
        print("spinup and prod may be running simultaneously; wait 100")
        time.sleep(100)
        addmodelfed(p)

  quit()
