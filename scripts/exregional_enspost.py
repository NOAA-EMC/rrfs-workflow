###################################################
#                                                 #
# RRFS-E Ensemble Post Processing                 #
#                                                 #
# Trevor Alcott                                   #
# 28 Apr 2017                                     #
#                                                 #
# Wrapper: ./pypost.ksh                           #
# User options: ../../static/UPP/pypost_config.py #
#                                                 #
###################################################

import os, sys, time, math, pygrib
import numpy as np
from datetime import datetime, timedelta
from scipy import ndimage
from scipy.signal import fftconvolve

# fix files
staticdir = sys.argv[1]
# USH dir
ushdir = sys.argv[2]
sys.path.append(ushdir)
from enspost_config import *
# RRFS-E cycle directory
rrfse_dir = sys.argv[3]
# RRFS-B (member 10) directory
rrfs_dir = sys.argv[4]
# Ensemble product output directory
outdir = sys.argv[5]
# cycle date
ymd = sys.argv[6]
# cycle hour
cycle = sys.argv[7]
# forecast hour
fhour = int(sys.argv[8])
# Flash flood guidance directories
ffg_latest = sys.argv[9]
ffg_local_dir = sys.argv[10]

print('Processing RRFS-E mean/spread fields')
print('Cycle:',ymd,cycle,'Forecast hour:',fhour)

# Parse cycle and determine Julian date
cy, cm, cd, ch = int(ymd[0:4]), int(ymd[4:6]), int(ymd[6:8]), int(cycle)
jul = (datetime(cy,cm,cd) - datetime(cy,1,1)).days + 1
d0 = datetime(cy,cm,cd,ch,0)

#####################
# FUNCTIONS

# skinner/NSSL technique
def compute_lpmm(ensemble, p, n, smooth):

   #Calculate a 2d array of the neighborhood probability matched mean when provided with an ensemble mean and raw data
   #ensemble - 3d array of raw data (e.g. var[member, y, x]) 
   #n - grid point radius to perform prob matching within (e.g. 15 corresponds to 30x30 grid point region) 
   #lpmm - 2d array of probability matched mean 

   print('Computing local PMM')

   mem, dx, dy = ensemble.shape
   ens_mean = np.mean(ensemble, axis=0)
   out = ens_mean * 0.
   i_patches = int(dx/p)
   j_patches = int(dy/p)

   for i_patch in range(i_patches):
      pi_min = i_patch*p
      pi_max = (i_patch+1)*p
      ci_min = pi_min - n
      ci_max = pi_max + n
      if ci_min < 0:
        ci_min = 0
        ci_max = p+2*n
      if ci_max > dx:
        ci_min = dx-(p+2*n)
        ci_max = dx

      for j_patch in range(j_patches):
         pj_min = j_patch*p
         pj_max = (j_patch+1)*p
         cj_min = pj_min - n
         cj_max = pj_max + n
         if cj_min < 0:
           cj_min = 0
           cj_max = p+2*n
         if cj_max > dy:
           cj_min = dy-(p+2*n)
           cj_max = dy

         ens_mean_calc = ens_mean[ci_min:ci_max,cj_min:cj_max]
         ens_calc = ensemble[:,ci_min:ci_max,cj_min:cj_max]
         ens_calc_dist = np.sort(ens_calc.flatten())[::-1]
         pmm_calc = ens_calc_dist[::mem]

         ens_mean_calc_index = np.argsort(ens_mean_calc.flatten())[::-1]
         temp = np.empty_like(pmm_calc)
         temp[ens_mean_calc_index] = pmm_calc 
         temp = np.where(ens_mean_calc.flatten() > 0, temp, 0.0)

         lpmm_calc = temp.reshape((p+2*n,p+2*n))
         out[pi_min:pi_max,pj_min:pj_max] = lpmm_calc[n:n+p,n:n+p]

   out = ndimage.filters.gaussian_filter(out,[int(smooth/3.0),int(smooth/3.0)],mode='constant')

   return out

