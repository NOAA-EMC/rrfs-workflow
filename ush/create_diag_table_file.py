#!/usr/bin/env python3

import os
import sys
import argparse
import unittest
from textwrap import dedent

from python_utils import (
    import_vars,
    set_env_var,
    print_input_args,
    print_info_msg,
    print_err_msg_exit,
    cfg_to_yaml_str,
    load_shell_config,
    flatten_dict,
)

from fill_jinja_template import fill_jinja_template


def create_diag_table_file(run_dir):
    """Creates a diagnostic table file for each cycle to be run

    Args:
        run_dir: run directory
    Returns:
        Boolean
    """

    print_input_args(locals())

    # import all environment variables
    import_vars()

    # create a diagnostic table file within the specified run directory
    print_info_msg(
        f"""
        Creating a diagnostics table file ('{DIAG_TABLE_FN}') in the specified
        run directory...

          run_dir = '{run_dir}'""",
        verbose=VERBOSE,
    )

    diag_table_fp = os.path.join(run_dir, DIAG_TABLE_FN)

    print_info_msg(
        f"""
        Using the template diagnostics table file:

            diag_table_tmpl_fp = {DIAG_TABLE_TMPL_FP}

        to create:

            diag_table_fp = '{diag_table_fp}'""",
        verbose=VERBOSE,
    )

    settings = {"starttime": CDATE, "cres": CRES}
    settings_str = cfg_to_yaml_str(settings)

    print_info_msg(
        dedent(
            f"""
            The variable 'settings' specifying values to be used in the '{DIAG_TABLE_FN}'
            file has been set as follows:\n
            settings =\n\n"""
        )
        + settings_str,
        verbose=VERBOSE,
    )

    # call fill jinja
    try:
        fill_jinja_template(
            ["-q", "-u", settings_str, "-t", DIAG_TABLE_TMPL_FP, "-o", diag_table_fp]
        )
    except:
        print_err_msg_exit(
            dedent(
                f"""
                Call to python script fill_jinja_template.py to create a '{DIAG_TABLE_FN}'
                file from a jinja2 template failed.  Parameters passed to this script are:
                  Full path to template diag table file:
                    DIAG_TABLE_TMPL_FP = '{DIAG_TABLE_TMPL_FP}'
                  Full path to output diag table file:
                    diag_table_fp = '{diag_table_fp}'
                  Namelist settings specified on command line:\n
                    settings =\n\n"""
            )
            + settings_str
        )
        return False
    return True


def parse_args(argv):
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Creates diagnostic table file.")

    parser.add_argument(
        "-r", "--run-dir", dest="run_dir", required=True, help="Run directory."
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
    create_diag_table_file(args.run_dir)

