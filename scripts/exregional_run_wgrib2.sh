#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
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

This is the ex-script for the task that runs the post-processor (UPP) on
the output files corresponding to a specified forecast hour.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( \
"cdate" \
"run_dir" \
"postprd_dir" \
"comout" \
"fhr_dir" \
"fhr" \
"tmmark" \
)
process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script.  Note that these will be printed out only if VERBOSE is set to
# TRUE.
#
#-----------------------------------------------------------------------
#
print_input_args valid_args
#
#-----------------------------------------------------------------------
#
# Load modules.
#
#-----------------------------------------------------------------------
#
case $MACHINE in

  "WCOSS_CRAY")

# Specify computational resources.
    export NODES=2
    export ntasks=48
    export ptile=24
    export threads=1
    export MP_LABELIO=yes
    export OMP_NUM_THREADS=$threads

    APRUN="aprun -j 1 -n${ntasks} -N${ptile} -d${threads} -cc depth"
    ;;

  "WCOSS_DELL_P3")

# Specify computational resources.
    export NODES=2
    export ntasks=48
    export ptile=24
    export threads=1
    export MP_LABELIO=yes
    export OMP_NUM_THREADS=$threads

    APRUN="mpirun"
    ;;

  "HERA")
    APRUN="srun"
    ;;

  "ORION")
    ulimit -s unlimited
    ulimit -a
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=1024M
    APRUN="srun"
    ;;

  "JET")
    APRUN="srun"
    ;;

  "ODIN")
    APRUN="srun -n 1"
    ;;

  "CHEYENNE")
    module list
    nprocs=$(( NNODES_RUN_POST*PPN_RUN_POST ))
    APRUN="mpirun -np $nprocs"
    ;;

  "STAMPEDE")
    nprocs=$(( NNODES_RUN_POST*PPN_RUN_POST ))
    APRUN="ibrun -n $nprocs"
    ;;

  *)
    print_err_msg_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN = \"$APRUN\""
    ;;

