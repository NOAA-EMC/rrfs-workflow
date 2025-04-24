"""
This file provides Hourly Wildfire Potential (HWP) tools.

"""

import numpy as np
import os
import datetime as dt
import shutil
from datetime import timedelta
import xarray as xr
import fnmatch

def check_restart_files(hourly_hwpdir, fcst_dates):
    """Check the restart files.

    Args:
         hourly_hwpdir: the directory where the RESTART data is copied (comrrfs/HOURLY_HWP)
         fcst_dates: Forecast dates
    Returns:
         lists of hours with and without available RESTART files
    """
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

def copy_missing_restart(comrrfs, hwp_non_avail_hours, hourly_hwpdir):
    """Check the restart files.

    The script loops through hwp_non_avail_hours (missing files in
    comrrfs/HOURLY_HWP) and determines if an alternative RESTART file in
    comrrfs/rrfs.YYYYMMDD/HH/forecast/RESTART is available instead.
    If so, it is appended to restart_avail_hours.

    Args:
         comrrfs: holds the boundary, INPUT, and RESTART files (e.g,
         described here:
         [ufs-community/ufs-srweather-app#654](https://github.com/ufs-community/ufs-srweather-app/issues/654))
         hwp_non_avail_hours: a list of hours without available RESTART files
         hourly_hwpdir: the directory where the RESTART data is copied (comrrfs/HOURLY_HWP)
    Returns:
         list of::
         - restart_avail_hours
         - restart_nonavail_hours_test which is a subset of hwp_non_avail_hours.

    """
    restart_avail_hours = []
    restart_nonavail_hours_test = []

    for cycle in hwp_non_avail_hours:
        try:
            YYYYMMDDHH = dt.datetime.strptime(cycle, "%Y%m%d%H")
            HH = cycle[8:10]
            prev_hr = YYYYMMDDHH - timedelta(hours=1)
            prev_hr_str = prev_hr.strftime("%Y%m%d%H")

            #source_restart_dir = os.path.join(comrrfs, 'rrfs.'+prev_hr_str[0:8], HH, 'forecast', 'RESTART')
            source_restart_dir = os.path.join(comrrfs, 'rrfs.'+prev_hr_str[0:8], prev_hr_str[8:10], 'forecast', 'RESTART')
            wildcard_name = f'*{HH}0000.phy_data.nc'

            try:
                matching_files = [f for f in os.listdir(source_restart_dir) if fnmatch.fnmatch(f, wildcard_name)]
                if not matching_files:
                    print(f"No matching files for cycle {cycle} in {source_restart_dir}")
                    restart_nonavail_hours_test.append(cycle)
                    continue

                for matching_file in matching_files:
                    source_file_path = os.path.join(source_restart_dir, matching_file)
                    target_file_path = os.path.join(hourly_hwpdir, matching_file)
                    var1, var2 = 'rrfs_hwp_ave', 'totprcp_ave'

                    #if os.path.exists(source_file_path):
                    try:
                            with xr.open_dataset(source_file_path) as ds:
                                if var1 in ds.variables and var2 in ds.variables:
                                    ds = ds[[var1, var2]]
                                    ds.to_netcdf(target_file_path)
                                    restart_avail_hours.append(cycle)
                                    print(f'Restart file copied: {matching_file}')
                                else:
                                    print(f'Missing variables {var1} or {var2} in {matching_file}. Skipping file.')
                    except (FileNotFoundError, IOError, OSError, RuntimeError, ValueError, TypeError, KeyError, IndexError, MemoryError) as e:
                            print(f"Error processing NetCDF file {source_file_path}: {e}")
                            restart_nonavail_hours_test.append(cycle)
                    #else:
                    #    print(f"Source file not found: {source_file_path}")
                    #    restart_nonavail_hours_test.append(cycle)

            except (FileNotFoundError, IOError, OSError, RuntimeError) as e:
                print(f"Error accessing directory {source_restart_dir}: {e}")
                restart_nonavail_hours_test.append(cycle)

        except (ValueError, TypeError) as e:
            print(f"Error processing cycle {cycle}: {e}")
            restart_nonavail_hours_test.append(cycle)


    return(restart_avail_hours, restart_nonavail_hours_test)

def process_hwp(fcst_dates, hourly_hwpdir, cols, rows, intp_dir, rave_to_intp):
    """Check the restart files.

    Args:
         fcst_dates: a list of forecasts (for production/ops/ebb=2, it is {current_day - 25 hours: current_day-1hours}, for ebb=1, it is current_day:current_day+24 hours)
         hourly_hwpdir: the directory where the RESTART data is copied (comrrfs/HOURLY_HWP)
         cols: hard coded dimension for the RRFS_NA_3km and RRFS_CONUS_3km domains:: cols = 2700 if predef_grid == 'RRFS_NA_3km' else 1092
         rows: hard coded dimension for the RRFS_NA_3km and RRFS_CONUS_3km domains:: rows = 3950 if predef_grid == 'RRFS_NA_3km' else 1820
         intp_dir: the working directory for smoke processing (${CYCLE_DIR}/process_smoke)
         rave_to_intp: a string based on the grid name:: rave_to_intp = predef_grid+"intp"
    Returns:
         list of::
         - average (through time) of HWP_AVE in the available RESTART files
         - hwp_ave_arr converted to an xarray DataArray
         - the total precipitation vector (totprcp) reshaped to the 2D grid
         - totprcp_ave_arr converted to an xarray DataArray
    """
    hwp_ave = [] 
    totprcp = np.zeros((cols*rows))
    var1, var2 = 'rrfs_hwp_ave', 'totprcp_ave' 

    for cycle in fcst_dates:
        try:
            print(f'Processing restart file for date: {cycle}')
            file_path = os.path.join(hourly_hwpdir, f"{cycle[:8]}.{cycle[8:10]}0000.phy_data.nc")
            rave_path = os.path.join(intp_dir, f"{rave_to_intp}{cycle}00_{cycle}59.nc")

            if os.path.exists(file_path) and os.path.exists(rave_path):
                try:
                    with xr.open_dataset(file_path) as nc:
                        if var1 in nc.variables and var2 in nc.variables:
                            hwp_values = nc.rrfs_hwp_ave.values.ravel() 
                            tprcp_values = nc.totprcp_ave.values.ravel()
                            totprcp += np.where(tprcp_values > 0, tprcp_values, 0)
                            hwp_ave.append(hwp_values)
                            print(f'Restart file processed for: {cycle}')
                        else:
                            print(f'Missing variables {var1} or {var2} in file: {file_path}')
                except (FileNotFoundError, IOError, OSError, RuntimeError, ValueError, TypeError, KeyError, IndexError, MemoryError) as e:
                    print(f"Error processing NetCDF file {file_path}: {e}")
            else:
                print(f'One or more files non-available for this cycle: {file_path}, {rave_path}')
        except (ValueError, TypeError) as e:
            print(f"Error processing cycle {cycle}: {e}")

    # Calculate the mean HWP values if available
    if hwp_ave:
        hwp_ave_arr = np.nanmean(hwp_ave, axis=0).reshape(cols, rows)
        totprcp_ave_arr = totprcp.reshape(cols, rows)
    else:
        hwp_ave_arr = np.zeros((cols, rows))
        totprcp_ave_arr = np.zeros((cols, rows))

    xarr_hwp = xr.DataArray(hwp_ave_arr)
    xarr_totprcp = xr.DataArray(totprcp_ave_arr)
    
    return(hwp_ave_arr, xarr_hwp, totprcp_ave_arr, xarr_totprcp)
