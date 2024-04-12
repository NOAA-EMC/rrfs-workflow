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
    cdate, cycle_type, cycle_subtype, stoch, run_dir, fhrot, nthreads, restart_hrs
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
    Returns:
        Boolean
    """

    print_input_args(locals())

    # import all environment variables
    import_vars()

    #
    # -----------------------------------------------------------------------
    #
    # Create a model configuration file in the specified run directory.
    #
    # -----------------------------------------------------------------------
    #
    print_info_msg(
        f"""
        Creating a model configuration file ('{MODEL_CONFIG_FN}') in the specified
        run directory (run_dir):
          run_dir = '{run_dir}'""",
        verbose=VERBOSE,
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
    dot_quilting_dot = f".{lowercase(str(QUILTING))}."
    dot_write_dopost = f".{lowercase(str(WRITE_DOPOST))}."
    restart_interval = restart_hrs
    nsout = NSOUT

    #
    # Decide the forecast length for this cycle
    #
    if FCST_LEN_HRS_CYCLES == None:
        FCST_LEN_HRS_thiscycle = FCST_LEN_HRS
    else:
        num_fhrs = len(FCST_LEN_HRS_CYCLES)
        ihh = int(hh)
        if num_fhrs > ihh:
            FCST_LEN_HRS_thiscycle = FCST_LEN_HRS_CYCLES[ihh]
        else:
            FCST_LEN_HRS_thiscycle = FCST_LEN_HRS



    OUTPUT_FH_thiscycle = OUTPUT_FH

    if FCST_LEN_HRS_thiscycle == 18:
        OUTPUT_FH_thiscycle = OUTPUT_FH_15min
    if FCST_LEN_HRS_thiscycle == 60:
      if stoch:
        OUTPUT_FH_thiscycle = OUTPUT_FH
      else:
        OUTPUT_FH_thiscycle = OUTPUT_FH_15min

    print_info_msg(
        f"""
        The forecast length for cycle ('{hh}') is ('{FCST_LEN_HRS_thiscycle}').
        """, verbose=VERBOSE,
    )

    if cycle_type == "spinup":
        FCST_LEN_HRS_thiscycle = FCST_LEN_HRS_SPINUP
        OUTPUT_FH_thiscycle = OUTPUT_FH
        if cycle_subtype == "ensinit":
            for cyc_start in CYCL_HRS_SPINSTART:
                if hh == cyc_start:
                    FCST_LEN_HRS_thiscycle = "{:0.5f}".format(DT_ATMOS/3600)
                    nsout = 1
                    restart_interval = "0"
                    print_info_msg(f"""
         DT_ATMOS ('{DT_ATMOS}') 
         FCST_LEN_HRS_thiscycle ('{FCST_LEN_HRS_thiscycle}')
         NSOUT ('{nsout}')
         RESTART_INTERVAL ('{restart_interval}')
                    """, verbose=VERBOSE)

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
        "dt_atmos": DT_ATMOS,
        'atmos_nthreads': nthreads,
        "restart_interval": restart_interval,
        "write_dopost": dot_write_dopost,
        "quilting": dot_quilting_dot,
        "output_grid": WRTCMP_output_grid,
        "output_file": WRTCMP_output_file,
        "zstandard_level" : WRTCMP_zstandard_level,
        "ideflate": WRTCMP_ideflate,
        "quantize_mode": WRTCMP_quantize_mode,
        "quantize_nsd": WRTCMP_quantize_nsd,
        "nfhout": NFHOUT,
        "nfhmax_hf": NFHMAX_HF,
        "nfhout_hf": NFHOUT_HF,
        "nsout": nsout,
        "output_fh": OUTPUT_FH_thiscycle,
    }
    #
    # If the write-component is to be used, then specify a set of computational
    # parameters and a set of grid parameters.  The latter depends on the type
    # (coordinate system) of the grid that the write-component will be using.
    #
    if QUILTING:
        settings.update(
            {
                "write_groups": WRTCMP_write_groups,
                "write_tasks_per_group": WRTCMP_write_tasks_per_group,
                "lon1": WRTCMP_lon_lwr_left,
                "lat1": WRTCMP_lat_lwr_left,
            }
        )

        if WRTCMP_output_grid == "lambert_conformal":
            settings.update(
                {
                    "cen_lon": WRTCMP_cen_lon,
                    "cen_lat": WRTCMP_cen_lat,
                    "stdlat1": WRTCMP_stdlat1,
                    "stdlat2": WRTCMP_stdlat2,
                    "nx": WRTCMP_nx,
                    "ny": WRTCMP_ny,
                    "dx": WRTCMP_dx,
                    "dy": WRTCMP_dy,
                    "lon2": "",
                    "lat2": "",
                    "dlon": "",
                    "dlat": "",
                }
            )
        elif WRTCMP_output_grid == "rotated_latlon":
            settings.update(
                {
                    "cen_lon": WRTCMP_cen_lon,
                    "cen_lat": WRTCMP_cen_lat,
                    "lon2": WRTCMP_lon_upr_rght,
                    "lat2": WRTCMP_lat_upr_rght,
                    "dlon": WRTCMP_dlon,
                    "dlat": WRTCMP_dlat,
                    "stdlat1": "",
                    "stdlat2": "",
                    "nx": "",
                    "ny": "",
                    "dx": "",
                    "dy": "",
                }
            )
        elif WRTCMP_output_grid == "regional_latlon":
            settings.update(
                {
                    "lon2": WRTCMP_lon_upr_rght,
                    "lat2": WRTCMP_lat_upr_rght,
                    "dlon": WRTCMP_dlon,
                    "dlat": WRTCMP_dlat,
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
            The variable 'settings' specifying values to be used in the '{MODEL_CONFIG_FN}'
            file has been set as follows:\n
            settings =\n\n"""
        )
        + settings_str,
        verbose=VERBOSE,
    )
    #
    # -----------------------------------------------------------------------
    #
    # Call a python script to generate the experiment's actual MODEL_CONFIG_FN
    # file from the template file.
    #
    # -----------------------------------------------------------------------
    #
    model_config_fp = os.path.join(run_dir, MODEL_CONFIG_FN)

    try:
        fill_jinja_template(
            [
                "-q",
                "-u",
                settings_str,
                "-t",
                MODEL_CONFIG_TMPL_FP,
                "-o",
                model_config_fp,
            ]
        )
    except:
        print_err_msg_exit(
            dedent(
                f"""
                Call to python script fill_jinja_template.py to create a '{MODEL_CONFIG_FN}'
                file from a jinja2 template failed.  Parameters passed to this script are:
                  Full path to template model config file:
                    MODEL_CONFIG_TMPL_FP = '{MODEL_CONFIG_TMPL_FP}'
                  Full path to output model config file:
                    model_config_fp = '{model_config_fp}'
                  Namelist settings specified on command line:\n
                    settings =\n\n"""
            )
            + settings_str
        )
        return False

    exit()

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
    )

