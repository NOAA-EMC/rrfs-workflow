#!/usr/bin/env python
import os
import calendar
from datetime import datetime, timedelta


def smart_cycledefs():
    # If users set CYCLEDEF_* variables explicitly in exp.setup, then just use it
    # otherwise calculate cycledef smartly

    num_spinup_cycledef = os.getenv('NUM_SPINUP_CYCLEDEF', '0')
    cycledef_ic = os.getenv('CYCLEDEF_IC', 'not_defined')
    if cycledef_ic != 'not_defined':
        cycledef_lbc = os.getenv('CYCLEDEF_LBC', 'not_defined')
        cycledef_prod = os.getenv('CYCLEDEF_PROD', 'not_defined')
        cycledef_spinup = os.getenv('CYCLEDEF_SPINUP', 'not_defined')
    else:  # compute cycledef automatically if no CYCLEDEF_* environment variables
        lbc_cycs = os.getenv('LBC_CYCS', '00 12').strip().split()
        lbc_step = str(int(24 / len(lbc_cycs)))
        lbc_startcyc = lbc_cycs[0]
        cyc_interval = os.getenv('CYC_INTERVAL', '3')
        cold_cycs = os.getenv('COLDSTART_CYCS', '03 15').strip().split()
        ic_step = str(int(24 / len(cold_cycs)))
        if os.getenv('DO_CYC', 'FALSE').upper() == "FALSE":
            cyc_interval = ic_step
        prodswitch_cycs = os.getenv('PRODSWITCH_CYCS', '09 21').strip().split()
        # compute spinup_hrs (usually coldstart at 03 or 15)
        spinup_hrs = cold_cycs[0] + "-" + f'{int(prodswitch_cycs[0])-1:02},'
        if len(cold_cycs) > 1:
            half_spinup = cold_cycs[1] + "-" + f'{int(prodswitch_cycs[1])-1:02}'
            spinup_hrs += half_spinup
        #
        realtime = os.getenv('REALTIME', 'false')
        spinup = os.getenv('DO_SPINUP', 'false')
        if realtime.upper() == "TRUE":
            cycledef_ic = f'''  &Y1;&M1;&D1;{cold_cycs[0]}00 &Y2;&M2;&D2;2300 {ic_step.zfill(2)}:00:00'''
            cycledef_lbc = f''' &Y1;&M1;&D1;{lbc_startcyc.zfill(2)}00 &Y2;&M2;&D2;2300 {lbc_step.zfill(2)}:00:00'''
            cycledef_prod = f'''&Y1;&M1;&D1;0000 &Y2;&M2;&D2;2300 {cyc_interval.zfill(2)}:00:00'''
            if spinup.upper() == 'TRUE':
                cycledef_spinup = f'''00 {spinup_hrs} * &M1;,&M2; &Y1;,&Y2; *'''
                num_spinup_cycledef = 1
        #
        # retros write out cycledefs explicitly without referencing XML entities
        elif spinup.upper() != "TRUE":  # no spinup cycles
            retrodates = os.getenv('RETRO_PERIOD', '2225010100-2225010800').split("-")
            cycledef_ic = f'''  {retrodates[0]}00 {retrodates[1]}00 {ic_step.zfill(2)}:00:00'''
            cycledef_lbc = f''' {retrodates[0]}00 {retrodates[1]}00 {lbc_step.zfill(2)}:00:00'''
            cycledef_prod = f'''{retrodates[0]}00 {retrodates[1]}00 {cyc_interval.zfill(2)}:00:00'''
        else:  # spinup cycles enabled
            retrodates = os.getenv('RETRO_PERIOD', '2225010100-2225010800').split("-")
            date1 = datetime.strptime(retrodates[0], "%Y%m%d%H")
            date2 = datetime.strptime(retrodates[1], "%Y%m%d%H")
            if date1.hour < 12:  # either start from 0z or from 12z depsite of user's start hour
                date1.replace(hour=0)
            else:
                date1.replace(hour=12)
            #
            if date1.year == date2.year and date1.month == date2.month:
                if date1.hour == 0:
                    prod_cyc1 = f'{int(prodswitch_cycs[0]):02}'
                    cycledef_spinup = f'''00 {spinup_hrs} {date1.day:02}-{date2.day:02} {date1.month:02} {date1.year:04} *'''
                    num_spinup_cycledef = 1
                else:  # 12z
                    prod_cyc1 = f'{int(prodswitch_cycs[1]):02}'
                    date1b = date1 + timedelta(hours=12)
                    cycledef_spinup = f'''00 {half_spinup} {date1.day:02} {date1.month:02} {date1.year:04} *'''
                    cycledef_spinup2 = f'''00 {spinup_hrs} {date1b.day:02}-{date2.day:02} {date1.month:02} {date1.year:04} *'''
                    num_spinup_cycledef = 2
            else:  # different month, year
                lastday = calendar.monthrange(date1.year, date1.month)[1]  # find the last day of a calendar month
                if date1.hour == 0:
                    prod_cyc1 = f'{int(prodswitch_cycs[0]):02}'
                    cycledef_spinup = f'''00 {spinup_hrs} {date1.day:02}-{lastday:02} {date1.month:02} {date1.year:04} *'''
                    cycledef_spinup2 = f'''00 {spinup_hrs} 01-{date2.day:02} {date2.month:02} {date2.year:04} *'''
                    num_spinup_cycledef = 2
                else:  # 12z
                    prod_cyc1 = f'{int(prodswitch_cycs[1]):02}'
                    date1b = date1 + timedelta(hours=12)
                    cycledef_spinup = f'''00 {half_spinup} {date1.day:02} {date1.month:02} {date1.year:04} *'''
                    cycledef_spinup2 = f'''00 {spinup_hrs} {date1b.day:02}-{lastday:02} {date1.month:02} {date1.year:04} *'''
                    cycledef_spinup3 = f'''00 {spinup_hrs} 01-{date2.day:02} {date2.month:02} {date2.year:04} *'''
                    num_spinup_cycledef = 3
            #
            cycledef_ic = f'''  {date1.strftime("%Y%m%d")}{cold_cycs[0]}00 {retrodates[1]}00 {ic_step.zfill(2)}:00:00'''
            cycledef_lbc = f''' {date1.strftime("%Y%m%d%H")}00 {retrodates[1]}00 {lbc_step.zfill(2)}:00:00'''
            cycledef_prod = f'''{date1.strftime("%Y%m%d")}{prod_cyc1}00 {retrodates[1]}00 {cyc_interval.zfill(2)}:00:00'''
    #
    # fill in the Cycledef dictionary
    dcCycledef = {}
    dcCycledef['ic'] = f'{cycledef_ic}'
    dcCycledef['lbc'] = f'{cycledef_lbc}'
    dcCycledef['prod'] = f'{cycledef_prod}'
    if os.getenv('DO_SPINUP', 'false').upper() == 'TRUE':
        dcCycledef['spinup'] = f'{cycledef_spinup}'
        if num_spinup_cycledef == 2:
            dcCycledef['spinup2'] = f'{cycledef_spinup2}'
        elif num_spinup_cycledef == 3:
            dcCycledef['spinup2'] = f'{cycledef_spinup2}'
            dcCycledef['spinup3'] = f'{cycledef_spinup3}'
    #
    # set the NUM_SPINUP_CYCLEDEF environment variable
    env_vars = {'NUM_SPINUP_CYCLEDEF': f'{num_spinup_cycledef}'}
    os.environ.update(env_vars)

    return dcCycledef
