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

This is the ex-script for the task that runs the post-processor (UPP) on
the output files corresponding to a specified forecast hour.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set environment
#
#-----------------------------------------------------------------------
#
ulimit -a

case $MACHINE in

  "WCOSS2")
    export OMP_NUM_THREADS=${TPP_POST}
    export MP_IOAGENT_CNT=all
    export MP_IO_BUFFER_SIZE=8M
    export MP_BINDPROC=NO
    export MP_SHARED_MEMORY=yes
    export FI_OFI_RXM_SAR_LIMIT=3145728
    export OMP_STACKSIZE=1G
    ncores=$(( NNODES_POST*PPN_POST))
    APRUN="mpiexec -n ${ncores} -ppn ${PPN_POST} --cpu-bind core --depth ${OMP_NUM_THREADS}"
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
UPP_DIR=${UPP_DIR:-$HOMErrfs/sorc/UPP}
#
#-----------------------------------------------------------------------
#
# Get the cycle date and hour (in formats of yyyymmdd and hh, respectively)
# from CDATE.
#
#-----------------------------------------------------------------------
#
yyyymmdd=${CDATE:0:8}
hh=${CDATE:8:2}
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
dyn_file="${shared_forecast_output_data}/dynf${fhr}.nc"
phy_file="${shared_forecast_output_data}/phyf${fhr}.nc"

SUBH_GEN=0

