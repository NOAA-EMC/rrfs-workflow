#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of recenter --------------------------------------------------------


def recenter(xmlFile, expdir):
    task_id='recenter'
    cycledefs='prod'
    # Task-specific EnVars beyond the task_common_vars
    extrn_mdl_source=os.getenv('IC_EXTRN_MDL_NAME','IC_PREFIX_not_defined')
    dcTaskEnv={
        'ENS_SIZE': os.getenv("ENS_SIZE",'5')
    }
    # dependencies
    timedep=""
    realtime=os.getenv("REALTIME","false")
    if realtime.upper() == "TRUE":
        starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep=f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    # ~~
    dependencies=f'''
  <dependency>
    <and>{timedep}
      <metataskdep metatask="prep_ic"/>
    </and>
    </dependency>'''
    #
    xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv=dcTaskEnv,dependencies=dependencies,command_id="RECENTER")
### end of recenter --------------------------------------------------------
