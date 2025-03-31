#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
from rocoto_funcs.base import xml_task

# begin of misc --------------------------------------------------------


def misc(xmlFile, expdir):
    task_id = 'misc'
    cycledefs = 'prod'
    #
    xml_task(xmlFile, expdir, task_id, cycledefs)
# end of misc --------------------------------------------------------
