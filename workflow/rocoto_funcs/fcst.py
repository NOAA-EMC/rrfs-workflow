#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of fcst --------------------------------------------------------
def fcst(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  meta_id='fcst'
  cycledefs='prod'
  hrs=os.getenv('PROD_BGN_AT_HRS', '3 15')
  fcst_len_hrs_cycles=os.getenv('FCST_LEN_HRS_CYCLES', '03 03')
  fcst_length=os.getenv('FCST_LENGTH','1')
  lbc_interval=os.getenv('LBC_INTERVAL','3')
  history_interval=os.getenv('HISTORY_INTERVAL', '1')
  restart_interval=os.getenv('RESTART_INTERVAL', '61')
  physics_suite=os.getenv('PHYSICS_SUITE','PHYSICS_SUITE_not_defined')
  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'LBC_INTERVAL': f'{lbc_interval}',
    'HISTORY_INTERVAL': f'{history_interval}',
    'RESTART_INTERVAL': f'{restart_interval}',
    'PHYSICS_SUITE': f'{physics_suite}',
    'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycles}'
  }

  if not do_ensemble:
    metatask=False
    task_id=f'{meta_id}'
    meta_bgn=""
    meta_end=""
    ensindexstr=""
    ensdirstr=""
    ensstr=""
  else:
    metatask=True
    task_id=f'{meta_id}_m#ens_index#'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    meta_bgn=""
    meta_end=""
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
    meta_end=f'\
</metatask>\n'
    ensindexstr="_m#ens_index#"
    ensdirstr="/m#ens_index#"
    ensstr="ens_"

  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'

  jedidep=""
  if os.getenv("DA_JEDI","FALSE").upper()=="TRUE":
    jedidep=f'<taskdep task="jedivar"/>'
  
  dependencies=f'''
  <dependency>
  <and>{timedep}
    <taskdep task="prep_lbc{ensindexstr}" cycle_offset="0:00:00"/>
    <taskdep task="prep_ic{ensindexstr}"/>
    {jedidep}
  </and>
  </dependency>'''
  
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"FCST",do_ensemble)
### end of fcst --------------------------------------------------------
