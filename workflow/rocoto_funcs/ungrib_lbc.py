#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of ungrib_lbc --------------------------------------------------------
def ungrib_lbc(xmlFile, expdir, do_ensemble=False):

  if not do_ensemble:
    metatask=False
    meta_id=''
    task_id=f'ungrib_lbc'
    cycledefs='lbc'
    # metatask (support nested metatasks)
#    fhr=os.getenv('FCST_LENGTH','12')
    offset=int(os.getenv('LBC_OFFSET','6'))
    length=int(os.getenv('LBC_LENGTH','12'))
    interval=int(os.getenv('LBC_INTERVAL','3'))
    meta_bgn=""
    meta_end=""
    extrn_mdl_source=os.getenv('LBC_EXTRN_MDL_NAME','GFS')
    lbc_source_basedir=os.getenv('LBC_EXTRN_MDL_BASEDIR','')
    lbc_name_pattern=os.getenv('LBC_EXTRN_MDL_NAME_PATTERN','')
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
    extrn_mdl_source=os.getenv('ENS_LBC_PREFIX','GEFS')

  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'TYPE': 'lbc',
    'SOURCE_BASEDIR': f'<cyclestr offset="-{offset}:00:00">{lbc_source_basedir}</cyclestr>',
    'NAME_PATTERN': f'<cyclestr offset="-{offset}:00:00">{lbc_name_pattern}</cyclestr>',
    'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
    'OFFSET': f'{offset}',
    'LENGTH': f'{length}',
    'INTERVAL': f'{interval}',
  }

  # dependencies
  COMINgfs=os.getenv("COMINgfs",'COMINgfs_not_defined')
  COMINgefs=os.getenv("COMINgefs",'COMINgefs_not_defined')
  if extrn_mdl_source == "GFS":
    fpath=f'{COMINgfs}/gfs.@Y@m@d/@H/gfs.t@Hz.pgrb2.0p25.f#fhr_in#'
  elif extrn_mdl_source == "GEFS":
    fpath=f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2ap5/gep#gmem#.t@Hz.pgrb2a.0p50.f#fhr_in#'
    fpath2=f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2bp5/gep#gmem#.t@Hz.pgrb2b.0p50.f#fhr_in#'
  else:
    fpath=f'{lbc_source_basedir}/{lbc_name_pattern}'

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n     <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  
  datadep=f' '
  for i in range( int(offset), int(length)+int(offset)+1, int(interval) ):
     comin_hr3=str(i).zfill(3)
     fpath3=fpath.replace('${HHH}', comin_hr3)
     datadep=datadep+f'\n     <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath3}</cyclestr></datadep>'

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
