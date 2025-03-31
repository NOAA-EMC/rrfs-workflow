#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of fcst --------------------------------------------------------


def prep_ic(xmlFile, expdir, do_ensemble=False, spinup_mode=0):
    # spinup_mode:
    #  0 = no parallel spinup cycles in the experiment
    #  1 = a spinup cycle
    # -1 = a prod cycle parallel to spinup cycles
    meta_id = 'prep_ic'
    if spinup_mode == 1:
        cycledefs = 'spinup'
        num_spinup_cycledef = os.getenv('NUM_SPINUP_CYCLEDEF', '1')
        if num_spinup_cycledef == '2':
            cycledefs = 'spinup,spinup2'
        elif num_spinup_cycledef == '3':
            cycledefs = 'spinup,spinup2,spinup3'
    else:
        cycledefs = 'prod'
    coldhrs = os.getenv('COLDSTART_CYCS', '03 15')
    cyc_interval = os.getenv('CYC_INTERVAL')

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'COLDSTART_CYCS': f'{coldhrs}'
    }
    if spinup_mode != 0:
        dcTaskEnv['SPINUP_MODE'] = f'{spinup_mode}'
    if not do_ensemble:
        metatask = False
        if spinup_mode == 1:
            task_id = f'{meta_id}_spinup'
        else:
            task_id = f'{meta_id}'
        meta_bgn = ""
        meta_end = ""
        ensindexstr = ""
        ensdirstr = ""
    else:
        metatask = True
        task_id = f'{meta_id}_m#ens_index#'
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"
        meta_bgn = ""
        meta_end = ""
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
        meta_end = f'\
</metatask>\n'
        ensindexstr = "_m#ens_index#"
        ensdirstr = "/mem#ens_index#"

    # dependencies
    coldhrs = coldhrs.split(' ')
    streqs = ""
    strneqs = ""
    for hr in coldhrs:
        hr = f"{hr:0>2}"
        streqs = streqs + f"\n        <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
        strneqs = strneqs + f"\n        <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"
    streqs = streqs.lstrip('\n')
    strneqs = strneqs.lstrip('\n')
    datadep_prod = f'''\n        <datadep age="00:05:00"><cyclestr offset="-{cyc_interval}:00:00">&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/fcst/&WGF;{ensdirstr}/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.00.00.nc</cyclestr></datadep>'''
    datadep_spinup = f'''\n        <taskdep task="fcst_spinup" cycle_offset="-1:00:00"/>'''
    if spinup_mode == 0:  # no parallel spinup cycles
        datadep = datadep_prod
    elif spinup_mode == 1:  # a spinup cycle
        datadep = datadep_spinup
    else:  # a prod cycle paralle to spinup cycles
        datadep = "whatever"  # dependencies will be rewritten near the end of this file

    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    #
    dependencies = f'''
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
{strneqs}{datadep}
      </and>
    </and>
   </or>
  </and>
  </dependency>'''

# overwrite dependencies if no cycling (forecst-only)
    if os.getenv('DO_CYC', 'FALSE').upper() == "FALSE":
        dependencies = f'''
  <dependency>
  <and>{timedep}
   <taskdep task="ic{ensindexstr}"/>
  </and>
  </dependency>'''

# overwrite dependencies if spinup_mode= -1
    if spinup_mode == -1:  # overwrite streqs and strneqs for prod tasks parallel to spinup cycles
        prodswitch_hrs = os.getenv('PRODSWITCH_CYCS', '09 21')
        # add the envar 'PRODSWITCH_CYCS'
        dcTaskEnv['PRODSWITCH_CYCS'] = f'{prodswitch_hrs}'
        streqs = ""
        strneqs = ""
        for hr in prodswitch_hrs.split(' '):
            hr = f"{hr:0>2}"
            streqs = streqs + f"\n        <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
            strneqs = strneqs + f"\n        <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"
        streqs = streqs.lstrip('\n')
        strneqs = strneqs.lstrip('\n')
        datadep_spinup = datadep_spinup.lstrip('\n')[2:]
        dependencies = f'''
  <dependency>
  <and>{timedep}
   <or>
    <and>
      <or>
{streqs}
      </or>
{datadep_spinup}
    </and>
    <and>
      <and>
{strneqs}{datadep_prod}
      </and>
    </and>
   </or>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies,
             metatask, meta_id, meta_bgn, meta_end, "PREP_IC")
# end of fcst --------------------------------------------------------
