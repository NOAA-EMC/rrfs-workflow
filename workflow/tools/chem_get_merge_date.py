#!/usr/bin/env python
import pandas as pd
import sys

# Create date ranges
thisyear = sys.argv[1]
julday = int(sys.argv[2])
baseyear = sys.argv[3]

dates_thisyear = pd.date_range(start=thisyear+'-01-01', end=thisyear+'-12-31')
dates_baseyear = pd.date_range(start=baseyear+'-01-01', end=baseyear+'-12-31')

mapping = []

#for d24 in dates_thisyear:
# Find dates in 2017 with the same day of the week
# and the minimum calendar distance
d24 = dates_thisyear[julday]
match_base = dates_baseyear[dates_baseyear.dayofweek == d24.dayofweek]

# Calculate absolute difference in days from the "same" calendar position
# (e.g., trying to stay as close to the same month/day as possible)
target_date_base = d24.replace(year=int(baseyear)) if not (d24.month == 2 and d24.day == 29) else pd.Timestamp(baseyear+'-02-28')

closest_day = min(match_base, key=lambda x: abs(x - target_date_base))

output = closest_day.date()

print(output)
