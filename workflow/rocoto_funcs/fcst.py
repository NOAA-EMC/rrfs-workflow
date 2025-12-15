#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of fcst --------------------------------------------------------


def fcst(xmlFile, expdir, do_ensemble=False, do_spinup=False):
    meta_id = 'fcst'
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
    fcst_len_hrs_cycles = os.getenv('FCST_LEN_HRS_CYCLES', '03 03')
    lbc_interval = os.getenv('LBC_INTERVAL', '3')
    history_interval = os.getenv('HISTORY_INTERVAL', '1')
    restart_interval = os.getenv('RESTART_INTERVAL', 'none')
    physics_suite = os.getenv('PHYSICS_SUITE', 'PHYSICS_SUITE_not_defined')
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
        'LBC_INTERVAL': f'{lbc_interval}',
        'HISTORY_INTERVAL': f'{history_interval}',
        'RESTART_INTERVAL': f'{restart_interval}',
        'MPASOUT_INTERVAL': os.getenv('MPASOUT_INTERVAL', '1'),
        'PHYSICS_SUITE': f'{physics_suite}',
        'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycles}',
        'FCST_DT': os.getenv('FCST_DT', 'FCST_DT_not_defined'),
        'FCST_SUBSTEPS': os.getenv('FCST_SUBSTEPS', 'FCST_SUBSTEPS_not_defined'),
        'FCST_RADT': os.getenv('FCST_RADT', 'FCST_RADT_not_defined'),
    }
    if os.getenv('FCST_CONVECTION_SCHEME', 'FALSE').upper() == 'TRUE':
        dcTaskEnv['FCST_CONVECTION_SCHEME'] = "TRUE"
    if os.getenv('MPASOUT_SAVE2COM_HRS', '') != '':
        dcTaskEnv['MPASOUT_SAVE2COM_HRS'] = os.getenv('MPASOUT_SAVE2COM_HRS')
    if do_spinup:
        dcTaskEnv['DO_SPINUP'] = "TRUE"

    if os.getenv('DO_CHEMISTRY', 'FALSE').upper() == "TRUE":
        dcTaskEnv['EBB_DCYCLE'] = os.getenv('EBB_DCYCLE', 0)
        dcTaskEnv['CHEM_GROUPS'] = os.getenv('CHEM_GROUPS', 'smoke')
        chemdep = '\n    <metataskdep metatask="prep_chem"/>'
    else:
        chemdep = ""

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

    jedidep = ""
    cloudana_dep = ""
    recenterdep = ""
    if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
        if do_spinup:
            cloudana_dep = f'\n    <taskdep task="nonvar_cldana_spinup"/>'
        else:
            cloudana_dep = f'\n    <taskdep task="nonvar_cldana{ensindexstr}"/>'
    elif os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
        if os.getenv("DO_ENSEMBLE", "FALSE").upper() == "TRUE":
            jedidep = f'\n<taskdep task="getkf_solver"/>'
        elif do_spinup:
            jedidep = f'\n<taskdep task="jedivar_spinup"/>'
        else:
            jedidep = f'\n<taskdep task="jedivar"/>'
    else:
        if os.getenv("DO_RECENTER", "FALSE").upper() == "TRUE":
            if os.getenv("DO_ENSEMBLE", "FALSE").upper() == "TRUE":
                recenterdep = f'\n<taskdep task="recenter"/>'

    prep_ic_dep = f'<taskdep task="prep_ic{ensindexstr}"/>'
    if do_spinup:
        prep_ic_dep = f'<taskdep task="prep_ic_spinup"/>'
    prep_lbc_dep = f'\n    <taskdep task="prep_lbc{ensindexstr}" cycle_offset="0:00:00"/>'
    if "global" in os.getenv("MESH_NAME"):
        prep_lbc_dep = ''

    dependencies = f'''
  <dependency>
  <and>{timedep}{prep_lbc_dep}
    {prep_ic_dep}{jedidep}{chemdep}{cloudana_dep}{recenterdep}
  </and>
  </dependency>'''

    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv,
             dependencies, metatask, meta_id, meta_bgn, meta_end, "FCST")
# end of fcst --------------------------------------------------------
