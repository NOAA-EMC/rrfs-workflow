#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of cloudanalysis_nonvar --------------------------------------------------------


def cloudanalysis_nonvar(xmlFile, expdir, do_spinup=False):
    if do_spinup:
        cycledefs = 'spinup'
        num_spinup_cycledef = os.getenv('NUM_SPINUP_CYCLEDEF', '1')
        if num_spinup_cycledef == '2':
            cycledefs = 'spinup,spinup2'
        elif num_spinup_cycledef == '3':
            cycledefs = 'spinup,spinup2,spinup3'
        task_id = 'cloudanalysis_nonvar_spinup'
    else:
        cycledefs = 'prod'
        task_id = 'cloudanalysis_nonvar'
    # Task-specific EnVars beyond the task_common_vars
    extrn_mdl_source = os.getenv('IC_EXTRN_MDL_NAME', 'IC_PREFIX_not_defined')
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
    }
    if do_spinup:
        dcTaskEnv['DO_SPINUP'] = 'TRUE'

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    prep_ic_dep = ""
    jedidep = ""
    if os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
        if os.getenv("DO_ENSEMBLE", "FALSE").upper() == "TRUE":
            jedidep = f'<taskdep task="getkf_solver"/>'
        elif do_spinup:
            jedidep = f'<taskdep task="jedivar_spinup"/>'
        else:
            jedidep = f'<taskdep task="jedivar"/>'
    else:
        prep_ic_dep = f'\n    <taskdep task="prep_ic"/>'
        if do_spinup:
            prep_ic_dep = f'\n    <taskdep task="prep_ic_spinup"/>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}{prep_ic_dep}
    {jedidep}
    <taskdep task="proc_bufr_nonvar"/>
    <taskdep task="refmosaic_nonvar"/>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of cloudanalysis_nonvar --------------------------------------------------------
