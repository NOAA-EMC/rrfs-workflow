#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of mpassit --------------------------------------------------------


def mpassit(xmlFile, expdir, do_ensemble=False):
    meta_id = 'mpassit'
    cycledefs = 'prod'
    #
    mpassit_group_total_num = int(os.getenv('MPASSIT_GROUP_TOTAL_NUM', '1'))
    fcst_length = os.getenv('FCST_LENGTH', '1')
    history_interval = os.getenv('HISTORY_INTERVAL', '1')
    fcst_len_hrs_cycles = os.getenv('FCST_LEN_HRS_CYCLES', '03 03')
    group_indices = ''.join(f'{i:02d} ' for i in range(
        1, int(mpassit_group_total_num) + 1, int(history_interval))).strip()
    fhr2 = ''.join(f'{i:02d} ' for i in range(0, int(mpassit_group_total_num), int(history_interval))).strip()

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'FCST_LENGTH': f'{fcst_length}',
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

    if not do_ensemble:
        # metatask (nested or not)
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="group_index">{group_indices}</var>
<var name="fhr2">{fhr2}</var>
'''
        meta_end = f'</metatask>\n'
        task_id = f'{meta_id}_g#group_index#'

        ensindexstr = ""
    else:
        # metatask (nested or not)
        fhr = os.getenv('ENS_FCST_LENGTH', '3')
        if int(fhr) >= 100:
            print(f'FCST_LENGTH>=100 not supported: {fhr}')
            exit()
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="group_index">{group_indices}</var>
<var name="fhr2">{fhr2}</var>'''
        meta_end = f'</metatask>\n</metatask>\n'
        task_id = f'{meta_id}_m#ens_index#_g#group_index#'
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"
        ensindexstr = "_m#ens_index#"

    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{meta_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    <taskdep task="save_fcst{ensindexstr}"/>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, True, meta_id, meta_bgn, meta_end, "MPASSIT")
# end of mpassit --------------------------------------------------------
