#!/usr/bin/env python3

import os
import sys
import argparse
import unittest
from datetime import datetime
from textwrap import dedent

from python_utils import (
    import_vars,
    set_env_var,
    print_input_args,
    str_to_type,
    print_info_msg,
    print_err_msg_exit,
    lowercase,
    cfg_to_yaml_str,
    load_shell_config,
    flatten_dict,
)

from fill_jinja_template import fill_jinja_template


def create_model_configure_file(
    cdate, cycle_type, cycle_subtype, stoch, run_dir, fhrot, nthreads, restart_hrs, WRTCMP_cen_lat, WRTCMP_cen_lon
):
    """Creates a model configuration file in the specified
    run directory

    Args:
        cdate: cycle date
        cycle_type: type of cycle
        cycle_subtype: sub-type of cycle
        stoch: logical indicating it is an ensemble forecast
        run_dir: run directory
        fhrot: forecast hour at restart
        nthreads: omp_num_threads
        restart_hrs: restart hours
        cen_lat: center latitude of grid
        cen_lon: center longitude of grid
    Returns:
        Boolean
    """

    print_input_args(locals())

    # import all environment variables
    import_vars()

    # Bind dynamically imported variables to local scope
    model_config_fn = MODEL_CONFIG_FN  # noqa: F821
    model_config_tmpl_fp = MODEL_CONFIG_TMPL_FP  # noqa: F821
    verbose = VERBOSE  # noqa: F821
    quilting = QUILTING  # noqa: F821
    use_saved_routehandles = USE_SAVED_ROUTEHANDLES  # noqa: F821
    write_dopost = WRITE_DOPOST  # noqa: F821
    nsout_var = NSOUT  # noqa: F821
    fcst_len_hrs_cycles = FCST_LEN_HRS_CYCLES  # noqa: F821
    fcst_len_hrs = FCST_LEN_HRS  # noqa: F821
    output_fh_15min = OUTPUT_FH_15min  # noqa: F821
    output_fh = OUTPUT_FH  # noqa: F821
    fcst_len_hrs_spinup = FCST_LEN_HRS_SPINUP  # noqa: F821
    cycl_hrs_spinstart = CYCL_HRS_SPINSTART  # noqa: F821
    dt_atmos = DT_ATMOS  # noqa: F821
    wrtcmp_output_grid = WRTCMP_output_grid  # noqa: F821
    wrtcmp_output_file = WRTCMP_output_file  # noqa: F821
    wrtcmp_zstandard_level = WRTCMP_zstandard_level  # noqa: F821
    wrtcmp_ideflate = WRTCMP_ideflate  # noqa: F821
    wrtcmp_quantize_mode = WRTCMP_quantize_mode  # noqa: F821
    wrtcmp_quantize_nsd = WRTCMP_quantize_nsd  # noqa: F821
    nfhout = NFHOUT  # noqa: F821
    nfhmax_hf = NFHMAX_HF  # noqa: F821
    nfhout_hf = NFHOUT_HF  # noqa: F821
    wrtcmp_write_groups = WRTCMP_write_groups  # noqa: F821
    wrtcmp_write_tasks_per_group = WRTCMP_write_tasks_per_group  # noqa: F821
    wrtcmp_lon_lwr_left = WRTCMP_lon_lwr_left  # noqa: F821
    wrtcmp_lat_lwr_left = WRTCMP_lat_lwr_left  # noqa: F821
    wrtcmp_stdlat1 = WRTCMP_stdlat1  # noqa: F821
    wrtcmp_stdlat2 = WRTCMP_stdlat2  # noqa: F821
    wrtcmp_nx = WRTCMP_nx  # noqa: F821
    wrtcmp_ny = WRTCMP_ny  # noqa: F821
    wrtcmp_dx = WRTCMP_dx  # noqa: F821
    wrtcmp_dy = WRTCMP_dy  # noqa: F821
    wrtcmp_lon_upr_rght = WRTCMP_lon_upr_rght  # noqa: F821
    wrtcmp_lat_upr_rght = WRTCMP_lat_upr_rght  # noqa: F821
    wrtcmp_dlon = WRTCMP_dlon  # noqa: F821
    wrtcmp_dlat = WRTCMP_dlat  # noqa: F821

    #
    # -----------------------------------------------------------------------
    #
    # Create a model configuration file in the specified run directory.
    #
    # -----------------------------------------------------------------------
    #
    print_info_msg(
        f"""
        Creating a model configuration file ('{model_config_fn}') in the specified
        run directory (run_dir):
          run_dir = '{run_dir}'""",
        verbose=verbose,
    )
    #
    # Extract from cdate the starting year, month, day, and hour of the forecast.
    #
    yyyy = cdate.year
    mm = cdate.month
    dd = cdate.day
    hh = cdate.hour
    #
    # Set parameters in the model configure file.
    #
    dot_quilting_dot = f".{lowercase(str(quilting))}."
    dot_usesavedroutehandles_dot = f".{lowercase(str(use_saved_routehandles))}."
    dot_write_dopost = f".{lowercase(str(write_dopost))}."
    restart_interval = restart_hrs
    nsout = nsout_var

    #
    # Decide the forecast length for this cycle
    #
    if fcst_len_hrs_cycles is None:
        FCST_LEN_HRS_thiscycle = fcst_len_hrs
    else:
        num_fhrs = len(fcst_len_hrs_cycles)
        ihh = int(hh)
        if num_fhrs > ihh:
            FCST_LEN_HRS_thiscycle = fcst_len_hrs_cycles[ihh]
        else:
            FCST_LEN_HRS_thiscycle = fcst_len_hrs

    # The deterministic and ensemble production forecasts are posted every 15 minutes, and the
    # post tasks are named for those files (dynf001-00-00.nc and so on), which the model writes
    # only when it is given the sub-hourly output list. Forecast lengths of 18, 60 and 84 hours
    # select the same forecasts in operations, but match none of them once the lengths are
    # shortened, and the model then writes hourly files that the post cannot open. The EnKF and
    # the spin-up cycle keep the plain list: neither is posted, and the EnKF has 30 members.
    if os.environ.get("WGF", "") in ("det", "ensf") and not stoch and cycle_type != "spinup":
        OUTPUT_FH_thiscycle = output_fh_15min
    else:
        OUTPUT_FH_thiscycle = output_fh

    print_info_msg(
        f"""
        The forecast length for cycle ('{hh}') is ('{FCST_LEN_HRS_thiscycle}').
        """,
        verbose=verbose,
    )

    if cycle_type == "spinup":
        FCST_LEN_HRS_thiscycle = fcst_len_hrs_spinup
        OUTPUT_FH_thiscycle = output_fh
        if cycle_subtype == "ensinit":
            for cyc_start in cycl_hrs_spinstart:
                if hh == cyc_start:
                    FCST_LEN_HRS_thiscycle = "{:0.5f}".format(dt_atmos / 3600)
                    nsout = 1
                    restart_interval = "0"
                    print_info_msg(
                        f"""
         DT_ATMOS ('{dt_atmos}') 
         FCST_LEN_HRS_thiscycle ('{FCST_LEN_HRS_thiscycle}')
         NSOUT ('{nsout}')
         RESTART_INTERVAL ('{restart_interval}')
                        """,
                        verbose=verbose,
                    )

    #
    # -----------------------------------------------------------------------
    #
    # Create a multiline variable that consists of a yaml-compliant string
    # specifying the values that the jinja variables in the template
    # model_configure file should be set to.
    #
    # -----------------------------------------------------------------------
    #
    settings = {
        "start_year": yyyy,
        "start_month": mm,
        "start_day": dd,
        "start_hour": hh,
        "nhours_fcst": FCST_LEN_HRS_thiscycle,
        "fhrot": fhrot,
        "dt_atmos": dt_atmos,
        "atmos_nthreads": nthreads,
        "restart_interval": restart_interval,
        "write_dopost": dot_write_dopost,
        "quilting": dot_quilting_dot,
        "use_saved_routehandles": dot_usesavedroutehandles_dot,
        "output_grid": wrtcmp_output_grid,
        "output_file": wrtcmp_output_file,
        "zstandard_level": wrtcmp_zstandard_level,
        "ideflate": wrtcmp_ideflate,
        "quantize_mode": wrtcmp_quantize_mode,
        "quantize_nsd": wrtcmp_quantize_nsd,
        "nfhout": nfhout,
        "nfhmax_hf": nfhmax_hf,
        "nfhout_hf": nfhout_hf,
        "nsout": nsout,
        "output_fh": OUTPUT_FH_thiscycle,
    }
    #
    # If the write-component is to be used, then specify a set of computational
    # parameters and a set of grid parameters.  The latter depends on the type
    # (coordinate system) of the grid that the write-component will be using.
    #
    if quilting:
        settings.update(
            {
                "write_groups": wrtcmp_write_groups,
                "write_tasks_per_group": wrtcmp_write_tasks_per_group,
                "lon1": wrtcmp_lon_lwr_left,
                "lat1": wrtcmp_lat_lwr_left,
            }
        )

        if wrtcmp_output_grid == "lambert_conformal":
            settings.update(
                {
                    "cen_lon": WRTCMP_cen_lon,
                    "cen_lat": WRTCMP_cen_lat,
                    "stdlat1": wrtcmp_stdlat1,
                    "stdlat2": wrtcmp_stdlat2,
                    "nx": wrtcmp_nx,
                    "ny": wrtcmp_ny,
                    "dx": wrtcmp_dx,
                    "dy": wrtcmp_dy,
                    "lon2": "",
                    "lat2": "",
                    "dlon": "",
                    "dlat": "",
                }
            )
        elif wrtcmp_output_grid == "rotated_latlon":
            settings.update(
                {
                    "cen_lon": WRTCMP_cen_lon,
                    "cen_lat": WRTCMP_cen_lat,
                    "lon2": wrtcmp_lon_upr_rght,
                    "lat2": wrtcmp_lat_upr_rght,
                    "dlon": wrtcmp_dlon,
                    "dlat": wrtcmp_dlat,
                    "stdlat1": "",
                    "stdlat2": "",
                    "nx": "",
                    "ny": "",
                    "dx": "",
                    "dy": "",
                }
            )
        elif wrtcmp_output_grid == "regional_latlon":
            settings.update(
                {
                    "lon2": wrtcmp_lon_upr_rght,
                    "lat2": wrtcmp_lat_upr_rght,
                    "dlon": wrtcmp_dlon,
                    "dlat": wrtcmp_dlat,
                    "cen_lon": "",
                    "cen_lat": "",
                    "stdlat1": "",
                    "stdlat2": "",
                    "nx": "",
                    "ny": "",
                    "dx": "",
                    "dy": "",
                }
            )

    settings_str = cfg_to_yaml_str(settings)

    print_info_msg(
        dedent(
            f"""
            The variable 'settings' specifying values to be used in the '{model_config_fn}'
            file has been set as follows:\n
            settings =\n\n"""
        )
        + settings_str,
        verbose=verbose,
    )
    #
    # -----------------------------------------------------------------------
    #
    # Call a python script to generate the experiment's actual MODEL_CONFIG_FN
    # file from the template file.
    #
    # -----------------------------------------------------------------------
    #
    model_config_fp = os.path.join(run_dir, model_config_fn)

    try:
        fill_jinja_template(
            [
                "-q",
                "-u",
                settings_str,
                "-t",
                model_config_tmpl_fp,
                "-o",
                model_config_fp,
            ]
        )
    except:
        print_err_msg_exit(
            dedent(
                f"""
                Call to python script fill_jinja_template.py to create a '{model_config_fn}'
                file from a jinja2 template failed.  Parameters passed to this script are:
                  Full path to template model config file:
                    MODEL_CONFIG_TMPL_FP = '{model_config_tmpl_fp}'
                  Full path to output model config file:
                    model_config_fp = '{model_config_fp}'
                  Namelist settings specified on command line:\n
                    settings =\n\n"""
            )
            + settings_str
        )
        return False

    sys.exit(0)

    return True