# sobash/NCAR technique
def compute_pmm(ensemble, smooth):

    print('Computing PMM')

    mem, dy, dx = ensemble.shape
    ens_mean = np.mean(ensemble, axis=0)
    ens_dist = np.sort(ensemble.flatten())[::-1]
    pmm = ens_dist[::mem]

    ens_mean_index = np.argsort(ens_mean.flatten())[::-1]
    temp = np.empty_like(pmm)
    temp[ens_mean_index] = pmm 

    temp = np.where(ens_mean.flatten() > 0, temp, 0.0)
    out = temp.reshape((dy,dx))
    out = ndimage.filters.gaussian_filter(out,[int(smooth/3.0),int(smooth/3.0)],mode='constant')
    return out

# calculate footprint for spatial filter
def get_footprint(r):
  footprint = np.ones([(int(r/dx))*2+1,(int(r/dx))*2+1],dtype=np.int8)
  footprint[int(math.ceil(r/dx)),int(math.ceil(r/dx))]=0
  dist = ndimage.distance_transform_edt(footprint,sampling=[dx,dx])
  footprint = np.where(np.greater(dist,r),0,1)
  return footprint


########################################
#
# ENSEMBLE MEAN/PMM/LPMM/MIN/MAX section
#
########################################

neighbor_footprint = get_footprint(pqpf_neighborhood)

# get sample file from this run to determine dimensions
rrfse_file = rrfse_dir+'/mem0001/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
if os.path.exists(rrfse_file):
  grbs = pygrib.open(rrfse_file)
  g1 = grbs[1]
  lats, lons = g1.latlons()
  grbs.close()
  nlats, nlons = np.shape(lats)
else:
  print('Sample file from this run could not be found. No dimensions available')
  sys.exit()

# get grib templates based on those dimensions
normal_template_file = staticdir+'/pypost_conus_basic_template.grib2'
accum_template_file = staticdir+'/pypost_conus_accum_template.grib2'
grbs = pygrib.open(normal_template_file)
normal_template = grbs[1]
grbs.close()
grbs = pygrib.open(accum_template_file)
accum_template = grbs[1]
grbs.close()

# start with a clean slate for this forecast hour
outfile = outdir + '/RRFS_CONUS.t%02d'%ch+'z.bgensf%03d'%fhour+'.tm00.grib2.tmp'
finalfile = outdir + '/RRFS_CONUS.t%02d'%ch+'z.bgensf%03d'%fhour+'.tm00.grib2'
softlink = outdir + '/BGENS_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
if os.path.exists(outfile):
  os.system('rm -f '+outfile)
if os.path.exists(finalfile):
  os.system('rm -f '+outfile)
if os.path.exists(softlink):
  os.system('unlink '+softlink)

# determine parameters to process
init_parms = list(set(mean_parms) | set(std_parms) | set(min_parms) | set(max_parms) | set(pmm_parms) | set(lpmm_parms))

post_parms = []
# reduce list to only applicable accumulation intervals
for i in range(len(init_parms)):
  p = init_parms[i]
  if p[0:2] == '1h' and fhour>=1:
    post_parms.append(p) 
  elif p[0:2] == '3h' and fhour>=3:
    post_parms.append(p) 
  elif p[0:2] == '6h' and fhour>=6:
    post_parms.append(p) 
  elif p[0:3] == '12h' and fhour>=12:
    post_parms.append(p) 
  elif p[0:3] == '24h' and fhour>=24:
    post_parms.append(p) 


