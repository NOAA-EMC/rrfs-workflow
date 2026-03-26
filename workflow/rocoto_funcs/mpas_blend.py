#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of mpas_blend --------------------------------------------------------


def mpas_blend(xmlFile, expdir, spinup_mode=0):
    do_spinup = spinup_mode == 1
    if do_spinup:
        cycledefs = 'spinup'
        task_id = 'mpas_blend_spinup'
    else:
        cycledefs = 'prod'
        task_id = 'mpas_blend'

    cyc_interval = os.getenv('CYC_INTERVAL')
    blending_cycs = os.getenv('BLENDING_CYCS', '99')

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'BLENDING_CYCS': f'{blending_cycs}',
    }

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()

    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'

    blendhrs = blending_cycs.split(' ')
    streqs = ""
    strneqs = ""
    for hr in blendhrs:
        hr = f"{hr:0>2}"
        streqs = streqs + f"\n        <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
        strneqs = strneqs + f"\n      <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"
    streqs = streqs.lstrip('\n')
    strneqs = strneqs.lstrip('\n')

    if do_spinup:
        prep_ic_dep = '<taskdep task="prep_ic_spinup"/>'
    else:
        prep_ic_dep = f'''\n   <taskdep task="prep_ic"/>'''

    if os.getenv("DO_BLENDING", "FALSE").upper() == "TRUE":
        datadep_neqs = ""
        datadep_eqs = f'''      <datadep age="00:01:00"><cyclestr offset="-{cyc_interval}:00:00">&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/fcst/&WGF;/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.00.00.nc</cyclestr></datadep>'''

    dependencies = f'''
  <dependency>
  <and>{timedep} {prep_ic_dep}
   <or>
    <and>
      <or>
{streqs}
      </or>
{datadep_eqs}
    </and>
    <and>
{strneqs}{datadep_neqs}
    </and>
   </or>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies)
# end of mpas_blend --------------------------------------------------------
