#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ioda_viirs ----------------------------------------------------------


def ioda_viirs(xmlFile, expdir):
    task_id = 'ioda_viirs'
    cycledefs = 'viirs'
    if os.getenv("DO_SPINUP", "FALSE").upper() == "TRUE":
        cycledefs = 'viirs,viirs_spinup'
    OBSPATH_VIIRS = os.getenv("OBSPATH_VIIRS", 'OBSPATH_VIIRS_not_defined')
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'YAML_GEN_METHOD': os.getenv('YAML_GEN_METHOD', '1'),
        'OBSPATH_VIIRS': f'{OBSPATH_VIIRS}'
    }

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    fpath = f'{OBSPATH_VIIRS}/@Y@m@d/JRR-AOD_v3r2_*.nc'
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    <datadep age="00:02:00"><cyclestr>{fpath}</cyclestr></datadep>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of ioda_viirs - --------------------------------------------------------
