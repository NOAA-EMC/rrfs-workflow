#!/usr/bin/env python
import os
from datetime import datetime, timedelta


def smart_cycledefs():
    # If users set CYCLEDEF_* variables explicitly in exp.setup, then just use it
    # otherwise calculate cycledef smartly

    warmda_only = os.getenv('COLDSTART_CYCS_DO_DA', 'FALSE').upper() == "FALSE"
    cycledef_warmda = ""

    cycledef_ic = os.getenv('CYCLEDEF_IC', 'not_defined')
    if cycledef_ic != 'not_defined':
        cycledef_lbc = os.getenv('CYCLEDEF_LBC', 'not_defined')
        cycledef_prod = os.getenv('CYCLEDEF_PROD', 'not_defined')
        cycledef_spinup = os.getenv('CYCLEDEF_SPINUP', 'not_defined')
    else:  # compute cycledef automatically if no CYCLEDEF_* environment variables
        lbc_cycs = os.getenv('LBC_CYCS', '00 12').strip().split()
        lbc_step = str(int(24 / len(lbc_cycs)))
        cyc_interval = os.getenv('CYC_INTERVAL', '3')
        cold_cycs = os.getenv('COLDSTART_CYCS', '03 15').strip().split()
        ic_step = str(int(24 / len(cold_cycs)))
        if os.getenv('DO_CYC', 'FALSE').upper() == "FALSE":
            cyc_interval = ic_step
        prodswitch_cycs = os.getenv('PRODSWITCH_CYCS', '09 21').strip().split()
        # compute spinup_hrs (usually coldstart at 03 or 15)
        spinup_hrs = list(range(int(cold_cycs[0]), int(prodswitch_cycs[0])))
        if len(cold_cycs) > 1:
            spinup_hrs.extend(list(range(int(cold_cycs[1]), int(prodswitch_cycs[1]))))
        #
        realtime = os.getenv('REALTIME', 'false')
        spinup = os.getenv('DO_SPINUP', 'false')
        if realtime.upper() == "TRUE":
            cycledef_ic = f'  &Y1;&M1;&D1;{cold_cycs[0]}00 &Y2;&M2;&D2;2300 {ic_step.zfill(2)}:00:00'
            cycledef_lbc = f' &Y1;&M1;&D1;{lbc_cycs[0]}00 &Y2;&M2;&D2;2300 {lbc_step.zfill(2)}:00:00'
            cycledef_prod = f'&Y1;&M1;&D1;0000 &Y2;&M2;&D2;2300 {cyc_interval.zfill(2)}:00:00'
            cycledef_spinup = cycledef_prod
        # ~~~~~
        # retros write out cycledefs explicitly without referencing XML entities
        else:
            retrodates = os.getenv('RETRO_PERIOD', '2225010100-2225010800').split("-")
            hour1 = retrodates[0][8:10]
            if spinup.upper() == "TRUE":
                if hour1 < 12:  # determine the first prod_cyc
                    prod_cyc1 = prodswitch_cycs[0]
                else:
                    prod_cyc1 = prodswitch_cycs[0]
            else:
                prod_cyc1 = cold_cycs[0]  # no spin up, prod_cyc starts from the first cold start cyc
            #
            cycledef_ic = f'  {retrodates[0][0:8]}{cold_cycs[0]}00 {retrodates[1]}00 {ic_step.zfill(2)}:00:00'
            cycledef_lbc = f' {retrodates[0][0:8]}{lbc_cycs[0]}00 {retrodates[1]}00 {lbc_step.zfill(2)}:00:00'
            cycledef_prod = f'{retrodates[0][0:8]}{prod_cyc1}00 {retrodates[1]}00 {cyc_interval.zfill(2)}:00:00'
            if spinup.upper() == "TRUE":
                cycledef_spinup = f'{retrodates[0][0:8]}{cold_cycs[0]}00 {retrodates[1]}00 {cyc_interval.zfill(2)}:00:00'
    #
    # fill in the Cycledef dictionary
    dcCycledef = {}
    dcCycledef['ic'] = f'{cycledef_ic}'
    dcCycledef['lbc'] = f'{cycledef_lbc}'
    dcCycledef['prod'] = f'{cycledef_prod}'
    if spinup.upper() == "TRUE":
        valid_str = " ".join(f"{i}" for i in spinup_hrs)
        dcCycledef['spinup'] = {'valid_hours': f'{valid_str}', "cycledef": f'{cycledef_spinup}'}
    # ~~~~
    return dcCycledef
