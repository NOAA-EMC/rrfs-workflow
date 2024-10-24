valid_vals_VERBOSE=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_SAVE_CYCLE_LOG=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_MACHINE=("WCOSS2" "HERA" "ORION" "JET" "HERCULES")
valid_vals_SCHED=("slurm" "pbspro" "lsf" "lsfcray" "none")
valid_vals_PREDEF_GRID_NAME=( \
"RRFS_CONUS_25km" \
"RRFS_CONUS_13km" \
"RRFS_CONUS_3km" \
"RRFS_CONUS_3km_HRRRIC" \
"RRFS_SUBCONUS_3km" \
"RRFS_AK_13km" \
"RRFS_AK_3km" \
"CONUS_25km_GFDLgrid" \
"CONUS_3km_GFDLgrid" \
"EMC_AK" \
"EMC_HI" \
"EMC_PR" \
"EMC_GU" \
"GSL_HAFSV0.A_25km" \
"GSL_HAFSV0.A_13km" \
"GSL_HAFSV0.A_3km" \
"GSD_HRRR_AK_50km" \
"GSD_RAP13km" \
"RRFS_NA_3km" \
"RRFS_FIREWX_1.5km" \
)
valid_vals_CCPP_PHYS_SUITE=( \
"FV3_GFS_v16" \
"FV3_RRFS_v1beta" \
"FV3_HRRR" \
"FV3_HRRR_gf" \
"FV3_HRRR_gf_nogwd" \
"FV3_RAP" \
"FV3_GFS_v15_thompson_mynn_lam3km" \
"RRFS_sas" \
"RRFS_sas_nogwd" \
) 
valid_vals_GFDLgrid_RES=("48" "96" "192" "384" "768" "1152" "3072")
valid_vals_EXTRN_MDL_NAME_ICS=("GSMGFS" "FV3GFS" "RAP" "HRRR" "NAM" "HRRRDAS" "GEFS" "GDASENKF" "RRFS")
valid_vals_EXTRN_MDL_NAME_LBCS=("GSMGFS" "FV3GFS" "RAP" "HRRR" "NAM" "GEFS" "GDASENKF" "RRFS")
valid_vals_USE_USER_STAGED_EXTRN_FILES=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_EXTRN_MDL_DATE_JULIAN=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_FV3GFS_FILE_FMT_ICS=("nemsio" "grib2" "netcdf")
valid_vals_FV3GFS_FILE_FMT_LBCS=("nemsio" "grib2" "netcdf")
valid_vals_GRID_GEN_METHOD=("GFDLgrid" "ESGgrid")
valid_vals_PREEXISTING_DIR_METHOD=("delete" "upgrade" "rename" "quit")
valid_vals_GTYPE=("regional")
valid_vals_WRTCMP_output_grid=("rotated_latlon" "lambert_conformal" "regional_latlon")
valid_vals_RUN_TASK_MAKE_GRID=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_RUN_TASK_MAKE_OROG=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_RUN_TASK_MAKE_SFC_CLIMO=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_RUN_TASK_RUN_PRDGEN=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_QUILTING=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_PRINT_ESMF=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_USE_CRON_TO_RELAUNCH=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DOT_OR_USCORE=("." "_")
valid_vals_NOMADS=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_NOMADS_file_type=("GRIB2" "grib2" "NEMSIO" "nemsio")
valid_vals_DO_ENSEMBLE=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_ENS_GRAPHICS=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_ENSPOST=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_ENSINIT=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SAVE_INPUT=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SAVE_DA_OUTPUT=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_GSIDIAG_OFFLINE=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_ENSFCST=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_ENSFCST_MULPHY=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_DACYCLE=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SURFACE_CYCLE=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SOIL_ADJUST=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_UPDATE_BC=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_RECENTER=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_BUFRSND=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_RETRO=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SPINUP=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_POST_SPINUP=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_POST_PROD=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_PARALLEL_PRDGEN=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_LBCS_ICS_ONLY=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_NONVAR_CLDANAL=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_JEDI_ENVAR_IODA=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SMOKE_DUST=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_EBB_DCYCLE=("1" "2")
valid_vals_DO_PM_DA=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_REFL2TTEN=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_NLDN_LGHT=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_GLM_FED_DA=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_PREP_MODEL_FOR_FED=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_GLMFED_DATA_MODE=("FULL" "TILES" "PROD")
valid_vals_DO_RADDA=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_ENS_RADDA=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_NON_DA_RUN=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_USE_RRFSE_ENS=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_USE_CLM=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_USE_CUSTOM_POST_CONFIG_FILE=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SHUM=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SPPT=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SPP=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_LSM_SPP=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_SKEB=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_USE_ZMTNBLCK=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_USE_FVCOM=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_PREP_FVCOM=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_COMPILER=("intel" "gnu")
valid_vals_WORKFLOW_MANAGER=("rocoto" "ecflow" "none")
valid_vals_BOOLEAN=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
valid_vals_DO_IODA_PREPBUFR=("TRUE" "true" "YES" "yes" "FALSE" "false" "NO" "no")
