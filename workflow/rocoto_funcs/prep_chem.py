#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of prep_chem --------------------------------------------------------


def prep_chem(xmlFile, expdir, do_ensemble=False, do_spinup=False):
    meta_id = 'prep_chem'
    cycledefs = 'prod'
    if do_spinup:
        cycledefs = 'spinup'
        num_spinup_cycledef = os.getenv('NUM_SPINUP_CYCLEDEF', '1')
        if num_spinup_cycledef == '2':
            cycledefs = 'spinup,spinup2'
        elif num_spinup_cycledef == '3':
            cycledefs = 'spinup,spinup2,spinup3'
    else:
        cycledefs = 'prod'
    realtime = os.getenv("REALTIME", "false")

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'FCST_LEN_HRS_CYCLES': os.getenv('FCST_LEN_HRS_CYCLES', '01 01'),
        'CHEM_INPUT': os.getenv('CHEM_INPUT', 'CHEM_INPUT_undefined'),
        'REGRID_WRAPPER_DIR': os.getenv('REGRID_WRAPPER_DIR', 'REGRID_WRAPPER_DIR_undefined'),
        'REGRID_CONDA_ENV': os.getenv('REGRID_CONDA_ENV', 'REGRID_CONDA_ENV_undefined'),
        'RAVE_INPUT': os.getenv('RAVE_INPUT', 'RAVE_INPUT_undefined'),
    }
    #
    metatask = True
    task_id = f'{meta_id}_#group#'
    dcTaskEnv['CHEM_GROUP'] = '#group#'
    dcTaskEnv['ANTHRO_EMISINV'] = 'GRA2PES'
    #
    chem_groups = os.getenv('CHEM_GROUPS', 'smoke').replace(',', ' ')
    meta_bgn = f'''
<metatask name="{meta_id}">
<var name="group">{chem_groups}</var>'''
    meta_end = f'</metatask>\n'

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    timedep = ''
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'

    dependencies = f'''
  <dependency>
  <and>{timedep}
    <taskdep task="prep_ic"/>
  </and>
  </dependency>'''

    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, metatask, meta_id, meta_bgn, meta_end, "PREP_CHEM")
# end of prep_chem --------------------------------------------------------
