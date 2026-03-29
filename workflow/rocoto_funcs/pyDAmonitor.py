#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
from rocoto_funcs.base import xml_task

# begin of pyDAmonitor --------------------------------------------------------


def pyDAmonitor(xmlFile, expdir):
    task_id = 'pyDAmonitor'
    cycledefs = 'prod'
    #
    dcTaskEnv = {
        'CHECK_IS_CYC_DONE': os.getenv("CHECK_IS_CYC_DONE", "FALSE"),  # default: TRUE for retros and FALSE for realtime
    }

    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{meta_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    <taskdep task="jedivar"/>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of pyDAmonitor --------------------------------------------------------