# determine whether all necessary files are present
rrfse_files = {}
mems = []
for m in range(1,nm+1):
  missing = 0
  filelist = []
  if m == 10:
    rrfse_file = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
  else:
    rrfse_file = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
  print(rrfse_file)
  if ('1hqpf' in post_parms) or ('1hsnow' in post_parms) or ('3hqpf' in post_parms) or ('3hsnow' in post_parms) or ('6hqpf' in post_parms) or ('6hsnow' in post_parms) or ('24hqpf' in post_parms) or ('24hsnow' in post_parms):
    filelist.append(rrfse_file)
    if not os.path.exists(rrfse_file):
      missing = 1
    if fhour > 1:
      if m == 10:
        rrfse_file2 = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-1)+'00'
      else:
        rrfse_file2 = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-1)+'00'
      filelist.append(rrfse_file2)
      if not os.path.exists(rrfse_file2):
        missing = 1
    if fhour > 3:
      if m == 10:
        rrfse_file3 = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-3)+'00'
      else:
        rrfse_file3 = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-3)+'00'
      filelist.append(rrfse_file3)
      if not os.path.exists(rrfse_file3):
        missing = 1
    if fhour > 6:
      if m == 10:
        rrfse_file4 = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-6)+'00'
      else:
        rrfse_file4 = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-6)+'00'
      filelist.append(rrfse_file4)
      if not os.path.exists(rrfse_file4):
        missing = 1
    if fhour > 12:
      if m == 10:
        rrfse_file5 = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-12)+'00'
      else:
        rrfse_file5 = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-12)+'00'
      filelist.append(rrfse_file5)
      if not os.path.exists(rrfse_file5):
        missing = 1
    if fhour > 24:
      if m == 10:
        rrfse_file6 = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-24)+'00'
      else:
        rrfse_file6 = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-24)+'00'
      filelist.append(rrfse_file6)
      if not os.path.exists(rrfse_file6):
        missing = 1
    if missing == 0:
      print('Found data for member',m)
      mems.append(m)
      rrfse_files[m] = filelist
    else:
      print('Missing data from member:',m)
  else:
    if os.path.exists(rrfse_file):
      print('Found data for member',m)
      mems.append(m)
      rrfse_files[m] = [rrfse_file]
    else:
      print('Missing data from member:',m)
if len(mems) == nm:
  print('Found',nm,'members for hour:',fhour)
else:
  print('Could not find all',nm,'members')
  sys.exit()

# calculate sum and sum of squares
psum = {}
psumsq = {}
pmin = {}
pmax = {}
for p in post_parms:
  psum[p] = np.zeros((nlats,nlons))
  if p in std_parms:
    psumsq[p] = np.zeros((nlats,nlons))
  if p in max_parms:
    pmax[p] = np.zeros((nlats,nlons))-999999999.
  if p in min_parms:
    pmin[p] = np.zeros((nlats,nlons))+999999999.

if pmm_parms != []:
  membervals = {}
  for p in pmm_parms:
    membervals[p] = np.zeros((len(mems),nlats,nlons))

if lpmm_parms != [] and pmm_parms == []:
  membervals = {}
  for p in lpmm_parms:
    membervals[p] = np.zeros((len(mems),nlats,nlons))

do_parms = []
for i in range(len(post_parms)):
  intv = int(post_parms[i].split('h')[0])
  if (fhour % ens_proc_intervals[intv] == 0 and fhour >= intv):
    do_parms.append(post_parms[i])

