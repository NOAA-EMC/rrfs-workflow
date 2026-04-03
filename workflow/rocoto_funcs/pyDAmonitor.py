#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
import textwrap
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of pyDAmonitor --------------------------------------------------------


def pyDAmonitor(xmlFile, expdir, spinup_mode=0):
    task_id = 'pyDAmonitor'
    nocoldda = os.getenv('COLDSTART_CYCS_DO_DA', 'TRUE').upper() == 'FALSE'
    do_spinup = spinup_mode == 1
    if do_spinup:
        if nocoldda:
            cycledefs = 'da_nocold'
        else:
            cycledefs = 'spinup'
    else:
        if spinup_mode == 0 and nocoldda:
            cycledefs = 'da_nocold'
        else:
            cycledefs = 'prod'
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'CHECK_IS_CYC_DONE': os.getenv("CHECK_IS_CYC_DONE", "FALSE"),  # default: TRUE for retros and FALSE for realtime
    }
    #
    do_nonvar_cloud_ana = os.getenv('DO_NONVAR_CLOUD_ANA', "FALSE").upper()
    if do_nonvar_cloud_ana == "TRUE":
        dcTaskEnv['DO_NONVAR_CLOUD_ANA'] = do_nonvar_cloud_ana
    #
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    taskdep = '\n<taskdep task="jedivar"/>'
    if do_nonvar_cloud_ana == "TRUE":
        taskdep += '\n<taskdep task="nonvar_cldana"/>'
    taskdep = textwrap.indent(taskdep, '    ')
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}{taskdep}
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of pyDAmonitor --------------------------------------------------------
