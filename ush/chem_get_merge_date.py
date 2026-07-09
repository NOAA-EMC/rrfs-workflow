#!/usr/bin/env python
import pandas as pd
import sys

# Create date ranges
thisyear = sys.argv[1]
# Subtract 1 because Pandas is 0-indexed and Julian days are 1-indexed
julday = int(sys.argv[2]) - 1
baseyear = sys.argv[3]

dates_thisyear = pd.date_range(start=f"{thisyear}-01-01", end=f"{thisyear}-12-31")
dates_baseyear = pd.date_range(start=f"{baseyear}-01-01", end=f"{baseyear}-12-31")

d24 = dates_thisyear[julday]

# --- HOLIDAY MAPPING INTERCEPTOR ---
# We use pd.date_range with 'W-MON' and 'W-THU' frequencies to flawlessly
# calculate floating holidays regardless of leap years or calendar shifts.


def get_holidays(yr):
    yr_str = str(yr)
    return {
        # Fixed Holidays
        pd.Timestamp(f"{yr_str}-01-01").date(): "NEW_YEARS",
        pd.Timestamp(f"{yr_str}-07-04").date(): "INDEPENDENCE",
        pd.Timestamp(f"{yr_str}-11-11").date(): "VETERANS",
        pd.Timestamp(f"{yr_str}-12-25").date(): "CHRISTMAS",

        # Floating Holidays
        pd.date_range(f"{yr_str}-01-01", f"{yr_str}-01-31", freq='W-MON')[2].date(): "MLK_DAY",         # 3rd Mon Jan
        pd.date_range(f"{yr_str}-02-01", f"{yr_str}-02-28", freq='W-MON')[2].date(): "PRESIDENTS",      # 3rd Mon Feb
        pd.date_range(f"{yr_str}-05-01", f"{yr_str}-05-31", freq='W-MON')[-1].date(): "MEMORIAL",       # Last Mon May
        pd.date_range(f"{yr_str}-09-01", f"{yr_str}-09-30", freq='W-MON')[0].date(): "LABOR_DAY",       # 1st Mon Sep
        pd.date_range(f"{yr_str}-10-01", f"{yr_str}-10-31", freq='W-MON')[1].date(): "COLUMBUS",        # 2nd Mon Oct
        pd.date_range(f"{yr_str}-11-01", f"{yr_str}-11-30", freq='W-THU')[3].date(): "THANKSGIVING",    # 4th Thu Nov
    }


# Generate the dictionaries for both the forecast year and 2017
holidays_this = get_holidays(thisyear)
# Reverse the base year dictionary so we can look up the date by the holiday name
holidays_base = {name: date for date, name in get_holidays(baseyear).items()}

# --- DATE SELECTION ---
# Check if today is a major holiday
if d24.date() in holidays_this:
    holiday_name = holidays_this[d24.date()]
    output = holidays_base[holiday_name]

else:
    # Original logic for standard weekdays/weekends
    match_base = dates_baseyear[dates_baseyear.dayofweek == d24.dayofweek]

    # Calculate absolute difference in days from the "same" calendar position
    target_date_base = d24.replace(year=int(baseyear)) if not (d24.month == 2 and d24.day == 29) else pd.Timestamp(f"{baseyear}-02-28")

    closest_day = min(match_base, key=lambda x: abs(x - target_date_base))
    output = closest_day.date()

print(output)
