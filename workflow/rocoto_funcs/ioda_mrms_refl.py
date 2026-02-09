#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ioda_bufr --------------------------------------------------------


def ioda_mrms_refl(xmlFile, expdir):
    task_id = 'ioda_mrms_refl'
    cycledefs = 'prod'
    num_spinup_cycledef = int(os.getenv('NUM_SPINUP_CYCLEDEF', '0'))
    if num_spinup_cycledef == 1:
        cycledefs = 'prod,spinup'
    elif num_spinup_cycledef == 2:
        cycledefs = 'prod,spinup,spinup2'
    elif num_spinup_cycledef == 3:
        cycledefs = 'prod,spinup,spinup2,spinup3'
    OBSPATH_NSSLMOSIAC = os.getenv("OBSPATH_NSSLMOSIAC", 'OBSPATH_NSSLMOSIAC_not_defined')
    RADARREFL_TIMELEVEL = os.getenv("RADARREFL_TIMELEVEL", 'RADARREFL_TIMELEVEL_not_defined')
    MRMS_GRIDSPACINGDEG = os.getenv("MRMS_GRIDSPACINGDEG", 'MRMS_GRIDSPACINGDEG_not_defined')
    do_jedi = os.getenv("DO_JEDI", "FALSE").upper()
    do_ensemble = os.getenv("DO_ENSEMBLE", "FALSE").upper()
    if do_ensemble == "TRUE" and do_jedi == "TRUE":
        ASSIM_METHOD = "getkf"
    elif do_jedi == "TRUE":
        ASSIM_METHOD = "jedivar"
    else:
        ASSIM_METHOD = "no_da"
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'OBSPATH_NSSLMOSIAC': f'{OBSPATH_NSSLMOSIAC}',
        'RADARREFL_TIMELEVEL': f'{RADARREFL_TIMELEVEL}',
        'MRMS_GRIDSPACINGDEG': f'{MRMS_GRIDSPACINGDEG}',
        'ASSIM_METHOD': f'{ASSIM_METHOD}'
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
# end of ioda_bufr --------------------------------------------------------
