#!/usr/bin/env python
import os
from xml_funcs.base import xml_task, source, get_cascade_env

### begin of ioda_bufr --------------------------------------------------------
def ioda_bufr(xmlFile, expdir):
  task_id='ioda_bufr'
  cycledefs='prod'
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z'
  }
  # dependencies
  OBSINprepbufr=os.getenv("OBSINprepbufr",'OBSINprepbufr_not_defined')
  fpath=f'{OBSINprepbufr}/@Y@m@d@H.rap.t@Hz.prepbufr.tm00'

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <datadep age="00:05:00"><cyclestr>{fpath}</cyclestr></datadep>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies)
  #xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,False,"", "", "","UNGRIB")
### end of ioda_bufr --------------------------------------------------------
