#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of fcst --------------------------------------------------------


def save_for_next(xmlFile, expdir, dcGrpInfo, do_ensemble=False):
    meta_id = 'save_for_next'
    fhr = dcGrpInfo["fhr"]
    task_id = f'{meta_id}_f{fhr:02d}'
    cycledefs = dcGrpInfo['cycledef']
    cyc_interval = os.getenv('CYC_INTERVAL')
    mpasout_interval = os.getenv('MPASOUT_INTERVAL', '1') or cyc_interval

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'MPASOUT_INTERVAL': mpasout_interval,
        'FCST_HR': f'{fhr}',
    }

    if do_ensemble:
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        dcTaskEnv['ENS_SIZE'] = str(ens_size)

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{meta_id}".upper()).upper()

    # dependencies
    if do_ensemble:
        datadep = ""
        for i in range(1, int(ens_size) + 1):
            memdirstr = f'/mem{i:03d}'
            datadep = datadep + f'''\n    <datadep age="00:00:10"><cyclestr>&DATAROOT;/@Y@m@d/&RUN;_fcst_@H_&rrfs_ver;/&WGF;{memdirstr}</cyclestr><cyclestr offset="{fhr}:00:00">/mpasout.@Y-@m-@d_@H.@M.@S.nc.done</cyclestr></datadep>'''
    else:
        datadep = f'''\n    <datadep age="00:00:10"><cyclestr>&DATAROOT;/@Y@m@d/&RUN;_fcst_@H_&rrfs_ver;/&WGF;</cyclestr><cyclestr offset="{fhr}:00:00">/mpasout.@Y-@m-@d_@H.@M.@S.nc.done</cyclestr></datadep>'''

    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_FCST".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}{datadep}
  </and>
  </dependency>'''

    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, command_id="SAVE_FOR_NEXT")
# end of fcst --------------------------------------------------------
