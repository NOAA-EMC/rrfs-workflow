#!/usr/bin/env python
import os
from datetime import datetime, timedelta
from rocoto_funcs.base import source

def smart_cycledefs(realtime):

  dcCycledef={}
  cycledef_ic=os.getenv('CYCLEDEF_IC','299901012100 299901012300 12:00:00')
  cycledef_lbc=os.getenv('CYCLEDEF_LBC','299901012100 299901012300 12:00:00')
  cycledef_prod=os.getenv('CYCLEDEF_PROD','299901012100 299901012300 12:00:00')
  dcCycledef['ic']=f'{cycledef_ic}'
  dcCycledef['lbc']=f'{cycledef_lbc}'
  dcCycledef['prod']=f'{cycledef_prod}'

  return dcCycledef
