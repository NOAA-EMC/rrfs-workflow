#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of upp --------------------------------------------------------


def upp(xmlFile, expdir, index, dcGrpInfo, do_ensemble=False, do_ensmean_post=False):
    meta_id = 'upp'
    cycledefs = dcGrpInfo['cycledef']
    group_hours = dcGrpInfo["hours"]
    parts = group_hours.split('-')
    if len(parts) == 1:
        str_hours = parts[0]
    else:
        step = 1
        if len(parts) == 3:
            step = int(parts[2])
        bgn_hr = int(parts[0])
        end_hr = int(parts[1])
        str_hours = " ".join(str(i) for i in range(bgn_hr, end_hr + step, step))
    #
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'FCST_LEN_HRS_CYCLES': os.getenv('FCST_LEN_HRS_CYCLES', '03 03'),
        'GROUP_INDEX': f'{index:02d}',
        'GROUP_HOURS': f'{str_hours}',
        'UPP_DOMAIN': os.getenv('UPP_DOMAIN', ''),
    }

    if not do_ensemble:
        metatask = False
        task_id = f'{meta_id}_g{index:02d}'
        meta_bgn = ""
        meta_end = ""
        ensindexstr = ""
        memdir = ""
    else:
        if not do_ensmean_post:
            ens_size = int(os.getenv('ENS_SIZE', '2'))
            metatask = True
            ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
            meta_bgn = f'''
<metatask name="{meta_id}_g{index:02d}">
<var name="ens_index">{ens_indices}</var>'''
            meta_end = f'</metatask>\n'
            task_id = f'{meta_id}_g{index:02d}_m#ens_index#'
            dcTaskEnv['ENS_INDEX'] = "#ens_index#"
            ensindexstr = "_m#ens_index#"
            memdir = "/mem#ens_index#"
        else:  # do_ensmean_post
            metatask = False
            meta_id = "upp_ensmean"
            task_id = f'{meta_id}_g{index:02d}'
            meta_bgn = ""
            meta_end = ""
            memdir = "/ensmean"
            ensindexstr = "_ensmean"

    dcTaskEnv['MEMDIR'] = f'{memdir}'
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
    <taskdep task="mpassit_g{index:02d}{ensindexstr}"/>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, metatask, meta_id, meta_bgn, meta_end, "UPP")
# end of upp --------------------------------------------------------
