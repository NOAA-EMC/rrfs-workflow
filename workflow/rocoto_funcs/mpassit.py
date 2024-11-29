#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of mpassit --------------------------------------------------------
def mpassit(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  mpassit_group_total_num=int(os.getenv('MPASSIT_GROUP_TOTAL_NUM','1'))
  fcst_length=os.getenv('FCST_LENGTH','1')
  history_interval=os.getenv('HISTORY_INTERVAL', '1')

  if not do_ensemble:
    meta_id='mpassit'
    cycledefs='prod'
    # metatask (nested or not)
    fcst_len_hrs_cycls=os.getenv('FCST_LEN_HRS_CYCLES', '03 03')

    group_indices=''.join(f'{i:02d} ' for i in range(1,int(mpassit_group_total_num)+1,int(history_interval))).strip()
    fhr2=''.join(f'{i:02d} ' for i in range(0,int(mpassit_group_total_num),int(history_interval))).strip()
    meta_bgn=f'''
<metatask name="{meta_id}">
<var name="group_index">{group_indices}</var>
<var name="fhr2">{fhr2}</var>
'''
    meta_end=f'</metatask>\n'
    task_id=f'{meta_id}_g#group_index#'

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
    group_indices=''.join(f'{i:02d} ' for i in range(1,int(mpassit_group_total_num)+1)).strip()
    fhr2=''.join(f'{i:02d} ' for i in range(int(mpassit_group_total_num)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="group_index">{group_indices}</var>
<var name="fhr2">{fhr2}</var>'''
    meta_end=f'</metatask>\n</metatask>\n'
    task_id=f'{meta_id}_m#ens_index#_g#group_index#'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    ensindexstr="_m#ens_index#"
    RUN='ens'

  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'HISTORY_INTERVAL': f'{history_interval}',
    'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycls}',
    'GROUP_TOTAL_NUM': f'{mpassit_group_total_num}',
    'GROUP_INDEX': f'#group_index#'
  }

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{meta_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  DATAROOT=os.getenv("DATAROOT","DATAROOT_NOT_DEFINED")
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  wgf=os.getenv("WGF","WGF_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <datadep age="00:05:00"><cyclestr>&DATAROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H{ensindexstr}/{wgf}/&RUN;_fcst_@H/</cyclestr><cyclestr offset="#fhr2#:00:00">diag.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,True,meta_id,meta_bgn,meta_end,"MPASSIT",do_ensemble)
### end of mpassit --------------------------------------------------------
