#!/usr/bin/env python
import xarray as xr
import sys
import os


def prioritize_emissions(primary_nc, secondary_nc):
    # Load datasets fully into memory
    with xr.open_dataset(primary_nc) as pri:
        ds_pri = pri.load()
    with xr.open_dataset(secondary_nc) as sec:
        ds_sec = sec.load()

    # Using .sizes to avoid FutureWarnings
    n_pri = ds_pri.sizes.get('nkanthro', 1)
    n_sec = ds_sec.sizes.get('nkanthro', 1)

    print(f"Primary vertical layers: {n_pri}")
    print(f"Secondary vertical layers: {n_sec}")

    # Initialize a completely fresh dataset
    ds_out = xr.Dataset()

    # --- COPY NON-EMISSIONS VARIABLES (lat, lon, xtime, etc.) ---
    for var in ds_pri.data_vars:
        if not var.startswith('e_ant'):
            da = ds_pri[var].copy()
            da.encoding.clear()
            ds_out[var] = da

    print("\n--- Processing 'e_ant' Variables ---")

    # Calculate how many layers we need to add to the primary data
    pad_size = max(0, n_sec - n_pri)

    # --- CASE 1 & CASE 2: Variables in Primary ---
    for var in ds_pri.data_vars:
        if var.startswith('e_ant'):
            da_pri = ds_pri[var]

            # Create a purely 2D spatial mask by dropping 'nkanthro'
            if 'nkanthro' in da_pri.dims:
                da_spatial = da_pri.isel(nkanthro=0, drop=True)
            else:
                da_spatial = da_pri

            valid_mask_2d = (da_spatial != 0) & (da_spatial.notnull())

            if var in ds_sec.data_vars:
                # CASE 1: Exists in both datasets
                da_sec = ds_sec[var]

                # Pad the primary variable with zeros for the upper layers
                if pad_size > 0:
                    da_pri_padded = da_pri.pad(nkanthro=(0, pad_size), constant_values=0)
                    da_pri_padded = da_pri_padded.assign_coords(nkanthro=da_sec['nkanthro'])
                else:
                    da_pri_padded = da_pri

                # Explicitly expand the 2D mask to a 3D mask that perfectly matches da_sec
                valid_mask_3d = valid_mask_2d.broadcast_like(da_sec)

                # Merge the data
                da_merged = xr.where(valid_mask_3d, da_pri_padded, da_sec)

                # MPAS FIX: Force the exact original dimension order
                da_merged = da_merged.transpose(*da_sec.dims)
                print(f"Case 1 (Merged spatial coverage): {var}")

            else:
                # CASE 2: Exists in primary only
                if pad_size > 0:
                    da_pri_padded = da_pri.pad(nkanthro=(0, pad_size), constant_values=0)
                    if 'nkanthro' in ds_sec.coords:
                        da_pri_padded = da_pri_padded.assign_coords(nkanthro=ds_sec['nkanthro'])
                else:
                    da_pri_padded = da_pri

                da_merged = da_pri_padded

                # MPAS FIX: Force the exact original dimension order (Time, nCells, nkanthro)
                # We use the original da_pri.dims and swap the padding appropriately
                # dim_order = [d for d in ds_pri[var].dims if d != 'nkanthro'] + ['nkanthro'] if 'nkanthro' in ds_sec.dims else ds_pri[var].dims
                # Fallback to standard MPAS order if guessing fails
                if set(['Time', 'nCells', 'nkanthro']).issubset(da_merged.dims):
                    da_merged = da_merged.transpose('Time', 'nCells', 'nkanthro')

                print(f"Case 2 (Padded primary-only variable): {var}")

            # Re-apply attributes and clear encoding
            da_merged.attrs = da_pri.attrs
            da_merged.encoding.clear()
            ds_out[var] = da_merged

    # --- CASE 3: Variables in Secondary Only ---
    for var in ds_sec.data_vars:
        if var.startswith('e_ant') and var not in ds_pri.data_vars:
            print(f"Case 3 (Copied secondary-only variable): {var}")
            da_new = ds_sec[var].copy()
            da_new.encoding.clear()

            # MPAS FIX: Force dimension order
            if set(['Time', 'nCells', 'nkanthro']).issubset(da_new.dims):
                da_new = da_new.transpose('Time', 'nCells', 'nkanthro')

            ds_out[var] = da_new

    # Ensure global attributes remain intact
    ds_out.attrs = ds_pri.attrs

    print("\n--- Saving output ---")
    temp_nc = primary_nc + ".tmp"

    # MPAS FIX: Explicitly set Time as an unlimited dimension
    unlimited = ['Time'] if 'Time' in ds_out.dims else None
    ds_out.to_netcdf(temp_nc, unlimited_dims=unlimited)

    os.replace(temp_nc, primary_nc)
    print(f"Successfully processed emissions and saved into: {primary_nc}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python chem_prep_prioritize_emissions.py <primary_file.nc> <secondary_file.nc>")
        sys.exit(1)

    primary_file = sys.argv[1]
    secondary_file = sys.argv[2]

    if not os.path.isfile(primary_file) or not os.path.isfile(secondary_file):
        print("Error: One or both of the provided NetCDF files do not exist.")
        sys.exit(1)

    prioritize_emissions(primary_file, secondary_file)
