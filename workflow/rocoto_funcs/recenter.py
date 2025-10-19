#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of recenter --------------------------------------------------------


def recenter(xmlFile, expdir):
    task_id = 'recenter'
    cycledefs = 'prod'
    recenter_cycs = os.getenv('RECENTER_CYCS', '99')
    det_recentercycs_do_da = os.getenv('DET_RECENTERCYCS_DO_DA', 'false')
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'ENS_SIZE': os.getenv("ENS_SIZE", '5'),
        'RECENTER_CYCS': f'{recenter_cycs}',
    }

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper())
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'

    if det_recentercycs_do_da.upper() == "TRUE":
        datadep_init = f'<datadep age="00:05:00"><cyclestr>&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/jedivar/det/init.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'
    else:
        datadep_init = f'<datadep age="00:05:00"><cyclestr>&DATAROOT;/@Y@m@d/&RUN;_prep_ic_@H_&rrfs_ver;/det/init.nc</cyclestr></datadep>'

    datadep = f'''<or>
         {datadep_init}
         <datadep age="00:05:00"><cyclestr>&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/jedivar/det/mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
       </or>'''

    recenterhrs = recenter_cycs.split(' ')
    streqs = ""
    strneqs = ""
    for hr in recenterhrs:
        hr = f"{hr:0>2}"
        streqs = streqs + f"\n         <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
        strneqs = strneqs + f"\n         <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"

    dependencies = f'''
  <dependency>
  <and>{timedep}
    <or>
      <and>
       <or>{streqs}
       </or>
       {datadep}
      </and>
      <and>{strneqs}
      </and>
    </or>
    <metataskdep metatask="prep_ic"/>
  </and>
  </dependency>'''
    #

    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv=dcTaskEnv, dependencies=dependencies, command_id="RECENTER")
# end of recenter --------------------------------------------------------
