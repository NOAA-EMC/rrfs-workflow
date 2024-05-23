#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHdir/source_util_funcs.sh
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
"fhr" \
"tmmark" \
"cycle_type" \
"ensmem_indx" \
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
# Set environment
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case $MACHINE in

  "WCOSS2")
    export OMP_NUM_THREADS=${TPP_RUN_POST}
    export MP_IOAGENT_CNT=all
    export MP_IO_BUFFER_SIZE=8M
    export MP_BINDPROC=NO
    export MP_SHARED_MEMORY=yes
    export FI_OFI_RXM_SAR_LIMIT=3145728
    export OMP_STACKSIZE=1G
    ncores=$(( NNODES_RUN_POST*PPN_RUN_POST))
    APRUN="mpiexec -n ${ncores} -ppn ${PPN_RUN_POST} --cpu-bind core --depth ${OMP_NUM_THREADS}"
    ;;

  "HERA")
    APRUN="srun --export=ALL"
    ;;

  "ORION")
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=1024M
    APRUN="srun --export=ALL"
    ;;

  "HERCULES")
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=1024M
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
# Remove any files from previous runs.
#
#-----------------------------------------------------------------------
#
rm -f fort.*
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
#
#-----------------------------------------------------------------------
#
# Create a text file (itag) containing arguments to pass to the post-
# processing executable.
#
#-----------------------------------------------------------------------
#
#  set to 15 minute output for subhour
if [ "${NSOUT_MIN}" = "0" ]; then
  nsout_min=61
else
  if [ "${NSOUT_MIN}" = "15" ]; then
    nsout_min=15
  else
    sout_min=61
    echo " WARNING: unknown subhour output frequency (NSOUT_MIN) value, set nsout_min to 61"
  fi
fi
#
dyn_file="${run_dir}/dynf${fhr}.nc"
phy_file="${run_dir}/phyf${fhr}.nc"