for m in mems:
  print('Processing member',(1+mems.index(m)),'of',len(mems))
  idx = pygrib.index(rrfse_files[m][0],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level')
  for p in do_parms:
    if 'qpf' in p:
      ptable = 'qpf'
    elif 'snow' in p:
      ptable = 'snow'
    else:
      ptable = p
    if (p == '1hqpf' or p == '1hsnow'):
      idx2 = pygrib.index(rrfse_files[m][0],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
      vals = idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
      idx2.close()
      if fhour > 1:
        idx2 = pygrib.index(rrfse_files[m][1],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
        vals = vals - idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
        idx2.close()
    elif (p == '3hqpf' or p == '3hsnow'):
      idx2 = pygrib.index(rrfse_files[m][0],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
      vals = idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
      idx2.close()
      if fhour > 3:
        idx2 = pygrib.index(rrfse_files[m][2],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
        vals = vals - idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
        idx2.close()
    elif (p == '6hqpf' or p == '6hsnow'):
      idx2 = pygrib.index(rrfse_files[m][0],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
      vals = idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
      idx2.close()
      if fhour > 6:
        idx2 = pygrib.index(rrfse_files[m][3],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
        vals = vals - idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
        idx2.close()
    elif (p == '12hqpf' or p == '12hsnow'):
      idx2 = pygrib.index(rrfse_files[m][0],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
      vals = idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
      idx2.close()
      if fhour > 12:
        idx2 = pygrib.index(rrfse_files[m][4],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
        vals = vals - idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
        idx2.close()
    elif (p == '24hqpf' or p == '24hsnow'):
      idx2 = pygrib.index(rrfse_files[m][0],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
      vals = idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
      idx2.close()
      if fhour > 24:
        idx2 = pygrib.index(rrfse_files[m][5],'discipline','parameterCategory','parameterNumber','typeOfFirstFixedSurface','level','startStep')
        vals = vals - idx2(discipline=grib_discipline[ptable],parameterCategory=grib_category[ptable],parameterNumber=grib_number[ptable],typeOfFirstFixedSurface=grib_surface[ptable],level=grib_level[ptable],startStep=0)[0].values
        idx2.close()
    psum[p] = psum[p] + vals
    if p in std_parms:
      psumsq[p] = psumsq[p] + vals**2
    if p in max_parms:
      pmax[p] = np.where(np.greater(vals,pmax[p]),vals,pmax[p])
    if p in min_parms:
      pmin[p] = np.where(np.less(vals,pmin[p]),vals,pmin[p])
    if p in pmm_parms or p in lpmm_parms:
      membervals[p][m-1] = vals
  idx.close()

for i in range(len(do_parms)):
  print('Working on',p)
  p = do_parms[i]
  intv = int(p.split('h')[0])
  if ('snow' in p) or ('qpf' in p):
    grbtmp = accum_template
    if 'qpf' in p:
      ptable = 'qpf'
    elif 'snow' in p:
      ptable = 'snow'
    else:
      ptable = p
  else:
    grbtmp = normal_template

  # fill in GRIB time definition metadata
  grbtmp['numberOfForecastsInEnsemble'] = len(mems)
  grbtmp['year'] = cy
  grbtmp['month'] = cm
  grbtmp['day'] = cd
  grbtmp['hour'] = ch
  grbtmp.packingType='grid_jpeg'  # complex packing for smallest file size

  # calculate mean
  pmean = psum[p]/float(len(mems))

  # set forecast hour(s)
  grbtmp['endStep'] = fhour
  grbtmp['startStep'] = fhour-intv

  # fill in GRIB parameter metadata
  grbtmp['discipline']=grib_discipline[ptable]
  grbtmp['parameterCategory']=grib_category[ptable]
  if isinstance(grib_number[ptable],int):
    grbtmp['parameterNumber']=grib_number[ptable]
  else:
    grbtmp['parameterNumber']=grib_number[ptable][2]
  if grib_surface == 'sfc':
    grbtmp['typeOfFirstFixedSurface']=grib_surface[ptable]
  grbtmp['level']=grib_level[ptable]
  if 'snow' in p:
    grbtmp['decimalPrecision']=3

  grbout = open(outfile,'ab')
  if p in mean_parms:
    if 'qpf' in p or 'snow' in p:
      pmean = np.clip(pmean,0,10000)
    grbtmp['values']=pmean.astype(np.float32)
    grbtmp['typeOfGeneratingProcess']=4
    grbtmp['derivedForecast']=0
    grbout.write(grbtmp.tostring())
  if p in std_parms:
    pstd = ((psumsq[p])/float(len(mems)) - pmean**2)**0.5
    pstd = np.where(np.greater_equal(pstd,0),pstd,0) # code NaN values as zero to prevent GRIB-API issues
    grbtmp['values']=pstd.astype(np.float32)
    grbtmp['typeOfGeneratingProcess']=4
    grbtmp['derivedForecast']=4
    grbout.write(grbtmp.tostring())
  if p in max_parms:
    if 'qpf' in p or 'snow' in p:
      pmax[p] = np.clip(pmax[p],0,10000)
    grbtmp['values']=pmax[p].astype(np.float32)
    grbtmp['typeOfGeneratingProcess']=4
    grbtmp['derivedForecast']=9
    grbout.write(grbtmp.tostring())
  if p in min_parms:
    if 'qpf' in p or 'snow' in p:
      pmin[p] = np.clip(pmin[p],0,10000)
    grbtmp['values']=pmin[p].astype(np.float32)
    grbtmp['typeOfGeneratingProcess']=4
    grbtmp['derivedForecast']=8
    grbout.write(grbtmp.tostring())
  if p in pmm_parms:
    pmm = compute_pmm(membervals[p],pmm_smooth)  # sobash method
    if 'qpf' in p or 'snow' in p:
      pmm = np.clip(pmm,0,10000)
    grbtmp['values']=pmm.astype(np.float32)
    grbtmp['typeOfGeneratingProcess']=193
    grbtmp['derivedForecast']=1
    grbout.write(grbtmp.tostring())
  if p in lpmm_parms:
    lpmm = compute_lpmm(membervals[p],lpmm_patch,lpmm_neighborhood,lpmm_smooth)
    if 'qpf' in p or 'snow' in p:
      lpmm = np.clip(lpmm,0,10000)
    grbtmp['values']=lpmm.astype(np.float32)
    grbtmp['typeOfGeneratingProcess']=193
    grbtmp['derivedForecast']=6
    grbout.write(grbtmp.tostring())

  grbout.close()

print('Wrote derived ensemble fields to:',outfile)

########################################
#                                      
#    PQPF section                      
#
########################################

# determine all PQPF accumulation intervals to process
for pqpf_acc_interval in pqpf_acc_intervals:

  if fhour % pqpf_proc_intervals[pqpf_acc_interval] == 0 and fhour >= pqpf_acc_interval:
    print('Working on ',pqpf_acc_interval,'h PQPF')
  
    # determine start/end times based on cycle string passed in
    starttime = d0+timedelta((fhour-pqpf_acc_interval)/24.0)
    endtime = d0+timedelta(fhour/24.0)
    
    # get sample file from this run to determine dimensions
    rrfse_file = rrfse_dir+'/mem0001/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
    if os.path.exists(rrfse_file):
      grbs = pygrib.open(rrfse_file)
      g1 = grbs[1]
      lats, lons = g1.latlons()
      latin1 = g1['Latin1InDegrees']
      lov = g1['LoVInDegrees']
      grbs.close()
      nlats, nlons = np.shape(lats)
    else:
      print('Sample file from this run could not be found. No dimensions available')
      sys.exit()
    
    # determine name of GRIB-2 template file
    template_file = staticdir+'/pypost_conus_pqpf_template.grib2'
    ari_template_file = staticdir+'/pypost_conus_ari_template.grib2'
    ffg_template_file = staticdir+'/pypost_conus_ffg_template.grib2'
    grbs = pygrib.open(template_file)
    g = grbs[1]
    grbs.close()
    if pqpf_acc_interval in ffg_acc_intervals:
      grbs = pygrib.open(ffg_template_file)
      g_ffg = grbs[1]
      grbs.close()
    if pqpf_acc_interval in ari_acc_intervals:
      grbs = pygrib.open(ari_template_file)
      g_ari = grbs[1]
      grbs.close()
    
    # determine whether all necessary files are present
    rrfse_files = {}
    mems = []
    for m in range(1,nm+1):
      files = []
      if fhour == pqpf_acc_interval:
        if m == 10:
          rrfse_file = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
        else:
          rrfse_file = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
        if os.path.exists(rrfse_file):
          rrfse_files[m] = [rrfse_file]
          mems.append(m)
          print('Found data for member',m)
        else:
          print('Missing data from member:',m)
      else:
        if m == 10:
          rrfse_file1 = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
          rrfse_file2 = rrfs_dir+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-pqpf_acc_interval)+'00'
        else:
          rrfse_file1 = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
          rrfse_file2 = rrfse_dir+'/mem%04d'%m+'/BGSFC_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%(fhour-pqpf_acc_interval)+'00'
        if os.path.exists(rrfse_file1) and os.path.exists(rrfse_file2):
          rrfse_files[m] = [rrfse_file1,rrfse_file2]
          mems.append(m)
          print('Found data for member',m)
        else:
          print('Missing data from member:',m)
    if len(mems) == nm:
      print('Found',nm,'members valid:',starttime,'-',endtime)
    else:
      print('Could not find all',nm,'members')
      sys.exit()
    
    # calculate probabilities
    prob = {}
    nprob = {}
    for t in pqpf_thresh[pqpf_acc_interval]:
      prob[t] = np.zeros((nlats,nlons))
      nprob[t] = np.zeros((nlats,nlons))
    
    # Get ARI data
    if pqpf_acc_interval in ari_acc_intervals:
      ari_prob = {}
      ari_nprob = {}
      ari_vals = {}
      for y in ari_years[pqpf_acc_interval]:
        ari_prob[y] = np.zeros((nlats,nlons))
        ari_nprob[y] = np.zeros((nlats,nlons))
        ari_file = staticdir + '/atlas14/atlas14_conus_%i'%y+'y_%i'%pqpf_acc_interval+'h.grib2' 
        grbs = pygrib.open(ari_file)
        grb = grbs[1]
        ari_lat, ari_lon = grb.latlons()
        ari_vals[y] = grb.values
        grbs.close()
        badvals = np.where(np.less(ari_vals[y],5),1,0)
        coastal = np.where(np.greater_equal(fftconvolve(badvals,neighbor_footprint,mode='same'),1),1,0)
        ari_vals[y] = np.where(np.equal(coastal,1),9999.,ari_vals[y])
        ari_vals[y] = np.where(np.less(ari_vals[y],5),9999.,ari_vals[y])
    
    # get FFG data and interpolate to RRFSE grid
    if pqpf_acc_interval in ffg_acc_intervals:
      ffg_prob = {}
      ffg_nprob = {}
      for tf in ffg_thresh:
        ffg_prob[tf] = np.zeros((nlats,nlons))
        ffg_nprob[tf] = np.zeros((nlats,nlons))
      ffg_local = ffg_local_dir + '/ffg_%02d'%pqpf_acc_interval+'h.grib2'
      if not os.path.exists(ffg_local):
        griddims = "lambert:%.1f"%(lov-360.0)+":%.1f"%latin1+" %.3f"%lons[0,0]+":%i"%nlons+":3000 %.3f"%lats[0,0]+":%i"%nlats+":3000"
        if pqpf_acc_interval not in [24,48]:
          remap_command = 'wgrib2 '+ffg_latest+' -match "0-%i'%pqpf_acc_interval+' hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid '+griddims+' '+ffg_local
        elif pqpf_acc_interval == 24:
          remap_command = 'wgrib2 '+ffg_latest+' -match "0-1 day" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid '+griddims+' '+ffg_local
        elif pqpf_acc_interval == 48:
          remap_command = 'wgrib2 '+ffg_latest+' -match "0-2 day" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid '+griddims+' '+ffg_local
        os.system(remap_command)
      grbs = pygrib.open(ffg_local)
      ffg_vals = grbs[1].values
      grbs.close()
    
    for m in mems:
      files = rrfse_files[m]
      print('Processing member',(1+mems.index(m)),'of',len(mems))
     
      idx = pygrib.index(files[0],'discipline','parameterCategory','parameterNumber','startStep')
      qpf = idx(discipline=0,parameterCategory=1,parameterNumber=8,startStep=0)[0].values
      idx.close()
      if len(files) == 2:
        idx = pygrib.index(files[1],'discipline','parameterCategory','parameterNumber','startStep')
        qpf = qpf - idx(discipline=0,parameterCategory=1,parameterNumber=8,startStep=0)[0].values
        idx.close()
      qpf = np.where(np.logical_and(np.greater_equal(qpf,0.0),np.less(qpf,9999)),qpf,0.0)
    
      # calculate PQPF
      for t in pqpf_thresh[pqpf_acc_interval]:
        exceed = np.where(np.greater_equal(qpf,t*25.4),1,0)
        # point probability
        prob[t] = prob[t] + np.where(np.greater_equal(exceed,1),1,0)
        # neighborhood probability (stopped using fft approximation 19 Feb 2020 - TA)
        #nprob[t] = nprob[t] + np.where(np.greater_equal(fftconvolve(exceed,neighbor_footprint,mode='same'),1),1,0)
        nprob[t] = nprob[t] + np.where(np.greater(ndimage.filters.maximum_filter(exceed,footprint=neighbor_footprint,mode='nearest'),0),1,0)
    
      # calculate probability of exceeding ARI
      if pqpf_acc_interval in ari_acc_intervals:
        for y in ari_years[pqpf_acc_interval]:
          exceed = np.where(np.greater_equal(qpf,ari_vals[y]),1,0)
          # point probability
          ari_prob[y] = ari_prob[y] + np.where(np.greater_equal(exceed,1),1,0)
          # neighborhood probability
          ari_nprob[y] = ari_nprob[y] + np.where(np.greater_equal(fftconvolve(exceed,neighbor_footprint,mode='same'),1),1,0)
    
      # calculate probability of exceeding FFG
      if pqpf_acc_interval in ffg_acc_intervals:
        for tf in ffg_thresh:
          exceed = np.where(np.greater_equal(qpf,ffg_vals+tf*25.4),1,0)
          # point probability
          ffg_prob[tf] = ffg_prob[tf] + np.where(np.greater_equal(exceed,1),1,0)
          # neighborhood probability
          ffg_nprob[tf] = ffg_nprob[tf] + np.where(np.greater_equal(fftconvolve(exceed,neighbor_footprint,mode='same'),1),1,0)
    
    g['dataDate']=int('%i'%d0.year+'%02d'%d0.month+'%02d'%d0.day)
    g['dataTime']=int('%02d'%d0.hour+'00')
    g['startStep']=int(fhour-pqpf_acc_interval)
    g['endStep']=int(fhour)
    g['yearOfEndOfOverallTimeInterval']=endtime.year
    g['monthOfEndOfOverallTimeInterval']=endtime.month
    g['dayOfEndOfOverallTimeInterval']=endtime.day
    g['hourOfEndOfOverallTimeInterval']=endtime.hour
    g['scaleFactorOfLowerLimit']=3
    g['scaleFactorOfUpperLimit']=0
    if pqpf_acc_interval in ffg_acc_intervals:
      g_ffg['dataDate']=int('%i'%d0.year+'%02d'%d0.month+'%02d'%d0.day)
      g_ffg['dataTime']=int('%02d'%d0.hour+'00')
      g_ffg['startStep']=int(fhour-pqpf_acc_interval)
      g_ffg['endStep']=int(fhour)
      g_ffg['yearOfEndOfOverallTimeInterval']=endtime.year
      g_ffg['monthOfEndOfOverallTimeInterval']=endtime.month
      g_ffg['dayOfEndOfOverallTimeInterval']=endtime.day
      g_ffg['hourOfEndOfOverallTimeInterval']=endtime.hour
      g_ffg['probabilityType']=3
      g_ffg['scaleFactorOfLowerLimit']=3
      g_ffg['scaleFactorOfUpperLimit']=0
    if pqpf_acc_interval in ari_acc_intervals:
      g_ari['dataDate']=int('%i'%d0.year+'%02d'%d0.month+'%02d'%d0.day)
      g_ari['dataTime']=int('%02d'%d0.hour+'00')
      g_ari['startStep']=int(fhour-pqpf_acc_interval)
      g_ari['endStep']=int(fhour)
      g_ari['yearOfEndOfOverallTimeInterval']=endtime.year
      g_ari['monthOfEndOfOverallTimeInterval']=endtime.month
      g_ari['dayOfEndOfOverallTimeInterval']=endtime.day
      g_ari['hourOfEndOfOverallTimeInterval']=endtime.hour
      g_ari['scaleFactorOfLowerLimit']=0
      g_ari['scaleFactorOfUpperLimit']=0
    
    # convert probability grid from count to percent and save in output file
    # encode neighborhood probability as >thresh and <neighborhood radius in meters
    for t in pqpf_thresh[pqpf_acc_interval]:
      prob[t] = 100.0 * prob[t] / float(len(mems))
      prob[t] = ndimage.filters.gaussian_filter(prob[t],[int(pqpf_smooth/3.0),int(pqpf_smooth/3.0)],mode='constant')
      prob[t] = np.clip(prob[t],0,100)
      nprob[t] = 100.0 * nprob[t] / float(len(mems))
      nprob[t] = ndimage.filters.gaussian_filter(nprob[t],[int(pqpf_neighbor_smooth/3.0),int(pqpf_neighbor_smooth/3.0)],mode='constant')
      nprob[t] = np.clip(nprob[t],0,100)
      grbout = open(outfile,'ab')
      if 'point' in pqpf_types:
        g['probabilityType']=3
        g['scaledValueOfLowerLimit']=int(1000*round(t*25.4,3))
        g['scaledValueOfUpperLimit']=pqpf_neighborhood*1000
        g['values']=(np.around(prob[t])).astype(int)
        g.packingType='grid_jpeg'  # complex packing for smallest file size
        grbout.write(g.tostring())
      if 'neighbor' in pqpf_types:
        g['probabilityType']=2
        g['scaledValueOfLowerLimit']=int(1000*round(t*25.4,3))
        g['scaledValueOfUpperLimit']=pqpf_neighborhood*1000
        g['values']=(np.around(nprob[t])).astype(int)
        g.packingType='grid_jpeg'  # complex packing for smallest file size
        grbout.write(g.tostring())
      grbout.close()
    
    if pqpf_acc_interval in ari_acc_intervals:
      for y in ari_years[pqpf_acc_interval]:
        ari_prob[y] = 100.0 * ari_prob[y] / float(len(mems))
        ari_prob[y] = ndimage.filters.gaussian_filter(ari_prob[y],[int(ari_smooth/3.0),int(ari_smooth/3.0)],mode='constant')
        ari_prob[y] = np.clip(ari_prob[y],0,100)
        ari_nprob[y] = 100.0 * ari_nprob[y] / float(len(mems))
        ari_nprob[y] = ndimage.filters.gaussian_filter(ari_nprob[y],[int(ari_neighbor_smooth/3.0),int(ari_neighbor_smooth/3.0)],mode='constant')
        ari_nprob[y] = np.clip(ari_nprob[y],0,100)
        grbout = open(outfile,'ab')
        if 'point' in ari_types:
          g_ari['probabilityType']=3
          g_ari['scaledValueOfLowerLimit']=int(y)
          g_ari['scaledValueOfUpperLimit']=ari_neighborhood*1000
          g_ari['values']=(np.around(ari_prob[y])).astype(int)
          g_ari.packingType='grid_jpeg'  # complex packing for smallest file size
          grbout.write(g_ari.tostring())
        if 'neighbor' in ari_types:
          g_ari['probabilityType']=2
          g_ari['scaledValueOfLowerLimit']=int(y)
          g_ari['scaledValueOfUpperLimit']=ari_neighborhood*1000
          g_ari['values']=(np.around(ari_nprob[y])).astype(int)
          g_ari.packingType='grid_jpeg'  # complex packing for smallest file size
          grbout.write(g_ari.tostring())
        grbout.close()
    
    if pqpf_acc_interval in ffg_acc_intervals:
      for tf in ffg_thresh:
        ffg_prob[tf] = 100.0 * ffg_prob[tf] / float(len(mems))
        ffg_prob[tf] = ndimage.filters.gaussian_filter(ffg_prob[tf],[int(ffg_smooth/3.0),int(ffg_smooth/3.0)],mode='constant')
        ffg_prob[tf] = np.clip(ffg_prob[tf],0,100)
        ffg_nprob[tf] = 100.0 * ffg_nprob[tf] / float(len(mems))
        ffg_nprob[tf] = ndimage.filters.gaussian_filter(ffg_nprob[tf],[int(ffg_neighbor_smooth/3.0),int(ffg_neighbor_smooth/3.0)],mode='constant')
        ffg_nprob[tf] = np.clip(ffg_nprob[tf],0,100)
        grbout = open(outfile,'ab')
        if 'point' in ffg_types:
          g_ffg['probabilityType']=3
          g_ffg['scaledValueOfLowerLimit']=int(1000*round(tf*25.4,3))
          g_ffg['scaledValueOfUpperLimit']=ffg_neighborhood*1000
          g_ffg['values']=(np.around(ffg_prob[tf])).astype(int)
          g_ffg.packingType='grid_jpeg'  # complex packing for smallest file size
          grbout.write(g_ffg.tostring())
        if 'neighbor' in ffg_types:
          g_ffg['probabilityType']=2
          g_ffg['scaledValueOfLowerLimit']=int(1000*round(tf*25.4,3))
          g_ffg['scaledValueOfUpperLimit']=ffg_neighborhood*1000
          g_ffg['values']=(np.around(ffg_nprob[tf])).astype(int)
          g_ffg.packingType='grid_jpeg'  # complex packing for smallest file size
          grbout.write(g_ffg.tostring())
        grbout.close()

print('Wrote PQPF products to:',outfile)
os.system('wgrib2 -v '+outfile)

print('Finalizing to remove temp file')
finalfile = outdir + '/RRFS_CONUS.t%02d'%ch+'z.bgensf%03d'%fhour+'.tm00.grib2'
os.system('mv '+outfile+' '+finalfile)
print('Final file:',finalfile)

softlink = outdir + '/BGENS_%02d'%(cy-2000)+'%03d'%jul+'%02d'%ch+'00%02d'%fhour+'00'
print('Creating softlink:',softlink)
os.system('ln -s '+finalfile+' '+softlink)

