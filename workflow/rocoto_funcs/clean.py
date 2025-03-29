#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
from rocoto_funcs.base import xml_task

# begin of clean --------------------------------------------------------


def clean(xmlFile, expdir):
    task_id = 'clean'
    cycledefs = 'prod'
    #
    dcTaskEnv = {
        'STMP_CLEAN_HRS': os.getenv("STMP_CLEAN_HRS", '24'),
        'COM_CLEAN_HRS': os.getenv("COM_CLEAN_HRS", '120'),  # 120 hrs = 5 days
        'LOG_CLEAN_HRS': os.getenv("LOG_CLEAN_HRS", '840'),  # 840 hrs = 35 days
        # go back 'CLEAN_BACK_DAYS' from the first valid clean hour
        'CLEAN_BACK_DAYS': os.getenv("CLEAN_BACK_DAYS", '5'),
    }
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv)
# end of clean --------------------------------------------------------
