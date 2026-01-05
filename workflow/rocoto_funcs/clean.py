#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
from rocoto_funcs.base import xml_task

# begin of clean --------------------------------------------------------


def clean(xmlFile, expdir):
    task_id = 'clean'
    cycledefs = 'prod'
    #
    clean_mode = int(os.getenv('CLEAN_MODE', '1'))
    dcTaskEnv = {
        'CLEAN_MODE': f'{clean_mode}',
        'STMP_RETENTION_CYCS': os.getenv("STMP_RETENTION_CYCS", '6'),
        'COM_RETENTION_CYCS': os.getenv("COM_RETENTION_CYCS", '120'),  # 120 hrs = 5 days
        'LOG_RETENTION_CYCS': os.getenv("LOG_RETENTION_CYCS", '840'),  # 840 hrs = 35 days
        # go back 'CLEAN_BACK_DAYS' from the first valid clean hour
        'CLEAN_BACK_DAYS': os.getenv("CLEAN_BACK_DAYS", '5'),
    }

    # determine the dependency
    taskdep = '<metataskdep metatask="upp"/>'
    if os.getenv("DO_ENSMEAN_POST", "FALSE").upper() == "TRUE":
        taskdep = taskdep + '\n    <metataskdep metatask="upp_ensmean"/>'
    if os.getenv("DO_HOFX", "FALSE").upper() == "TRUE":
        taskdep = taskdep + '\n    <taskdep task="hofx"/>'
    #
    dependencies = f'''
  <dependency>
  <and>
    {taskdep}
  </and>
  </dependency>'''
    if clean_mode == 1:
        dependencies = ""
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of clean --------------------------------------------------------
