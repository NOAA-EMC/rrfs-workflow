#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of fcst --------------------------------------------------------
def save_fcst(xmlFile, expdir, do_ensemble=False, do_spinup=False):
  meta_id='save_fcst'
  if do_spinup:
    cycledefs='spinup'
  else:
    cycledefs='prod'
  WGF=os.getenv('WGF','WGF not defined')
  # Task-specific EnVars beyond the task_common_vars
  fcst_length=os.getenv('FCST_LENGTH','1')
  history_interval=os.getenv('HISTORY_INTERVAL', '1')
  restart_interval=os.getenv('RESTART_INTERVAL', '99')
  fcst_len_hrs_cycles=os.getenv('FCST_LEN_HRS_CYCLES', '03 03')
  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'HISTORY_INTERVAL': f'{history_interval}',
    'RESTART_INTERVAL': f'{restart_interval}',
    'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycles}'
  }

  if not do_ensemble:
    metatask=False
    if do_spinup:
      task_id=f'{meta_id}_spinup'
    else:
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
  if do_spinup:
    datadep=f'''<datadep age="00:01:00"><cyclestr>&DATAROOT;/@Y@m@d/&RUN;_fcst_spinup_@H_&rrfs_ver;/&WGF;{ensdirstr}/fcst_spinup_@H/diag.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'''
  else:
    datadep=f'''<datadep age="00:01:00"><cyclestr>&DATAROOT;/@Y@m@d/&RUN;_fcst_@H_&rrfs_ver;/&WGF;{ensdirstr}/fcst_@H/diag.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'''
  timedep=""
  realtime=os.getenv("REALTIME","false")
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_FCST".upper())
    timedep=f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
    {datadep}
  </and>
  </dependency>'''


  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"SAVE_FCST",do_ensemble)
### end of fcst --------------------------------------------------------
