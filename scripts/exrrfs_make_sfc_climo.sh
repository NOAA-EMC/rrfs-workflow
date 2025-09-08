#!/bin/bash
set -x

source ${FIXrrfs}/workflow/${WGF}/workflow.conf

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. $USHrrfs/source_util_funcs.sh
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
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that generates surface fields from
climatology.
========================================================================"
#
#-----------------------------------------------------------------------
#
# OpenMP environment settings.
#
#-----------------------------------------------------------------------
#
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=1024m
nprocs=$(( NNODES_MAKE_SFC_CLIMO * PPN_MAKE_SFC_CLIMO ))
#
#-----------------------------------------------------------------------
#
# For the fire weather grid, read in the center lat/lon from the
# operational NAM fire weather nest.  The center lat/lon is set by the
# SDM.  When RRFS is implemented, a similar file will be needed.
# Rewrite the default center lat/lon values in var_defns.sh, if needed.
#
#-----------------------------------------------------------------------
#
if [ ${WGF} = "firewx" ]; then
  hh="${CDATE:8:2}"
  firewx_loc="${COMINnam}/input/nam_firewx_loc"
  center_lat=${LAT_CTR}
  center_lon=${LON_CTR}
  LAT_CTR=`grep ${hh}z $firewx_loc | awk '{print $2}'`
  LON_CTR=`grep ${hh}z $firewx_loc | awk '{print $3}'`

  if [ ${center_lat} != ${LAT_CTR} ] || [ ${center_lon} != ${LON_CTR} ]; then
    sed -i -e "s/${center_lat}/${LAT_CTR}/g" ${GLOBAL_VAR_DEFNS_FP}
    sed -i -e "s/${center_lon}/${LON_CTR}/g" ${GLOBAL_VAR_DEFNS_FP}
    . ${GLOBAL_VAR_DEFNS_FP}
  fi
fi
#
#-----------------------------------------------------------------------
#
# Create the namelist that the sfc_climo_gen code will read in.
#
#-----------------------------------------------------------------------
#
if [ "${PREDEF_GRID_NAME}" = "RRFS_FIREWX_1.5km" ]; then
  input_substrate_temperature_file="${SFC_CLIMO_INPUT_DIR}/substrate_temperature.gfs.0.5.nc"
  input_soil_type_file="${SFC_CLIMO_INPUT_DIR}/soil_type.bnu.v2.30s.nc"
  input_vegetation_type_file="${SFC_CLIMO_INPUT_DIR}/vegetation_type.viirs.v2.igbp.30s.nc"
  vegsoilt_frac=.true.
else
  input_substrate_temperature_file="${SFC_CLIMO_INPUT_DIR}/substrate_temperature.2.6x1.5.nc"
  input_soil_type_file="${SFC_CLIMO_INPUT_DIR}/soil_type.statsgo.0.05.nc"
  input_vegetation_type_file="${SFC_CLIMO_INPUT_DIR}/vegetation_type.igbp.0.05.nc"
  vegsoilt_frac=.false.
fi

cat << EOF > ./fort.41
&config
input_facsf_file="${SFC_CLIMO_INPUT_DIR}/facsf.1.0.nc"
input_substrate_temperature_file="${input_substrate_temperature_file}"
input_maximum_snow_albedo_file="${SFC_CLIMO_INPUT_DIR}/maximum_snow_albedo.0.05.nc"
input_snowfree_albedo_file="${SFC_CLIMO_INPUT_DIR}/snowfree_albedo.4comp.0.05.nc"
input_slope_type_file="${SFC_CLIMO_INPUT_DIR}/slope_type.1.0.nc"
input_soil_type_file="${input_soil_type_file}"
input_vegetation_type_file="${input_vegetation_type_file}"
input_vegetation_greenness_file="${SFC_CLIMO_INPUT_DIR}/vegetation_greenness.0.144.nc"
mosaic_file_mdl="${COMOUT}/fix/${CRES}${DOT_OR_USCORE}mosaic.halo${NH4}.nc"
orog_dir_mdl="${COMOUT}/fix"
orog_files_mdl="${CRES}${DOT_OR_USCORE}oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
halo=${NH4}
maximum_snow_albedo_method="bilinear"
snowfree_albedo_method="bilinear"
vegetation_greenness_method="bilinear"
fract_vegsoil_type=${vegsoilt_frac}
/
EOF
#
#-----------------------------------------------------------------------
#
# Set the machine-dependent run command.
#
#-----------------------------------------------------------------------
#
ulimit -a

case $MACHINE in

  "WCOSS2")
    APRUN="mpiexec -n ${nprocs}"
    ;;

  "HERA")
    APRUN="srun --export=ALL"
    ;;

  "ORION")
    APRUN="srun --export=ALL"
    ;;

  "HERCULES")
    APRUN="srun --export=ALL"
    ;;

  "JET")
    APRUN="srun --export=ALL"
    ;;

  *)
    err_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN = \"$APRUN\""
    ;;

esac
#
#-----------------------------------------------------------------------
#
# Generate the surface climatology files.
#
#-----------------------------------------------------------------------
#
export pgm="sfc_climo_gen"
. prep_step

$APRUN $EXECrrfs/$pgm >>$pgmout 2>errfile
export err=$?; err_chk
#
#-----------------------------------------------------------------------
#
# Move output files out of the run directory.
#
#-----------------------------------------------------------------------
#
case "$GTYPE" in

