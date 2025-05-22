#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of jedivar --------------------------------------------------------


def jedivar(xmlFile, expdir, do_spinup=False):
    if do_spinup:
        cycledefs = 'spinup'
        num_spinup_cycledef = os.getenv('NUM_SPINUP_CYCLEDEF', '1')
        if num_spinup_cycledef == '2':
            cycledefs = 'spinup,spinup2'
        elif num_spinup_cycledef == '3':
            cycledefs = 'spinup,spinup2,spinup3'
        task_id = 'jedivar_spinup'
    else:
        cycledefs = 'prod'
        task_id = 'jedivar'
    # Task-specific EnVars beyond the task_common_vars
    extrn_mdl_source = os.getenv('IC_EXTRN_MDL_NAME', 'IC_PREFIX_not_defined')
    physics_suite = os.getenv('PHYSICS_SUITE', 'PHYSICS_SUITE_not_defined')
    ens_size = int(os.getenv('ENS_SIZE', '2'))
    ens_bec_look_back_hrs = int(os.getenv('ENS_BEC_LOOK_BACK_HRS', '3'))
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
        'PHYSICS_SUITE': f'{physics_suite}',
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'YAML_GEN_METHOD': os.getenv('YAML_GEN_METHOD', '1'),
        'COLDSTART_CYCS_DO_DA': os.getenv('COLDSTART_CYCS_DO_DA', 'true'),
        'DO_ENVAR_RADAR_REF': os.getenv('DO_ENVAR_RADAR_REF', 'false'),
        'HYB_WGT_ENS': os.getenv('HYB_WGT_ENS', '0.85'),
        'HYB_WGT_STATIC': os.getenv('HYB_WGT_STATIC', '0.15'),
        'HYB_ENS_TYPE': os.getenv('HYB_ENS_TYPE', '0'),
        'HYB_ENS_PATH': os.getenv('HYB_ENS_PATH', ''),
        'ENS_BEC_LOOK_BACK_HRS': f'{ens_bec_look_back_hrs}',
    }
    if do_spinup:
        dcTaskEnv['DO_SPINUP'] = 'TRUE'
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    NET = os.getenv("NET", "NET_NOT_DEFINED")
    VERSION = os.getenv("VERSION", "VERSION_NOT_DEFINED")
    HYB_ENS_TYPE = os.getenv("HYB_ENS_TYPE", "0")
    HYB_WGT_ENS = os.getenv("HYB_WGT_ENS", "0.85")
    HYB_ENS_PATH = os.getenv("HYB_ENS_PATH", "")
    if HYB_ENS_PATH == "":
        HYB_ENS_PATH = f'&COMROOT;/{NET}/{VERSION}'
    ens_dep = ""
    if HYB_WGT_ENS != "0" and HYB_WGT_ENS != "0.0" and HYB_ENS_TYPE == "1":  # rrfsens
        RUN = 'rrfs'
        ens_dep0 = ""
        for enshrs in range(1, int(ens_bec_look_back_hrs) + 1):
            ens_depm = ""
            for i in range(1, int(ens_size) + 1):
                ensindexstr = f'mem{i:03d}'
                ens_depm = ens_depm + f'\n       <datadep age="00:05:00"><cyclestr offset="-{enshrs}:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/fcst/enkf/</cyclestr>{ensindexstr}/<cyclestr>mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'
            ens_dep0 = ens_dep0 + f'''
     <and>{ens_depm}
     </and>'''

        ens_dep = f'''
    <or>
     {ens_dep0}
    </or>'''

    elif HYB_WGT_ENS != "0" and HYB_WGT_ENS != "0.0" and HYB_ENS_TYPE == "2":  # interpolated GDAS/GEFS
        RUN = 'rrfs'
        ens_dep = f'''
    <or>
      <datadep age="00:05:00"><cyclestr  offset="0:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-1:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-2:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-3:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-4:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-5:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-6:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
    </or>'''

    # ~~~~
    if do_spinup:
        prep_ic_dep = '<taskdep task="prep_ic_spinup"/>'
    else:
        prep_ic_dep = '<taskdep task="prep_ic"/>'
    # ~~~~
    if os.getenv("DO_IODA", "FALSE").upper() == "TRUE":
        iodadep = '<taskdep task="ioda_bufr"/>'
    else:
        iodadep = f'<datadep age="00:01:00"><cyclestr>&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/ioda_bufr/det/ioda_aircar.nc</cyclestr></datadep>'

    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    {prep_ic_dep}
    {iodadep}{ens_dep}
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, command_id="JEDIVAR")
# end of jedivar --------------------------------------------------------
