#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of proc_bufr_nonvar --------------------------------------------------------


def proc_bufr_nonvar(xmlFile, expdir):
    task_id = 'proc_bufr_nonvar'
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
        'OBSPATH': f'{OBSPATH}'
    }

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    larc_path = f'{OBSPATH}/@Y@m@d@H.rap.t@Hz.lgycld.tm00.bufr_d'
    lght_path = f'{OBSPATH}/@Y@m@d@H.rap.t@Hz.lghtng.tm00.bufr_d'
    metar_path = f'{OBSPATH}/@Y@m@d@H.rap.t@Hz.prepbufr.tm00'

    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    <datadep age="00:05:00"><cyclestr>{larc_path}</cyclestr></datadep>
    <datadep age="00:05:00"><cyclestr>{lght_path}</cyclestr></datadep>
    <datadep age="00:05:00"><cyclestr>{metar_path}</cyclestr></datadep>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of proc_bufr_nonvar --------------------------------------------------------
