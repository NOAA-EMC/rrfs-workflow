#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, source, get_cascade_env

### begin of prep_chem --------------------------------------------------------
def prep_chem(xmlFile, expdir,do_ensemble=False, do_spinup=False):
  meta_id='prep_chem'
  cycledefs='prod'
#  if do_spinup:
#    cycledefs='spinup'
#    num_spinup_cycledef=os.getenv('NUM_SPINUP_CYCLEDEF','1')
#    if num_spinup_cycledef=='2':
#      cycledefs='spinup,spinup2'
#    elif num_spinup_cycledef=='3':
#      cycledefs='spinup,spinup2,spinup3'
#  else:
#    cycledefs='prod'
  realtime=os.getenv("REALTIME","false")
  
  create_own_data=os.getenv('CREATE_OWN_DATA',"FALSE").upper()

  # Task-specific EnVars beyond the task_common_vars
  datadir_chem=os.getenv('CHEMPATH','/lfs6/BMC/rtwbl/cheMPAS-Fire/input/')
  mesh_name=os.getenv('MESH_NAME','conus3km').lower()
  fcst_length=os.getenv('FCST_LENGTH','24')
  rave_dir=os.getenv('RAVE_DIR','')
  regrid_wrapper_dir=os.getenv('REGRID_WRAPPER_DIR')
  regrid_conda_env=os.getenv('REGRID_CONDA_ENV')
  

  dcTaskEnv={
    'FCST_LENGTH': f'{fcst_length}',
    'MESH_NAME': f'{mesh_name}',
    'DATADIR_CHEM': f'{datadir_chem}',
    'CREATE_OWN_DATA' : f'{create_own_data}',
    'REALTIME' : f'{realtime}',
    'REGRID_WRAPPER_DIR' : f'{regrid_wrapper_dir}',
    'REGRID_CONDA_ENV' : f'{regrid_conda_env}' }
#
  if realtime.upper() == "TRUE":
     rave_dir='/public/data/grids/nesdis/3km_fire_emissions/'
  else:
     if len(rave_dir) > 1: 
        rave_dir=rave_dir
     else:
        rave_dir=datadir_chem + '/emissions/RAVE/'

  dcTaskEnv['RAVE_DIR']=f'{rave_dir}'
  metatask=True
  task_id=f'{meta_id}_#sector#'
  dcTaskEnv['EMIS_SECTOR_TO_PROCESS']='#sector#'
  dcTaskEnv['ANTHRO_EMISINV']='GRA2PES'
  meta_bgn=""
  meta_end=""

# Emission sectors / metatask

  emis_sectors_test= ["smoke", "anthro", "pollen","dust","rwc"]
  emis_sectors=""
  for sector in emis_sectors_test:
     testval = os.getenv('DO_' + sector.upper(),'FALSE').upper()
     if testval == "TRUE":
        emis_sectors=emis_sectors+sector + ' '
  emis_sectors = emis_sectors.strip()

#

  meta_bgn=f'''
<metatask name="{meta_id}">
<var name="sector">{emis_sectors}</var>'''
  meta_end=f'\
</metatask>\n'

  # dependencies

  timedep=f''
  if realtime.upper() == "TRUE":
    starttime=get_cascade_env(f"STARTTIME_{task_id}".upper())
    timedep=f'\n   <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
    
  #
  initdep=f'\n   <taskdep task="prep_ic"/>'
  dependencies=f'''
  <dependency>
  <and>{timedep}
  {initdep}
  </and>
  </dependency>'''

  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,metatask,meta_id,meta_bgn,meta_end,"PREP_CHEM")
### end of prep_chem --------------------------------------------------------