len_fhr=${#fhr}
if [ ${len_fhr} -eq 9 ]; then
  post_fhr=${fhr:0:3}
  post_min=${fhr:4:2}
  if [ ${post_min} -lt ${nsout_min} ]; then
    post_min=00
#	  if [ $post_fhr -ge 1 -a $post_fhr -le $POSTPROC_SUBH_LEN_HRS ]
	  if [ $post_fhr -ge 1 -a $post_fhr -le 18 ]
	  then
          SUBH_GEN=1
	  fi
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
 MODELNAME='FV3R'
 SUBMODELNAME='FV3R'
 fileNameFlux='${phy_file}'
 fileNameFlat='postxconfig-NT.txt'
/

 &NAMPGB
 KPO=47,PO=1000.,975.,950.,925.,900.,875.,850.,825.,800.,775.,750.,725.,700.,675.,650.,625.,600.,575.,550.,525.,500.,475.,450.,425.,400.,375.,350.,325.,300.,275.,250.,225.,200.,175.,150.,125.,100.,70.,50.,30.,20.,10.,7.,5.,3.,2.,1.,slrutah_on=.true.,gtg_on=.false.,
 /
EOF

#-----------------------------------------------------------------------
#
# stage necessary files in run directory.
#
#-----------------------------------------------------------------------
#
cpreq -p ${UPP_DIR}/parm/nam_micro_lookup.dat ./eta_micro_lookup.dat

# get crtm fix files
for what in "amsre_aqua" "imgr_g11" "imgr_g12" "imgr_g13" \
    "imgr_g15" "imgr_mt1r" "imgr_mt2" "seviri_m10" \
    "ssmi_f13" "ssmi_f14" "ssmi_f15" "ssmis_f16" \
    "ssmis_f17" "ssmis_f18" "ssmis_f19" "ssmis_f20" \
    "tmi_trmm" "v.seviri_m10" "imgr_insat3d" "abi_gr" \
    "ahi_himawari8" ; do
    ln -s "${FIX_UPP_CRTM}/${what}.TauCoeff.bin" .
    ln -s "${FIX_UPP_CRTM}/${what}.SpcCoeff.bin" .
done

for what in 'Aerosol' 'Cloud' ; do
    ln -s "${FIX_UPP_CRTM}/${what}Coeff.bin" .
done

for what in  ${FIX_UPP_CRTM}/*Emis* ; do
   ln -s $what .
done

if [ ${USE_CUSTOM_POST_CONFIG_FILE} = "TRUE" ]; then
# For RRFS: use special postcntrl for fhr=0,1 to eliminate duplicate 
# max/min hourly (f000 only) and accumulation fields (f000 and f001);
# use special postcntrl for ensemble and firewx forecasts
  if [ ${PREDEF_GRID_NAME} = "RRFS_NA_3km" ] || [ ${PREDEF_GRID_NAME} = "RRFS_FIREWX_1.5km" ]; then
    if [ ${post_fhr} -eq 000 ]; then
      if [ ${WGF} = "det" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-rrfs_f00.txt"
      elif [ ${WGF} = "ensf" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-refs_f00.txt"
      elif [ ${WGF} = "firewx" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-rrfs_firewx_f00.txt"
      fi
    elif [ ${post_fhr} -eq 001 ]; then
      if [ ${WGF} = "det" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-rrfs_f01.txt"
      elif [ ${WGF} = "ensf" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-refs_f01.txt"
      elif [ ${WGF} = "firewx" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-rrfs_firewx_f01.txt"
      fi
    else
      if [ ${WGF} = "det" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-rrfs.txt"
      elif [ ${WGF} = "ensf" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-refs.txt"
      elif [ ${WGF} = "firewx" ]; then
        CUSTOM_POST_CONFIG_FP="${HOMErrfs}/fix/upp/postxconfig-NT-rrfs_firewx.txt"
      fi
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
to the post forecast hour directory (DATA):
  CUSTOM_POST_CONFIG_FP = \"${CUSTOM_POST_CONFIG_FP}\"
  CUSTOM_POST_PARAMS_FP = \"${CUSTOM_POST_PARAMS_FP}\"
  DATA = \"${DATA}\"
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
forecast hour directory (DATA):
  post_config_fp = \"${post_config_fp}\"
  post_params_fp = \"${post_params_fp}\"
  DATA = \"${DATA}\"
===================================================================="
fi
cpreq -p ${post_config_fp} ./postxconfig-NT.txt
cpreq -p ${post_params_fp} ./params_grib2_tbl_new

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
# For ensemble forecasts, set the e1, e2, and e3 environment variables
# that are needed by the UPP code.
#
# e1 - type of ensemble forecast (3 for REFS - positively perturbed forecast -
# refer to Grib2 Code Table 4.6)
# e2 - 2-digit member number (e.g. 01, 02, 03, 04, 05)
# e3 - total number of ensemble members (5 for REFS)
#
#-----------------------------------------------------------------------
#
if [ ${WGF} = "ensf" ]; then
  export e1=3
  export e2=`echo ${MEMBER_NAME} | cut -c2-3`
  export e3=5
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

${APRUN} $EXECrrfs/$pgm < itag >>$pgmout 2>errfile
export err=$?; err_chk
#
#-----------------------------------------------------------------------
#
# Move (and rename) the output files.
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
# 9 is sub-hourly forecast and 3 is full hour forecast only.
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
gridspacing=""
if [ ${PREDEF_GRID_NAME} = "RRFS_FIREWX_1.5km" ]; then
  gridname="firewx"
  gridspacing="1p5km"
elif [ ${PREDEF_GRID_NAME} = "RRFS_CONUS_25km" ]; then
  gridname="conus"
  gridspacing="25km"
elif [ ${PREDEF_GRID_NAME} = "RRFS_CONUS_13km" ]; then
  gridname="conus"
  gridspacing="13km"
elif [ ${PREDEF_GRID_NAME} = "RRFS_CONUS_3km" ]; then
  gridname="conus"
  gridspacing="3km"
elif [ ${PREDEF_GRID_NAME} = "RRFS_NA_3km" ]; then
  gridname="na"
  gridspacing="3km"
fi
net4=$(echo ${NET:0:4} | tr '[:upper:]' '[:lower:]')

# Include member number with ensemble forecast output
if [ ${DO_ENSFCST} = "TRUE" ]; then
  prslev=${DATA}/${net4}.t${cyc}z.${mem_num}.prslev.${gridspacing}.f${fhr}.${gridname}.grib2
  natlev=${DATA}/${net4}.t${cyc}z.${mem_num}.natlev.${gridspacing}.f${fhr}.${gridname}.grib2
  nbmfld=${DATA}/${net4}.t${cyc}z.${mem_num}.nbmfld.${gridspacing}.f${fhr}.${gridname}.grib2
else
  prslev=${DATA}/${net4}.t${cyc}z.prslev.${gridspacing}.f${fhr}.${gridname}.grib2
  natlev=${DATA}/${net4}.t${cyc}z.natlev.${gridspacing}.f${fhr}.${gridname}.grib2
  nbmfld=${DATA}/${net4}.t${cyc}z.nbmfld.${gridspacing}.f${fhr}.${gridname}.grib2
fi

if [ -f PRSLEV.GrbF${post_fhr} ]; then
# If post_min is 15, 30, or 45, then copy the grib2 file to umbrella_post_data
  if [ $post_min = 15 -o $post_min = 30 -o $post_min = 45 ]; then
    cpreq -p PRSLEV.GrbF${post_fhr} ${umbrella_post_data}
    echo "Subhourly file copied to umbrella data directory, exit post task"
    exit
  fi

  wgrib2 PRSLEV.GrbF${post_fhr} -set center 7 -grib ${prslev} >>$pgmout 2>>errfile

  if [ $SUBH_GEN = 1 ]
  then
    prslev_subh_combo=${DATA}/${net4}.t${cyc}z.prslev.${gridspacing}.subh.f${fhr}.${gridname}.grib2
    prslev_subh=${DATA}/PRSLEV.GrbF${fhr}.00
    wgrib2 ${prslev} -not_if 'ave fcst' | grep -F -f ${FIX_UPP}/subh_fields.txt | wgrib2 -i -grib ${prslev_subh}  ${prslev}

    fhrm1tmp="$((10#$fhr-1))"
    fhrm1=`printf "%02d\n" $fhrm1tmp`

    tm15=${umbrella_post_data}/PRSLEV.GrbF${fhrm1}.45
    tm30=${umbrella_post_data}/PRSLEV.GrbF${fhrm1}.30
    tm45=${umbrella_post_data}/PRSLEV.GrbF${fhrm1}.15

# Safety check to ensure all 15 min output files are available
    looplim=30
    loop=1
    while [ $loop -le $looplim ]
    do
      if [ -e $tm15 -a -e $tm30 -a -e $tm45 ]
      then
        break
      else 
        loop=$((loop+1))
        sleep 20
      fi
      if [ $loop -ge $looplim ]
      then
        msg="FATAL ERROR: ABORTING after 10 minutes of waiting for 15 minute UPP output $tm15 $tm30 $tm45"
        err_exit $msg
      fi
    done

    if [ -e $prslev_subh -a -e $tm15 -a -e $tm30 -a -e $tm45 ]
    then
      cat $tm45 $tm30 $tm15 $prslev_subh > PRSLEV.GrbF${fhr}_subh
      wgrib2 PRSLEV.GrbF${fhr}_subh -set center 7 -grib $prslev_subh_combo >> $pgmout 2>> errfile
    else
      msg="FATAL ERROR: ABORTING due to missing 15 minute UPP output $prslev_subh $tm15 $tm30 $tm45"
      err_exit $msg
    fi 
  fi # SUB_GEN=1 test
fi # PRSLEV test

if [ -f NATLEV.GrbF${post_fhr} ]; then
  wgrib2 NATLEV.GrbF${post_fhr} -set center 7 -grib ${natlev} >>$pgmout 2>>errfile
fi

if [ -f NBMFLD.GrbF${post_fhr} ]; then
  wgrib2 NBMFLD.GrbF${post_fhr} -set center 7 -grib ${nbmfld} >>$pgmout 2>>errfile
fi
#
#-----------------------------------------------------------------------
#   copy post-processed grib2 files to COMOUT
#-----------------------------------------------------------------------
#
cpreq -p ${prslev} ${COMOUT}
# Native level output is disabled for ensemble forecasts after f00
if [[ -f ${natlev} ]]; then
  cpreq -p ${natlev} ${COMOUT}
fi
# NBMFLD file is only generated for RRFS and REFS
if [[ -f ${nbmfld} ]]; then
  cpreq -p ${nbmfld} ${COMOUT}
  wgrib2 ${nbmfld} -s > ${COMOUT}/${net4}.t${cyc}z.nbmfld.${gridspacing}.f${fhr}.${gridname}.grib2.idx
fi

# Only one latlons_corners file per cycle is needed in COMOUT - make this change later
if [ ${PREDEF_GRID_NAME} = "RRFS_FIREWX_1.5km" ]; then
  cpreq -p latlons_corners.txt.f${fhr} ${COMOUT}
fi
if [ ${SUBH_GEN} = 1 ]; then
  cpreq -p ${prslev_subh_combo} ${COMOUT}
fi

#-----------------------------------------------------------------------
#   clean forecast umbrella data directory
#-----------------------------------------------------------------------
#if [ ${fhr#0} -eq ${FCST_LEN_HRS_CYCLES[$cyc]#0} ]; then
#  if [ -f ${umbrella_forecast_data}/forecast_${CYCLE_TYPE}_clean.flag ]; then
#    if [ ${KEEPDATA} == "YES" ]; then
#      cd ${umbrella_forecast_data}
#      backup_directory=BACKUP_$$
#      mkdir ${backup_directory}
#      mv output RESTART ./${backup_directory}
#    else
#      rm -rf ${umbrella_forecast_data}
#    fi
#    cd $DATA
#  fi
#fi
#
#-----------------------------------------------------------------------
#   clean forecast netcdf files for saving space
#-----------------------------------------------------------------------
#
#if [ ${PREDEF_GRID_NAME} = "RRFS_NA_3km" ]; then
#  indx="00 06 12 18"
#  for i in $indx
#  do
#    if [ "$cyc" == $i ]; then
#      echo "long forecast cycle, keep .nc for bufrsnd" 
#    else
#      rm -f ${dyn_file}
#      rm -f ${phy_file}
#    fi
#  done
#fi
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
