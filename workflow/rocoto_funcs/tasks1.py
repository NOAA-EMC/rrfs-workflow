#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of ic --------------------------------------------------------
def ic(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={}
  if not do_ensemble:
    metatask=False
    meta_id=''
    task_id='ic'
    cycledefs='ic,lbc' #don't know why we need init.nc for the lbc process but live with it right now
    meta_bgn=""
    meta_end=""
    ensindexstr=""
  else:
    metatask=True
    meta_id='ic'
    task_id=f'{meta_id}_m#ens_index#'
    cycledefs='ens_ic,ens_lbc'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
    meta_end=f'\
</metatask>\n'
    ensindexstr="_m#ens_index#"

  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <or>
    <taskdep task="ungrib_ic{ensindexstr}"/>
    <taskdep task="ungrib_lbc{ensindexstr}_f000"/>
  </or>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"IC",do_ensemble)
### end of ic --------------------------------------------------------

### begin of lbc --------------------------------------------------------
def lbc(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'FHR': '#fhr#',
  }
  if not do_ensemble:
    meta_id='lbc'
    cycledefs='lbc'
    # metatask (nested or not)
    fhr=os.getenv('FCST_LENGTH','12')
    offset=int(os.getenv('LBC_OFFSET','6'))
    length=int(os.getenv('LBC_LENGTH','18'))
    interval=int(os.getenv('LBC_INTERVAL','3'))
    meta_hr= ''.join(f'{i:03d} ' for i in range(0,int(length)+1,int(interval))).strip()
    meta_bgn=f'''
<metatask name="{meta_id}">
<var name="fhr">{meta_hr}</var>'''
    meta_end=f'\
</metatask>\n'
    task_id=f'{meta_id}_f#fhr#'
    ensindexstr=""
  #
  else: #ensemble
    meta_id='lbc'
    cycledefs='ens_lbc'
    # metatask (nested or not)
    fhr=os.getenv('ENS_FCST_LENGTH','6')
    offset=int(os.getenv('ENS_LBC_OFFSET','36'))
    length=int(os.getenv('ENS_LBC_LENGTH','12'))
    interval=int(os.getenv('ENS_LBC_INTERVAL','3'))
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_hr= ''.join(f'{i:03d} ' for i in range(0,int(length)+1,int(interval))).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>
<metatask name="{meta_id}_m#ens_index#">
<var name="fhr">{meta_hr}</var>'''
    meta_end=f'\
</metatask>\n\
</metatask>\n'
    task_id=f'{meta_id}_m#ens_index#_f#fhr#'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    ensindexstr="_m#ens_index#"

  # dependencies
  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <taskdep task="ungrib_lbc{ensindexstr}_f#fhr#"/>
  <taskdep task="ic{ensindexstr}"/>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,True,meta_id,meta_bgn,meta_end,"LBC",do_ensemble)
### end of lbc --------------------------------------------------------

### begin of da --------------------------------------------------------
def da(xmlFile, expdir):
  task_id='da'
  cycledefs='prod'
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    '_PLACEHOLDER_': 'just a place holder',
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
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  DATAROOT=os.getenv("DATAROOT","DATAROOT_NOT_DEFINED")
  RUN='rrfs'
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
    <or>
      <and>
        <or>
{streqs}
        </or>
        <taskdep task="ic"/>
      </and>
      <and>
        <or>
{strneqs}
        </or>
        <datadep age="00:05:00"><cyclestr offset="-1:00:00">{DATAROOT}/{NET}/{VERSION}/{RUN}.@Y@m@d/@H/fcst/</cyclestr><cyclestr>restart.@Y-@m-@d_@H.@M.@S.nc</cyclestr></datadep>
      </and>
    </or>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies)
### end of da --------------------------------------------------------

### begin of fcst --------------------------------------------------------
def fcst(xmlFile, expdir, do_ensemble=False):
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={}
  if not do_ensemble:
    metatask=False
    meta_id=''
    task_id='fcst'
    cycledefs='prod'
    hrs=os.getenv('PROD_BGN_AT_HRS', '3 15')
    meta_bgn=""
    meta_end=""
    RUN='rrfs'
    ensindexstr=""
    ensstr=""
  else:
    metatask=True
    meta_id='fcst'
    task_id=f'{meta_id}_m#ens_index#'
    cycledefs='ens_prod'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
    hrs=os.getenv('ENS_PROD_BGN_AT_HRS', '3 15')
    meta_bgn=""
    meta_end=""
    ens_size=int(os.getenv('ENS_SIZE','2'))
    ens_indices=''.join(f'{i:03d} ' for i in range(1,int(ens_size)+1)).strip()
    meta_bgn=f'''
<metatask name="ens_{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
    meta_end=f'\
</metatask>\n'
    RUN='ens'
    ensindexstr="_m#ens_index#"
    ensstr="ens_"

  # dependencies
  hrs=hrs.split(' ')
  streqs=""; strneqs=""; first=True
  for hr in hrs:
    hr=f"{hr:0>2}"
    if first:
      first=False
      streqs=streqs  +f"        <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
      strneqs=strneqs+f"        <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"
    else:
      streqs=streqs  +f"\n        <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
      strneqs=strneqs+f"\n        <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  DATAROOT=os.getenv("DATAROOT","DATAROOT_NOT_DEFINED")
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
   <or>
    <metataskdep metatask="lbc{ensindexstr}" cycle_offset="0:00:00"/>
    <metataskdep metatask="lbc{ensindexstr}" cycle_offset="-1:00:00"/>
    <metataskdep metatask="lbc{ensindexstr}" cycle_offset="-2:00:00"/>
    <metataskdep metatask="lbc{ensindexstr}" cycle_offset="-3:00:00"/>
    <metataskdep metatask="lbc{ensindexstr}" cycle_offset="-4:00:00"/>
    <metataskdep metatask="lbc{ensindexstr}" cycle_offset="-5:00:00"/>
    <metataskdep metatask="lbc{ensindexstr}" cycle_offset="-6:00:00"/>
   </or>
   <or>
    <and>
      <or>
{streqs}
      </or>
      <taskdep task="ic{ensindexstr}"/>
    </and>
    <and>
      <and>
{strneqs}
      </and>
      <taskdep task="{ensstr}da"/>
    </and>
   </or>
  </and>
  </dependency>'''
  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"FCST",do_ensemble)
### end of fcst --------------------------------------------------------

### begin of ens_da --------------------------------------------------------
def ens_da(xmlFile, expdir):
  task_id='ens_da'
  cycledefs='ens_prod'
  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={}
  # dependencies
  hrs=os.getenv('ENS_PROD_BGN_AT_HRS', '3 15')
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
  starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
  if realtime.upper() == "TRUE":
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
