#!/usr/bin/env python

# Purpose: Creates all annual merge dates files including ramp-ups
# Usage: Change variables for run days and year.
# Type ./create_merge_dates.py <YYYY>
#
# By James Beidler (Beidler.James@epa.gov) 2/09/10
#  Changed holidays method from holidays file to predictive  26 Mar 2014
#  Requires Python 2.0 +

import calendar
import sys
from datetime import date, timedelta

# Run information

# Path to output files
outPath = "."

# End Variable Section.  You should not have to change anything past this point.

year = sys.argv[1]
year = int(year)


def checkHol(repDate, calDate, holidays):
    # Check if a date is a holiday
    if calDate in holidays:
        return calDate
    else:
        return repDate


def goodFriday(year):
    # Use the Butcher calculation to get Good Friday
    a = year % 19
    b = year // 100
    c = year % 100
    d = ((19 * a) + b - (b // 4) - ((b - ((b + 8) // 25) + 1) // 3) + 15) % 30
    e = (32 + (2 * (b % 4)) + (2 * (c // 4)) - d - (c % 4)) % 7
    f = d + e - (7 * ((a + (11 * d) + (22 * e)) // 451)) + 114
    month = f // 31
    day = (f % 31) + 1

    easter = date(year, month, day)
    gf = easter - timedelta(2)

    return gf


def getXDay(year, month, xOccur, dayOfWeek):
    '''
    Get the X occurance of a specific weekday in a month
    ie. 4th Monday in April
    Works for Memorial Day, Labor Day

    xOccur = 1, 2, 3, 4, 5 (where 5 is understood as the last occurance, whether that is the 4th or 5th occurance)
    dayOfWeek = 0, 1, 2, 3, 4, 5, 6 (where 0 is Sunday and 6 is Saturday)
    '''
    monArray = calendar.monthcalendar(year, month)

    # Convert occurance to a python index number
    if xOccur == 5:
        wom = -1
    else:
        wom = xOccur - 1

    # Move up an index if that weekday doesn't exist in the first list in the array
    if wom >= 0 and monArray[0][dayOfWeek] == 0:
        wom += 1

    day = monArray[wom][dayOfWeek]

    # If the weekday does not exist in the last list, then move back an index
    if wom == -1 and day == 0:
        day = monArray[-2][dayOfWeek]

    return date(year, month, day)


def getHolidays(year):
    # Fixed date holidays: New Year's, 4th of July, Christmas Eve, Christmas Day
    fix = [date(year - 1, 12, 24), date(year - 1, 12, 25), date(year, 1, 1),
           date(year, 7, 4), date(year, 12, 24), date(year, 12, 25)]

    # If the 4th of July falls on a weekend, then add the day before or day after
    if date(year, 7, 4).weekday() == 5:
        fix.append(date(year, 7, 3))
    elif date(year, 7, 4).weekday() == 6:
        fix.append(date(year, 7, 5))

    gd = goodFriday(year)                 # Good Friday
    mem = getXDay(year, 5, 5, 0)          # Memorial Day
    lab = getXDay(year, 9, 1, 0)          # Labor Day
    thx = getXDay(year, 11, 4, 3)         # Thanksgiving
    thxa = thx + timedelta(1)             # Day after Thanksgiving

    hd = fix + [gd, mem, lab, thx, thxa]

    # Add the day after each holiday
    holidays = hd[:]
    for hDay in hd:
        holidays.append(hDay + timedelta(1))

    return holidays


def getAveDay(year, month, holidays):
    # Find the average day for the month
    # This uses a *slightly* different method than the getRepWeek
    #  for some inexplicable reason
    for wk in calendar.monthcalendar(year, month):
        if 0 in wk:
            continue

        dWeek = [date(year, month, day) for day in wk]

        if dWeek[1] in holidays:
            continue
        else:
            break
#               hWk = False
#               for day in dWeek:
#                       if day in holidays:
#                               hWk = True
#
#               # Return the rep_week if there were no holidays
#               if hWk == False:
#                       break

    return dWeek[1]


def getRepWeek(year, month, holidays):
    # Find representative week in the base year
    # This is the first full week in the month without holidays
    # For some reason if the first Monday is the first day of the year
    #  then you wouldn't use that week as a rep week...?
    for wk in calendar.monthcalendar(year, month):
        if 0 in wk or wk[0] == 1:
            continue

        rep_week = [date(year, month, day) for day in wk]

        hWk = False
        for day in rep_week:
            if day in holidays:
                hWk = True

        # Return the rep_week if there were no holidays
        if hWk is False:
            break

    return rep_week


# Generate the holidays
holidays = getHolidays(year)

# Loop for each month, starting with the ramp-up
outFileName = 'smk_merge_dates_%s.txt' % year
outFile = open('%s/%s' % (outPath, outFileName), 'w')
# Write header
outFile.write('    Date, aveday_N, aveday_Y,  mwdss_N,  mwdss_Y,   week_N,   week_Y,      all\n')
# Loop for each month, starting with the ramp-up
for month in range(13):
    if month == 0:
        # Use settings for ramp-up
        run_year = year - 1
        month = 12
    else:
        run_year = year

    # Get the representative Tuesday
    ave_rep = getAveDay(year, month, holidays)
    # Get the representative week
    rep_week = getRepWeek(year, month, holidays)

    # Write header
    outFile.write('    Date, aveday_N, aveday_Y,  mwdss_N,  mwdss_Y,   week_N,   week_Y,      all\n')

    # Loop for each day in the month of the calendar year
    for day in range(1, calendar.monthrange(run_year, month)[1] + 1):
        dDate = date(run_year, month, day)
        aDate = date(year, month, day)
        day_of_week = calendar.weekday(year, month, day)           # Find the day of the week in the calendar year
        wk_day = rep_week[day_of_week]
        mw_day = rep_week[day_of_week]  # Default representative day
        if day_of_week in range(1, 5):
            mw_day = rep_week[1]    # Overridden for Tues-Fri

        runDate = dDate
        avedayN = ave_rep
        avedayY = checkHol(ave_rep, aDate, holidays)
        mwdssN = mw_day
        mwdssY = checkHol(mw_day, aDate, holidays)
        weekN = wk_day
        weekY = checkHol(wk_day, aDate, holidays)

        day_list = (runDate, avedayN, avedayY, mwdssN, mwdssY, weekN, weekY, runDate)
        outFile.write('%s\n' % ', '.join([day.strftime('%Y%m%d') for day in day_list]))
