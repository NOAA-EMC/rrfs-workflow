#!/usr/bin/env python
import os
import ast
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ioda_bufr --------------------------------------------------------


def ioda_bufr(xmlFile, expdir):
    task_id = 'ioda_bufr'
    cycledefs = 'prod'
    if os.getenv("DO_SPINUP", "FALSE").upper() == "TRUE":
        cycledefs = 'prod,spinup'
    OBSPATH = os.getenv("OBSPATH", 'OBSPATH_not_defined')
    dcObs = {
        'prepbufr': '@Y@m@d@H.rap.t@Hz.prepbufr.tm00',
        'ztd': '@Y@m@d@H.rap.t@Hz.ztd.tm00',
        'satwnd': '@Y@m@d@H.rap.t@Hz.satwnd.tm00',
        'abi': '@Y@m@d@H.rap.t@Hz.gsrcsr.tm00',
        'atms': '@Y@m@d@H.rap.t@Hz.atms.tm00',
        'crisfs': '@Y@m@d@H.rap.t@Hz.crisf4.tm00',
        'iasi': '@Y@m@d@H.rap.t@Hz.mtiasi.tm00',
    }
    #
    # update default dcObs with user input
    obs_filename_pattern = os.getenv('OBS_FILENAME_PATTERN', '{}')
    dcObsX = ast.literal_eval(obs_filename_pattern)
    for key, value in dcObsX.items():
        dcObs[key] = value

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'YAML_GEN_METHOD': os.getenv('YAML_GEN_METHOD', '1'),
        'OBSPATH': f'{OBSPATH}',
        'FILE_PREPBUFR': f'<cyclestr>{dcObs["prepbufr"]}</cyclestr>',
        'FILE_ZTD': f'<cyclestr>{dcObs["ztd"]}</cyclestr>',
        'FILE_SATWND': f'<cyclestr>{dcObs["satwnd"]}</cyclestr>',
        'FILE_ABI': f'<cyclestr>{dcObs["abi"]}</cyclestr>',
        'FILE_ATMS': f'<cyclestr>{dcObs["atms"]}</cyclestr>',
        'FILE_CRISFS': f'<cyclestr>{dcObs["crisfs"]}</cyclestr>',
        'FILE_IASI': f'<cyclestr>{dcObs["iasi"]}</cyclestr>',
    }

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    fpath = f'{OBSPATH}/{dcObs["prepbufr"]}'

    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    <datadep age="00:02:00"><cyclestr>{fpath}</cyclestr></datadep>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of ioda_bufr --------------------------------------------------------
