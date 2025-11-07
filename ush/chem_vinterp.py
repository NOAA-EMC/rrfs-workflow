import numpy as np
import xarray as xr
from scipy.interpolate import interp1d
import argparse


def log_interpolate_netcdf(input_file, template_file, output_file, data_var_name, old_kemit_coord_name, new_kemit_coord_name):
    """
    Log-interpolates a 3D NetCDF dataset along a specified coordinate, using
    the coordinates from a template NetCDF file.

    Parameters:
    input_file (str): Path to the input NetCDF file containing the data.
    template_file (str): Path to the NetCDF file containing the target kemit coordinate.
    output_file (str): Path for the output NetCDF file.
    data_var_name (str): The name of the data variable in the NetCDF files.
    old_kemit_coord_name (str): The name of the old kemit coordinate variable.
    new_kemit_coord_name (str): The name of the new kemit coordinate variable.
    """
    try:
        # Open both input NetCDF files using xarray
        with xr.open_dataset(input_file) as ds_in, xr.open_dataset(template_file) as ds_template:
            # Extract data and coordinates
            data_3d = ds_in[data_var_name].values
            kemit_old = ds_in[old_kemit_coord_name].values
            kemit_new = ds_template[new_kemit_coord_name].values

            # Ensure data and kemit values are positive for log interpolation
            if np.any(kemit_old <= 0) or np.any(kemit_new <= 0):
                raise ValueError("kemit values must be positive for log interpolation.")
            if np.any(data_3d <= 0):
                print("Warning: Input data contains non-positive values. Adding a small epsilon.")
                epsilon = np.finfo(float).eps
                data_3d = data_3d + epsilon

            # --- Log-interpolation logic ---
            log_data_3d = np.log10(data_3d)
            log_kemit_old = np.log10(kemit_old)
            log_kemit_new = np.log10(kemit_new)

            interpolator = interp1d(log_kemit_old, log_data_3d, axis=2, kind='linear',
                                    bounds_error=False, fill_value='extrapolate')

            log_data_interp = interpolator(log_kemit_new)
            data_interp = np.power(10, log_data_interp)

            # --- Write the new NetCDF file ---
            # Use the input dataset as a template for the output
            ds_out = ds_in.copy(deep=False)

            # Replace the kemit coordinate with the new values
            ds_out[new_kemit_coord_name] = kemit_new

            # Create a new DataArray for the interpolated data with updated coordinates
            da_interp = xr.DataArray(
                data_interp,
                coords=ds_out[data_var_name].coords,
                dims=ds_out[data_var_name].dims,
                name=data_var_name,
                attrs=ds_in[data_var_name].attrs
            )
            ds_out[data_var_name] = da_interp

            # Save the new Dataset to a NetCDF file
            ds_out.to_netcdf(output_file)
            print(f"Interpolation successful. Output saved to {output_file}")

    except FileNotFoundError as e:
        print(f"Error: A file was not found: {e}")
    except KeyError as e:
        print(f"Error: Missing variable or coordinate name in input file. {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Log-interpolate 3D NetCDF data along the kemit dimension using a template file.")
    parser.add_argument("input_file", help="Path to the input NetCDF file.")
    parser.add_argument("template_file", help="Path to the NetCDF file containing the target kemit dimension.")
    parser.add_argument("output_file", help="Path for the output NetCDF file.")
    parser.add_argument("data_var_name", help="Name of the data variable to interpolate.")
    parser.add_argument("old_kemit_coord_name", help="Name of the old kemit coordinate variable.")
    parser.add_argument("new_kemit_coord_name", help="Name of the new kemit coordinate variable.")

    args = parser.parse_args()

    log_interpolate_netcdf(
        args.input_file,
        args.template_file,
        args.output_file,
        args.data_var_name,
        args.old_kemit_coord_name,
        args.new_kemit_coord_name,
    )
