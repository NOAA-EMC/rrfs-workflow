#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of nonvar_cldana --------------------------------------------------------


def nonvar_cldana(xmlFile, expdir, do_ensemble=False, do_spinup=False):
    meta_id = 'nonvar_cldana'
    if do_spinup:
        cycledefs = 'spinup'
        num_spinup_cycledef = os.getenv('NUM_SPINUP_CYCLEDEF', '1')
        if num_spinup_cycledef == '2':
            cycledefs = 'spinup,spinup2'
        elif num_spinup_cycledef == '3':
            cycledefs = 'spinup,spinup2,spinup3'
    else:
        cycledefs = 'prod'
    # Task-specific EnVars beyond the task_common_vars
    extrn_mdl_source = os.getenv('IC_EXTRN_MDL_NAME', 'IC_PREFIX_not_defined')
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
    }
    if do_spinup:
        dcTaskEnv['DO_SPINUP'] = 'TRUE'

    if not do_ensemble:
        metatask = False
        if do_spinup:
            task_id = f'{meta_id}_spinup'
        else:
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
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    prep_ic_dep = ""
    jedidep = ""
    if os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
        if os.getenv("DO_ENSEMBLE", "FALSE").upper() == "TRUE":
            jedidep = f'\n    <taskdep task="getkf_solver"/>'
        elif do_spinup:
            jedidep = f'\n    <taskdep task="jedivar_spinup"/>'
        else:
            jedidep = f'\n    <taskdep task="jedivar"/>'
    else:
        prep_ic_dep = f'\n    <taskdep task="prep_ic{ensindexstr}"/>'
        if do_spinup:
            prep_ic_dep = f'\n    <taskdep task="prep_ic_spinup"/>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}{prep_ic_dep}{jedidep}
    <taskdep task="nonvar_bufrobs"/>
    <taskdep task="nonvar_reflobs"/>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies,
             metatask, meta_id, meta_bgn, meta_end)
# end of nonvar_cldana --------------------------------------------------------
