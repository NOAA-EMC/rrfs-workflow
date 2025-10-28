#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of prep_chem --------------------------------------------------------
def prep_chem_icbc(xmlFile, expdir,do_ensemble=False, do_spinup=False):
  meta_id='prep_chem_icbc'
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
  realtime=os.getenv("REALTIME","false")

  # Task-specific EnVars beyond the task_common_vars
  chempath=os.getenv('CHEMPATH','/lfs6/BMC/rtwbl/cheMPAS-Fire/input/')
  mesh_name=os.getenv('MESH_NAME','conus3km').lower()
  fcst_length=os.getenv('FCST_LENGTH','24')

  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'MESH_NAME': f'{mesh_name}',
    'CHEMPATH': f'{chempath}' }
#

  metatask=False
  task_id=f'{meta_id}'
  meta_bgn=""
  meta_end=""

  # dependencies

  timedep=f''
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    
  #
  initdep=f'\n   <taskdep task="prep_ic"/>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  {initdep}
  </and>
  </dependency>'''

  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"PREP_CHEM_ICBC")
### end of prep_chem --------------------------------------------------------
