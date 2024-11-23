#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of lbc --------------------------------------------------------
def lbc(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'FHR': '#fhr#',
  }
  if not do_ensemble:
    meta_id='lbc'
    cycledefs='lbc'
    # metatask (nested or not)
    extern_mdl_source=os.getenv('LBC_EXTRN_MDL_NAME','GFS')
    fhr=os.getenv('FCST_LENGTH','12')
    offset=int(os.getenv('LBC_OFFSET','6'))
    length=int(os.getenv('LBC_LENGTH','18'))
    interval=int(os.getenv('LBC_INTERVAL','3'))
    lbc_group_num=int(os.getenv('LBC_GROUP_NUM','1'))
    group_indices=''.join(f'{i:02d} ' for i in range(1,int(lbc_group_num)+1)).strip()
    meta_bgn=f'''
<metatask name="{meta_id}_group">
<var name="group_index">{group_indices}</var>'''
    meta_end=f'\
</metatask>\n'
    task_id=f'{meta_id}_g#group_index#'
    ensindexstr=""
  #
  else: #ensemble
    meta_id='lbc'
    cycledefs='ens_lbc'
    # metatask (nested or not)
    fhr=os.getenv('ENS_FCST_LENGTH','6')
    offset=int(os.getenv('ENS_LBC_OFFSET','36'))
    length=int(os.getenv('ENS_LBC_LENGTH','12'))
    interval=int(os.getenv('ENS_LBC_INTERVAL','3'))
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_hr= ''.join(f'{i:03d} ' for i in range(0,int(length)+1,int(interval))).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="fhr">{meta_hr}</var>'''
    meta_end=f'\
</metatask>\n\
</metatask>\n'
    task_id=f'{meta_id}_m#ens_index#_f#fhr#'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    ensindexstr="_m#ens_index#"

  # Task-specific EnVars beyond the task_common_vars
  physics_suite=os.getenv('PHYSICS_SUITE','PHYSICS_SUITE_not_defined')
  dcTaskEnv={
    'EXTRN_MDL_SOURCE': f'{extern_mdl_source}',
    'PHYSICS_SUITE': f'{physics_suite}',
    'OFFSET': f'{offset}',
    'LENGTH': f'{length}',
    'INTERVAL': f'{interval}',
    'GROUP_INDEX': f'#group_index#',
    'GROUP_NUM': f'{lbc_group_num}'
  }

  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <metataskdep metatask="ungrib_lbc_group{ensindexstr}"/>
  <taskdep task="ic{ensindexstr}"/>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,True,meta_id,meta_bgn,meta_end,"LBC",do_ensemble)
### end of lbc --------------------------------------------------------
