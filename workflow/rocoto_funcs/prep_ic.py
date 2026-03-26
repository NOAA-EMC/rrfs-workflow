#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of fcst --------------------------------------------------------


def prep_ic(xmlFile, expdir, do_ensemble=False, spinup_mode=0):
    # spinup_mode:
    #  0 = no parallel spinup cycles in the experiment
    #  1 = a spinup cycle
    # -1 = a prod cycle parallel to spinup cycles
    if spinup_mode == 1:
        cycledefs = 'spinup'
    else:
        cycledefs = 'prod'
    coldhrs = os.getenv('COLDSTART_CYCS', '03 15')
    cyc_interval = os.getenv('CYC_INTERVAL')
    sfc_update_cycs = os.getenv('SFC_UPDATE_CYCS', '99')

    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'COLDSTART_CYCS': f'{coldhrs}',
        'SFC_UPDATE_CYCS': f'{sfc_update_cycs}',
        'SFC_UPDATE_SOURCE_DIR': os.getenv('SFC_UPDATE_SOURCE_DIR'),
        'DO_BLENDING': os.getenv('DO_BLENDING', 'FALSE'),
    }
    if spinup_mode != 0:
        dcTaskEnv['SPINUP_MODE'] = f'{spinup_mode}'
    if spinup_mode == 1:
        task_id = 'prep_ic_spinup'
    else:
        task_id = 'prep_ic'

    if do_ensemble:
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        dcTaskEnv['ENS_SIZE'] = str(ens_size)

    # determine prep_ic type so that we know where to find correct satbias files
    do_jedi = os.getenv("DO_JEDI", "FALSE").upper()
    if do_ensemble and do_jedi == "TRUE":
        PREP_IC_TYPE = "getkf"
    elif do_jedi == "TRUE":
        PREP_IC_TYPE = "jedivar"
    else:
        PREP_IC_TYPE = "no_da"
    dcTaskEnv['PREP_IC_TYPE'] = PREP_IC_TYPE
    if PREP_IC_TYPE == "jedivar" or PREP_IC_TYPE == "getkf":
        dcTaskEnv['USE_THE_LATEST_SATBIAS'] = os.getenv("USE_THE_LATEST_SATBIAS", "FALSE").upper()

    if "global" in os.getenv("MESH_NAME"):
        dcTaskEnv['cpreq'] = "ln -snf"
    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    coldhrs = coldhrs.split(' ')
    streqs = ""
    strneqs = ""
    for hr in coldhrs:
        hr = f"{hr:0>2}"
        streqs = streqs + f"\n        <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>"
        strneqs = strneqs + f"\n      <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"
    streqs = streqs.lstrip('\n')
    strneqs = strneqs.lstrip('\n')
    if do_ensemble:
        datadep_prod = ""
        for i in range(1, int(ens_size) + 1):
            memdirstr = f'/mem{i:03d}'
            datadep_prod = datadep_prod + f'''\n      <datadep age="00:01:00"><cyclestr offset="-{cyc_interval}:00:00">&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/fcst/&WGF;{memdirstr}/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.00.00.nc</cyclestr></datadep>'''
    else:
        datadep_prod = f'''\n      <datadep age="00:01:00"><cyclestr offset="-{cyc_interval}:00:00">&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/fcst/&WGF;/</cyclestr><cyclestr>mpasout.@Y-@m-@d_@H.00.00.nc</cyclestr></datadep>'''

    datadep_spinup = f'''\n      <taskdep task="fcst_spinup" cycle_offset="-1:00:00"/>'''
    if spinup_mode == 0:  # no parallel spinup cycles
        datadep = datadep_prod
    elif spinup_mode == 1:  # a spinup cycle
        datadep = datadep_spinup
    else:  # spinup_mode == -1, i.e. a prod cycle paralle to spinup cycles
        datadep = "whatever"  # dependencies will be rewritten near the end of this file

    #
    satbias_dep = ""
    if os.getenv("USE_THE_LATEST_SATBIAS", "FALSE").upper() == "TRUE":
        # cold start cycles wait for the latest satbias updated from the -1h cycles
        spaces = " " * 6
        satbias_dep = '\n' + spaces + '<or>'
        satbias_dep += '\n' + spaces + f'  <taskdep task="jedivar" cycle_offset="-{cyc_interval}:00:00"/>'
        satbias_dep += '\n' + spaces + f'  <datadep><cyclestr offset="-{cyc_interval}:00:00">&COMROOT;/&NET;/&rrfs_ver;/&RUN;.@Y@m@d/@H/jedivar/&WGF;/satbias_jumpstart</cyclestr></datadep>'
        satbias_dep += '\n' + spaces + '</or>'
    #
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    if os.getenv('DO_IC_LBC', 'TRUE').upper() == "TRUE":
        if do_ensemble:
            icdep = f'\n      <metataskdep metatask="ic"/>'
        else:
            icdep = f'\n      <taskdep task="ic"/>'
    else:
        icdep = ""
    #
    dependencies = f'''
  <dependency>
  <and>{timedep}
   <or>
    <and>
      <or>
{streqs}
      </or>{icdep}{satbias_dep}
    </and>
    <and>
{strneqs}{datadep}
    </and>
   </or>
  </and>
  </dependency>'''

# overwrite dependencies if no cycling (forecst-only)
    if os.getenv('DO_CYC', 'FALSE').upper() == "FALSE":
        dependencies = ""
        if os.getenv('DO_IC_LBC', 'TRUE').upper() == "TRUE":
            dependencies = f'''
  <dependency>
  <and>{timedep}
   <taskdep task="ic"/>
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
            strneqs = strneqs + f"\n      <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>"
        streqs = streqs.lstrip('\n')
        strneqs = strneqs.lstrip('\n')
        datadep_spinup = datadep_spinup.lstrip('\n')
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
{strneqs}{datadep_prod}
    </and>
   </or>
  </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, command_id="PREP_IC")
# end of fcst --------------------------------------------------------
