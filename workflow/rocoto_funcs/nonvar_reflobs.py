#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of nonvar_reflobs --------------------------------------------------------


def nonvar_reflobs(xmlFile, expdir):
    task_id = 'nonvar_reflobs'
    cycledefs = 'prod'
    if os.getenv("DO_SPINUP", "FALSE").upper() == "TRUE":
        cycledefs = 'prod,spinup'
    OBSPATH_NSSLMOSIAC = os.getenv("OBSPATH_NSSLMOSIAC", 'OBSPATH_NSSLMOSIAC_not_defined')
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'OBSPATH_NSSLMOSIAC': f'{OBSPATH_NSSLMOSIAC}'
    }

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies

    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
        dependencies = f'''
  <dependency>
    {timedep}
  </dependency>'''
    else:
        dependencies = f' '
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of nonvar_reflobs --------------------------------------------------------
