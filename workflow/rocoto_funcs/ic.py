#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of ic --------------------------------------------------------
def ic(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={}
  if not do_ensemble:
    metatask=False
    meta_id=''
    task_id='ic'
    cycledefs='ic,lbc' #don't know why we need init.nc for the lbc process but live with it right now
    meta_bgn=""
    meta_end=""
    ensindexstr=""
  else:
    metatask=True
    meta_id='ic'
    task_id=f'{meta_id}_m#ens_index#'
    cycledefs='ens_ic,ens_lbc'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
    meta_end=f'\
</metatask>\n'
    ensindexstr="_m#ens_index#"

  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <or>
    <taskdep task="ungrib_ic{ensindexstr}"/>
    <taskdep task="ungrib_lbc{ensindexstr}_f000"/>
  </or>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"IC",do_ensemble)
### end of ic --------------------------------------------------------
