#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of fcst --------------------------------------------------------
def prep_lbc(xmlFile, expdir, do_ensemble=False):

  # Task-specific EnVars beyond the task_common_vars
  meta_id='prep_lbc'
  cycledefs='prod'
  hrs=os.getenv('PROD_BGN_AT_HRS', '3 15')
  fcst_length=os.getenv('FCST_LENGTH','1')
  lbc_interval=os.getenv('LBC_INTERVAL','3')
  fcst_len_hrs_cycls=os.getenv('FCST_LEN_HRS_CYCLES', '3 15')
  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'LBC_INTERVAL': f'{lbc_interval}',
    'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycls}'
  }

  if not do_ensemble:
    metatask=False
    task_id=f'{meta_id}'
    meta_bgn=""
    meta_end=""
    RUN='rrfs'
    ensindexstr=""
    ensdirstr=""
    ensstr=""
  else:
    metatask=True
    task_id=f'{meta_id}_m#ens_index#'
    dcTaskEnv['ENS_INDEX']="#ens_index#"
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
    ensdirstr="/m#ens_index#"
    ensstr="ens_"

  dcTaskEnv['DATAROOT']=f'<cyclestr>&DATAROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H{ensdirstr}</cyclestr>'
  dcTaskEnv['MEMDIR']=f'{ensdirstr}'

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
   <metataskdep metatask="lbc{ensindexstr}" cycle_offset="0:00:00"/>
   <or>
    <and>
      <or>
{streqs}
      </or>
      <taskdep task="prep_ic{ensindexstr}"/>
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
  # overwrite dependencies if it is FCST_ONLY
  if os.getenv('FCST_ONLY','FALSE').upper() == "TRUE":
    dependencies=f'''
  <dependency>
  <and>{timedep}
   <taskdep task="prep_ic{ensindexstr}"/>
  </and>
  </dependency>'''

  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"PREP_LBC",do_ensemble)
### end of fcst --------------------------------------------------------
