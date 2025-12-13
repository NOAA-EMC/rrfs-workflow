#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ensmean --------------------------------------------------------


def ensmean(xmlFile, expdir):
    meta_id = 'ensmean'
    cycledefs = 'prod'
    #
    ensmean_group_total_num = int(os.getenv('ENSMEAN_GROUP_TOTAL_NUM', '3'))
    history_interval = os.getenv('HISTORY_INTERVAL', '1')
    fcst_len_hrs_cycles = os.getenv('FCST_LEN_HRS_CYCLES', '03 03')
    group_indices = ''.join(f'{i:02d} ' for i in range(
        1, int(ensmean_group_total_num) + 1, int(history_interval))).strip()
    ens_size = int(os.getenv('ENS_SIZE', '2'))

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'HISTORY_INTERVAL': f'{history_interval}',
        'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycles}',
        'GROUP_TOTAL_NUM': f'{ensmean_group_total_num}',
        'GROUP_INDEX': f'#group_index#',
        'ENS_SIZE': f'{ens_size}',
    }

    # metatask (nested or not)
    meta_bgn = f'''
<metatask name="{meta_id}">
<var name="group_index">{group_indices}</var>'''
    meta_end = f'</metatask>\n'
    task_id = f'{meta_id}_g#group_index#'

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
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
    <metataskdep metatask="fcst"/>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, True, meta_id, meta_bgn, meta_end, "ENSMEAN")
# end of ensmean --------------------------------------------------------