def parse_args(argv):
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Creates model configuration file.")

    parser.add_argument(
        "-d", 
        "--run-dir", 
        dest="run_dir", 
        required=True, 
        help="Run directory."
    )

    parser.add_argument(
        "-c",
        "--cdate",
        dest="cdate",
        required=True,
        help="Date string in YYYYMMDD format.",
    )

    parser.add_argument(
        "-t",
        "--cycle_type",
        dest="cycle_type",
        required=True,
        help="Type of cycle.",
    )

    parser.add_argument(
        "-s",
        "--cycle_subtype",
        dest="cycle_subtype",
        required=True,
        help="Sub-type of cycle.",
    )

    parser.add_argument(
        "-e",
        "--stoch",
        dest="stoch",
        required=True,
        help="Logical for stochastic perturbations.",
    )

    parser.add_argument(
        "-f",
        "--fhrot",
        dest="fhrot",
        required=True,
        help="Forecast hour at restart.",
    )

    parser.add_argument(
        "-n",
        "--nthreads",
        dest="nthreads",
        required=True,
        help="OMP_NUM_THREADS.",
    )

    parser.add_argument(
        "-r",
        "--restart_hrs",
        dest="restart_hrs",
        required=True,
        help="Restart hours.",
    )

    parser.add_argument(
        "--cen_lat",
        dest="cen_lat",
        required=True,
        help="Center latitude of grid.",
    )

    parser.add_argument(
        "--cen_lon",
        dest="cen_lon",
        required=True,
        help="Center longitude of grid.",
    )

    parser.add_argument(
        "-p",
        "--path-to-defns",
        dest="path_to_defns",
        required=True,
        help="Path to var_defns file.",
    )

    return parser.parse_args(argv)


if __name__ == "__main__":
    args = parse_args(sys.argv[1:])
    cfg = load_shell_config(args.path_to_defns)
    cfg = flatten_dict(cfg)
    import_vars(dictionary=cfg)
    create_model_configure_file(
        run_dir=args.run_dir,
        cdate=str_to_type(args.cdate),
        cycle_type=str_to_type(args.cycle_type),
        stoch=str_to_type(args.stoch),
        cycle_subtype=str_to_type(args.cycle_subtype),
        fhrot=str_to_type(args.fhrot),
        nthreads=str_to_type(args.nthreads),
        restart_hrs=str_to_type(args.restart_hrs),
        WRTCMP_cen_lat=str_to_type(args.cen_lat),
        WRTCMP_cen_lon=str_to_type(args.cen_lon),
    )