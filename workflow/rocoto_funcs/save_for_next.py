#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of fcst --------------------------------------------------------


def save_for_next(xmlFile, expdir, do_ensemble=False, do_spinup=False):
    cyc_interval = os.getenv('CYC_INTERVAL')
    cycledefs = 'prod'
    task_id = 'save_for_next'

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'MPASOUT_INTERVAL': os.getenv('MPASOUT_INTERVAL', '1'),
        'CYC_INTERVAL': os.getenv('CYC_INTERVAL', '3'),
    }

    if do_ensemble:
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        dcTaskEnv['ENS_SIZE'] = str(ens_size)

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    if do_ensemble:
        datadep = ""
        for i in range(1, int(ens_size) + 1):
            memdirstr = f'/mem{i:03d}'
            datadep = datadep + f'''\n    <datadep age="00:01:00"><cyclestr>&DATAROOT;/@Y@m@d/&RUN;_fcst_@H_&rrfs_ver;/&WGF;{memdirstr}</cyclestr><cyclestr offset="{cyc_interval}:00:00">/mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'''
    else:
        datadep = f'''\n    <datadep age="00:01:00"><cyclestr>&DATAROOT;/@Y@m@d/&RUN;_fcst_@H_&rrfs_ver;/&WGF;</cyclestr><cyclestr offset="{cyc_interval}:00:00">/mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'''

    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_FCST".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>{timedep}{datadep}
  </dependency>'''

    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, command_id="SAVE_FOR_NEXT")
# end of fcst --------------------------------------------------------