len_fhr=${#fhr}
if [ ${len_fhr} -eq 9 ]; then
  post_fhr=${fhr:0:3}
  post_min=${fhr:4:2}
  if [ ${post_min} -lt ${nsout_min} ]; then
    post_min=00
  fi
else
  post_fhr=${fhr}
  post_min=00
fi

post_time=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${post_fhr} hours" "+%Y%m%d%H" )
post_yyyy=${post_time:0:4}
post_mm=${post_time:4:2}
post_dd=${post_time:6:2}
post_hh=${post_time:8:2}

cat > itag <<EOF
&model_inputs
 fileName='${dyn_file}'
 IOFORM='netcdf'
 grib='grib2'
 DateStr='${post_yyyy}-${post_mm}-${post_dd}_${post_hh}:${post_min}:00'
 MODELNAME='${POST_FULL_MODEL_NAME}'
 SUBMODELNAME='${POST_SUB_MODEL_NAME}'
 fileNameFlux='${phy_file}'
 fileNameFlat='postxconfig-NT.txt'
/

 &NAMPGB
 KPO=47,PO=1000.,975.,950.,925.,900.,875.,850.,825.,800.,775.,750.,725.,700.,675.,650.,625.,600.,575.,550.,525.,500.,475.,450.,425.,400.,375.,350.,325.,300.,275.,250.,225.,200.,175.,150.,125.,100.,70.,50.,30.,20.,10.,7.,5.,3.,2.,1.,slrutah_on=.true.,gtg_on=.true.,
 /
EOF

#-----------------------------------------------------------------------
#
# GTG_rrfs config file in UPP source code sub directory
#
#-----------------------------------------------------------------------

cp ${UPP_DIR}/sorc/ncep_post.fd/post_gtg.fd/gtg.config.rrfs ./gtg.config.rrfs
cp ${UPP_DIR}/sorc/ncep_post.fd/post_gtg.fd/gtg.input.rrfs ./gtg.input.rrfs

#-----------------------------------------------------------------------
#
# stage necessary files in fhr_dir.
#
#-----------------------------------------------------------------------
#
cp ${UPP_DIR}/parm/nam_micro_lookup.dat ./eta_micro_lookup.dat

ln -snf ${FIX_UPP_CRTM}/*bin ./

if [ ${USE_CUSTOM_POST_CONFIG_FILE} = "TRUE" ]; then
# For RRFS: use special postcntrl for fhr=0,1 to eliminate duplicate 
# max/min hourly (f000 only) and accumulation fields (f000 and f001);
# use special postcntrl for ensemble and firewx forecasts to eliminate
# smoke/dust fields
  if [ ${PREDEF_GRID_NAME} = "RRFS_NA_3km" ] || [ ${PREDEF_GRID_NAME} = "RRFS_FIREWX_1.5km" ]; then
    if [ ${post_fhr} -eq 000 ]; then
      if [ "${DO_SMOKE_DUST}" = "TRUE" ]; then
        CUSTOM_POST_CONFIG_FP="$(cd "$( dirname "${BASH_SOURCE[0]}" )/.." &>/dev/null&&pwd)/fix/upp/postxconfig-NT-rrfs_f00.txt"
      else
        CUSTOM_POST_CONFIG_FP="$(cd "$( dirname "${BASH_SOURCE[0]}" )/.." &>/dev/null&&pwd)/fix/upp/postxconfig-NT-rrfs_nosmokedust_f00.txt"
      fi
    elif [ ${post_fhr} -eq 001 ]; then
      if [ "${DO_SMOKE_DUST}" = "TRUE" ]; then
        CUSTOM_POST_CONFIG_FP="$(cd "$( dirname "${BASH_SOURCE[0]}" )/.." &>/dev/null&&pwd)/fix/upp/postxconfig-NT-rrfs_f01.txt"
      else
        CUSTOM_POST_CONFIG_FP="$(cd "$( dirname "${BASH_SOURCE[0]}" )/.." &>/dev/null&&pwd)/fix/upp/postxconfig-NT-rrfs_nosmokedust_f01.txt"
      fi
    elif [ "${DO_SMOKE_DUST}" = "FALSE" ]; then
      CUSTOM_POST_CONFIG_FP="$(cd "$( dirname "${BASH_SOURCE[0]}" )/.." &>/dev/null&&pwd)/fix/upp/postxconfig-NT-rrfs_nosmokedust.txt"
    fi
  fi
  if [ ${post_min} -ge ${nsout_min} ]; then
     CUSTOM_POST_CONFIG_FP="${FIX_UPP}/postxconfig-NT-rrfs_subh.txt"
  fi
  post_config_fp="${CUSTOM_POST_CONFIG_FP}"
  post_params_fp="${CUSTOM_POST_PARAMS_FP}"
  print_info_msg "
====================================================================
Copying the user-defined post flat file specified by CUSTOM_POST_CONFIG_FP
to the post forecast hour directory (fhr_dir):
  CUSTOM_POST_CONFIG_FP = \"${CUSTOM_POST_CONFIG_FP}\"
  CUSTOM_POST_PARAMS_FP = \"${CUSTOM_POST_PARAMS_FP}\"
  fhr_dir = \"${fhr_dir}\"
===================================================================="
else
  post_config_fp="${FIX_UPP}/postxconfig-NT-rrfs.txt"
  post_params_fp="${FIX_UPP}/params_grib2_tbl_new"
  if [ ${post_min} -ge ${nsout_min} ]; then
     post_config_fp="${FIX_UPP}/postxconfig-NT-rrfs_subh.txt"
  fi
  print_info_msg "
====================================================================
Copying the default post flat file specified by post_config_fp to the post
forecast hour directory (fhr_dir):
  post_config_fp = \"${post_config_fp}\"
  post_params_fp = \"${post_params_fp}\"
  fhr_dir = \"${fhr_dir}\"
===================================================================="
fi
cp ${post_config_fp} ./postxconfig-NT.txt
cp ${post_params_fp} ./params_grib2_tbl_new

if [ ${PREDEF_GRID_NAME} = "RRFS_CONUS_3km_HRRRIC" ]; then
  grid_specs_rrfs="lambert:-97.5:38.500000 237.826355:1746:3000 21.885885:1014:3000"
elif [ ${PREDEF_GRID_NAME} = "RRFS_CONUS_3km" ]; then
  grid_specs_rrfs="lambert:-97.5:38.500000 237.280472:1799:3000 21.138115:1059:3000"
elif [ ${PREDEF_GRID_NAME} = "RRFS_NA_3km" ]; then
  grid_specs_rrfs="rot-ll:247.000000:-35.000000:0.000000 299.000000:4881:0.025000 -37.0000000:2961:0.025000"
elif [ ${PREDEF_GRID_NAME} = "GSD_RAP13km" ]; then
  grid_specs_rrfs="rot-ll:254.000000:-36.000000:0.000000 304.174600:956:0.1169118 -48.5768500:831:0.1170527"
fi
if [ ${PREDEF_GRID_NAME} = "RRFS_CONUS_3km_HRRRIC" ] || [ ${PREDEF_GRID_NAME} = "RRFS_CONUS_3km" ] || [ ${PREDEF_GRID_NAME} = "RRFS_NA_3km" ] || [ ${PREDEF_GRID_NAME} = "GSD_RAP13km" ]; then
  if [ -f ${FFG_DIR}/latest.FFG ]; then
    cp ${FFG_DIR}/latest.FFG .
    wgrib2 latest.FFG -match "0-12 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_12h.grib2
    wgrib2 latest.FFG -match "0-6 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_06h.grib2
    wgrib2 latest.FFG -match "0-3 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_03h.grib2
    wgrib2 latest.FFG -match "0-1 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_01h.grib2
  fi
  for ayear in 100y 10y 5y 2y ; do
    for ahour in 01h 03h 06h 12h 24h; do
      if [ -f ${FIX_UPP}/${PREDEF_GRID_NAME}/ari${ayear}_${ahour}.grib2 ]; then
        ln -snf ${FIX_UPP}/${PREDEF_GRID_NAME}/ari${ayear}_${ahour}.grib2 ari${ayear}_${ahour}.grib2
      fi
    done
  done
fi
#
#-----------------------------------------------------------------------
#
# Run the post-processor.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "Starting post-processing for fhr = $fhr hr..."

export pgm="upp.x"
. prep_step

${APRUN} $EXECdir/$pgm < itag >>$pgmout 2>errfile
export err=$?; err_chk
#
#-----------------------------------------------------------------------
#
# Move (and rename) the output files from the work directory to their
# final location (postprd_dir).  Then delete the work directory.
#
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
#
# A separate ${post_fhr} forecast hour variable is required for the post
# files, since they may or may not be three digits long, depending on the
# length of the forecast.
#
# A separate ${subh_fhr} is needed for subhour post.
#-----------------------------------------------------------------------
#
# get the length of the fhr string to decide format of forecast time stamp.
# 9 is sub-houry forecast and 3 is full hour forecast only.
len_fhr=${#fhr}
if [ ${len_fhr} -eq 9 ]; then
  post_min=${fhr:4:2}
  if [ ${post_min} -lt ${nsout_min} ]; then
    post_min=00
  fi
else
  post_min=00
fi

subh_fhr=${fhr}
if [ ${len_fhr} -eq 2 ]; then
  post_fhr=${fhr}
elif [ ${len_fhr} -eq 3 ]; then
  if [ "${fhr:0:1}" = "0" ]; then
    post_fhr="${fhr:1}"
  else
    post_fhr=${fhr}
  fi
elif [ ${len_fhr} -eq 9 ]; then
  if [ "${fhr:0:1}" = "0" ]; then
    if [ ${post_min} -eq 00 ]; then
      post_fhr="${fhr:1:2}"
      subh_fhr="${fhr:0:3}"
    else
      post_fhr="${fhr:1:2}.${fhr:4:2}"
    fi
  else
    if [ ${post_min} -eq 00 ]; then
      post_fhr="${fhr:0:3}"
      subh_fhr="${fhr:0:3}"
    else
      post_fhr="${fhr:0:3}.${fhr:4:2}"
    fi
  fi
else
  err_exit "\
The \${fhr} variable contains too few or too many characters:
  fhr = \"$fhr\""
fi

# replace fhr with subh_fhr
echo "fhr=${fhr} and subh_fhr=${subh_fhr}"
fhr=${subh_fhr}

gridname=""
if [ ${PREDEF_GRID_NAME} = "RRFS_FIREWX_1.5km" ]; then
  gridname="firewx."
fi
net4=$(echo ${NET:0:4} | tr '[:upper:]' '[:lower:]')

# Include member number with ensemble forecast output
if [ ${DO_ENSFCST} = "TRUE" ]; then
  ensmem_num=$(echo "${ensmem_indx}" | awk '{print $1+0}')	  # 1,2,3,4,5 for REFS
  bgdawp=${postprd_dir}/${net4}.t${cyc}z.m0${ensmem_num}.prslev.f${fhr}.${gridname}grib2
  bgrd3d=${postprd_dir}/${net4}.t${cyc}z.m0${ensmem_num}.natlev.f${fhr}.${gridname}grib2
  bgifi=${postprd_dir}/${net4}.t${cyc}z.m0${ensmem_num}.ififip.f${fhr}.${gridname}grib2
  bgavi=${postprd_dir}/${net4}.t${cyc}z.m0${ensmem_num}.aviati.f${fhr}.${gridname}grib2
else
  bgdawp=${postprd_dir}/${net4}.t${cyc}z.prslev.f${fhr}.${gridname}grib2
  bgrd3d=${postprd_dir}/${net4}.t${cyc}z.natlev.f${fhr}.${gridname}grib2
  bgifi=${postprd_dir}/${net4}.t${cyc}z.ififip.f${fhr}.${gridname}grib2
  bgavi=${postprd_dir}/${net4}.t${cyc}z.aviati.f${fhr}.${gridname}grib2
fi

if [ -f PRSLEV.GrbF${post_fhr} ]; then
  wgrib2 PRSLEV.GrbF${post_fhr} -set center 7 -grib ${bgdawp} >>$pgmout 2>>errfile
fi
if [ -f NATLEV.GrbF${post_fhr} ]; then
  wgrib2 NATLEV.GrbF${post_fhr} -set center 7 -grib ${bgrd3d} >>$pgmout 2>>errfile
fi

if [ -f IFIFIP.GrbF${post_fhr} ]; then
  wgrib2 IFIFIP.GrbF${post_fhr} -set center 7 -grib ${bgifi} >>$pgmout 2>>errfile
fi

if [ -f AVIATI.GrbF${post_fhr} ]; then
  wgrib2 AVIATI.GrbF${post_fhr} -set center 7 -grib ${bgavi} >>$pgmout 2>>errfile
fi

# Keep latlons_corners.txt file for RRFS fire weather grid
if [ ${PREDEF_GRID_NAME} = "RRFS_FIREWX_1.5km" ]; then
  cp ${postprd_dir}/${fhr}/latlons_corners.txt.f${fhr} ${postprd_dir}
fi

#
#-----------------------------------------------------------------------
#   clean forecast netcdf files for saving space
#-----------------------------------------------------------------------
#
if [ ${PREDEF_GRID_NAME} = "RRFS_NA_3km" ]; then
  indx="00 06 12 18"
  for i in $indx
  do
    if [ "$cyc" == $i ]; then
      echo "long forecast cycle, keep .nc for bufrsnd" 
    else
      rm -f ${dyn_file}
      rm -f ${phy_file}
    fi
  done
fi
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
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

