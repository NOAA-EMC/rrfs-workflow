#!/usr/bin/env python
import os
from datetime import datetime, timedelta
from rocoto_funcs.base import source

def smart_cycledefs():
  # If users set CYCLEDEF_* variables explicitly in exp.setup, then just use it
  # otherwise calculate cycledef smartly

  cycledef_ic=os.getenv('CYCLEDEF_IC','not_defined')
  if cycledef_ic != 'not_defined':
    cycledef_lbc=os.getenv('CYCLEDEF_LBC','not_defined')
    cycledef_prod=os.getenv('CYCLEDEF_PROD','not_defined')
    cycledef_spinup=os.getenv('CYCLEDEF_SPINUP','not_defined')
  else:
    ic_step=os.getenv('CYCLEDEF_IC_STEP_HRS','6')
    lbc_step=os.getenv('CYCLEDEF_LBC_STEP_HRS','6')
    cyc_interval=os.getenv('CYC_INTERVAL','3')
    cold_cycs=os.getenv('COLDSTART_CYCS','03 15').strip().split(' ')
    prodswitch_cycs=os.getenv('PRODSWITCH_CYCS', '09 21').strip().split(' ')
    # compute spinup_hrs (usually coldstart at 03 or 15)
    spinup_hrs=cold_cycs[0]+"-"+f'{int(prodswitch_cycs[0])-1:02},'
    spinup_hrs=spinup_hrs+cold_cycs[1]+"-"+f'{int(prodswitch_cycs[1])-1:02}'

    cycledef_ic=f'''  &Y1;&M1;&D1;&H1;00 &Y2;&M2;&D2;&H2;00 {ic_step.zfill(2)}:00:00'''
    cycledef_lbc=f''' &Y1;&M1;&D1;&H1;00 &Y2;&M2;&D2;&H2;00 {lbc_step.zfill(2)}:00:00'''
    #
    realtime=os.getenv('REALTIME','false')
    spinup=os.getenv('DO_SPINUP','false')
    if realtime.upper() == "TRUE":
      cycledef_prod=f'''&Y1;&M1;&D1;&H1;00 &Y2;&M2;&D2;&H2;00 {cyc_interval.zfill(2)}:00:00'''
      if spinup.upper()=='TRUE':
          cycledef_spinup=f'''00 {spinup_hrs} * &M1;-&M2; &Y1;-&Y2; *'''
    else:
      cycledef_prod=f'''&Y1;&M1;&D1;&HP;00 &Y2;&M2;&D2;&H2;00 {cyc_interval.zfill(2)}:00:00'''
      cycledef_spinup=f''' 00 {spinup_hrs} &D1;-&D2; &M1;-&M2; &Y1;-&Y2; *'''
      cycledef_spinup2=f''' 00 {spinup_hrs} &D1;-&D2; &M1;-&M2; &Y1;-&Y2; *'''

  # fill in the Cycledef dictionary
  dcCycledef={}
  dcCycledef['ic']=f'{cycledef_ic}'
  dcCycledef['lbc']=f'{cycledef_lbc}'
  dcCycledef['prod']=f'{cycledef_prod}'
  if os.getenv('DO_SPINUP').upper()=='TRUE':
    dcCycledef['spinup']=f'{cycledef_spinup}'

  return dcCycledef
