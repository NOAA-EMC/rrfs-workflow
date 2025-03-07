#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
from rocoto_funcs.base import xml_task, get_cascade_env

### begin of clean --------------------------------------------------------
def clean(xmlFile, expdir):
  task_id='clean'
  cycledefs='prod'
  #
  dcTaskEnv={
    'STMP_RETENTION_HRS': os.getenv("STMP_RETENTION_HRS",'24'),
    'COM_RETENTION_HRS': os.getenv("COM_RETENTION_HRS",'120'),
    'CLEAN_BACK_DAYS': os.getenv("CLEAN_BACK_DAYS",'5'),
  }
  #
  xml_task(xmlFile,expdir,task_id,cycledefs)
### end of clean --------------------------------------------------------
