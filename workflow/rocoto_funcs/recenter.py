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
    if os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
        datadep = '     <datadep age="00:05:00"><cyclestr>&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/jedivar/det/mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'
        taskdep = '     <taskdep task="getkf_solver"/>'
        # If not doing DA during cold start cycles, then just check for cycle and then only wait for GETKF to finish
        if os.getenv("COLDSTART_CYCS_DO_DA", "TRUE").upper() == "FALSE":
            coldhrs = os.getenv('COLDSTART_CYCS', '03 15')
            coldhrs = coldhrs.split(' ')
            streqs = ""
            strneqs = ""
            for hr in coldhrs:
                hr = f"{hr:0>2}"
                streqs = streqs + f"\n        <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
                strneqs = strneqs + f"\n        <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"
            dependencies = f'''
  <dependency>
  <and>{timedep}
   <or>
    <and>
      <or>{streqs}
      </or>
 {taskdep}
    </and>
    <and>
      <and>{strneqs}
   {datadep}
   {taskdep}
      </and>
    </and>
   </or>
  </and>
  </dependency>'''
        # If doing DA during cold start cycles then just need to wait for GETKF and JEDIVAR to finish
        else:
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
