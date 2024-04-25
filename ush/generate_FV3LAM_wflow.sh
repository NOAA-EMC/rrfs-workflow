#!/bin/bash
#
#-----------------------------------------------------------------------
#
# This file defines and then calls a function that sets up a forecast
# experiment and creates a workflow (according to the parameters speci-
# fied in the configuration file; see instructions).
#
#-----------------------------------------------------------------------
#
function generate_FV3LAM_wflow() {
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
local scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
local scrfunc_fn=$( basename "${scrfunc_fp}" )
local scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Get the name of this function.
#
#-----------------------------------------------------------------------
#
local func_name="${FUNCNAME[0]}"
#
#-----------------------------------------------------------------------
#
# Set directories.
#
#-----------------------------------------------------------------------
#
USHdir="${scrfunc_dir}"
#
#-----------------------------------------------------------------------
#
# Source bash utility functions and other necessary files.
#
#-----------------------------------------------------------------------
#
. $USHdir/source_util_funcs.sh
. $USHdir/set_FV3nml_sfc_climo_filenames.sh
#
#-----------------------------------------------------------------------
#
# Run python checks
#
#-----------------------------------------------------------------------
#

# This line will return two numbers: the python major and minor versions
pyversion=($(/usr/bin/env python3 -c 'import platform; major, minor, patch = platform.python_version_tuple(); print(major); print(minor)'))

#Now, set an error check variable so that we can print all python errors rather than just the first
pyerrors=0

# Check that the call to python3 returned no errors, then check if the 
# python3 minor version is 6 or higher
if [[ -z "$pyversion" ]];then
  print_info_msg "\

  Error: python3 not found"
  pyerrors=$((pyerrors+1))
else
  if [[ ${#pyversion[@]} -lt 2 ]]; then
    print_info_msg "\

  Error retrieving python3 version"
    pyerrors=$((pyerrors+1))
  elif [[ ${pyversion[1]} -lt 6 ]]; then
    print_info_msg "\

  Error: python version must be 3.6 or higher
  python version: ${pyversion[*]}"
    pyerrors=$((pyerrors+1))
  fi
fi

#Next, check for the non-standard python packages: jinja2, yaml, and f90nml
pkgs=(jinja2 yaml f90nml)
for pkg in ${pkgs[@]}  ; do
  if ! /usr/bin/env python3 -c "import ${pkg}" &> /dev/null; then
  print_info_msg "\

  Error: python module ${pkg} not available"
  pyerrors=$((pyerrors+1))
  fi
done

#Finally, check if the number of errors is >0, and if so exit with helpful message
if [ $pyerrors -gt 0 ];then
  print_err_msg_exit "Errors found: check your python environment"
fi

#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u -x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
# check whether the .agent link is initialized
# if not, run Init.sh (otherwise, the workflow generation will fail)
#-----------------------------------------------------------------------
#
if [[ ! -L ${USHdir}/../fix/.agent || ! -e ${USHdir}/../fix/.agent ]] \
  && [ -e ${USHdir}/Init.sh ]; then
    ${USHdir}/Init.sh
fi
#
#-----------------------------------------------------------------------
#
# Source the file that defines and then calls the setup function.  The
# setup function in turn first sources the default configuration file
# (which contains default values for the experiment/workflow parameters)
# and then sources the user-specified configuration file (which contains
# user-specified values for a subset of the experiment/workflow parame-
# ters that override their default values).
#
#-----------------------------------------------------------------------
#
. $USHdir/setup.sh
#
#-----------------------------------------------------------------------
#
# Set the full path to the experiment's rocoto workflow xml file.  This
# file will be placed at the top level of the experiment directory and
# then used by rocoto to run the workflow.
#
#-----------------------------------------------------------------------
#
WFLOW_XML_FP="$EXPTDIR/${WFLOW_XML_FN}"
#
#-----------------------------------------------------------------------
#
# Create a multiline variable that consists of a yaml-compliant string
# specifying the values that the jinja variables in the template rocoto
# XML should be set to.  These values are set either in the user-specified
# workflow configuration file (EXPT_CONFIG_FN) or in the setup.sh script
# sourced above.  Then call the python script that generates the XML.
#
#-----------------------------------------------------------------------
#
ensmem_indx_name="\"\""
uscore_ensmem_name="\"\""
slash_ensmem_subdir="\"\""
if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
  ensmem_indx_name="mem"
  uscore_ensmem_name="_mem#${ensmem_indx_name}#"
  slash_ensmem_subdir="/mem#${ensmem_indx_name}#"
fi

settings="\
#
# Parameters needed by the job scheduler.
#
  'account': $ACCOUNT
  'service_account': ${SERVICE_ACCOUNT:-$ACCOUNT}
  'hpss_account': ${HPSS_ACCOUNT:-$SERVICE_ACCOUNT}
  'reservation': $RESERVATION
  'reservation_post': $RESERVATION_POST
  'sched': $SCHED
  'partition_default': ${PARTITION_DEFAULT}
  'queue_default': ${QUEUE_DEFAULT}
  'partition_hpss': ${PARTITION_HPSS}
  'queue_hpss': ${QUEUE_HPSS}
  'partition_sfc_climo': ${PARTITION_SFC_CLIMO}
  'partition_fcst': ${PARTITION_FCST}
  'queue_fcst': ${QUEUE_FCST}
  'partition_graphics': ${PARTITION_GRAPHICS}
  'queue_graphics': ${QUEUE_GRAPHICS}
  'machine': ${MACHINE}
  'partition_analysis': ${PARTITION_ANALYSIS}
  'queue_analysis': ${QUEUE_ANALYSIS}
  'partition_prdgen': ${PARTITION_PRDGEN}
  'queue_prdgen': ${QUEUE_PRDGEN}
  'partition_post': ${PARTITION_POST}
  'queue_post': ${QUEUE_POST}
#
# Workflow task names.
#
  'make_grid_tn': ${MAKE_GRID_TN}
  'make_orog_tn': ${MAKE_OROG_TN}
  'make_sfc_climo_tn': ${MAKE_SFC_CLIMO_TN}
  'get_extrn_ics_tn': ${GET_EXTRN_ICS_TN}
  'get_extrn_lbcs_tn': ${GET_EXTRN_LBCS_TN}
  'get_extrn_lbcs_long_tn': ${GET_EXTRN_LBCS_LONG_TN}
  'get_gefs_lbcs_tn': ${GET_GEFS_LBCS_TN}
  'make_ics_tn': ${MAKE_ICS_TN}
  'blend_ics_tn': ${BLEND_ICS_TN}
  'make_lbcs_tn': ${MAKE_LBCS_TN}
  'add_aerosol_tn': ${ADD_AEROSOL_TN}
  'run_fcst_tn': ${RUN_FCST_TN}
  'run_post_tn': ${RUN_POST_TN}
  'run_prdgen_tn': ${RUN_PRDGEN_TN}
  'analysis_gsi': ${ANALYSIS_GSI_TN}
  'analysis_gsidiag': ${ANALYSIS_GSIDIAG_TN}
  'analysis_sd_gsi': ${ANALYSIS_SD_GSI_TN}
  'post_anal': ${POSTANAL_TN}
  'observer_gsi_ensmean': ${OBSERVER_GSI_ENSMEAN_TN}
  'observer_gsi': ${OBSERVER_GSI_TN}
  'prep_start': ${PREP_START_TN}
  'prep_cyc_spinup': ${PREP_CYC_SPINUP_TN}
  'prep_cyc_prod': ${PREP_CYC_PROD_TN}
  'prep_cyc_ensmean': ${PREP_CYC_ENSMEAN_TN}
  'prep_cyc': ${PREP_CYC_TN}
  'calc_ensmean': ${CALC_ENSMEAN_TN}
  'process_radarref': ${PROCESS_RADAR_REF_TN}
  'process_lightning': ${PROCESS_LIGHTNING_TN}
  'process_glmfed': ${PROCESS_GLMFED_TN}
  'process_bufr': ${PROCESS_BUFR_TN}
  'process_smoke': ${PROCESS_SMOKE_TN}
  'process_pm': ${PROCESS_PM_TN}
  'radar_refl2tten': ${RADAR_REFL2TTEN_TN}
  'cldanl_nonvar': ${CLDANL_NONVAR_TN}
  'run_bufrsnd_tn': ${RUN_BUFRSND_TN}
  'save_restart': ${SAVE_RESTART_TN}
  'save_da_output': ${SAVE_DA_OUTPUT_TN}
  'tag': ${TAG}
  'net': ${NET}
  'run': ${RUN}
  'jedi_envar_ioda': ${JEDI_ENVAR_IODA_TN}
  'ioda_prepbufr': ${IODA_PREPBUFR_TN}
#
# Number of nodes to use for each task.
#
  'nnodes_make_grid': ${NNODES_MAKE_GRID}
  'nnodes_make_orog': ${NNODES_MAKE_OROG}
  'nnodes_make_sfc_climo': ${NNODES_MAKE_SFC_CLIMO}
  'nnodes_get_extrn_ics': ${NNODES_GET_EXTRN_ICS}
  'nnodes_get_extrn_lbcs': ${NNODES_GET_EXTRN_LBCS}
  'nnodes_make_ics': ${NNODES_MAKE_ICS}
  'nnodes_blend_ics': ${NNODES_BLEND_ICS}
  'nnodes_make_lbcs': ${NNODES_MAKE_LBCS}
  'nnodes_run_prepstart': ${NNODES_RUN_PREPSTART}
  'nnodes_run_fcst': ${NNODES_RUN_FCST}
  'nnodes_run_analysis': ${NNODES_RUN_ANALYSIS}
  'nnodes_run_gsidiag': ${NNODES_RUN_GSIDIAG}
  'nnodes_run_postanal': ${NNODES_RUN_POSTANAL}
  'nnodes_run_enkf': ${NNODES_RUN_ENKF}
  'nnodes_run_recenter': ${NNODES_RUN_RECENTER}
  'nnodes_run_post': ${NNODES_RUN_POST}
  'nnodes_run_prdgen': ${NNODES_RUN_PRDGEN}
  'nnodes_proc_radar': ${NNODES_PROC_RADAR}
  'nnodes_proc_lightning': ${NNODES_PROC_LIGHTNING}
  'nnodes_proc_glmfed': ${NNODES_PROC_GLMFED}
  'nnodes_proc_bufr': ${NNODES_PROC_BUFR}
  'nnodes_proc_smoke': ${NNODES_PROC_SMOKE}
  'nnodes_proc_pm': ${NNODES_PROC_PM}
  'nnodes_run_ref2tten': ${NNODES_RUN_REF2TTEN}
  'nnodes_run_nonvarcldanl': ${NNODES_RUN_NONVARCLDANL}
  'nnodes_run_graphics': ${NNODES_RUN_GRAPHICS}
  'nnodes_run_enspost': ${NNODES_RUN_ENSPOST}
  'nnodes_run_bufrsnd': ${NNODES_RUN_BUFRSND}
  'nnodes_save_restart': ${NNODES_SAVE_RESTART}
  'nnodes_run_jedienvar_ioda': ${NNODES_RUN_JEDIENVAR_IODA}
  'nnodes_run_ioda_prepbufr': ${NNODES_RUN_IODA_PREPBUFR}
  'nnodes_add_aerosol': ${NNODES_ADD_AEROSOL}
#
# Number of cores used for a task
#
  'ncores_run_fcst': ${PE_MEMBER01}
  'native_run_fcst': ${NATIVE_RUN_FCST}
  'ncores_run_analysis': ${NCORES_RUN_ANALYSIS}
  'ncores_run_observer': ${NCORES_RUN_OBSERVER}
  'native_run_analysis': ${NATIVE_RUN_ANALYSIS}
  'ncores_run_enkf': ${NCORES_RUN_ENKF}
  'native_run_enkf': ${NATIVE_RUN_ENKF}
#
# Number of logical processes per node for each task.  If running without
# threading, this is equal to the number of MPI processes per node.
#
  'ppn_make_grid': ${PPN_MAKE_GRID}
  'ppn_make_orog': ${PPN_MAKE_OROG}
  'ppn_make_sfc_climo': ${PPN_MAKE_SFC_CLIMO}
  'ppn_get_extrn_ics': ${PPN_GET_EXTRN_ICS}
  'ppn_get_extrn_lbcs': ${PPN_GET_EXTRN_LBCS}
  'ppn_make_ics': ${PPN_MAKE_ICS}
  'ppn_blend_ics': ${PPN_BLEND_ICS}
  'ppn_make_lbcs': ${PPN_MAKE_LBCS}
  'ppn_run_prepstart': ${PPN_RUN_PREPSTART}
  'ppn_run_fcst': ${PPN_RUN_FCST}
  'ppn_run_analysis': ${PPN_RUN_ANALYSIS}
  'ppn_run_gsidiag': ${PPN_RUN_GSIDIAG}
  'ppn_run_postanal': ${PPN_RUN_POSTANAL}
  'ppn_run_enkf': ${PPN_RUN_ENKF}
  'ppn_run_recenter': ${PPN_RUN_RECENTER}
  'ppn_run_post': ${PPN_RUN_POST}
  'ppn_run_prdgen': ${PPN_RUN_PRDGEN}
  'ppn_proc_radar': ${PPN_PROC_RADAR}
  'ppn_proc_lightning': ${PPN_PROC_LIGHTNING}
  'ppn_proc_glmfed': ${PPN_PROC_GLMFED}
  'ppn_proc_bufr': ${PPN_PROC_BUFR}
  'ppn_proc_smoke': ${PPN_PROC_SMOKE}
  'ppn_proc_pm': ${PPN_PROC_PM}
  'ppn_run_ref2tten': ${PPN_RUN_REF2TTEN}
  'ppn_run_nonvarcldanl': ${PPN_RUN_NONVARCLDANL}
  'ppn_run_graphics': ${PPN_RUN_GRAPHICS}
  'ppn_run_enspost': ${PPN_RUN_ENSPOST}
  'ppn_run_bufrsnd': ${PPN_RUN_BUFRSND}
  'ppn_save_restart': ${PPN_SAVE_RESTART}
  'ppn_run_jedienvar_ioda': ${PPN_RUN_JEDIENVAR_IODA}
  'ppn_run_ioda_prepbufr': ${PPN_RUN_IODA_PREPBUFR}
  'ppn_add_aerosol': ${PPN_ADD_AEROSOL}
#
  'tpp_make_ics': ${TPP_MAKE_ICS}
  'tpp_make_lbcs': ${TPP_MAKE_LBCS}
  'tpp_run_analysis': ${TPP_RUN_ANALYSIS}
  'tpp_run_enkf': ${TPP_RUN_ENKF}
  'tpp_run_fcst': ${TPP_RUN_FCST}
  'tpp_run_post': ${TPP_RUN_POST}
  'tpp_run_bufrsnd': ${TPP_RUN_BUFRSND}
#
# Maximum wallclock time for each task.
#
  'wtime_make_grid': ${WTIME_MAKE_GRID}
  'wtime_make_orog': ${WTIME_MAKE_OROG}
  'wtime_make_sfc_climo': ${WTIME_MAKE_SFC_CLIMO}
  'wtime_get_extrn_ics': ${WTIME_GET_EXTRN_ICS}
  'wtime_get_extrn_lbcs': ${WTIME_GET_EXTRN_LBCS}
  'wtime_make_ics': ${WTIME_MAKE_ICS}
  'wtime_blend_ics': ${WTIME_BLEND_ICS}
  'wtime_make_lbcs': ${WTIME_MAKE_LBCS}
  'wtime_run_prepstart': ${WTIME_RUN_PREPSTART}
  'wtime_run_prepstart_ensmean': ${WTIME_RUN_PREPSTART_ENSMEAN}
  'wtime_run_fcst': ${WTIME_RUN_FCST}
  'wtime_run_fcst_long': ${WTIME_RUN_FCST_LONG}
  'wtime_run_fcst_spinup': ${WTIME_RUN_FCST_SPINUP}
  'wtime_run_analysis': ${WTIME_RUN_ANALYSIS}
  'wtime_run_gsidiag': ${WTIME_RUN_GSIDIAG}
  'wtime_run_postanal': ${WTIME_RUN_POSTANAL}
  'wtime_run_enkf': ${WTIME_RUN_ENKF}
  'wtime_run_recenter': ${WTIME_RUN_RECENTER}
  'wtime_run_post': ${WTIME_RUN_POST}
  'wtime_run_enspost': ${WTIME_RUN_ENSPOST}
  'wtime_run_prdgen': ${WTIME_RUN_PRDGEN}
  'wtime_proc_radar': ${WTIME_PROC_RADAR}
  'wtime_proc_lightning': ${WTIME_PROC_LIGHTNING}
  'wtime_proc_glmfed': ${WTIME_PROC_GLMFED}
  'wtime_proc_bufr': ${WTIME_PROC_BUFR}
  'wtime_proc_smoke': ${WTIME_PROC_SMOKE}
  'wtime_proc_pm': ${WTIME_PROC_PM}
  'wtime_run_ref2tten': ${WTIME_RUN_REF2TTEN}
  'wtime_run_nonvarcldanl': ${WTIME_RUN_NONVARCLDANL}
  'wtime_run_bufrsnd': ${WTIME_RUN_BUFRSND}
  'wtime_save_restart': ${WTIME_SAVE_RESTART}
  'wtime_run_jedienvar_ioda': ${WTIME_RUN_JEDIENVAR_IODA}
  'wtime_run_ioda_prepbufr': ${WTIME_RUN_IODA_PREPBUFR}
  'wtime_add_aerosol': ${WTIME_ADD_AEROSOL}
#
# start time for each task.
#
  'start_time_spinup': ${START_TIME_SPINUP}
  'start_time_prod': ${START_TIME_PROD}
  'start_time_conventional_spinup': ${START_TIME_CONVENTIONAL_SPINUP}
  'start_time_blending': ${START_TIME_BLENDING}
  'start_time_late_analysis': ${START_TIME_LATE_ANALYSIS}
  'start_time_conventional': ${START_TIME_CONVENTIONAL}
  'start_time_ioda_prepbufr': ${START_TIME_IODA_PREPBUFR}
  'start_time_nsslmosiac': ${START_TIME_NSSLMOSIAC}
  'start_time_lightningnc': ${START_TIME_LIGHTNINGNC}
  'start_time_proc_glmfed': ${START_TIME_GLMFED}
  'start_time_procsmoke': ${START_TIME_PROCSMOKE}
  'start_time_procpm': ${START_TIME_PROCPM}
#
# Maximum memory for each task.
#
  'memo_run_processbufr': ${MEMO_RUN_PROCESSBUFR}
  'memo_run_ref2tten': ${MEMO_RUN_REF2TTEN}
  'memo_run_nonvarcldanl': ${MEMO_RUN_NONVARCLDANL}
  'memo_run_prepstart': ${MEMO_RUN_PREPSTART}
  'memo_run_prdgen': ${MEMO_RUN_PRDGEN}
  'memo_run_jedienvar_ioda': ${MEMO_RUN_JEDIENVAR_IODA}
  'memo_run_ioda_prepbufr': ${MEMO_RUN_IODA_PREPBUFR}
  'memo_prep_cyc': ${MEMO_PREP_CYC}
  'memo_save_restart': ${MEMO_SAVE_RESTART}
  'memo_save_input': ${MEMO_SAVE_INPUT}
  'memo_proc_smoke': ${MEMO_PROC_SMOKE}
  'memo_proc_glmfed': ${MEMO_PROC_GLMFED}
  'memo_proc_pm': ${MEMO_PROC_PM}
  'memo_save_da_output': ${MEMO_SAVE_DA_OUTPUT}
  'memo_add_aerosol': ${MEMO_ADD_AEROSOL}
#
# Maximum number of tries for each task.
#
  'maxtries_make_grid': ${MAXTRIES_MAKE_GRID}
  'maxtries_make_orog': ${MAXTRIES_MAKE_OROG}
  'maxtries_make_sfc_climo': ${MAXTRIES_MAKE_SFC_CLIMO}
  'maxtries_get_extrn_ics': ${MAXTRIES_GET_EXTRN_ICS}
  'maxtries_get_extrn_lbcs': ${MAXTRIES_GET_EXTRN_LBCS}
  'maxtries_make_ics': ${MAXTRIES_MAKE_ICS}
  'maxtries_blend_ics': ${MAXTRIES_BLEND_ICS}
  'maxtries_make_lbcs': ${MAXTRIES_MAKE_LBCS}
  'maxtries_run_prepstart': ${MAXTRIES_RUN_PREPSTART}
  'maxtries_run_fcst': ${MAXTRIES_RUN_FCST}
  'maxtries_analysis_gsi': ${MAXTRIES_ANALYSIS_GSI}
  'maxtries_postanal': ${MAXTRIES_POSTANAL}
  'maxtries_analysis_enkf': ${MAXTRIES_ANALYSIS_ENKF}
  'maxtries_recenter': ${MAXTRIES_RECENTER}
  'maxtries_run_post': ${MAXTRIES_RUN_POST}
  'maxtries_run_prdgen': ${MAXTRIES_RUN_PRDGEN}
  'maxtries_process_radarref': ${MAXTRIES_PROCESS_RADARREF}
  'maxtries_process_lightning': ${MAXTRIES_PROCESS_LIGHTNING}
  'maxtries_proc_glmfed': ${MAXTRIES_PROC_GLMFED}
  'maxtries_process_bufr': ${MAXTRIES_PROCESS_BUFR}
  'maxtries_process_smoke': ${MAXTRIES_PROCESS_SMOKE}
  'maxtries_process_pm': ${MAXTRIES_PROCESS_PM}
  'maxtries_radar_ref2tten': ${MAXTRIES_RADAR_REF2TTEN}
  'maxtries_cldanl_nonvar': ${MAXTRIES_CLDANL_NONVAR}
  'maxtries_save_restart': ${MAXTRIES_SAVE_RESTART}
  'maxtries_save_da_output': ${MAXTRIES_SAVE_DA_OUTPUT}
  'maxtries_jedi_envar_ioda': ${MAXTRIES_JEDI_ENVAR_IODA}
  'maxtries_ioda_prepbufr': ${MAXTRIES_IODA_PREPBUFR}
  'maxtries_add_aerosol': ${MAXTRIES_ADD_AEROSOL}
#
# Flags that determine whether to run the specific tasks.
#
  'run_task_make_grid': ${RUN_TASK_MAKE_GRID}
  'run_task_make_orog': ${RUN_TASK_MAKE_OROG}
  'run_task_make_sfc_climo': ${RUN_TASK_MAKE_SFC_CLIMO}
  'run_task_run_prdgen': ${RUN_TASK_RUN_PRDGEN}
  'run_task_add_aerosol': ${RUN_TASK_ADD_AEROSOL}
#
  'is_rtma':  ${IS_RTMA}
  'fg_rootdir': ${FG_ROOTDIR}
#
# Number of physical cores per node for the current machine.
#
  'ncores_per_node': ${NCORES_PER_NODE}
#
# Directories and files.
#
  'jobsdir': $JOBSdir
  'log_basedir': ${LOG_BASEDIR:-}
  'cycle_basedir': ${CYCLE_BASEDIR:-}
  'ensctrl_cycle_basedir': ${ENSCTRL_CYCLE_BASEDIR:-}
  'nwges_basedir': ${NWGES_BASEDIR:-}
  'ensctrl_nwges_basedir': ${ENSCTRL_NWGES_BASEDIR:-}
  'ensctrl_comout_basedir': ${ENSCTRL_COMOUT_BASEDIR:-}
  'ensctrl_comout_dir': ${ENSCTRL_COMOUT_DIR:-}
  'rrfse_nwges_basedir': ${RRFSE_NWGES_BASEDIR:-}
  'obstype_source': ${OBSTYPE_SOURCE}
  'obspath': ${OBSPATH}
  'obspath_pm': ${OBSPATH_PM}
  'global_var_defns_fp': ${GLOBAL_VAR_DEFNS_FP}
  'load_modules_run_task_fp': ${LOAD_MODULES_RUN_TASK_FP}
#
# External model information for generating ICs and LBCs.
#
  'extrn_mdl_name_ics': ${EXTRN_MDL_NAME_ICS}
  'extrn_mdl_name_lbcs': ${EXTRN_MDL_NAME_LBCS}
  'extrn_mdl_sysbasedir_ics': ${EXTRN_MDL_SYSBASEDIR_ICS}
  'extrn_mdl_sysbasedir_lbcs': ${EXTRN_MDL_SYSBASEDIR_LBCS}
  'extrn_mdl_ics_offset_hrs': ${EXTRN_MDL_ICS_OFFSET_HRS}
  'extrn_mdl_lbcs_offset_hrs': ${EXTRN_MDL_LBCS_OFFSET_HRS}
  'extrn_mdl_lbcs_search_offset_hrs': ${EXTRN_MDL_LBCS_SEARCH_OFFSET_HRS}
  'lbcs_search_hrs': ${LBCS_SEARCH_HRS}
  'bc_update_interval': ${LBC_SPEC_INTVL_HRS}
  'fv3gfs_file_fmt_ics': ${FV3GFS_FILE_FMT_ICS}
  'fv3gfs_file_fmt_lbcs': ${FV3GFS_FILE_FMT_LBCS}
#
# Parameters that determine the set of cycles to run.
#
  'date_first_cycl': ${DATE_FIRST_CYCL}
  'date_last_cycl': ${DATE_LAST_CYCL}
  'cdate_first_cycl': !datetime ${DATE_FIRST_CYCL}${CYCL_HRS[0]}
  'cdate_last_cycl': !datetime ${DATE_LAST_CYCL}${CYCL_HRS[0]}
  'cdate_first_arch': !datetime ${DATE_FIRST_CYCL}07
  'cdate_last_arch': !datetime ${DATE_LAST_CYCL}07
  'cycl_hrs': [ $( printf "\'%s\', " "${CYCL_HRS[@]}" ) ]
  'cycl_hrs_spinstart': [ $( printf "\'%s\', " "${CYCL_HRS_SPINSTART[@]}" ) ]
  'cycl_hrs_prodstart': [ $( printf "\'%s\', " "${CYCL_HRS_PRODSTART[@]}" ) ]
  'cycl_hrs_prodstart_ens': [ $( printf "\'%s\', " "${CYCL_HRS_PRODSTART_ENS[@]}" ) ]
  'cycl_hrs_recenter': [ $( printf "\'%s\', " "${CYCL_HRS_RECENTER[@]}" ) ]
  'cycl_hrs_stoch': [ $( printf "\'%s\', " "${CYCL_HRS_STOCH[@]}" ) ]
  'cycl_hrs_hyb_fv3lam_ens': [ $( printf "\'%s\', " "${CYCL_HRS_HYB_FV3LAM_ENS[@]}" ) ]
  'restart_hrs_prod': ${RESTART_INTERVAL}
  'restart_hrs_prod_long': ${RESTART_INTERVAL_LONG}
  'cycl_freq': !!str 12:00:00
  'at_start_cycledef': ${AT_START_CYCLEDEF}
  'initial_cycledef': ${INITIAL_CYCLEDEF}
  'boundary_cycledef': ${BOUNDARY_CYCLEDEF}
  'boundary_long_cycledef': ${BOUNDARY_LONG_CYCLEDEF}
  'spinup_cycledef': ${SPINUP_CYCLEDEF}
  'prod_cycledef': ${PROD_CYCLEDEF}
  'prodlong_cycledef': ${PRODLONG_CYCLEDEF}
  'saveda_cycledef': ${SAVEDA_CYCLEDEF}
  'recenter_cycledef': ${RECENTER_CYCLEDEF}
  'archive_cycledef': ${ARCHIVE_CYCLEDEF}
  'dt_atmos': ${DT_ATMOS}
#
# boundary, forecast, and post process length.
#
  'fcst_len_hrs': ${FCST_LEN_HRS}
  'fcst_len_hrs_spinup': ${FCST_LEN_HRS_SPINUP}
  'boundary_len_hrs': ${BOUNDARY_LEN_HRS}
  'boundary_long_len_hrs': ${BOUNDARY_LONG_LEN_HRS}
  'postproc_len_hrs': ${POSTPROC_LEN_HRS}
  'postproc_long_len_hrs': ${POSTPROC_LONG_LEN_HRS}
  'postproc_nsout_min': ${NSOUT_MIN}
  'postproc_nfhmax_hrs': ${NFHMAX_HF}
  'postproc_nfhout_hrs': ${NFHOUT}
  'postproc_nfhout_hf_hrs': ${NFHOUT_HF}
  'boundary_proc_group_num': ${BOUNDARY_PROC_GROUP_NUM}
#
# Ensemble-related parameters.
#
  'do_ensemble': ${DO_ENSEMBLE}
  'do_ensfcst': ${DO_ENSFCST}
  'do_ensfcst_mulphy': ${DO_ENSFCST_MULPHY}
  'num_ens_members': ${NUM_ENS_MEMBERS}
  'num_ens_members_fcst': ${NUM_ENS_MEMBERS_FCST}
  'ndigits_ensmem_names': !!str ${NDIGITS_ENSMEM_NAMES}
  'ensmem_indx_name': ${ensmem_indx_name}
  'uscore_ensmem_name': ${uscore_ensmem_name}
  'slash_ensmem_subdir': ${slash_ensmem_subdir}
  'do_enscontrol': ${DO_ENSCONTROL}
  'do_gsiobserver': ${DO_GSIOBSERVER}
  'do_enkfupdate': ${DO_ENKFUPDATE}
  'do_enkf_radar_ref': ${DO_ENKF_RADAR_REF}
  'do_envar_radar_ref': ${DO_ENVAR_RADAR_REF}
  'do_envar_radar_ref_once': ${DO_ENVAR_RADAR_REF_ONCE}
  'do_recenter': ${DO_RECENTER}
  'do_bufrsnd': ${DO_BUFRSND}
  'do_ens_graphics': ${DO_ENS_GRAPHICS}
  'do_enspost': ${DO_ENSPOST}
  'do_ensinit': ${DO_ENSINIT}
  'do_save_da_output': ${DO_SAVE_DA_OUTPUT}
  'do_gsidiag_offline': ${DO_GSIDIAG_OFFLINE}
  'do_save_input': ${DO_SAVE_INPUT}
#
# data assimilation related parameters.
#
  'do_dacycle': ${DO_DACYCLE}
  'do_surface_cycle': ${DO_SURFACE_CYCLE}
  'da_cycle_interval_hrs': ${DA_CYCLE_INTERV}
  'do_nonvar_cldanal': ${DO_NONVAR_CLDANAL}
  'do_refl2tten': ${DO_REFL2TTEN}
  'do_spinup': ${DO_SPINUP}
  'do_post_spinup': ${DO_POST_SPINUP}
  'do_post_prod': ${DO_POST_PROD}
  'do_nldn_lght': ${DO_NLDN_LGHT}
  'do_glmfed_da': ${DO_GLM_FED_DA}
  'prep_model_for_fed': ${PREP_MODEL_FOR_FED}
  'regional_ensemble_option': ${regional_ensemble_option}
  'radar_ref_thinning': ${RADAR_REF_THINNING}
  'ensctrl_stmp': ${ENSCTRL_STMP}
  'use_rrfse_ens': ${USE_RRFSE_ENS}
#
# cycle start and end date
#
  'startyear': ${STARTYEAR}
  'startmonth': ${STARTMONTH}
  'startday': ${STARTDAY}
  'starthour': ${STARTHOUR}
  'endyear': ${ENDYEAR}
  'endmonth': ${ENDMONTH}
  'endday': ${ENDDAY}
  'endhour': ${ENDHOUR}
#
# JEDI related parameters (liaofan)
#
  'do_jedi_envar_ioda': ${DO_JEDI_ENVAR_IODA}
#
# IODA related parameters
#
  'do_ioda_prepbufr': ${DO_IODA_PREPBUFR}
#
# smoke and dust related parameters.
#
  'do_smoke_dust': ${DO_SMOKE_DUST}
  'ebb_dcycle'   : ${EBB_DCYCLE}
#
# PM related parameters.
#
  'do_pm_da': ${DO_PM_DA}
#
# graphics related parameters
#
  'tilelabels': \"${TILE_LABELS}\"
  'tilesets': \"${TILE_SETS}\"
#
#  retrospective experiments
#
  'do_retro': ${DO_RETRO}
#
#  large-scale blending EnKF initialization
#
  'do_ens_blending': ${DO_ENS_BLENDING}
" # End of "settings" variable.

print_info_msg $VERBOSE "
The variable \"settings\" specifying values of the rococo XML variables
has been set as follows:
#-----------------------------------------------------------------------
settings =
$settings"

#
# Set the full path to the template rocoto XML file.  Then call a python
# script to generate the experiment's actual XML file from this template
# file.
#
template_xml_fp="${PARMdir}/${WFLOW_XML_TMPL_FN}"
$USHdir/fill_jinja_template.py -q \
                               -u "${settings}" \
                               -t ${template_xml_fp} \
                               -o ${WFLOW_XML_FP} || \
  print_err_msg_exit "\
Call to python script fill_jinja_template.py to create a rocoto workflow
XML file from a template file failed.  Parameters passed to this script
are:
  Full path to template rocoto XML file:
    template_xml_fp = \"${template_xml_fp}\"
  Full path to output rocoto XML file:
    WFLOW_XML_FP = \"${WFLOW_XML_FP}\"
  Namelist settings specified on command line:
    settings =
$settings"

#
#-----------------------------------------------------------------------
#
# Create a symlink in the experiment directory that points to the workflow
# (re)launch script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
Creating symlink in the experiment directory (EXPTDIR) that points to the
workflow launch script (WFLOW_LAUNCH_SCRIPT_FP):
  EXPTDIR = \"${EXPTDIR}\"
  WFLOW_LAUNCH_SCRIPT_FP = \"${WFLOW_LAUNCH_SCRIPT_FP}\""
ln -fs "${WFLOW_LAUNCH_SCRIPT_FP}" "$EXPTDIR"

print_info_msg "Generating an alternate simple launch script
${EXPTDIR}/run_rocoto.sh"

echo "#!/bin/bash" > ${EXPTDIR}/run_rocoto.sh
if [[ "${MACHINE,,}" == "wcoss2" ]] ; then
  echo "module use /apps/ops/test/nco/modulefiles" >> ${EXPTDIR}/run_rocoto.sh
  echo "module load core/rocoto/${rocoto_ver}" >> ${EXPTDIR}/run_rocoto.sh
else
  echo "source /etc/profile" >> ${EXPTDIR}/run_rocoto.sh
  echo "module load rocoto" >> ${EXPTDIR}/run_rocoto.sh
fi
echo "rocotorun -w ${WFLOW_XML_FN} -d ${WFLOW_XML_FN%.*}.db" >> ${EXPTDIR}/run_rocoto.sh
chmod +x ${EXPTDIR}/run_rocoto.sh
#
#-----------------------------------------------------------------------
#
# If USE_CRON_TO_RELAUNCH is set to TRUE, add a line to the user's cron
# table to call the (re)launch script every CRON_RELAUNCH_INTVL_MNTS mi-
# nutes.
#
#-----------------------------------------------------------------------
#
if [ "${USE_CRON_TO_RELAUNCH}" = "TRUE" ]; then
#
# Make a backup copy of the user's crontab file and save it in a file.
#
  time_stamp=$( date "+%F_%T" )
  crontab_backup_fp="$EXPTDIR/crontab.bak.${time_stamp}"
  print_info_msg "
Copying contents of user cron table to backup file:
  crontab_backup_fp = \"${crontab_backup_fp}\""
  crontab -l > ${crontab_backup_fp}
#
# Below, we use "grep" to determine whether the crontab line that the
# variable CRONTAB_LINE contains is already present in the cron table.
# For that purpose, we need to escape the asterisks in the string in
# CRONTAB_LINE with backslashes.  Do this next.
#
  crontab_line_esc_astr=$( printf "%s" "${CRONTAB_LINE}" | \
                           sed -r -e "s%[*]%\\\\*%g" )
#
# In the grep command below, the "^" at the beginning of the string be-
# ing passed to grep is a start-of-line anchor while the "$" at the end
# of the string is an end-of-line anchor.  Thus, in order for grep to
# find a match on any given line of the output of "crontab -l", that
# line must contain exactly the string in the variable crontab_line_-
# esc_astr without any leading or trailing characters.  This is to eli-
# minate situations in which a line in the output of "crontab -l" con-
# tains the string in crontab_line_esc_astr but is precedeeded, for ex-
# ample, by the comment character "#" (in which case cron ignores that
# line) and/or is followed by further commands that are not part of the
# string in crontab_line_esc_astr (in which case it does something more
# than the command portion of the string in crontab_line_esc_astr does).
#
  grep_output=$( crontab -l | grep "^${crontab_line_esc_astr}$" )
  exit_status=$?

  if [ "${exit_status}" -eq 0 ]; then

    print_info_msg "
The following line already exists in the cron table and thus will not be
added:
  CRONTAB_LINE = \"${CRONTAB_LINE}\""

  else

    print_info_msg "
Adding the following line to the cron table in order to automatically
resubmit FV3-LAM workflow:
  CRONTAB_LINE = \"${CRONTAB_LINE}\""

    ( crontab -l; echo "${CRONTAB_LINE}" ) | crontab -

  fi

fi
#
#-----------------------------------------------------------------------
#
# Create the FIX directories under the experiment directory.
#
#-----------------------------------------------------------------------
#
if [ "${DO_DACYCLE}" = "TRUE" ]; then
  # Resolve the target directory that the FIXgsi symlink points to
  ln -fsn "$FIX_GSI" "$FIXgsi"
  path_resolved=$( readlink -m "$FIXgsi" )
  if [ ! -d "${path_resolved}" ]; then
    print_err_msg_exit "Missing link to FIXgsi
    FIXgsi = \"$FIXgsi\"
    path_resolved = \"${path_resolved}\"
    Please ensure that path_resolved is an existing directory and then rerun
    the experiment generation script."
  fi
fi  # check if DA

# Resolve the target directory that the FIXcrtm symlink points to
ln -fsn "$FIX_CRTM" "$FIXcrtm"
path_resolved=$( readlink -m "$FIXcrtm" )
if [ ! -d "${path_resolved}" ]; then
  print_err_msg_exit "Missing link to FIXcrtm
  FIXcrtm = \"$FIXcrtm\"
  path_resolved = \"${path_resolved}\"
  Please ensure that path_resolved is an existing directory and then rerun
  the experiment generation script."
fi

# Resolve the target directory that the FIXuppcrtm symlink points to
ln -fsn "$FIX_UPP_CRTM" "$FIXuppcrtm"
path_resolved=$( readlink -m "$FIXuppcrtm" )
if [ ! -d "${path_resolved}" ]; then
  print_err_msg_exit "\
  Missing link to FIXuppcrtm
  FIXuppcrtm = \"$FIXuppcrtm\"
  path_resolved = \"${path_resolved}\"
  Please ensure that path_resolved is an existing directory and then rerun
  the experiment generation script."
fi

# Resolve the target directory that the FIXsmokedust symlink points to
ln -fsn "$FIX_SMOKE_DUST" "$FIXsmokedust"
path_resolved=$( readlink -m "$FIXsmokedust" )
if [ ! -d "${path_resolved}" ]; then
  print_err_msg_exit "Missing link to FIXsmokedust
  FIXsmokedust = \"$FIXsmokedust\"
  path_resolved = \"${path_resolved}\"
  Please ensure that path_resolved is an existing directory and then rerun
  the experiment generation script."
fi

if [ "${DO_BUFRSND}" = "TRUE" ]; then
  # Resolve the target directory that the FIXbufrsnd symlink points to
  ln -fsn "$FIX_BUFRSND" "$FIXbufrsnd"
  path_resolved=$( readlink -m "$FIXbufrsnd" )
  if [ ! -d "${path_resolved}" ]; then
    print_err_msg_exit "Missing link to FIXbufrsnd
    FIXsmokedust = \"$FIXbufrsnd\"
    path_resolved = \"${path_resolved}\"
    Please ensure that path_resolved is an existing directory and then rerun
    the experiment generation script."
  fi
fi

# Resolve target directory that FIXam symlink points to
check_for_preexist_dir_file "$FIXam" "delete"
ln -fsn "$FIXgsm" "$FIXam"
path_resolved=$( readlink -m "$FIXam" )
if [ ! -d "${path_resolved}" ]; then
  print_err_msg_exit "\
  The path specified by FIXam after resolving all symlinks (path_resolved) 
  must be an existing directory:
  FIXam = \"$FIXam\"
  path_resolved = \"${path_resolved}\"
  Please ensure that path_resolved is an existing directory and then rerun
  the experiment generation script."
fi

#
#-----------------------------------------------------------------------
#
# Copy templates of various input files to the experiment directory.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Copying templates of various input files to the experiment directory..."

print_info_msg "$VERBOSE" "
  Copying the template data table file to the experiment directory..."
cp "${DATA_TABLE_TMPL_FP}" "${DATA_TABLE_FP}"

print_info_msg "$VERBOSE" "
  Copying the template field table file to the experiment directory..."
cp "${FIELD_TABLE_TMPL_FP}" "${FIELD_TABLE_FP}"

#
# Copy the CCPP physics suite definition file from its location in the
# clone of the FV3 code repository to the experiment directory (EXPT-
# DIR).
#
print_info_msg "$VERBOSE" "
Copying the CCPP physics suite definition XML file from its location in
the forecast model directory sturcture to the experiment directory..."
cp "${CCPP_PHYS_SUITE_IN_CCPP_FP}" "${CCPP_PHYS_SUITE_FP}"

#
# copy nems.yaml from its location in the
# clone of the FV3 code repository to the experiment directory
#
print_info_msg "$VERBOSE" "
Copying the nems.yaml from its location in
the forecast model directory sturcture to the experiment directory..."
cp "${UFS_YAML_IN_PARM_FP}" "${UFS_YAML_FP}"
#
#-----------------------------------------------------------------------
#
# Set parameters in the FV3-LAM namelist file.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Setting parameters in FV3 namelist file (FV3_NML_FP):
  FV3_NML_FP = \"${FV3_NML_FP}\""
#
# Set npx and npy, which are just NX plus 1 and NY plus 1, respectively.
# These need to be set in the FV3-LAM Fortran namelist file.  They represent
# the number of cell vertices in the x and y directions on the regional
# grid.
#
npx=$((NX+1))
npy=$((NY+1))
#
# For the physics suites that use RUC LSM, set the parameter kice to 9,
# Otherwise, leave it unspecified (which means it gets set to the default
# value in the forecast model).
#
# NOTE:
# May want to remove kice from FV3.input.yml (and maybe input.nml.FV3).
#
kice=""
if [ "${SDF_USES_RUC_LSM}" = "TRUE" ]; then
  kice="9"
fi
#
# Set lsoil, which is the number of input soil levels provided in the 
# chgres_cube output NetCDF file.  This is the same as the parameter 
# nsoill_out in the namelist file for chgres_cube.  [On the other hand, 
# the parameter lsoil_lsm (not set here but set in input.nml.FV3 and/or 
# FV3.input.yml) is the number of soil levels that the LSM scheme in the
# forecast model will run with.]  Here, we use the same approach to set
# lsoil as the one used to set nsoill_out in exrrfs_make_ics.sh.  
# See that script for details.
#
# NOTE:
# May want to remove lsoil from FV3.input.yml (and maybe input.nml.FV3).
# Also, may want to set lsm here as well depending on SDF_USES_RUC_LSM.
#
lsoil="4"
if [ "${EXTRN_MDL_NAME_ICS}" = "HRRR" -o \
     "${EXTRN_MDL_NAME_ICS}" = "RAP" -o \
     "${EXTRN_MDL_NAME_ICS}" = "HRRRDAS" -o \
     "${EXTRN_MDL_NAME_ICS}" = "RRFS" ] && \
   [ "${SDF_USES_RUC_LSM}" = "TRUE" ]; then
  lsoil="9"
fi
# 
# fhzero = 0.25
#     get time-max fields like UH to reset at 15-minute intervals
#
# avg_max_length=900, sec, 
#     for needing restart files also output at higher frequency
#     or other time-max fields output at high frequency
#
avg_max_length="3600.0"
fhzero="1.0"
if [ "${NSOUT_MIN}" = "15" ]; then
  avg_max_length="3600.0"
  fhzero="1.0"
fi
#
# Create a multiline variable that consists of a yaml-compliant string
# specifying the values that the namelist variables that are physics-
# suite-independent need to be set to.  Below, this variable will be
# passed to a python script that will in turn set the values of these
# variables in the namelist file.
#
# IMPORTANT:
# If we want a namelist variable to be removed from the namelist file,
# in the "settings" variable below, we need to set its value to the
# string "null".  This is equivalent to setting its value to 
#    !!python/none
# in the base namelist file specified by FV3_NML_BASE_SUITE_FP or the 
# suite-specific yaml settings file specified by FV3_NML_YAML_CONFIG_FP.
#
# It turns out that setting the variable to an empty string also works
# to remove it from the namelist!  Which is better to use??
#
settings="\
'atmos_model_nml': {
    'avg_max_length': ${avg_max_length},
    'blocksize': $BLOCKSIZE,
    'ccpp_suite': ${CCPP_PHYS_SUITE},
  }
'fv_core_nml': {
    'target_lon': ${LON_CTR},
    'target_lat': ${LAT_CTR},
    'nrows_blend': ${HALO_BLEND},
    'regional_bcs_from_gsi': FALSE,
    'write_restart_with_bcs': FALSE,
    'stretch_fac': ${STRETCH_FAC},
    'npx': $npx,
    'npy': $npy,
    'io_layout': [${IO_LAYOUT_X}, ${IO_LAYOUT_Y}],
    'layout': [${LAYOUT_X}, ${LAYOUT_Y}],
    'bc_update_interval': ${LBC_SPEC_INTVL_HRS},
  }
'gfs_physics_nml': {
    'fhzero':${fhzero},
    'kice': ${kice:-null},
    'lsoil': ${lsoil:-null},
    'print_diff_pgr': ${PRINT_DIFF_PGR},
    'rrfs_sd': ${DO_SMOKE_DUST},
    'ebb_dcycle': ${EBB_DCYCLE},
  }"
if [ "${USE_CLM}" = "TRUE" ]; then
    settings="$settings
'gfs_physics_nml': {
    'lkm': 1,
    'iopt_lake': 2,
    'clm_lake_debug': FALSE,
    'clm_debug_print': FALSE,
    'frac_ice': TRUE,
    'kice': 9,
    'min_seaice': 0.15,
    'min_lakeice': 0.15,
    'fhzero':${fhzero},
    'lsoil': ${lsoil:-null},
    'print_diff_pgr': ${PRINT_DIFF_PGR},
    'rrfs_sd': ${DO_SMOKE_DUST},
    'ebb_dcycle': ${EBB_DCYCLE},
  }"
fi
#
# Add to "settings" the values of those namelist variables that specify
# the paths to fixed files in the FIXam directory.  As above, these namelist
# variables are physcs-suite-independent.
#
# Note that the array FV3_NML_VARNAME_TO_FIXam_FILES_MAPPING contains
# the mapping between the namelist variables and the names of the files
# in the FIXam directory.  Here, we loop through this array and process
# each element to construct each line of "settings".
#
settings="$settings
'namsfc': {"

dummy_run_dir="$EXPTDIR/any_cyc"
if [ "${DO_ENSEMBLE}" = "TRUE" ]; then
  dummy_run_dir="${dummy_run_dir}/any_ensmem"
fi

regex_search="^[ ]*([^| ]+)[ ]*[|][ ]*([^| ]+)[ ]*$"
num_nml_vars=${#FV3_NML_VARNAME_TO_FIXam_FILES_MAPPING[@]}
for (( i=0; i<${num_nml_vars}; i++ )); do

  mapping="${FV3_NML_VARNAME_TO_FIXam_FILES_MAPPING[$i]}"
  nml_var_name=$( printf "%s\n" "$mapping" | \
                  sed -n -r -e "s/${regex_search}/\1/p" )
  FIXam_fn=$( printf "%s\n" "$mapping" |
              sed -n -r -e "s/${regex_search}/\2/p" )

  fp="\"\""
  if [ ! -z "${FIXam_fn}" ]; then
    fp="$FIXam/${FIXam_fn}"
  fi
#
# Add a line to the variable "settings" that specifies (in a yaml-compliant
# format) the name of the current namelist variable and the value it should
# be set to.
#
  settings="$settings
    '${nml_var_name}': $fp,"

done
#
# Add the closing curly bracket to "settings".
#
settings="$settings
  }"
#
#
#-----------------------------------------------------------------------
#
# Call the set_namelist.py script to create a new FV3 namelist file (full
# path specified by FV3_NML_FP) using the file FV3_NML_BASE_SUITE_FP as
# the base (i.e. starting) namelist file, with physics-suite-dependent
# modifications to the base file specified in the yaml configuration file
# FV3_NML_YAML_CONFIG_FP (for the physics suite specified by CCPP_PHYS_SUITE),
# and with additional physics-suite-independent modificaitons specified
# in the variable "settings" set above.
#
#-----------------------------------------------------------------------
#
# For generating the namelist for the fire weather grid, do not use a yaml file.
#
if [ "${PREDEF_GRID_NAME}" = "RRFS_FIREWX_1.5km" ]; then
$USHdir/set_namelist.py -q \
                        -n ${FV3_NML_BASE_SUITE_FP} \
                        -u "$settings" \
                        -o ${FV3_NML_FP} || \
  print_err_msg_exit "\
Call to python script set_namelist.py to generate an FV3 namelist file
failed.  Parameters passed to this script are:
  Full path to base namelist file:
    FV3_NML_BASE_SUITE_FP = \"${FV3_NML_BASE_SUITE_FP}\"
  Full path to output namelist file: 
    FV3_NML_FP = \"${FV3_NML_FP}\"
  Namelist settings specified on command line:
    settings =
$settings"

else
$USHdir/set_namelist.py -q \
                        -n ${FV3_NML_BASE_SUITE_FP} \
                        -c ${FV3_NML_YAML_CONFIG_FP} ${CCPP_PHYS_SUITE} \
                        -u "$settings" \
                        -o ${FV3_NML_FP} || \
  print_err_msg_exit "\
Call to python script set_namelist.py to generate an FV3 namelist file
failed.  Parameters passed to this script are:
  Full path to base namelist file:
    FV3_NML_BASE_SUITE_FP = \"${FV3_NML_BASE_SUITE_FP}\"
  Full path to yaml configuration file for various physics suites:
    FV3_NML_YAML_CONFIG_FP = \"${FV3_NML_YAML_CONFIG_FP}\"
  Physics suite to extract from yaml configuration file:
    CCPP_PHYS_SUITE = \"${CCPP_PHYS_SUITE}\"
  Full path to output namelist file:
    FV3_NML_FP = \"${FV3_NML_FP}\"
  Namelist settings specified on command line:
    settings =
$settings"
#
# If not running the MAKE_GRID_TN task (which implies the workflow will
# use pregenerated grid files), set the namelist variables specifying
# the paths to surface climatology files.  These files are located in
# (or have symlinks that point to them) in the FIXLAM directory.
#
# Note that if running the MAKE_GRID_TN task, this action usually cannot
# be performed here but must be performed in that task because the names
# of the surface climatology files depend on the CRES parameter (which is
# the C-resolution of the grid), and this parameter is in most workflow
# configurations is not known until the grid is created.
#
if [ "${RUN_TASK_MAKE_GRID}" = "FALSE" ]; then

  set_FV3nml_sfc_climo_filenames || print_err_msg_exit "\
Call to function to set surface climatology file names in the FV3 namelist
file failed."

fi

if [[ "${DO_DACYCLE}" = "TRUE" || "${DO_ENKFUPDATE}" = "TRUE" ]]; then
  if [ "${SDF_USES_RUC_LSM}" = "TRUE" ]; then
    lsoil="9"
  fi
  lupdatebc="false"
  if [ "${DO_UPDATE_BC}" = "TRUE" ]; then
    lupdatebc="false" # not ready for setting this to true yet
  fi

# need to generate a namelist for da cycle
 settings="\
 'fv_core_nml': {
     'external_ic': false,
     'make_nh'    : false,
     'na_init'    : 0,
     'nggps_ic'   : false,
     'mountain'  : true,
     'regional_bcs_from_gsi': ${lupdatebc},
     'warm_start' : true,
   }
 'gfs_physics_nml': {
     'lsoil': ${lsoil:-null},
   }"
# commnet out for using current develop branch that has no radar tten code yet.
# 'gfs_physics_nml': {
#    'fh_dfi_radar': [${FH_DFI_RADAR[@]}],
#  }"
 
 $USHdir/set_namelist.py -q \
                         -n ${FV3_NML_FP} \
                         -u "$settings" \
                         -o ${FV3_NML_RESTART_FP} || \
   print_err_msg_exit "\
 Call to python script set_namelist.py to generate an restart FV3 namelist file
 failed.  Parameters passed to this script are:
   Full path to base namelist file:
     FV3_NML_FP = \"${FV3_NML_FP}\"
   Full path to output namelist file for DA:
     FV3_NML_RESTART_FP = \"${FV3_NML_RESTART_FP}\"
   Namelist settings specified on command line:
     settings =
 $settings"
fi
#
# Add the relevant tendency-based stochastic physics namelist variables to
# "settings" when running with SPPT, SHUM, or SKEB turned on. If running 
# with SPP or LSM SPP, set the "new_lscale" variable.  Otherwise only 
# include an empty "nam_stochy" stanza. 
#
settings="\
'gfs_physics_nml': {
    'do_shum': ${DO_SHUM},
    'do_sppt': ${DO_SPPT},
    'do_skeb': ${DO_SKEB},
    'do_spp': ${DO_SPP},
    'n_var_spp': ${N_VAR_SPP},
    'n_var_lndp': ${N_VAR_LNDP},
    'lndp_type': ${LNDP_TYPE},
    'lndp_each_step': ${LSM_SPP_EACH_STEP},
    'fhcyc': ${FHCYC_LSM_SPP_OR_NOT},
  }"
settings="$settings
'nam_stochy': {"
if [ "${DO_SPPT}" = "TRUE" ]; then 
    settings="$settings
    'iseed_sppt': ${ISEED_SPPT},
    'sppt': ${SPPT_MAG},
    'sppt_logit': ${SPPT_LOGIT},
    'sppt_lscale': ${SPPT_LSCALE},
    'sppt_sfclimit': ${SPPT_SFCLIMIT},
    'sppt_tau': ${SPPT_TSCALE},
    'spptint': ${SPPT_INT},
    'use_zmtnblck': ${USE_ZMTNBLCK},"
fi

if [ "${DO_SHUM}" = "TRUE" ]; then 
    settings="$settings
    'iseed_shum': ${ISEED_SHUM},
    'shum': ${SHUM_MAG},
    'shum_lscale': ${SHUM_LSCALE},
    'shum_tau': ${SHUM_TSCALE},
    'shumint': ${SHUM_INT},"
fi

if [ "${DO_SKEB}" = "TRUE" ]; then
    settings="$settings
    'iseed_skeb': ${ISEED_SKEB},
    'skeb': ${SKEB_MAG},
    'skeb_lscale': ${SKEB_LSCALE},
    'skebnorm': ${SKEBNORM},
    'skeb_tau': ${SKEB_TSCALE},
    'skebint': ${SKEB_INT},
    'skeb_vdof': ${SKEB_VDOF},"
fi

if [ "${DO_SPP}" = "TRUE" ] || [ "${DO_LSM_SPP}" = "TRUE" ] || [ "${DO_SPPT}" = "TRUE" ] || [ "${DO_SHUM}" = "TRUE" ] || [ "${DO_SKEB}" = "TRUE" ]; then
    settings="$settings
    'new_lscale': ${NEW_LSCALE},"
fi
settings="$settings
  }"
#
# Add the relevant SPP namelist variables to "settings" when running with
# SPP turned on.  Otherwise only include an empty "nam_sppperts" stanza.
#
settings="$settings
'nam_sppperts': {"
if [ "${DO_SPP}" = "TRUE" ]; then
    settings="$settings
    'iseed_spp': [ $( printf "%s, " "${ISEED_SPP[@]}" ) ],
    'spp_lscale': [ $( printf "%s, " "${SPP_LSCALE[@]}" ) ],
    'sppint': ${SPPINT},
    'spp_prt_list': [ $( printf "%s, " "${SPP_MAG_LIST[@]}" ) ],
    'spp_sigtop1': [ $( printf "%s, " "${SPP_SIGTOP1[@]}" ) ],
    'spp_sigtop2': [ $( printf "%s, " "${SPP_SIGTOP2[@]}" ) ],
    'spp_stddev_cutoff': [ $( printf "%s, " "${SPP_STDDEV_CUTOFF[@]}" ) ],
    'spp_tau': [ $( printf "%s, " "${SPP_TSCALE[@]}" ) ],
    'spp_var_list': [ $( printf "%s, " "${SPP_VAR_LIST[@]}" ) ],"
fi
settings="$settings
  }"
#
# Add the relevant LSM SPP namelist variables to "settings" when running with
# LSM SPP turned on.
#
settings="$settings
'nam_sfcperts': {"
if [ "${DO_LSM_SPP}" = "TRUE" ]; then
    settings="$settings
    'lndp_type': ${LNDP_TYPE},
    'lndpint':  ${LNDPINT},
    'lndp_model_type': ${LNDP_TYPE},
    'lndp_tau': [ $( printf "%s, " "${LSM_SPP_TSCALE[@]}" ) ],
    'lndp_lscale': [ $( printf "%s, " "${LSM_SPP_LSCALE[@]}" ) ],
    'iseed_lndp': [ $( printf "%s, " "${ISEED_LSM_SPP[@]}" ) ],
    'lndp_var_list': [ $( printf "%s, " "${LSM_SPP_VAR_LIST[@]}" ) ],
    'lndp_prt_list': [ $( printf "%s, " "${LSM_SPP_MAG_LIST[@]}" ) ],"
fi
settings="$settings
  }"
print_info_msg $VERBOSE "
The variable \"settings\" specifying values of the namelist variables
has been set as follows:

settings =
$settings"
#
#-----------------------------------------------------------------------
#
# Generate namelist files with stochastic physics if needed
#
if [ "${DO_ENSEMBLE}" = TRUE ] && ([ "${DO_SPP}" = TRUE ] || [ "${DO_SPPT}" = TRUE ] || [ "${DO_SHUM}" = TRUE ] \
  || [ "${DO_SKEB}" = TRUE ] || [ "${DO_LSM_SPP}" =  TRUE ]); then

  $USHdir/set_namelist.py -q \
                          -n  ${FV3_NML_FP}  \
                          -u "$settings" \
                          -o ${FV3_NML_STOCH_FP} || \
  print_err_msg_exit "\
  Call to python script set_namelist.py to generate an FV3 namelist file with stochastics
  failed.  Parameters passed to this script are:
   Full path to base namelist file:
     FV3_NML_FP = \"${FV3_NML_FP}\"
   Full path to output namelist file for stochastics:
     FV3_NML_STOCH_FP = \"${FV3_NML_STOCH_FP}\"
   Namelist settings specified on command line:
     settings =
 $settings"
#
#-----------------------------------------------------------------------
#
if [[ "${DO_DACYCLE}" = "TRUE" || "${DO_ENKFUPDATE}" = "TRUE" ]]; then
  $USHdir/set_namelist.py -q \
                          -n  ${FV3_NML_RESTART_FP}  \
                          -u "$settings" \
                          -o ${FV3_NML_RESTART_STOCH_FP} || \
  print_err_msg_exit "\
 Call to python script set_namelist.py to generate an restart FV3 namelist file with stochastics
 failed.  Parameters passed to this script are:
   Full path to base namelist file:
     FV3_NML_RESTART_FP = \"${FV3_NML_RESTART_FP}\"
   Full path to output namelist file for DA with stochastics:
     FV3_NML_RESTART_STOCH_FP = \"${FV3_NML_RESTART_STOCH_FP}\"
   Namelist settings specified on command line:
     settings =
 $settings"

 if [ "${DO_ENSFCST_MULPHY}" = "TRUE" ]; then
   for i in {1..5}
   do
     $USHdir/set_namelist.py -q \
                             -n  ${FV3_NML_RESTART_STOCH_FP}  \
                             -c ${FV3_NML_YAML_CONFIG_FP}_ensphy rrfsens_phy${i}  \
                             -o ${FV3_NML_RESTART_STOCH_FP}_ensphy${i}
   done
 fi

fi

fi
fi
#
#-----------------------------------------------------------------------
#
# To have a record of how this experiment/workflow was generated, copy
# the experiment/workflow configuration file to the experiment directo-
# ry.
#
#-----------------------------------------------------------------------
#
cp $USHdir/${EXPT_CONFIG_FN} $EXPTDIR
#
#-----------------------------------------------------------------------
#
# For convenience, print out the commands that need to be issued on the
# command line in order to launch the workflow and to check its status.
# Also, print out the command that should be placed in the user's cron-
# tab in order for the workflow to be continually resubmitted.
#
#-----------------------------------------------------------------------
#
wflow_db_fn="${WFLOW_XML_FN%.xml}.db"
rocotorun_cmd="rocotorun -w ${WFLOW_XML_FN} -d ${wflow_db_fn} -v 10"
rocotostat_cmd="rocotostat -w ${WFLOW_XML_FN} -d ${wflow_db_fn} -v 10"

print_info_msg "
========================================================================
========================================================================

Workflow generation completed.

========================================================================
========================================================================

The experiment directory is:

  > EXPTDIR=\"$EXPTDIR\"

"

print_info_msg "\
To launch the workflow, first ensure that you have a compatible version
of rocoto loaded.  For example, to load version 1.3.1 of rocoto, use

  > module load rocoto/1.3.1

"

print_info_msg "
To launch the workflow, change location to the experiment directory
(EXPTDIR) and issue the rocotrun command, as follows:

  > cd $EXPTDIR
  > ${rocotorun_cmd}

To check on the status of the workflow, issue the rocotostat command
(also from the experiment directory):

  > ${rocotostat_cmd}

Note that:

1) The rocotorun command must be issued after the completion of each
   task in the workflow in order for the workflow to submit the next
   task(s) to the queue.

2) In order for the output of the rocotostat command to be up-to-date,
   the rocotorun command must be issued immediately before the rocoto-
   stat command.

