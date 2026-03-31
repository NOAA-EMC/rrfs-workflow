#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of graphics --------------------------------------------------------


def graphics(xmlFile, expdir, index, dcGrpInfo, lastGrp=False):
    task_id = f'graphics_g{index:02d}'
    cycledefs = dcGrpInfo['cycledef']
    group_hours = dcGrpInfo["hours"]
    parts = group_hours.split('-')
    if len(parts) == 1:
        str_hours = parts[0]
    else:
        step = 1
        if len(parts) == 3:
            step = int(parts[2])
        bgn_hr = int(parts[0])
        end_hr = int(parts[1])
        str_hours = " ".join(str(i) for i in range(bgn_hr, end_hr + step, step))
    #
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'FCST_LEN_HRS_CYCLES': os.getenv('FCST_LEN_HRS_CYCLES', '03 03'),
        'GROUP_INDEX': f'{index:02d}',
        'GROUP_HOURS': f'{str_hours}',
        'TILES': os.getenv('GRAPHICS_TILES', 'full'),
        'GRAPHICS_ZIP': os.getenv('GRAPHICS_ZIP', 'FALSE').upper(),
        'LAST_GROUP': f'{lastGrp}'.upper(),
    }
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    <taskdep task="upp_g{index:02d}"/>
  </and>
  </dependency>'''

    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, command_id="GRAPHICS")

# end of graphics --------------------------------------------------------
