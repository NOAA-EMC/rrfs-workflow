#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ungrib_lbc --------------------------------------------------------


def ungrib_lbc(xmlFile, expdir, do_ensemble=False):
    meta_id = 'ungrib_lbc'
    cycledefs = 'lbc'
    #
    offset = int(os.getenv('LBC_OFFSET', '6'))
    length = int(os.getenv('LBC_LENGTH', '12'))
    interval = int(os.getenv('LBC_INTERVAL', '3'))
    extrn_mdl_source = os.getenv('LBC_EXTRN_MDL_NAME', 'GFS')
    lbc_source_basedir = os.getenv('LBC_EXTRN_MDL_BASEDIR', '')
    lbc_filename_pattern = os.getenv('LBC_EXTRN_MDL_FILENAME_PATTERN', '')
    lbc_filename_pattern_b = os.getenv('LBC_EXTRN_MDL_FILENAME_PATTERN_B', '')
    lbc_ungrib_group_total_num = int(os.getenv('LBC_UNGRIB_GROUP_TOTAL_NUM', '1'))
    group_indices = ''.join(f'{i:02d} ' for i in range(1, int(lbc_ungrib_group_total_num) + 1)).strip()

# Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'TYPE': 'lbc',
        'SOURCE_BASEDIR': f'<cyclestr offset="-{offset}:00:00">{lbc_source_basedir}</cyclestr>',
        'FILENAME_PATTERN': f'<cyclestr offset="-{offset}:00:00">{lbc_filename_pattern}</cyclestr>',
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
        'OFFSET': f'{offset}',
        'LENGTH': f'{length}',
        'INTERVAL': f'{interval}',
    }

    if os.getenv('DO_CHEMISTRY', 'FALSE').upper() == "TRUE":
        dcTaskEnv['USE_EXTERNAL_CHEM'] = os.getenv('USE_EXTERNAL_CHEM_LBCS', 'FALSE').upper()

    if not do_ensemble:
        meta_bgn = ""
        meta_end = ""
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="group_index">{group_indices}</var>
'''
        meta_end = f'</metatask>\n'
        task_id = f'ungrib_lbc_g#group_index#'
    #
    else:  # ensemble
        # metatask (support nested metatasks)
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
        gmems = ''.join(f'{i:02d} ' for i in range(1, int(ens_size) + 1)).strip()
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>
<var name="gmem">{gmems}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="group_index">{group_indices}</var>
'''
        meta_end = f'</metatask>\n</metatask>\n'
        task_id = f'{meta_id}_g#group_index#_m#ens_index#'
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"

    dcTaskEnv['GROUP_INDEX'] = f'#group_index#'
    dcTaskEnv['GROUP_TOTAL_NUM'] = f'{lbc_ungrib_group_total_num}'

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    if extrn_mdl_source == "GFS_NCO":
        COMINgfs = os.getenv("COMINgfs", 'COMINgfs_not_defined')
        fpath = f'{COMINgfs}/gfs.@Y@m@d/@H/gfs.t@Hz.pgrb2.0p25.f{offset:>03}'
        fpath2 = f'{COMINgfs}/gfs.@Y@m@d/@H/gfs.t@Hz.pgrb2b.0p25.f{offset:>03}'
    elif extrn_mdl_source == "GEFS_NCO":
        COMINgefs = os.getenv("COMINgefs", 'COMINgefs_not_defined')
        fpath = f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2ap5/gep#gmem#.t@Hz.pgrb2a.0p50.f{offset:>03}'
        fpath2 = f'{COMINgefs}/gefs.@Y@m@d/@H/pgrb2bp5/gep#gmem#.t@Hz.pgrb2b.0p50.f{offset:>03}'
    else:
        fpath = f'{lbc_source_basedir}/{lbc_filename_pattern}'

    if lbc_filename_pattern_b != '':
        dcTaskEnv['FILENAME_PATTERN_B'] = f'<cyclestr offset="-{offset}:00:00">{lbc_filename_pattern_b}</cyclestr>'
        fpath2 = f'{lbc_source_basedir}/{lbc_filename_pattern_b}'

    timedep = ""
    realtime = os.getenv("REALTIME", "FALSE")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n     <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #

    datadep = ''
    if interval == 1 and extrn_mdl_source == "GEFS":
        interval = 3
    for i in range(int(offset), int(length) + int(offset) + 1, int(interval)):
        comin_hr3 = str(i).zfill(3)
        fpath3 = fpath.replace('^HHH^', comin_hr3)
        fpath3 = fpath3.replace('^HH^', str(i).zfill(2))
        datadep = datadep + \
            f'\n     <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath3}</cyclestr></datadep>'
        if lbc_filename_pattern_b != '':
            fpath4 = fpath2.replace('^HHH^', comin_hr3)
            fpath4 = fpath4.replace('^HH^', str(i).zfill(2))
            datadep = datadep + \
                f'\n     <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath4}</cyclestr></datadep>'

    dependencies = f'''
  <dependency>
  <and>{timedep}{datadep}
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, True, meta_id, meta_bgn, meta_end, "UNGRIB")
# end of ungrib_lbc --------------------------------------------------------