For automatic resubmission of the workflow (say every 3 minutes), the
following line can be added to the user's crontab (use \"crontab -e\" to
edit the cron table):

*/3 * * * * cd $EXPTDIR && ./run_rocoto.sh
or
*/3 * * * * cd $EXPTDIR && ./launch_FV3LAM_wflow.sh

NOTE: '-l' was removed from the first line of launch_FV3LAM_wflow.sh
It is suggested to add the following line to the top of crontab

SHELL=/bin/bash -l


Done.
"
#
echo -e "../fix/.agent points to " $(readlink -f ${HOMErrfs}/fix/.agent) "\n"

#
# If necessary, run the NOMADS script to source external model data.
#
if [ "${NOMADS}" = "TRUE" ]; then
  echo "Getting NOMADS online data"
  echo "NOMADS_file_type=" $NOMADS_file_type
  cd $EXPTDIR
  $USHdir/NOMADS_get_extrn_mdl_files.sh $DATE_FIRST_CYCL $CYCL_HRS $NOMADS_file_type $FCST_LEN_HRS $LBC_SPEC_INTVL_HRS
fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

}

#
#-----------------------------------------------------------------------
#
# Start of the script that will call the experiment/workflow generation
# function defined above.
#
#-----------------------------------------------------------------------
#
set -u
[[ ! -f config.sh ]] && echo "config.sh not found!" && exit 1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Set directories.
#
#-----------------------------------------------------------------------
#
USHdir="${scrfunc_dir}"
#
# Set the name of and full path to the temporary file in which we will
# save some experiment/workflow variables.  The need for this temporary
# file is explained below.
#
tmp_fn="tmp"
tmp_fp="$USHdir/${tmp_fn}"
rm -f "${tmp_fp}"
#
# Set the name of and full path to the log file in which the output from
# the experiment/workflow generation function will be saved.
#
log_fn="log.generate_FV3LAM_wflow"
log_fp="$USHdir/${log_fn}"
rm -f "${log_fp}"
#
# Call the generate_FV3LAM_wflow function defined above to generate the
# experiment/workflow.  Note that we pipe the output of the function
# (and possibly other commands) to the "tee" command in order to be able
# to both save it to a file and print it out to the screen (stdout).
# The piping causes the call to the function (and the other commands
# grouped with it using the curly braces, { ... }) to be executed in a
# subshell.  As a result, the experiment/workflow variables that the
# function sets are not available outside of the grouping, i.e. they are
# not available at and after the call to "tee".  Since some of these va-
# riables are needed after the call to "tee" below, we save them in a
# temporary file and read them in outside the subshell later below.
#
{
generate_FV3LAM_wflow 2>&1  # If this exits with an error, the whole {...} group quits, so things don't work...
retval=$?
echo "$EXPTDIR" >> "${tmp_fp}"
echo "$retval" >> "${tmp_fp}"
} | tee "${log_fp}"
#
# Read in experiment/workflow variables needed later below from the tem-
# porary file created in the subshell above containing the call to the
# generate_FV3LAM_wflow function.  These variables are not directly
# available here because the call to generate_FV3LAM_wflow above takes
# place in a subshell (due to the fact that we are then piping its out-
# put to the "tee" command).  Then remove the temporary file.
#
exptdir=$( sed "1q;d" "${tmp_fp}" )
retval=$( sed "2q;d" "${tmp_fp}" )
rm "${tmp_fp}"
#
# If the call to the generate_FV3LAM_wflow function above was success-
# ful, move the log file in which the "tee" command saved the output of
# the function to the experiment directory.
#
if [ $retval -eq 0 ]; then
  mv "${log_fp}" "$exptdir"
#
# If the call to the generate_FV3LAM_wflow function above was not suc-
# cessful, print out an error message and exit with a nonzero return
# code.
#
else
  printf "
Experiment/workflow generation failed.  Check the log file from the ex-
periment/workflow generation script in the file specified by log_fp:
  log_fp = \"${log_fp}\"
Stopping.
"
  exit 1
fi
