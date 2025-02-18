#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of ens_da --------------------------------------------------------
def ens_da(xmlFile, expdir):
  task_id='ens_da'
  cycledefs='ens_prod'
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={}
  # dependencies
  hrs=os.getenv('COLDSTART_CYCS', '3 15')
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
  DATAROOT=os.getenv("DATAROOT","DATAROOT_NOT_DEFINED")
  RUN='ens'
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  ens_size=int(os.getenv('ENS_SIZE','2'))
  for i in range(1,int(ens_size)+1):
    if i == 1:
      datadep=f'        <datadep age="00:05:00"><cyclestr offset="-1:00:00">{DATAROOT}/{NET}/{VERSION}/{RUN}.@Y@m@d/@H/mem{i:03}/fcst/</cyclestr><cyclestr>restart.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'
    else:
      datadep=datadep+f'\n        <datadep age="00:05:00"><cyclestr offset="-1:00:00">{DATAROOT}/{NET}/{VERSION}/{RUN}.@Y@m@d/@H/mem{i:03}/fcst/</cyclestr><cyclestr>restart.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
    <or>
      <and>
        <or>
{streqs}
        </or>
        <metataskdep metatask="ens_ic"/>
      </and>
      <and>
        <or>
{strneqs}
        </or>
{datadep}
      </and>
    </or>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv=dcTaskEnv,dependencies=dependencies,do_ensemble=True)
### end of ens_da --------------------------------------------------------
