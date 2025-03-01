#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of jedivar --------------------------------------------------------
def jedivar(xmlFile, expdir,do_spinup=False):
  if do_spinup:
    cycledefs='spinup'
    num_spinup_cycledef=os.getenv('NUM_SPINUP_CYCLEDEF','1')
    if num_spinup_cycledef=='2':
      cycledefs='spinup,spinup2'
    elif num_spinup_cycledef=='3':
      cycledefs='spinup,spinup2,spinup3'
    task_id='jedivar_spinup'
  else:
    cycledefs='prod'
    task_id='jedivar'
  # Task-specific EnVars beyond the task_common_vars
  extrn_mdl_source=os.getenv('IC_EXTRN_MDL_NAME','IC_PREFIX_not_defined')
  physics_suite=os.getenv('PHYSICS_SUITE','PHYSICS_SUITE_not_defined')
  dcTaskEnv={
    'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
    'PHYSICS_SUITE': f'{physics_suite}',
    'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
    'HYB_WGT_ENS': os.getenv('HYB_WGT_ENS','0.85'),
    'HYB_WGT_STATIC': os.getenv('HYB_WGT_STATIC','0.15'),
    'HYB_ENS_TYPE': os.getenv('HYB_ENS_TYPE','0'),
    'HYB_ENS_PATH': os.getenv('HYB_ENS_STATIC','')
  }
  if do_spinup:
    dcTaskEnv['DO_SPINUP']='TRUE'
  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  COMROOT=os.getenv("COMROOT","COMROOT_NOT_DEFINED")
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  HYB_ENS_TYPE=os.getenv("HYB_ENS_TYPE","0")
  HYB_WGT_ENS=os.getenv("HYB_WGT_ENS","0.85")
  ens_dep=""
  if HYB_WGT_ENS != "0" and HYB_WGT_ENS != "0.0" and HYB_ENS_TYPE == "1": # rrfsens
    RUN='rrfs'
    ens_dep=f'''
    <or>
      <datadep age="00:05:00"><cyclestr offset="-1:00:00">&COMROOT;/{NET}/{VERSION}/{RUN}enkf.@Y@m@d/@H/m030/fcst/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-2:00:00">&COMROOT;/{NET}/{VERSION}/{RUN}enkf.@Y@m@d/@H/m030/fcst/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-3:00:00">&COMROOT;/{NET}/{VERSION}/{RUN}enkf.@Y@m@d/@H/m030/fcst/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
    </or>'''
  #
  if do_spinup:
    prep_ic_dep='<taskdep task="prep_ic_spinup"/>'
  else:
    prep_ic_dep='<taskdep task="prep_ic"/>'

  #
  dependencies=f'''
  <dependency>
  <and>{timedep}
    {prep_ic_dep}
    <taskdep task="ioda_bufr"/>{ens_dep}
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,command_id="JEDIVAR")
### end of jedivar --------------------------------------------------------
