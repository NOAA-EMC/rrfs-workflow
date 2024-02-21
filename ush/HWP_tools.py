import numpy as np
import os
import datetime as dt
import shutil
from datetime import timedelta
import xarray as xr
import fnmatch

def check_restart_files(hourly_hwpdir, fcst_dates):
    hwp_avail_hours = []
    hwp_non_avail_hours = []

    for cycle in fcst_dates:
        restart_file = f"{cycle[:8]}.{cycle[8:10]}0000.phy_data.nc"
        file_path = os.path.join(hourly_hwpdir, restart_file)

        if os.path.exists(file_path):
            print(f'Restart file available for: {restart_file}')
            hwp_avail_hours.append(cycle)
        else:
            print(f'Copy restart file for: {restart_file}')
            hwp_non_avail_hours.append(cycle)

    print(f'Available restart at: {hwp_avail_hours}, Non-available restart files at: {hwp_non_avail_hours}')
    return(hwp_avail_hours, hwp_non_avail_hours)

def copy_missing_restart(nwges_dir, hwp_non_avail_hours, hourly_hwpdir):
    restart_avail_hours = []
    restart_nonavail_hours_test = []

    for cycle in hwp_non_avail_hours:
        YYYYMMDDHH = dt.datetime.strptime(cycle, "%Y%m%d%H")
        prev_hr = YYYYMMDDHH - timedelta(hours=1)
        prev_hr_str = prev_hr.strftime("%Y%m%d%H")

        source_restart_dir = os.path.join(nwges_dir, prev_hr_str, 'fcst_fv3lam', 'RESTART')
        wildcard_name = '*.phy_data.nc'
        try:
            matching_files = [f for f in os.listdir(source_restart_dir) if fnmatch.fnmatch(f, wildcard_name)]
            for matching_file in matching_files:
                source_file_path = os.path.join(source_restart_dir, matching_file)
                target_file_path = os.path.join(hourly_hwpdir, matching_file)
                var1, var2 = 'rrfs_hwp_ave', 'totprcp_ave'
 
                if os.path.exists(source_file_path):
                    with xr.open_dataset(source_file_path) as ds:
                        ds = ds[[var1, var2]]
                        ds.to_netcdf(target_file_path)
                        restart_avail_hours.append(cycle)
                        print(f'Restart file copied: {matching_file}')
                else:
                    raise FileNotFoundError(f"Source file not found: {source_file_path}")
        except (FileNotFoundError, AttributeError) as e:
            restart_nonavail_hours_test.append(cycle)
            print(f'Issue with file for cycle {cycle}: {e}')

        except Exception as e:  # Catch-all for unexpected errors
            restart_nonavail_hours_test.append(cycle)
            print(f'Unexpected error for cycle {cycle}: {e}')

    return(restart_avail_hours, restart_nonavail_hours_test)

def process_hwp(fcst_dates, hourly_hwpdir, cols, rows, intp_dir, rave_to_intp):
    hwp_ave = [] 
    totprcp = np.zeros((cols*rows))
    
    for cycle in fcst_dates:
        print(f'Processing restart file for date: {cycle}')
        file_path = os.path.join(hourly_hwpdir, f"{cycle[:8]}.{cycle[8:10]}0000.phy_data.nc")
        rave_path = os.path.join(intp_dir, f"{rave_to_intp}{cycle}00_{cycle}59.nc")

        if os.path.exists(file_path) and os.path.exists(rave_path):
            with xr.open_dataset(file_path) as nc:
                hwp_values = nc.rrfs_hwp_ave.values.ravel()  # Keeping as numpy array for efficiency
                tprcp_values = nc.totprcp_ave.values.ravel()  # Ensure you extract numpy array
                totprcp += np.where(tprcp_values > 0, tprcp_values, 0)
                hwp_ave.append(hwp_values) 
        else:
            print('One or more files non-available for this cycle.')
    # Calculate the mean HWP values if available
    if hwp_ave:
        hwp_ave_arr = np.nanmean(hwp_ave, axis=0).reshape(cols, rows)
        totprcp_ave_arr = totprcp.reshape(cols, rows)
    else:
        hwp_ave_arr = np.zeros((cols, rows))
        totprcp_ave_arr = np.zeros((cols, rows))

    xarr_hwp = xr.DataArray(hwp_ave_arr)
    xarr_totprcp  = xr.DataArray(totprcp_ave_arr)

    return(hwp_ave_arr, xarr_hwp, totprcp_ave_arr, xarr_totprcp)
