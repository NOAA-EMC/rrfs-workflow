#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
import textwrap
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of graphics --------------------------------------------------------


def graphics(xmlFile, expdir):
    meta_id = 'graphics'
    task_id = f'{meta_id}_#tile#'
    tiles = os.getenv('GRAPHICS_TILES', 'full')
    meta_bgn = f'''
<metatask name="{meta_id}">
<var name="tile">{tiles}</var>'''
    meta_end = f'</metatask>\n'
    cycledefs = 'prod'
    #
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'FCST_LEN_HRS_CYCLES': os.getenv('FCST_LEN_HRS_CYCLES', '03 03'),
        'TILE': '#tile#',
        'GRAPHICS_ZIP': os.getenv('GRAPHICS_ZIP', 'FALSE').upper(),
        'GRAPHICS_MODEL': os.getenv('GRAPHICS_MODEL', ''),
    }
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    taskdep = '\n<taskdep task="upp_g00"/>'
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
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, True, meta_id, meta_bgn, meta_end, "GRAPHICS")

# end of graphics --------------------------------------------------------
