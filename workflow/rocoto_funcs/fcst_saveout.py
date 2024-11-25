#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of fcst --------------------------------------------------------
def fcst_saveout(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={}
  if not do_ensemble:
    metatask=False
    meta_id=''
    task_id='fcst_saveout'
    cycledefs='prod'
    hrs=os.getenv('PROD_BGN_AT_HRS', '3 15')
    fcst_len_hrs_cycls=os.getenv('FCST_LEN_HRS_CYCLES', '03 03')
    meta_bgn=""
    meta_end=""
    RUN='rrfs'
    ensindexstr=""
    ensstr=""
  else:
    metatask=True
    meta_id='fcst_saveout'
    task_id=f'{meta_id}_m#ens_index#'
    cycledefs='ens_prod'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    hrs=os.getenv('ENS_PROD_BGN_AT_HRS', '3 15')
    meta_bgn=""
    meta_end=""
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
    meta_end=f'\
</metatask>\n'
    RUN='ens'
    ensindexstr="_m#ens_index#"
    ensstr="ens_"

  # Task-specific EnVars beyond the task_common_vars
  fcst_length=os.getenv('FCST_LENGTH','1')
  history_interval=os.getenv('HISTORY_INTERVAL', '1')
  restart_interval=os.getenv('RESTART_INTERVAL', '61')
  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'HISTORY_INTERVAL': f'{history_interval}',
    'RESTART_INTERVAL': f'{restart_interval}',
    'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycls}'
  }

  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_FCST".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  DATAROOT=os.getenv("DATAROOT","DATAROOT_NOT_DEFINED")
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <datadep age="00:01:00"><cyclestr>&DATAROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H{ensindexstr}/&RUN;_fcst_@H/diag.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
  </and>
  </dependency>'''


  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"FCST_SAVEOUT",do_ensemble)
### end of fcst --------------------------------------------------------
