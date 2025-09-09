#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of prep_chem --------------------------------------------------------
def prep_chem(xmlFile, expdir,do_ensemble=False, do_spinup=False):
  meta_id='prep_chem'
  cycledefs='prod'
#  if do_spinup:
#    cycledefs='spinup'
#    num_spinup_cycledef=os.getenv('NUM_SPINUP_CYCLEDEF','1')
#    if num_spinup_cycledef=='2':
#      cycledefs='spinup,spinup2'
#    elif num_spinup_cycledef=='3':
#      cycledefs='spinup,spinup2,spinup3'
#  else:
#    cycledefs='prod'

  # Task-specific EnVars beyond the task_common_vars
  datadir_chem=os.getenv('DATADIR_CHEM','/lfs6/BMC/rtwbl/cheMPAS-Fire/input/')
  mesh_name=os.getenv('MESH_NAME','conus3km').lower()
  fcst_length=os.getenv('FCST_LENGTH','24')

  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'MESH_NAME': f'{mesh_name}',
    'DATADIR_CHEM': f'{datadir_chem}' }
#
  metatask=True
  task_id=f'{meta_id}_#sector#'
  dcTaskEnv['EMIS_SECTOR_TO_PROCESS']='#sector#'
  dcTaskEnv['ANTHRO_EMISINV']='GRAPES'
  meta_bgn=""
  meta_end=""

  num_emis=int(os.getenv('NUM_EMIS_SECTORS','1'))
#  emis_indices=''.join(f'{i:03d} ' for i in range(1,int(num_emis)+1)).strip()
  emis_sectors='smoke anthro pollen dust rwc'.strip()


  meta_bgn=f'''
<metatask name="{meta_id}_">
<var name="sector">{emis_sectors}</var>'''
  meta_end=f'\
</metatask>\n'

  # dependencies

  timedep=""
  realtime=os.getenv("REALTIME","false")
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  #initdep=f'\n   <taskdep><task="init_ctl"/>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  </and>
  </dependency>'''

  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"PREP_CHEM")
### end of prep_chem --------------------------------------------------------
