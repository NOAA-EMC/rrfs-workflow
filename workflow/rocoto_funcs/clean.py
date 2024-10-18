#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of clean --------------------------------------------------------
def clean(xmlFile, expdir):
  task_id='clean'
  cycledefs='prod'
  xml_task(xmlFile,expdir,task_id,cycledefs)
### end of clean --------------------------------------------------------
