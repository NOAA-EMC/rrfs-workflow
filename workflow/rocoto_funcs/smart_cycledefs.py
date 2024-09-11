#!/usr/bin/env python
import os
from datetime import datetime, timedelta
from rocoto_funcs.base import source
0
def smart_cycledefs(realtime,realtime_days,retro_period):
  if realtime.upper() == "TRUE":
    now=datetime.now()+timedelta(days=-1) #go back one day for possible remedy runs
    end=now+timedelta(days=int(realtime_days))
    pdy=now.strftime("%Y%m%d")
    pdy2=end.strftime("%Y%m%d")
    hr_bgn=now.hour
    hr_end='23'
  else:
    retrodates=retro_period.split("-")
    pdy=retrodates[0][:8]
    hr_bgn=retrodates[0][8:]
    pdy2=retrodates[1][:8]
    hr_end=retrodates[1][8:]
  #
  if int(hr_bgn) <= 3:
    ic_bgn='03'
    lbc_bgn='00'
  else:
    ic_bgn='15'
    lbc_bgn='12'

  dcCycledef={}
  #CYCLEDEF_PROD="00 00-23 26,27 05 2024 *"\n\
  if os.getenv('DO_DETERMINISTIC','TRUE').upper() == "TRUE":
    dcCycledef['ic']=f'{pdy}{ic_bgn}00 {pdy2}{hr_end}00 12:00:00'
    dcCycledef['lbc']=f'{pdy}{lbc_bgn}00 {pdy2}{hr_end}00 06:00:00'
    dcCycledef['prod']=f'{pdy}{ic_bgn}00 {pdy2}{hr_end}00 01:00:00'
  #
  if os.getenv('DO_ENSEMBLE','FALSE').upper() == "TRUE":
    dcCycledef['ens_ic']=f'{pdy}{ic_bgn}00 {pdy2}{hr_end}00 12:00:00'
    dcCycledef['ens_lbc']=f'{pdy}{lbc_bgn}00 {pdy2}{hr_end}00 06:00:00'
    dcCycledef['ens_prod']=f'{pdy}{ic_bgn}00 {pdy2}{hr_end}00 01:00:00'
  return dcCycledef
