#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of lbc --------------------------------------------------------


def lbc(xmlFile, expdir, do_ensemble=False):
    meta_id = 'lbc'
    cycledefs = 'lbc'
    extern_mdl_source = os.getenv('LBC_EXTRN_MDL_NAME', 'GFS')
    offset = int(os.getenv('LBC_OFFSET', '6'))
    length = int(os.getenv('LBC_LENGTH', '18'))
    interval = int(os.getenv('LBC_INTERVAL', '3'))
    lbc_group_total_num = int(os.getenv('LBC_GROUP_TOTAL_NUM', '1'))
    group_indices = ''.join(f'{i:02d} ' for i in range(1, int(lbc_group_total_num) + 1)).strip()
    physics_suite = os.getenv('PHYSICS_SUITE', 'PHYSICS_SUITE_not_defined')

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': f'{extern_mdl_source}',
        'PHYSICS_SUITE': f'{physics_suite}',
        'OFFSET': f'{offset}',
        'LENGTH': f'{length}',
        'INTERVAL': f'{interval}',
        'GROUP_INDEX': f'#group_index#',
        'GROUP_TOTAL_NUM': f'{lbc_group_total_num}',
        'NSOIL_LEVELS': os.getenv('NSOIL_LEVELS', '9'),
    }

    if os.getenv('DO_CHEMISTRY', 'FALSE').upper() == "TRUE":
        dcTaskEnv['USE_EXTERNAL_CHEM'] = os.getenv('USE_EXTERNAL_CHEM_LBCS', 'FALSE').upper()
        dcTaskEnv['CHEM_GROUPS'] = os.getenv('CHEM_GROUPS', 'smoke')

    if not do_ensemble:
        # metatask (nested or not)
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="group_index">{group_indices}</var>'''
        meta_end = f'\
</metatask>\n'
        task_id = f'{meta_id}_g#group_index#'
        ensindexstr = ""
    #
    else:  # ensemble
        # metatask (nested or not)
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="group_index">{group_indices}</var>'''
        meta_end = f'\
</metatask>\n\
</metatask>\n'
        task_id = f'{meta_id}_g#group_index#_m#ens_index#'
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"
        ensindexstr = "_m#ens_index#"

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "FALSE")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    dependencies = f'''
  <dependency>
  <and>{timedep}
    <metataskdep metatask="ungrib_lbc{ensindexstr}"/>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, True, meta_id, meta_bgn, meta_end, "LBC")
# end of lbc --------------------------------------------------------
