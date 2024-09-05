#!/usr/bin/env python
import os
from xml_funcs.base import xml_task, source, get_cascade_env

### begin of ungrib_ic --------------------------------------------------------
def ungrib_ic(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'FHR': '000',
    'TYPE': 'ic'
  }
  #
  if not do_ensemble:
    metatask=False
    meta_id=''
    task_id='ungrib_ic'
    cycledefs='ic'
    prefix=os.getenv('IC_PREFIX','IC_PREFIX_not_defined')
    offset=os.getenv('IC_OFFSET','3')
    meta_bgn=""
    meta_end=""
  else:
    metatask=True
    meta_id='ungrib_ic'
    task_id=f'{meta_id}_m#ens_index#'
    cycledefs='ens_ic'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    prefix=os.getenv('ENS_IC_PREFIX','GEFS')
    offset=os.getenv('ENS_IC_OFFSET','36')
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    gmems=''.join(f'{i:02d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>
<var name="gmem">{gmems}</var>'''
    meta_end=f'</metatask>\n'
  #
  # dependencies
  COMINgfs=os.getenv("COMINgfs",'COMINgfs_not_defined')
  COMINrrfs=os.getenv("COMINrrfs",'COMINrrfs_not_defined')
  COMINrap=os.getenv("COMINrap",'COMINrap_not_defined')
  COMINhrrr=os.getenv("COMINhrrr",'COMINhrrr_not_defined')
  COMINgefs=os.getenv("COMINgefs",'COMINgefs_not_defined')
  if prefix == "GFS":
    fpath=f'{COMINgfs}/gfs.@Y@m@d/@H/gfs.t@Hz.pgrb2.0p25.f{offset:>03}'
  elif prefix == "RRFS":
    fpath=f'{COMINrrfs}/rrfs.@Y@m@d/@H/rrfs.t@Hz.natlve.f{offset:>02}.grib2'
  elif prefix == "RAP":
    fpath=f'{COMINrap}/rap.@Y@m@d/rap.t@Hz.wrfnatf{offset:>02}.grib2'
  elif prefix == "GEFS":
    fpath=f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2ap5/gep#gmem#.t@Hz.pgrb2a.0p50.f{offset:>03}'
    fpath2=f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2bp5/gep#gmem#.t@Hz.pgrb2b.0p50.f{offset:>03}'
  else:
    fpath=f'/not_supported_LBC_PREFIX={prefix}'

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  datadep=f'<datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath}</cyclestr></datadep>'
  if do_ensemble:
    datadep=datadep+f'\n  <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath2}</cyclestr></datadep>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  {datadep}
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"UNGRIB",do_ensemble)
### end of ungrib_ic --------------------------------------------------------

### begin of ungrib_lbc --------------------------------------------------------
def ungrib_lbc(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'FHR': '#fhr#',
    'TYPE': 'lbc',
  }
  if not do_ensemble:
    meta_id='ungrib_lbc'
    cycledefs='lbc'
    # metatask (support nested metatasks)
    fhr=os.getenv('FCST_LENGTH','12')
    offset=int(os.getenv('LBC_OFFSET','6'))
    length=int(os.getenv('LBC_LENGTH','18'))
    interval=int(os.getenv('LBC_INTERVAL','3'))
    meta_hr= ''.join(f'{i:03d} ' for i in range(0,int(length)+1,int(interval))).strip()
    comin_hr=''.join(f'{i:03d} ' for i in range(int(offset),int(length)+int(offset)+1,int(interval))).strip()
    meta_bgn=f'''
<metatask name="{meta_id}">
<var name="fhr">{meta_hr}</var>
<var name="fhr_in">{comin_hr}</var>'''
    meta_end=f'</metatask>\n'
    task_id=f'{meta_id}_f#fhr#'
    prefix=os.getenv('LBC_PREFIX','GFS')
  #
  else: # ensemble
    meta_id='ungrib_lbc'
    cycledefs='ens_lbc'
    # metatask (support nested metatasks)
    fhr=os.getenv('ENS_FCST_LENGTH','6')
    offset=int(os.getenv('ENS_LBC_OFFSET','36'))
    length=int(os.getenv('ENS_LBC_LENGTH','12'))
    interval=int(os.getenv('ENS_LBC_INTERVAL','3'))
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    gmems=''.join(f'{i:02d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_hr= ''.join(f'{i:03d} ' for i in range(0,int(length)+1,int(interval))).strip()
    comin_hr=''.join(f'{i:03d} ' for i in range(int(offset),int(length)+int(offset)+1,int(interval))).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>
<var name="gmem">{gmems}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="fhr">{meta_hr}</var>
<var name="fhr_in">{comin_hr}</var>'''
    meta_end=f'</metatask>\n</metatask>\n'
    task_id=f'{meta_id}_m#ens_index#_f#fhr#'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    prefix=os.getenv('ENS_LBC_PREFIX','GEFS')

  # dependencies
  COMINgfs=os.getenv("COMINgfs",'COMINgfs_not_defined')
  COMINrrfs=os.getenv("COMINrrfs",'COMINrrfs_not_defined')
  COMINrap=os.getenv("COMINrap",'COMINrap_not_defined')
  COMINhrrr=os.getenv("COMINhrrr",'COMINhrrr_not_defined')
  COMINgefs=os.getenv("COMINgefs",'COMINgefs_not_defined')
  if prefix == "GFS":
    fpath=f'{COMINgfs}/gfs.@Y@m@d/@H/gfs.t@Hz.pgrb2.0p25.f#fhr_in#'
  elif prefix == "RRFS":
    fpath=f'{COMINrrfs}/rrfs.@Y@m@d/@H/rrfs.t@Hz.natlve.f#fhr_in#.grib2'
  elif prefix == "RAP":
    fpath=f'{COMINrap}/rap.@Y@m@d/rap.t@Hz.wrfnatf#fhr_in#.grib2'
  elif prefix == "GEFS":
    fpath=f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2ap5/gep#gmem#.t@Hz.pgrb2a.0p50.f#fhr_in#'
    fpath2=f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2bp5/gep#gmem#.t@Hz.pgrb2b.0p50.f#fhr_in#'
  else:
    fpath=f'/not_supported_LBC_PREFIX={prefix}'

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{meta_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  datadep=f'<datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath}</cyclestr></datadep>'
  if do_ensemble:
    datadep=datadep+f'\n  <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath2}</cyclestr></datadep>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  {datadep}
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,True,meta_id,meta_bgn,meta_end,"UNGRIB",do_ensemble)
### end of ungrib_lbc --------------------------------------------------------

### begin of mpassit --------------------------------------------------------
def mpassit(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'FHR': '#fhr#',
  }
  if not do_ensemble:
    meta_id='mpassit'
    cycledefs='prod'
    # metatask (nested or not)
    fhr=os.getenv('FCST_LENGTH','3')
    if int(fhr) >=100:
      print(f'FCST_LENGTH>=100 not supported: {fhr}')
      exit()
    #meta_hr=''.join(f'{i:03d} ' for i in range(int(fhr)+1)).strip()
    meta_hr=''.join(f'{i:03d} ' for i in range(int(fhr)+1)).strip()[4:] #remove '000 ' as no f000 diag and history files for restart cycles yet, gge.debug
    fhr2=''.join(f'{i:02d} ' for i in range(int(fhr)+1)).strip()[3:] #remove '00 '
    meta_bgn=f'''
<metatask name="{meta_id}">
<var name="fhr">{meta_hr}</var>
<var name="fhr2">{fhr2}</var>'''
    meta_end=f'</metatask>\n'
    task_id=f'{meta_id}_f#fhr#'
    ensindexstr=""
    RUN='rrfs'
  else:
    meta_id='mpassit'
    cycledefs='ens_prod'
    # metatask (nested or not)
    fhr=os.getenv('ENS_FCST_LENGTH','3')
    if int(fhr) >=100:
      print(f'FCST_LENGTH>=100 not supported: {fhr}')
      exit()
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    #meta_hr=''.join(f'{i:03d} ' for i in range(int(fhr)+1)).strip()
    meta_hr=''.join(f'{i:03d} ' for i in range(int(fhr)+1)).strip()[4:] #remove '000 ' as no f000 diag and history files for restart cycles yet, gge.debug
    fhr2=''.join(f'{i:02d} ' for i in range(int(fhr)+1)).strip()[3:] #remove '00 '
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="fhr">{meta_hr}</var>
<var name="fhr2">{fhr2}</var>'''
    meta_end=f'</metatask>\n</metatask>\n'
    task_id=f'{meta_id}_m#ens_index#_f#fhr#'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    ensindexstr="_m#ens_index#"
    RUN='ens'

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{meta_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  DATAROOT=os.getenv("DATAROOT","DATAROOT_NOT_DEFINED")
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <datadep age="00:05:00"><cyclestr>{DATAROOT}/{NET}/{VERSION}/{RUN}.@Y@m@d/@H{ensindexstr}/fcst/</cyclestr><cyclestr offset="#fhr2#:00:00">diag.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
  <datadep age="00:05:00"><cyclestr>{DATAROOT}/{NET}/{VERSION}/{RUN}.@Y@m@d/@H{ensindexstr}/fcst/</cyclestr><cyclestr offset="#fhr2#:00:00">history.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,True,meta_id,meta_bgn,meta_end,"MPASSIT",do_ensemble)
### end of mpassit --------------------------------------------------------

### begin of upp --------------------------------------------------------
def upp(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'FHR': '#fhr#',
  }
  if not do_ensemble:
    meta_id='upp'
    cycledefs='prod'
    # metatask (nested or not)
    fhr=os.getenv('FCST_LENGTH','9')
    #meta_hr=''.join(f'{i:03d} ' for i in range(int(fhr)+1)).strip()
    meta_hr=''.join(f'{i:03d} ' for i in range(int(fhr)+1)).strip()[4:] #remove '000 ' as no f000 diag and history files for restart cycles yet, gge.debug
    meta_bgn=f'''
<metatask name="{meta_id}">
<var name="fhr">{meta_hr}</var>'''
    meta_end=f'</metatask>\n'
    task_id=f'{meta_id}_f#fhr#'
    ensindexstr=""
  else:
    meta_id='upp'
    cycledefs='ens_prod'
    # metatask (nested or not)
    fhr=os.getenv('ENS_FCST_LENGTH','9')
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    #meta_hr=''.join(f'{i:03d} ' for i in range(int(fhr)+1)).strip()
    meta_hr=''.join(f'{i:03d} ' for i in range(int(fhr)+1)).strip()[4:] #remove '000 ' as no f000 diag and history files for restart cycles yet, gge.debug
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="fhr">{meta_hr}</var>'''
    meta_end=f'</metatask>\n</metatask>\n'
    task_id=f'{meta_id}_m#ens_index#_f#fhr#'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    ensindexstr="_m#ens_index#"

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{meta_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <taskdep task="mpassit{ensindexstr}_f#fhr#"/>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,True,meta_id,meta_bgn,meta_end,"UPP",do_ensemble)
### end of upp --------------------------------------------------------
