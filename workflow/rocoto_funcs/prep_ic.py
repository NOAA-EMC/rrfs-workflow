#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of fcst --------------------------------------------------------
def prep_ic(xmlFile, expdir, do_ensemble=False):
  meta_id='prep_ic'
  cycledefs='prod'
  coldhrs=os.getenv('COLDSTART_AT_HRS', '03 15')
  cyc_interval=os.getenv('CYC_INTERVAL')

  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'COLDSTART_AT_HRS': f'{coldhrs}',
  }
  if not do_ensemble:
    metatask=False
    task_id=f'{meta_id}'
    meta_bgn=""
    meta_end=""
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
    ensindexstr="_m#ens_index#"
    ensdirstr="/m#ens_index#"
    ensstr="ens_"

  # dependencies
  coldhrs=coldhrs.split(' ')
  streqs=""; strneqs=""; first=True
  for hr in coldhrs:
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
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  dependencies=f'''
  <dependency>
  <and>{timedep}
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
        <datadep age="00:05:00"><cyclestr offset="-{cyc_interval}:00:00">&COMROOT;/&NET;/&rrfs_ver;/&RUN;&WGF;.@Y@m@d/@H{ensdirstr}/fcst/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.00.00.nc</cyclestr></datadep>
      </and>
    </and>
   </or>
  </and>
  </dependency>'''
  # overwrite dependencies if it is not DO_CYC
  if os.getenv('DO_CYC','FALSE').upper() == "FALSE":
    dependencies=f'''
  <dependency>
  <and>{timedep}
   <taskdep task="ic{ensindexstr}"/>
  </and>
  </dependency>'''

  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"PREP_IC",do_ensemble)
### end of fcst --------------------------------------------------------
