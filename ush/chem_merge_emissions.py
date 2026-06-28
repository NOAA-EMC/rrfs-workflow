#!/usr/bin/env python
import sys
import xarray as xr
from functools import partial


def filter_vars(ds, variables_to_keep):
    existing_vars = [var for var in variables_to_keep if var in ds.data_vars]
    return ds[existing_vars]


def main():
    if len(sys.argv) < 4:
        return

    out_file = sys.argv[1]
    var_list = sys.argv[2].split(',')
    in_files = sys.argv[3:]

    preprocess_with_vars = partial(filter_vars, variables_to_keep=var_list)

    print(f"Opening {len(in_files)} files...")
    print(f"Targeting only: {var_list}")

    # OPTIMIZATION:
    # 1. 'data_vars=var_list' tells Xarray to ignore the other 96 variables entirely.
    # 2. 'drop_variables' handles the problematic 'VAR' dimension and its members.
    # 3. 'chunks' enables Dask, which is essential for large file performance.

    # Let's find any variable associated with 'VAR' in the first file to drop it.
    with xr.open_dataset(in_files[0]) as ds:
        vars_to_drop = [v for v in ds.variables if 'VAR' in ds[v].dims]
        if 'VAR' in ds.dims:
            vars_to_drop.append('VAR')

    ds = xr.open_mfdataset(
        in_files,
        combine='nested',
        concat_dim='file_index',
        #        data_vars=var_list,      # Ignore the other ~96 variables
        preprocess=preprocess_with_vars,
        drop_variables=vars_to_drop,
        coords="minimal",        # Don't compare coordinates across all files
        compat="override",       # Trust that lat/lon are the same
        parallel=True,           # Use multi-threading to open files
    )

    print("Computing sum...")
    # keep_attrs=True ensures you don't lose units/long_names
    running_total = ds[var_list].sum(dim='file_index', keep_attrs=True)

    print(f"Writing to {out_file}...")
    running_total.to_netcdf(out_file)

    print("Done.")


if __name__ == "__main__":
    main()
