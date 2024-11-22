#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of ungrib_ic --------------------------------------------------------
def ungrib_ic(xmlFile, expdir, do_ensemble=False):
  #
  if not do_ensemble:
    metatask=False
    meta_id=''
    task_id='ungrib_ic'
    cycledefs='ic'
    extrn_mdl_source=os.getenv('IC_EXTRN_MDL_NAME','IC_PREFIX_not_defined')
    offset=os.getenv('IC_OFFSET','3')
    meta_bgn=""
    meta_end=""
    ic_source_basedir=os.getenv('IC_EXTRN_MDL_BASEDIR','MDL_BASEDIR_not_defined')
    ic_name_pattern=os.getenv('IC_EXTRN_MDL_NAME_PATTERN','NAME_PATTERN_not_defined')
    offset=int(os.getenv('IC_OFFSET','6'))
    net=os.getenv('NET','3')
    rrfs_ver=os.getenv('VERSION','v2.0.0')
  else:
    metatask=True
    meta_id='ungrib_ic'
    task_id=f'{meta_id}_m#ens_index#'
    cycledefs='ens_ic'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    extrn_mdl_source=os.getenv('ENS_IC_PREFIX','GEFS')
    offset=os.getenv('ENS_IC_OFFSET','36')
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    gmems=''.join(f'{i:02d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>
<var name="gmem">{gmems}</var>'''
    meta_end=f'</metatask>\n'

  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'TYPE': 'ic',
    'SOURCE_BASEDIR': f'<cyclestr offset="-{offset}:00:00">{ic_source_basedir}</cyclestr>',
    'NAME_PATTERN': f'<cyclestr offset="-{offset}:00:00">{ic_name_pattern}</cyclestr>',
    'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
    'OFFSET': f'{offset}',
  }
  #
  # dependencies
  COMINgfs=os.getenv("COMINgfs",'COMINgfs_not_defined')
  COMINgefs=os.getenv("COMINgefs",'COMINgefs_not_defined')
  if source == "GFS":
    fpath=f'{COMINgfs}/gfs.@Y@m@d/@H/gfs.t@Hz.pgrb2.0p25.f{offset:>03}'
  elif source == "GEFS":
    fpath=f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2ap5/gep#gmem#.t@Hz.pgrb2a.0p50.f{offset:>03}'
    fpath2=f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2bp5/gep#gmem#.t@Hz.pgrb2b.0p50.f{offset:>03}'
  else:
    fpath=f'{ic_source_basedir}/{ic_name_pattern}'

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  comin_hr=str(int(offset)).zfill(3)
  fpath3=fpath.replace('fHHH', comin_hr)
  datadep=f'   <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath3}</cyclestr></datadep>'
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
