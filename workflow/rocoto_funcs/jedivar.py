#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of jedivar --------------------------------------------------------
def jedivar(xmlFile, expdir):
  task_id='jedivar'
  cycledefs='prod'
  physics_suite=os.getenv('PHYSICS_SUITE','PHYSICS_SUITE_not_defined')
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'PHYSICS_SUITE': f'{physics_suite}',
    'REFERENCE_TIME': '@Y-@m-@dT@H:00:00Z',
    'DATAROOT': f'<cyclestr>&DATAROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H</cyclestr>'
  }
  # dependencies
  hrs=os.getenv('PROD_BGN_AT_HRS', '3 15')
  hrs=hrs.split(' ')
  streqs=""; strneqs=""; first=True
  for hr in hrs:
    hr=f"{hr:0>2}"
    if first:
      first=False
      streqs=streqs  +f"          <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
      strneqs=strneqs+f"          <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"
    else:
      streqs=streqs  +f"\n          <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
      strneqs=strneqs+f"\n          <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"

  timedep=""
  realtime=os.getenv("REALTIME","false")
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  COMROOT=os.getenv("COMROOT","COMROOT_NOT_DEFINED")
  RUN='rrfs'
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
    <taskdep task="prep_ic"/>
    <taskdep task="ioda_bufr"/>
    <or>
      <datadep age="00:05:00"><cyclestr offset="-1:00:00">&COMROOT;/{NET}/{VERSION}/{RUN}enkf.@Y@m@d/@H/m001/fcst/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-2:00:00">&COMROOT;/{NET}/{VERSION}/{RUN}enkf.@Y@m@d/@H/m001/fcst/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
      <datadep age="00:05:00"><cyclestr offset="-3:00:00">&COMROOT;/{NET}/{VERSION}/{RUN}enkf.@Y@m@d/@H/m001/fcst/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
    </or>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies)
### end of jedivar --------------------------------------------------------
