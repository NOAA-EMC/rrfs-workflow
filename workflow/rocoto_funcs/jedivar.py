#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of jedivar --------------------------------------------------------


def jedivar(xmlFile, expdir, spinup_mode=0):
    nocoldda = os.getenv('COLDSTART_CYCS_DO_DA', 'TRUE').upper() == 'FALSE'
    do_spinup = spinup_mode == 1
    if do_spinup:
        if nocoldda:
            cycledefs = 'da_nocold'
        else:
            cycledefs = 'spinup'
        task_id = 'jedivar_spinup'
    else:
        if spinup_mode == 0 and nocoldda:
            cycledefs = 'da_nocold'
        else:
            cycledefs = 'prod'
        task_id = 'jedivar'
    # Task-specific EnVars beyond the task_common_vars
    extrn_mdl_source = os.getenv('IC_EXTRN_MDL_NAME', 'IC_PREFIX_not_defined')
    physics_suite = os.getenv('PHYSICS_SUITE', 'PHYSICS_SUITE_not_defined')
    ens_size = int(os.getenv('ENS_SIZE', '2'))
    ens_bec_look_back_hrs = int(os.getenv('ENS_BEC_LOOK_BACK_HRS', '3'))
    snudgetype = os.getenv('SNUDGETYPES', '')
    analysis_variables = os.getenv('ANALYSIS_VARIABLES', '0')
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
        'PHYSICS_SUITE': f'{physics_suite}',
        'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
        'YAML_GEN_METHOD': os.getenv('YAML_GEN_METHOD', '1'),
        'COLDSTART_CYCS_DO_DA': os.getenv('COLDSTART_CYCS_DO_DA', 'TRUE').upper(),
        'DO_RADAR_REF': os.getenv('DO_RADAR_REF', 'FALSE').upper(),
        'HYB_WGT_ENS': os.getenv('HYB_WGT_ENS', '0.85'),
        'HYB_WGT_STATIC': os.getenv('HYB_WGT_STATIC', '0.15'),
        'HYB_ENS_TYPE': os.getenv('HYB_ENS_TYPE', '0'),
        'HYB_ENS_PATH': os.getenv('HYB_ENS_PATH', ''),
        'ENS_BEC_LOOK_BACK_HRS': f'{ens_bec_look_back_hrs}',
        'ENS_SIZE': f'{ens_size}',
        'USE_CONV_SAT_INFO': os.getenv('USE_CONV_SAT_INFO', 'TRUE').upper(),
        'EMPTY_OBS_SPACE_ACTION': os.getenv('EMPTY_OBS_SPACE_ACTION', 'skip output'),
        'STATIC_BEC_MODEL': os.getenv('STATIC_BEC_MODEL', 'GSIBEC'),
        'GSIBEC_X': os.getenv('GSIBEC_X', 'GSIBEC_X_not_defined'),
        'GSIBEC_Y': os.getenv('GSIBEC_Y', 'GSIBEC_Y_not_defined'),
        'GSIBEC_NLAT': os.getenv('GSIBEC_NLAT', 'GSIBEC_NLAT_not_defined'),
        'GSIBEC_NLON': os.getenv('GSIBEC_NLON', 'GSIBEC_NLON_not_defined'),
        'GSIBEC_LAT_START': os.getenv('GSIBEC_LAT_START', 'GSIBEC_LAT_START_not_defined'),
        'GSIBEC_LAT_END': os.getenv('GSIBEC_LAT_END', 'GSIBEC_LAT_END_not_defined'),
        'GSIBEC_LON_START': os.getenv('GSIBEC_LON_START', 'GSIBEC_LON_START_not_defined'),
        'GSIBEC_LON_END': os.getenv('GSIBEC_LON_END', 'GSIBEC_LON_END_not_defined'),
        'GSIBEC_NORTH_POLE_LAT': os.getenv('GSIBEC_NORTH_POLE_LAT', 'GSIBEC_NORTH_POLE_LAT_not_defined'),
        'GSIBEC_NORTH_POLE_LON': os.getenv('GSIBEC_NORTH_POLE_LON', 'GSIBEC_NORTH_POLE_LON_not_defined'),
    }
    if do_spinup:
        dcTaskEnv['DO_SPINUP'] = 'TRUE'
    if len(snudgetype) >= 3:
        dcTaskEnv['SNUDGETYPES'] = snudgetype
    if analysis_variables != '0':
        dcTaskEnv['ANALYSIS_VARIABLES'] = analysis_variables

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "FALSE")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    NET = os.getenv("NET", "NET_not_defined")
    VERSION = os.getenv("VERSION", "VERSION_not_defined")
    HYB_ENS_TYPE = os.getenv("HYB_ENS_TYPE", "0")
    HYB_WGT_ENS = os.getenv("HYB_WGT_ENS", "0.85")
    HYB_ENS_PATH = os.getenv("HYB_ENS_PATH", "")
    if HYB_ENS_PATH == "":
        HYB_ENS_PATH = f'&COMROOT;/{NET}/{VERSION}'

    ens_dep = ""
    if HYB_WGT_ENS != "0" and HYB_WGT_ENS != "0.0" and HYB_ENS_TYPE == "1":  # rrfsens
        RUN = 'rrfs'
        ens_dep = "\n    <or>"
        for enshrs in range(1, int(ens_bec_look_back_hrs) + 1):
            ens_dep = ens_dep + "\n    <and>"
            for i in range(1, int(ens_size) + 1):
                ensindexstr = f'mem{i:03d}'
                ens_dep = ens_dep + f'\n      <datadep age="00:01:00"><cyclestr offset="-{enshrs}:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/fcst/enkf/</cyclestr>{ensindexstr}/<cyclestr>mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'
            ens_dep = ens_dep + "\n    </and>"
        ens_dep = ens_dep + "\n    </or>"

    elif HYB_WGT_ENS != "0" and HYB_WGT_ENS != "0.0" and HYB_ENS_TYPE == "2":  # interpolated GDAS/GEFS
        RUN = 'rrfs'
        ens_dep = f'''
    <or>
      <datadep age="00:01:00"><cyclestr  offset="0:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:01:00"><cyclestr offset="-1:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:01:00"><cyclestr offset="-2:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:01:00"><cyclestr offset="-3:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:01:00"><cyclestr offset="-4:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:01:00"><cyclestr offset="-5:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
      <datadep age="00:01:00"><cyclestr offset="-6:00:00">{HYB_ENS_PATH}/{RUN}.@Y@m@d/@H/ic/enkf/mem030/init.nc</cyclestr></datadep>
    </or>'''

    # ~~~~
    if do_spinup:
        prep_ic_dep = '<taskdep task="prep_ic_spinup"/>'
    else:
        prep_ic_dep = '<taskdep task="prep_ic"/>'
    # ~~~~

    mpas_blend_dep = ""
    if os.getenv("DO_BLENDING", "FALSE").upper() == "TRUE":
        if do_spinup:
            mpas_blend_dep = f'\n    <taskdep task="mpas_blend_spinup"/>'
        else:
            mpas_blend_dep = f'\n    <taskdep task="mpas_blend"/>'

    if os.getenv("DO_IODA", "FALSE").upper() == "TRUE":
        iodadep = '<taskdep task="ioda_bufr"/>'
    else:
        iodadep = f'<datadep age="00:01:00"><cyclestr>&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/ioda_bufr/det/ioda_aircar.nc</cyclestr></datadep>'
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
    {prep_ic_dep}{mpas_blend_dep}
    {iodadep}{ens_dep}
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, command_id="JEDIVAR")
# end of jedivar --------------------------------------------------------
