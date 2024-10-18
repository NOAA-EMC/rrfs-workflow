#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

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
