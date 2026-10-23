#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
import textwrap
from rocoto_funcs.base import xml_task, get_cascade_env
from rocoto_funcs.smart_graphics_groups import smart_graphics_groups

# begin of graphics --------------------------------------------------------


def graphics(xmlFile, expdir):
    meta_id = 'graphics'
    cycledefs = 'prod'
    list_groups = smart_graphics_groups()

    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{meta_id}".upper())
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

    for grp in list_groups:
        task_id = grp['task_id']
        dcTaskEnv = {
            'FCST_LEN_HRS_CYCLES': os.getenv('FCST_LEN_HRS_CYCLES', '03 03'),
            'TILES_IN_GROUP': grp['tiles_str'],
            'GRAPHICS_CORES_PER_TILE': str(grp['cores_per_tile']),
            'GRAPHICS_ZIP': os.getenv('GRAPHICS_ZIP', 'FALSE').upper(),
            'GRAPHICS_MODEL': os.getenv('GRAPHICS_MODEL', ''),
            'UPP_DOMAIN': os.getenv('UPP_DOMAIN', 'conus.'),
        }

        xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, False, meta_id, "", "", "GRAPHICS")

# end of graphics --------------------------------------------------------
