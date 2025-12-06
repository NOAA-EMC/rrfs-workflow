#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of mpassit --------------------------------------------------------


def mpassit(xmlFile, expdir, do_ensemble=False, do_ensmean_post=False):
    meta_id = 'mpassit'
    cycledefs = 'prod'
    #
    mpassit_group_total_num = int(os.getenv('MPASSIT_GROUP_TOTAL_NUM', '1'))
    history_interval = os.getenv('HISTORY_INTERVAL', '1')
    fcst_len_hrs_cycles = os.getenv('FCST_LEN_HRS_CYCLES', '03 03')
    group_indices = ''.join(f'{i:02d} ' for i in range(
        1, int(mpassit_group_total_num) + 1, int(history_interval))).strip()

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'HISTORY_INTERVAL': f'{history_interval}',
        'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycles}',
        'GROUP_TOTAL_NUM': f'{mpassit_group_total_num}',
        'GROUP_INDEX': f'#group_index#',
        'MPASSIT_NX': os.getenv('MPASSIT_NX', 'MPASSIT_NX_not_defined'),
        'MPASSIT_NY': os.getenv('MPASSIT_NY', 'MPASSIT_NY_not_defined'),
        'MPASSIT_DX': os.getenv('MPASSIT_DX', 'MPASSIT_DX_not_defined'),
        'MPASSIT_REF_LAT': os.getenv('MPASSIT_REF_LAT', 'MPASSIT_REF_LAT_not_defined'),
        'MPASSIT_REF_LON': os.getenv('MPASSIT_REF_LON', 'MPASSIT_REF_LON_not_defined'),
    }

    if os.getenv('DO_CHEMISTRY', 'FALSE').upper() == "TRUE":
        dcTaskEnv['CHEM_GROUPS'] = os.getenv('CHEM_GROUPS', 'smoke')

    if not do_ensemble:
        # metatask (nested or not)
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="group_index">{group_indices}</var>
'''
        meta_end = f'</metatask>\n'
        task_id = f'{meta_id}_g#group_index#'

        ensindexstr = ""
        memdir = ""
    else:
        # metatask (nested or not)
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        if not do_ensmean_post:
            ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
            meta_bgn = f'''
<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="group_index">{group_indices}</var>'''
            meta_end = f'</metatask>\n</metatask>\n'
            task_id = f'{meta_id}_m#ens_index#_g#group_index#'
            dcTaskEnv['ENS_INDEX'] = "#ens_index#"
            ensindexstr = "_m#ens_index#"
            memdir = "/mem#ens_index#"
        else:
            # metatask (nested or not)
            meta_id = "mpassit_ensmean"
            meta_bgn = f'''
<metatask name="{meta_id}">
<var name="group_index">{group_indices}</var>
'''
            meta_end = f'</metatask>\n'
            task_id = f'{meta_id}_g#group_index#'
            memdir = "/ensmean"

    dcTaskEnv['MEMDIR'] = f'{memdir}'
    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{meta_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    if do_ensmean_post:
        taskdep = f'\n   <metataskdep metatask="ensmean"/>'
    else:
        taskdep = f'\n   <taskdep task="fcst{ensindexstr}"/>'

    dependencies = f'''
  <dependency>
  <and>{timedep}
  {taskdep}
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, True, meta_id, meta_bgn, meta_end, "MPASSIT")
# end of mpassit --------------------------------------------------------