#
# Consider, global, stetched, and nested grids.
#
"global" | "stretch" | "nested")
#
# Move all files ending with ".nc" to the COMOUT directory.
# In the process, rename them so that the file names start with the C-
# resolution (followed by an underscore).
#
  for fn in *.nc; do
    if [[ -f $fn ]]; then
      cpreq -p $fn ${COMOUT}/fix/${CRES}_${fn}
    fi
  done
  ;;

#
# Consider regional grids.
#
"regional")
#
# Move all files ending with ".halo.nc" (which are the files for a grid
# that includes the specified non-zero-width halo) to the WORKDIR_SFC_-
# CLIMO directory.  In the process, rename them so that the file names
# start with the C-resolution (followed by a dot) and contain the (non-
# zero) halo width (in units of number of grid cells).
#
  for fn in *.halo.nc; do
    if [ -f $fn ]; then
      bn="${fn%.halo.nc}"
      cpreq -p $fn ${COMOUT}/fix/${CRES}.${bn}.halo${NH4}.nc
    fi
  done
#
# Move all remaining files ending with ".nc" (which are the files for a
# grid that doesn't include a halo) to the COMOUT directory.
# In the process, rename them so that the file names start with the C-
# resolution (followed by a dot) and contain the string "halo0" to indi-
# cate that the grids in these files do not contain a halo.
#
  for fn in *.nc; do
    if [ -f $fn ]; then
      bn="${fn%.nc}"
      cpreq -p $fn ${COMOUT}/fix/${CRES}.${bn}.halo${NH0}.nc
    fi
  done
  ;;

esac
#
#-----------------------------------------------------------------------
#
# Add fractional vegetation/soil information to the halo0 and halo4 
# orography files.  For the fire weather grid, vegsoilt_frac = true.
#
#-----------------------------------------------------------------------
#
if [ $vegsoilt_frac = .true. ]; then
  ncrename -d nx,lon -d ny,lat ${COMOUT}/fix/${CRES}.soil_type.tile7.halo0.nc
  ncrename -d nx,lon -d ny,lat ${COMOUT}/fix/${CRES}.soil_type.tile7.halo4.nc
  ncrename -d nx,lon -d ny,lat ${COMOUT}/fix/${CRES}.vegetation_type.tile7.halo0.nc
  ncrename -d nx,lon -d ny,lat ${COMOUT}/fix/${CRES}.vegetation_type.tile7.halo4.nc
  ncrename -d num_categories,num_veg_cat ${COMOUT}/fix/${CRES}.vegetation_type.tile7.halo0.nc
  ncrename -d num_categories,num_veg_cat ${COMOUT}/fix/${CRES}.vegetation_type.tile7.halo4.nc
  ncrename -d num_categories,num_soil_cat ${COMOUT}/fix/${CRES}.soil_type.tile7.halo0.nc
  ncrename -d num_categories,num_soil_cat ${COMOUT}/fix/${CRES}.soil_type.tile7.halo4.nc
  ncks -v vegetation_type_pct ${COMOUT}/fix/${CRES}.vegetation_type.tile7.halo0.nc -A ${COMOUT}/fix/${CRES}_oro_data.tile7.halo0.nc
  ncks -v vegetation_type_pct ${COMOUT}/fix/${CRES}.vegetation_type.tile7.halo4.nc -A ${COMOUT}/fix/${CRES}_oro_data.tile7.halo4.nc
  ncks -v soil_type_pct ${COMOUT}/fix/${CRES}.soil_type.tile7.halo0.nc -A ${COMOUT}/fix/${CRES}_oro_data.tile7.halo0.nc
  ncks -v soil_type_pct ${COMOUT}/fix/${CRES}.soil_type.tile7.halo4.nc -A ${COMOUT}/fix/${CRES}_oro_data.tile7.halo4.nc
fi
#
#-----------------------------------------------------------------------
#
# Copy tile7.halo4.nc versions of sfc climo fix files to tile7.nc
# Where was this done previously - in link_fix.sh?
#
#-----------------------------------------------------------------------
#
cpreq -p ${COMOUT}/fix/${CRES}.facsf.tile7.halo4.nc ${COMOUT}/fix/${CRES}.facsf.tile7.nc
cpreq -p ${COMOUT}/fix/${CRES}.maximum_snow_albedo.tile7.halo4.nc ${COMOUT}/fix/${CRES}.maximum_snow_albedo.tile7.nc
cpreq -p ${COMOUT}/fix/${CRES}.slope_type.tile7.halo4.nc ${COMOUT}/fix/${CRES}.slope_type.tile7.nc
cpreq -p ${COMOUT}/fix/${CRES}.snowfree_albedo.tile7.halo4.nc ${COMOUT}/fix/${CRES}.snowfree_albedo.tile7.nc
cpreq -p ${COMOUT}/fix/${CRES}.soil_type.tile7.halo4.nc ${COMOUT}/fix/${CRES}.soil_type.tile7.nc
cpreq -p ${COMOUT}/fix/${CRES}.substrate_temperature.tile7.halo4.nc ${COMOUT}/fix/${CRES}.substrate_temperature.tile7.nc
cpreq -p ${COMOUT}/fix/${CRES}.vegetation_greenness.tile7.halo4.nc ${COMOUT}/fix/${CRES}.vegetation_greenness.tile7.nc
cpreq -p ${COMOUT}/fix/${CRES}.vegetation_type.tile7.halo4.nc ${COMOUT}/fix/${CRES}.vegetation_type.tile7.nc

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
All surface climatology files generated successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
