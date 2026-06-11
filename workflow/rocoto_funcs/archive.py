#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
import textwrap
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of archive --------------------------------------------------------


def archive(xmlFile, expdir):
    task_id = 'archive'
    cycledefs = 'archive'
    do_graphics = os.getenv("DO_GRAPHICS", "FALSE").upper()
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'ARCHIVE_INTERVAL': os.getenv("ARCHIVE_INTERVAL", "2"),
        'ARCHIVE_HPSSDIR': os.getenv("ARCHIVE_HPSSDIR", ""),
        'ARCHIVE_COM1_SPEC': os.getenv("ARCHIVE_COM1_SPEC", ""),
        'ARCHIVE_STMP': os.getenv("ARCHIVE_STMP", ""),
        'ARCHIVE_STMP_INTERVAL': os.getenv("ARCHIVE_STMP_INTERVAL", "1"),
    }
    archive_module = os.getenv("ARCHIVE_MODULE", "")
    if archive_module:
        dcTaskEnv["ARCHIVE_MODULE"] = archive_module
    #
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    #
    taskdep = '\n<taskdep task="upp_g00"/>'
    if do_graphics == "TRUE":
        taskdep += '\n<metataskdep metatask="graphics"/>'
    ngroup = int(os.getenv('POST_GROUP_TOT_NUM'))
    for i in range(1, ngroup):
        taskdep += f'''
<or>
  <not><taskvalid task="upp_g{i:02d}"/></not>
  <taskdep task="upp_g{i:02d}"/>
</or>'''
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
