#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ioda_airnow --------------------------------------------------------


def ioda_airnow(xmlFile, expdir):
    task_id = 'ioda_airnow'
    cycledefs = 'prod'
    num_spinup_cycledef = int(os.getenv('NUM_SPINUP_CYCLEDEF', '0'))
    if num_spinup_cycledef == 1:
        cycledefs = 'prod,spinup'
    elif num_spinup_cycledef == 2:
        cycledefs = 'prod,spinup,spinup2'
    elif num_spinup_cycledef == 3:
        cycledefs = 'prod,spinup,spinup2,spinup3'
    OBSPATH_AIRNOW = os.getenv("OBSPATH_AIRNOW", 'OBSPATH_AIRNOW_not_defined')
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'YAML_GEN_METHOD': os.getenv('YAML_GEN_METHOD', '1'),
        'OBSPATH_AIRNOW': f'{OBSPATH_AIRNOW}'
    }

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    fpath = f'{OBSPATH_AIRNOW}/HourlyData_@Y@m@d@H.dat'

    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    <datadep age="00:05:00"><cyclestr>{fpath}</cyclestr></datadep>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of ioda_airnow --------------------------------------------------------
