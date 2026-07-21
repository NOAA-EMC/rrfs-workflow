#!/usr/bin/env python
import xarray as xr
import sys


def merge_netcdf_files(input_files, variables, output_filename):
    """
    Concatenates specific variables from multiple files along dimension 'L'.
    """
    try:
        # 1. Open the dataset
        # 'preprocess' limits the data loaded into memory to only the variables you want
        def select_vars(ds):
            return ds[variables]

        print(f"Opening {len(input_files)} files...")
        print(f"Obtaining {variables}")
        ds = xr.open_mfdataset(
            input_files,
            concat_dim="ROW",
            combine="nested",
            data_vars=list(variables),
        )

        # 3. Write to disk
        print(f"Writing concatenated data to {output_filename}...")
        ds.to_netcdf(output_filename)
        print("Success!")
        ds.close()

    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    #
    files = sys.argv[3:]
    vars_to_keep = sys.argv[2].split(',')
    output = sys.argv[1]

    merge_netcdf_files(files, vars_to_keep, output)
