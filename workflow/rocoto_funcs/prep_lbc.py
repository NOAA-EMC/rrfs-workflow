#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of fcst --------------------------------------------------------
def prep_lbc(xmlFile, expdir, do_ensemble=False):
  meta_id='prep_lbc'
  cycledefs='prod'
  num_spinup_cycledef=int(os.getenv('NUM_SPINUP_CYCLEDEF','0'))
  if num_spinup_cycledef==1:
    cycledefs='prod,spinup'
  elif num_spinup_cycledef==2:
    cycledefs='prod,spinup,spinup2'
  elif num_spinup_cycledef==3:
    cycledefs='prod,spinup,spinup2,spinup3'

  # Task-specific EnVars beyond the task_common_vars
  fcst_length=os.getenv('FCST_LENGTH','1')
  lbc_interval=os.getenv('LBC_INTERVAL','3')
  fcst_len_hrs_cycles=os.getenv('FCST_LEN_HRS_CYCLES', '3 15')
  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'LBC_INTERVAL': f'{lbc_interval}',
    'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycles}'
  }

  if not do_ensemble:
    metatask=False
    task_id=f'{meta_id}'
    meta_bgn=""
    meta_end=""
    ensindexstr=""
    ensdirstr=""
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
    ensdirstr="/mem#ens_index#"

  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'

  taskdep=""
  for hr in range(0,12):
    taskdep=taskdep + f'\n     <metataskdep metatask="lbc{ensindexstr}" cycle_offset="-{hr}:00:00" />'
  
  dependencies=f'''
  <dependency>
  <and>{timedep}
   <or>{taskdep}
   </or>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"PREP_LBC",do_ensemble)
### end of fcst --------------------------------------------------------
