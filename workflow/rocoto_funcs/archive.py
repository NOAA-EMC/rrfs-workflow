#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
import textwrap
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of archive --------------------------------------------------------


def archive(xmlFile, expdir, spinup_mode=0):
    task_id = 'archive'
    do_spinup = spinup_mode == 1
    if do_spinup:
        cycledefs = 'spinup'
    else:
        cycledefs = 'prod'
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'ARCHIVE_HPSSDIR': os.getenv("ARCHIVE_HPSSDIR", ""),
        'ARCHIVE_COM_LIST1': os.getenv("ARCHIVE_COM_LIST1", ""),
        'ARCHIVE_COM_LIST2': os.getenv("ARCHIVE_COM_LIST2", ""),
        'ARCHIVE_STMP': os.getenv("ARCHIVE_STMP", ""),
    }
    #
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    taskdep = ''
    ngroup = int(os.getenv('POST_GROUP_TOT_NUM'))
    for i in range(ngroup):
        taskdep += f'\n<taskdep task="upp_g{i:02d}"/>'
    taskdep = textwrap.indent(taskdep, '    ')
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}{taskdep}
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of archive --------------------------------------------------------
