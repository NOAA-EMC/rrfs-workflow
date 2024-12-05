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
    meta_bgn=""
    meta_end=""
    #
    extrn_mdl_source=os.getenv('IC_EXTRN_MDL_NAME','IC_PREFIX_not_defined')
    ic_source_basedir=os.getenv('IC_EXTRN_MDL_BASEDIR','MDL_BASEDIR_not_defined')
    ic_name_pattern=os.getenv('IC_EXTRN_MDL_NAME_PATTERN','NAME_PATTERN_not_defined')
    ic_name_pattern_b=os.getenv('IC_EXTRN_MDL_NAME_PATTERN_B','')
    offset=os.getenv('IC_OFFSET','3')
    net=os.getenv('NET','rrfs')
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
  fpath=f'{ic_source_basedir}/{ic_name_pattern}'.replace('fHHH', offset.zfill(3))

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  datadep=f'  <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath}</cyclestr></datadep>'
  if ic_name_pattern_b != '':
    dcTaskEnv['NAME_PATTERN_B']=f'<cyclestr offset="-{offset}:00:00">{ic_name_pattern_b}</cyclestr>'
    fpath2=f'{ic_source_basedir}/{ic_name_pattern_b}'.replace('fHHH', offset.zfill(3))
    datadep=datadep+f'\n     <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath2}</cyclestr></datadep>'
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