esac
#
#-----------------------------------------------------------------------
#
# Get the cycle date and hour (in formats of yyyymmdd and hh, respectively)
# from cdate.
#
#-----------------------------------------------------------------------
#
yyyymmdd=${cdate:0:8}
hh=${cdate:8:2}
cyc=$hh
#-----------------------------------------------------------------------
#
# A separate ${post_fhr} forecast hour variable is required for the post
# files, since they may or may not be three digits long, depending on the
# length of the forecast.
#
#-----------------------------------------------------------------------
#
len_fhr=${#fhr}
if [ ${len_fhr} -eq 2 ]; then
  post_fhr=${fhr}
elif [ ${len_fhr} -eq 3 ]; then
  if [ "${fhr:0:1}" = "0" ]; then
    post_fhr="${fhr:1}"
  fi
else
  print_err_msg_exit "\
The \${fhr} variable contains too few or too many characters:
  fhr = \"$fhr\""
fi

bgdawp=${postprd_dir}/${NET}.t${cyc}z.bgdawpf${fhr}.${tmmark}.grib2
bgrd3d=${postprd_dir}/${NET}.t${cyc}z.bgrd3df${fhr}.${tmmark}.grib2
bgsfc=${postprd_dir}/${NET}.t${cyc}z.bgsfcf${fhr}.${tmmark}.grib2

# extract the output fields for the testbed
touch ${bgsfc}
if [[ ! -z ${TESTBED_FIELDS_FN} ]]; then
  if [[ -f ${FIX_UPP}/${TESTBED_FIELDS_FN} ]]; then
    wgrib2 ${bgdawp} | grep -F -f ${FIX_UPP}/${TESTBED_FIELDS_FN} | wgrib2 -i -grib ${bgsfc} ${bgdawp}
  else
    echo "${FIX_UPP}/${TESTBED_FIELDS_FN} not found"
  fi
fi

#Link output for transfer to Jet
# Should the following be done only if on jet??

# Seems like start_date is the same as "$yyyymmdd $hh", where yyyymmdd
# and hh are calculated above, i.e. start_date is just cdate but with a
# space inserted between the dd and hh.  If so, just use "$yyyymmdd $hh"
# instead of calling sed.
basetime=$( date +%y%j%H%M -d "${yyyymmdd} ${hh}" )
cp_vrfy ${bgdawp} ${comout}/${NET}.t${cyc}z.bgdawpf${fhr}.${tmmark}.grib2
cp_vrfy ${bgrd3d} ${comout}/${NET}.t${cyc}z.bgrd3df${fhr}.${tmmark}.grib2
cp_vrfy ${bgsfc}  ${comout}/${NET}.t${cyc}z.bgsfcf${fhr}.${tmmark}.grib2
ln_vrfy -sf --relative ${comout}/${NET}.t${cyc}z.bgdawpf${fhr}.${tmmark}.grib2 ${comout}/BGDAWP_${basetime}${post_fhr}00
ln_vrfy -sf --relative ${comout}/${NET}.t${cyc}z.bgrd3df${fhr}.${tmmark}.grib2 ${comout}/BGRD3D_${basetime}${post_fhr}00
ln_vrfy -sf --relative ${comout}/${NET}.t${cyc}z.bgsfcf${fhr}.${tmmark}.grib2  ${comout}/BGSFC_${basetime}${post_fhr}00

ln_vrfy -sf --relative ${comout}/${NET}.t${cyc}z.bgdawpf${fhr}.${tmmark}.grib2 ${comout}/rrfs.t${cyc}z.prslev.f${fhr}.grib2
ln_vrfy -sf --relative ${comout}/${NET}.t${cyc}z.bgrd3df${fhr}.${tmmark}.grib2 ${comout}/rrfs.t${cyc}z.natlev.f${fhr}.grib2
# Remap to additional output grids if requested
if [ ${#ADDNL_OUTPUT_GRIDS[@]} -gt 0 ]; then

  cd_vrfy ${comout}

  grid_specs_130="lambert:265:25.000000 233.862000:451:13545.000000 16.281000:337:13545.000000"
  grid_specs_200="lambert:253:50.000000 285.720000:108:16232.000000 16.201000:94:16232.000000"
  grid_specs_221="lambert:253:50.000000 214.500000:349:32463.000000 1.000000:277:32463.000000"
  grid_specs_242="nps:225:60.000000 187.000000:553:11250.000000 30.000000:425:11250.000000"
  grid_specs_243="latlon 190.0:126:0.400 10.000:101:0.400"
  grid_specs_clue="lambert:262.5:38.5 239.891:1620:3000.0 20.971:1120:3000.0"
  grid_specs_hrrr="lambert:-97.5:38.5 -122.719528:1799:3000.0 21.138123:1059:3000.0"
  grid_specs_hrrre="lambert:-97.5:38.5 -122.719528:1800:3000.0 21.138123:1060:3000.0"
  grid_specs_rrfsak="lambert:-161.5:63.0 172.102615:1379:3000.0 45.84576:1003:3000.0"
  grid_specs_hrrrak="nps:225:60.000000 185.117126:1299:3000.0 41.612949:919:3000.0"

  for grid in ${ADDNL_OUTPUT_GRIDS[@]}
  do
    for leveltype in dawp rd3d sfc
    do
      
      eval grid_specs=\$grid_specs_${grid}
      subdir=${postprd_dir}/${grid}_grid
      mkdir -p ${subdir}/${fhr}
      bg_remap=${subdir}/${NET}.t${cyc}z.bg${leveltype}f${fhr}.${tmmark}.grib2

      # Interpolate fields to new grid
      eval infile=\$bg${leveltype}
      if [ ${NET} = "RRFS_NA_13km" ]; then
         wgrib2 ${infile} -set_bitmap 1 -set_grib_type c3 -new_grid_winds grid \
           -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH" \
           -new_grid_interpolation bilinear \
           -if ":(WEASD|APCP|NCPCP|ACPCP|SNOD):" -new_grid_interpolation budget -fi \
           -if ":(NCONCD|NCCICE|SPNCR|CLWMR|CICE|RWMR|SNMR|GRLE|PMTF|PMTC|REFC|CSNOW|CICEP|CFRZR|CRAIN|LAND|ICEC|TMP:surface|VEG|CCOND|SFEXC|MSLMA|PRES:tropopause|LAI|HPBL|HGT:planetary boundary layer):" -new_grid_interpolation neighbor -fi \
           -new_grid ${grid_specs} ${subdir}/${fhr}/tmp_${grid}.grib2 &
      else
         wgrib2 ${infile} -set_bitmap 1 -set_grib_type c3 -new_grid_winds grid \
           -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH" \
           -new_grid_interpolation neighbor \
           -new_grid ${grid_specs} ${subdir}/${fhr}/tmp_${grid}.grib2 &
      fi
      wait 

      # Merge vector field records
      wgrib2 ${subdir}/${fhr}/tmp_${grid}.grib2 -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH" -submsg_uv ${bg_remap} &
      wait 

      # Remove temporary files
      rm -f ${subdir}/${fhr}/tmp_${grid}.grib2

      # Save to com directory 
      mkdir -p ${comout}/${grid}_grid
      cp_vrfy ${bg_remap} ${comout}/${grid}_grid/${NET}.t${cyc}z.bg${leveltype}f${fhr}.${tmmark}.grib2

      if [ $leveltype = 'dawp' ]; then
         ln_vrfy -fs --relative ${comout}/${grid}_grid/${NET}.t${cyc}z.bg${leveltype}f${fhr}.${tmmark}.grib2 ${comout}/rrfs.t${cyc}z.prslev.f${fhr}.conus_3km.grib2
      fi

      if [ $leveltype = 'rd3d' ]; then
         ln_vrfy -fs --relative ${comout}/${grid}_grid/${NET}.t${cyc}z.bg${leveltype}f${fhr}.${tmmark}.grib2 ${comout}/rrfs.t${cyc}z.natlev.f${fhr}.conus_3km.grib2
      fi

      if [ $leveltype = 'sfc' ]; then
         ln_vrfy -fs --relative ${comout}/${grid}_grid/${NET}.t${cyc}z.bg${leveltype}f${fhr}.${tmmark}.grib2 ${comout}/rrfs.t${cyc}z.testbed.f${fhr}.conus_3km.grib2
      fi

      # Link output for transfer from Jet to web
      ln_vrfy -fs --relative ${comout}/${grid}_grid/${NET}.t${cyc}z.bg${leveltype}f${fhr}.${tmmark}.grib2 ${comout}/${grid}_grid/BG${leveltype^^}_${basetime}${post_fhr}00
    done
  done
fi

rm_vrfy -rf ${fhr_dir}
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Post-processing for forecast hour $fhr completed successfully.

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

