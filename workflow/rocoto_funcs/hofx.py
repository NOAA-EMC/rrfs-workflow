#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of hofx --------------------------------------------------------


def hofx(xmlFile, expdir, do_spinup=False):
    cycledefs = 'prod'
    task_id = 'hofx'
    # Task-specific EnVars beyond the task_common_vars
    COMROOT = os.getenv('COMROOT', 'COMROOT_not_defined')
    NET = os.getenv('NET', 'rrfs')
    rrfs_ver = os.getenv('VERSION', 'v2.0.0')
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': os.getenv('IC_EXTRN_MDL_NAME', 'IC_PREFIX_not_defined'),
        'PHYSICS_SUITE': os.getenv('PHYSICS_SUITE', 'PHYSICS_SUITE_not_defined'),
        'EMPTY_OBS_SPACE_ACTION': os.getenv('EMPTY_OBS_SPACE_ACTION', 'skip output'),
        'HOFX_FHRS': os.getenv('HOFX_FHRS', '001'),
        'IODA_PATH': f'{COMROOT}/{NET}/{rrfs_ver}'
    }

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "FALSE")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>{timedep}
    <taskdep task="fcst"/>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, command_id="hofx")
# end of hofx --------------------------------------------------------
