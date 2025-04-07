#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of getkf ---------------------------------------------------------------


def getkf(xmlFile, expdir, taskType):
    if taskType.upper() == "OBSERVER":
        task_id = "getkf_observer"
    elif taskType.upper() == "SOLVER":
        task_id = "getkf_solver"
    cycledefs = 'prod'
    # Task-specific EnVars beyond the task_common_vars
    extrn_mdl_source = os.getenv('IC_EXTRN_MDL_NAME', 'IC_PREFIX_not_defined')
    physics_suite = os.getenv('PHYSICS_SUITE', 'PHYSICS_SUITE_not_defined')
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
        'PHYSICS_SUITE': f'{physics_suite}',
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'YAML_GEN_METHOD': os.getenv('YAML_GEN_METHOD', '1'),
        'ENS_SIZE': os.getenv("ENS_SIZE", '5'),
        'TYPE': taskType.lower(),
    }
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    if taskType.upper() == "OBSERVER":
        if os.getenv("DO_IODA", "FALSE").upper() == "TRUE":
            iodadep = '<taskdep task="ioda_bufr"/>'
            dcTaskEnv['IODA_BUFR_WGF'] = 'enkf'
        else:
            iodadep = f'<datadep age="00:01:00"><cyclestr>&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/ioda_bufr/det/ioda_aircar.nc</cyclestr></datadep>'
            dcTaskEnv['IODA_BUFR_WGF'] = 'det'
        dependencies = f'''
      <dependency>
      <and>{timedep}
        <metataskdep metatask="prep_ic"/>
        {iodadep}
      </and>
      </dependency>'''
    elif taskType.upper() == "SOLVER":
        dependencies = f'''
      <dependency>
      <and>{timedep}
        <taskdep task="getkf_observer"/>
      </and>
      </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv=dcTaskEnv, dependencies=dependencies, command_id="GETKF")
# end of getkf -----------------------------------------------------------------
