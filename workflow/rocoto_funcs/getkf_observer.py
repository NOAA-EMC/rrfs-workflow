#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of getkf_observer --------------------------------------------------------
def getkf_observer(xmlFile, expdir):
  task_id='getkf_observer'
  cycledefs='prod'
  # Task-specific EnVars beyond the task_common_vars
  extrn_mdl_source=os.getenv('IC_EXTRN_MDL_NAME','IC_PREFIX_not_defined')
  physics_suite=os.getenv('PHYSICS_SUITE','PHYSICS_SUITE_not_defined')
  dcTaskEnv={
    'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
    'PHYSICS_SUITE': f'{physics_suite}',
    'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
    'TYPE': 'OBSERVER'
  }
  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  COMROOT=os.getenv("COMROOT","COMROOT_NOT_DEFINED")
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
    <taskdep task="prep_ic"/>
    <taskdep task="ioda_bufr"/>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv=dcTaskEnv,dependencies=dependencies,command_id="GETKF")
### end of getkf_observer --------------------------------------------------------
