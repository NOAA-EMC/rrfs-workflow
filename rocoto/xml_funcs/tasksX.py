#!/usr/bin/env python
# this file hosts all tasks that will not be needed by NCO
import os
from xml_funcs.base import xml_task, source, get_cascade_env

### begin of dummy --------------------------------------------------------
### this dummy task does nothing, but may be used to reboot a cycle without any adverse effects
def dummy(xmlFile, expdir):
  task_id='dummy'
  cycledefs='prod'
  xml_task(xmlFile,expdir,task_id,cycledefs)
### end of dummy --------------------------------------------------------

### begin of clean --------------------------------------------------------
def clean(xmlFile, expdir):
  task_id='clean'
  cycledefs='prod'
  xml_task(xmlFile,expdir,task_id,cycledefs)
### end of clean --------------------------------------------------------

### begin of graphics --------------------------------------------------------
def graphics(xmlFile, expdir):
  meta_id='graphics'
  cycledefs='prod'
  # metatask (nested or not)
  meta_bgn= \
f'''
<metatask name="{meta_id}">
<var name="area">full NE NC NW SE SC SW EastCO</var>'''
  meta_end=f'\
</metatask>\n'

  # Task-specific EnVars beyond the task_common_vars
  dcTaskEnv={
    'FHR': os.getenv('FCST_LENGTH','6'),
    'AREA': '#area#'
  }
  task_id=f'{meta_id}_#area#'

  timedep=""
  realtime=os.getenv("REALTIME","false")
  starttime=get_cascade_env(f"STARTTIME_{meta_id}".upper())
  if realtime.upper() == "TRUE":
    timedep=f'\n  <timedep><cyclestr offset="{starttime}">@Y@m@d@H@M00</cyclestr></timedep>'
  #
  COMROOT=os.getenv("COMROOT","COMROOT_NOT_DEFINED")
  RUN='rrfs'
  NET=os.getenv("NET","NET_NOT_DEFINED")
  VERSION=os.getenv("VERSION","VERSION_NOT_DEFINED")
  dependencies=f'''
  <dependency>
  <and>{timedep}
  <metataskdep metatask="upp"/>
  </and>
  </dependency>'''

  #
  xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv,dependencies,True,meta_id,meta_bgn,meta_end)

### end of graphics --------------------------------------------------------
