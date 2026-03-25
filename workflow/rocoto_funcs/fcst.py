#!/usr/bin/env python
import os
import sys
import textwrap
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of fcst --------------------------------------------------------


def fcst(xmlFile, expdir, do_ensemble=False, dcEnsGrpInfo=None, do_spinup=False):
    meta_id = 'fcst'
    dep_xml = ""
    if do_spinup:
        cycledefs = 'spinup'
    else:
        cycledefs = 'prod'
    # Task-specific EnVars beyond the task_common_vars
    extrn_mdl_source = os.getenv('IC_EXTRN_MDL_NAME', 'IC_PREFIX_not_defined')
    fcst_len_hrs_cycles = os.getenv('FCST_LEN_HRS_CYCLES', '03 03')
    lbc_interval = os.getenv('LBC_INTERVAL', '3')
    history_interval = os.getenv('HISTORY_INTERVAL', '1')
    restart_interval = os.getenv('RESTART_INTERVAL', 'none')
    physics_suite = os.getenv('PHYSICS_SUITE', 'PHYSICS_SUITE_not_defined')
    coldhrs = os.getenv('COLDSTART_CYCS', '03 15')
    coldstart_cyc_do_da = os.getenv('COLDSTART_CYCS_DO_DA', 'TRUE')
    recenter_cycs = os.getenv('RECENTER_CYCS', '99')
    dcTaskEnv = {
        'EXTRN_MDL_SOURCE': f'{extrn_mdl_source}',
        'LBC_INTERVAL': f'{lbc_interval}',
        'HISTORY_INTERVAL': f'{history_interval}',
        'RESTART_INTERVAL': f'{restart_interval}',
        'MPASOUT_INTERVAL': os.getenv('MPASOUT_INTERVAL', '1'),
        'MPASOUT_TIMELEVELS': os.getenv('MPASOUT_TIMELEVELS', ''),
        'PHYSICS_SUITE': f'{physics_suite}',
        'FCST_LEN_HRS_CYCLES': f'{fcst_len_hrs_cycles}',
        'FCST_DT': os.getenv('FCST_DT', 'FCST_DT_not_defined'),
        'FCST_SUBSTEPS': os.getenv('FCST_SUBSTEPS', 'FCST_SUBSTEPS_not_defined'),
        'FCST_RADT': os.getenv('FCST_RADT', 'FCST_RADT_not_defined'),
    }
    if os.getenv('FCST_CONVECTION_SCHEME', 'FALSE').upper() == 'TRUE':
        dcTaskEnv['FCST_CONVECTION_SCHEME'] = "TRUE"
    if os.getenv('MPASOUT_SAVE2COM_HRS', '') != '':
        dcTaskEnv['MPASOUT_SAVE2COM_HRS'] = os.getenv('MPASOUT_SAVE2COM_HRS')
    if do_spinup:
        dcTaskEnv['DO_SPINUP'] = "TRUE"

    if os.getenv('DO_CHEMISTRY', 'FALSE').upper() == "TRUE":
        dcTaskEnv['EBB_DCYCLE'] = os.getenv('EBB_DCYCLE', 0)
        dcTaskEnv['CHEM_GROUPS'] = os.getenv('CHEM_GROUPS', 'smoke')
        chemdep = '\n    <metataskdep metatask="prep_chem"/>'
    else:
        chemdep = ""

    if not do_ensemble:
        metatask = False
        if do_spinup:
            task_id = f'{meta_id}_spinup'
        else:
            task_id = f'{meta_id}'
        meta_bgn = ""
        meta_end = ""
        ensindexstr = ""
    else:
        if dcEnsGrpInfo is None:
            print('dcEnsGrpInfo not set up or incorrect!')
            sys.exit(1)
        ens_indices = dcEnsGrpInfo["ens_indices"]
        dep_xml = dcEnsGrpInfo["dep_xml"]
        group_name = dcEnsGrpInfo["group_name"]
        metatask = True
        task_id = f'{meta_id}_m#ens_index#'
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"
        meta_bgn = ""
        meta_end = ""
        meta_bgn = f'''
<metatask name="{group_name}">
<var name="ens_index">{ens_indices}</var>'''
        meta_end = f'\
</metatask>\n'
        ensindexstr = "_m#ens_index#"

    dcTaskEnv['KEEPDATA'] = get_cascade_env(f"KEEPDATA_{task_id}".upper()).upper()
    # dependencies
    timedep = ""
    realtime = os.getenv("REALTIME", "false")
    if realtime.upper() == "TRUE":
        starttime = get_cascade_env(f"STARTTIME_{task_id}".upper())
        timedep = f'\n    <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'

    jedidep = ""
    cloudana_dep = ""
    final_recenterdep = ""
    recenterdep = ""
    spaces = " " * 6
    do_da = False
    if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
        do_da = True
        if do_spinup:
            cloudana_dep = f'\n    <taskdep task="nonvar_cldana_spinup"/>'
        else:
            cloudana_dep = f'\n    <taskdep task="nonvar_cldana{ensindexstr}"/>'

    if os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
        do_da = True
        if os.getenv("DO_ENSEMBLE", "FALSE").upper() == "TRUE":
            jedidep = f'\n    <taskdep task="getkf_solver"/>'
        elif do_spinup:
            jedidep = f'\n    <taskdep task="jedivar_spinup"/>'
        else:
            jedidep = f'\n    <taskdep task="jedivar"/>'

    if os.getenv("DO_RECENTER", "FALSE").upper() == "TRUE":
        if os.getenv("DO_ENSEMBLE", "FALSE").upper() == "TRUE":
            recenterhrs = recenter_cycs.split(' ')
            recenterdep = f'\n<taskdep task="recenter"/>'
            streqs_rec = "<or>"
            strneqs_rec = "<and>"
            for hr in recenterhrs:
                hr = f"{int(hr):02d}"
                streqs_rec += '\n' + spaces + f'  <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>'
                strneqs_rec += '\n' + spaces + f'  <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>'
            streqs_rec += '\n' + spaces + '</or>'
            strneqs_rec += '\n    </and>'
            recenterdep_indented = textwrap.indent(recenterdep, "      ")  # 6 extra spaces
            final_recenterdep = f'''
    <or>
    {strneqs_rec}
    <and>
      {streqs_rec}{recenterdep_indented}
    </and>
    </or>'''

    coldhrs = coldhrs.split(' ')
    streqs = ""
    strneqs = ""
    if do_da:
        if coldstart_cyc_do_da.upper() == "FALSE":  # if no DA at coldstart cycs, skip checking DA tasks
            streqs = "<or>"
            for hr in coldhrs:
                hr = f"{int(hr):02d}"
                streqs += '\n' + spaces + f'  <streq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></streq>'
                strneqs += '\n' + spaces + f'  <strneq><left><cyclestr>@H</cyclestr></left><right>{hr}</right></strneq>'
            streqs += '\n' + spaces + '</or>'
            jedidep_indented = textwrap.indent(jedidep, "    ")  # four extra spaces
            cloudana_dep_indented = textwrap.indent(cloudana_dep, "    ")  # four extra spaces
            da_dep = f'''
    <or>
      {streqs}
      <and>{strneqs}{jedidep_indented}{cloudana_dep_indented}
      </and>
    </or>'''

        else:
            da_dep = f'{jedidep}{cloudana_dep}'

    else:
        da_dep = ""

    prep_ic_dep = f'<taskdep task="prep_ic"/>'
    if do_spinup:
        prep_ic_dep = f'<taskdep task="prep_ic_spinup"/>'
    prep_lbc_dep = f'\n    <taskdep task="prep_lbc{ensindexstr}" cycle_offset="0:00:00"/>'
    if "global" in os.getenv("MESH_NAME"):
        prep_lbc_dep = ''

    dependencies = f'''
  <dependency>
  <and>{timedep}{prep_lbc_dep}{da_dep}
    {prep_ic_dep}{chemdep}{final_recenterdep}{dep_xml}
  </and>
  </dependency>'''

    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv,
             dependencies, metatask, meta_id, meta_bgn, meta_end, "FCST")
# end of fcst --------------------------------------------------------
