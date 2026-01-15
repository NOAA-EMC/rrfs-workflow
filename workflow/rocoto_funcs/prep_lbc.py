#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of prep_lbc --------------------------------------------------------


def prep_lbc(xmlFile, expdir, do_ensemble=False):
    meta_id = 'prep_lbc'
    cycledefs = 'prod'
    num_spinup_cycledef = int(os.getenv('NUM_SPINUP_CYCLEDEF', '0'))
    prep_lbc_look_back_hrs = int(os.getenv("PREP_LBC_LOOK_BACK_HRS", "6"))
    if num_spinup_cycledef == 1:
        cycledefs = 'prod,spinup'
    elif num_spinup_cycledef == 2:
        cycledefs = 'prod,spinup,spinup2'
    elif num_spinup_cycledef == 3:
        cycledefs = 'prod,spinup,spinup2,spinup3'

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'LBC_INTERVAL': os.getenv('LBC_INTERVAL', '3'),
        'FCST_LEN_HRS_CYCLES': os.getenv('FCST_LEN_HRS_CYCLES', '03 03'),
        'PREP_LBC_LOOK_BACK_HRS': f'{prep_lbc_look_back_hrs}',
    }

    if not do_ensemble:
        metatask = False
        task_id = f'{meta_id}'
        meta_bgn = ""
        meta_end = ""
        ensindexstr = ""
    else:
        metatask = True
        task_id = f'{meta_id}_m#ens_index#'
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"
        meta_bgn = ""
        meta_end = ""
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
        meta_end = f'\
</metatask>\n'
        ensindexstr = "_m#ens_index#"

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'

    taskdep = ""
    for hr in range(0, int(prep_lbc_look_back_hrs) + 1):
        taskdep = taskdep + f'\n     <metataskdep metatask="lbc{ensindexstr}" cycle_offset="-{hr}:00:00" />'

    dependencies = ""
    if os.getenv('DO_IC_LBC', 'TRUE').upper() == "TRUE":
        dependencies = f'''
  <dependency>
  <and>{timedep}
   <or>{taskdep}
   </or>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies,
             metatask, meta_id, meta_bgn, meta_end, "PREP_LBC")
# end of prep_lbc  --------------------------------------------------------
