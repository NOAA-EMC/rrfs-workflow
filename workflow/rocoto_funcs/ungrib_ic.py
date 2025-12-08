#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ungrib_ic --------------------------------------------------------


def ungrib_ic(xmlFile, expdir, do_ensemble=False):
    meta_id = 'ungrib_ic'
    cycledefs = 'ic'
    #
    extrn_mdl_source = os.getenv('IC_EXTRN_MDL_NAME', 'IC_PREFIX_not_defined')
    ic_source_basedir = os.getenv('IC_EXTRN_MDL_BASEDIR', 'MDL_BASEDIR_not_defined')
    ic_filename_pattern = os.getenv('IC_EXTRN_MDL_FILENAME_PATTERN', 'FILENAME_PATTERN_not_defined')
    ic_filename_pattern_b = os.getenv('IC_EXTRN_MDL_FILENAME_PATTERN_B', '')
    offset = os.getenv('IC_OFFSET', '3')
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'TYPE': 'ic',
        'SOURCE_BASEDIR': f'<cyclestr offset="-{offset}:00:00">{ic_source_basedir}</cyclestr>',
        'FILENAME_PATTERN': f'<cyclestr offset="-{offset}:00:00">{ic_filename_pattern}</cyclestr>',
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
        'OFFSET': f'{offset}',
    }

    if os.getenv('DO_CHEMISTRY', 'FALSE').upper() == "TRUE":
        dcTaskEnv['USE_EXTERNAL_CHEM'] = os.getenv('USE_EXTERNAL_CHEM_ICS', 'FALSE').upper()
    #
    if not do_ensemble:
        metatask = False
        task_id = f'{meta_id}'
        meta_bgn = ""
        meta_end = ""
    else:
        metatask = True
        task_id = f'{meta_id}_m#ens_index#'
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
        gmems = ''.join(f'{i:02d} ' for i in range(1, int(ens_size) + 1)).strip()
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>
<var name="gmem">{gmems}</var>'''
        meta_end = f'</metatask>\n'

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
        fpath = f'{ic_source_basedir}/{ic_filename_pattern}'.replace('^HHH^', offset.zfill(3))
        fpath = f'{fpath}'.replace('^HH^', offset.zfill(2))

    timedep = ""
    realtime = os.getenv("REALTIME", "FALSE")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    datadep = f'  <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath}</cyclestr></datadep>'
    if ic_filename_pattern_b != '':
        dcTaskEnv['FILENAME_PATTERN_B'] = f'<cyclestr offset="-{offset}:00:00">{ic_filename_pattern_b}</cyclestr>'
        fpath2 = f'{ic_source_basedir}/{ic_filename_pattern_b}'.replace('^HHH^', offset.zfill(3))
        fpath2 = f'{fpath2}'.replace('^HH^', offset.zfill(2))
        datadep = datadep + \
            f'\n    <datadep age="00:05:00"><cyclestr offset="-{offset}:00:00">{fpath2}</cyclestr></datadep>'
    dependencies = f'''
  <dependency>
  <and>{timedep}
  {datadep}
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies,
             metatask, meta_id, meta_bgn, meta_end, "UNGRIB")
# end of ungrib_ic --------------------------------------------------------
