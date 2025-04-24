#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of recenter --------------------------------------------------------


def recenter(xmlFile, expdir):
    task_id = 'recenter'
    cycledefs = 'prod'
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'ENS_SIZE': os.getenv("ENS_SIZE", '5')
    }
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    # ~~
    if os.getenv("DO_ENSEMBLE", "FALSE").upper() == "TRUE":
        dependencies = f'''
  <dependency>
  <and>{timedep}
    <datadep age="00:05:00"><cyclestr>&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/jedivar/det/mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
    <taskdep task="getkf_solver"/>
  </and>
  </dependency>'''
    else:
        dependencies = f'''
  <dependency>
  <and>{timedep}
    <datadep age="00:05:00"><cyclestr>&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/jedivar/det/mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
    <metataskdep metatask="prep_ic"/>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv=dcTaskEnv, dependencies=dependencies, command_id="RECENTER")
# end of recenter --------------------------------------------------------
