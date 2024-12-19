#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of ic --------------------------------------------------------
def ic(xmlFile, expdir, do_ensemble=False):
  meta_id='ic'
  cycledefs='ic,lbc' #don't know why we need init.nc for the lbc process but live with it right now
  extrn_mdl_source=os.getenv('IC_EXTRN_MDL_NAME','IC_PREFIX_not_defined')
  # Task-specific EnVars beyond the task_common_vars
  physics_suite=os.getenv('PHYSICS_SUITE','PHYSICS_SUITE_not_defined')
  dcTaskEnv={
    'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
    'PHYSICS_SUITE': f'{physics_suite}',
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
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
    meta_end=f'\
</metatask>\n'
    ensindexstr="_m#ens_index#"
    ensdirstr="/m#ens_index#"

  dcTaskEnv['DATAROOT']=f'<cyclestr>&DATAROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H{ensdirstr}</cyclestr>'

  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n      <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  dependencies=f'''
  <dependency>
    <and>{timedep}
      <taskdep task="ungrib_ic{ensindexstr}"/>
    </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"IC",do_ensemble)
### end of ic --------------------------------------------------------
