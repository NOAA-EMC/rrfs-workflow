#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ioda_bufr --------------------------------------------------------


def ioda_bufr(xmlFile, expdir):
    task_id = 'ioda_bufr'
    cycledefs = 'prod'
    num_spinup_cycledef = int(os.getenv('NUM_SPINUP_CYCLEDEF', '0'))
    if num_spinup_cycledef == 1:
        cycledefs = 'prod,spinup'
    elif num_spinup_cycledef == 2:
        cycledefs = 'prod,spinup,spinup2'
    elif num_spinup_cycledef == 3:
        cycledefs = 'prod,spinup,spinup2,spinup3'
    OBSPATH = os.getenv("OBSPATH", 'OBSPATH_not_defined')
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'YAML_GEN_METHOD': os.getenv('YAML_GEN_METHOD', '1'),
        'OBSPATH': f'{OBSPATH}'
    }
    # dependencies
    fpath = f'{OBSPATH}/@Y@m@d@H.rap.t@Hz.prepbufr.tm00'

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
# end of ioda_bufr --------------------------------------------------------
