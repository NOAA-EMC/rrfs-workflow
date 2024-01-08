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

This script, along with the python script it calls, is used to remap the 
fvcom output from the 5 lakes onto the RRFS grid. It maps skin temp and 
ice concentration. The resulting file is used by RRFS for improving lake 
effect snow forecasts.
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
valid_args=( "modelinputdir" "FIXLAM" "FVCOM_DIR" "YYYYJJJHH" "YYYYMMDD" "YYYYMMDDm1" "HH")
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

# Working directory
dir=${modelinputdir}/fvcom_remap

mkdir -m 775 -p ${dir}
cd ${dir}

# FVCOM output files
# PDY and cycle of forecast period - if most recent files are not available, look back one cycle
if [ $HH -eq 02 -o $HH -eq 03 -o $HH -eq 04 -o $HH -eq 05 -o $HH -eq 06 -o $HH -eq 07 ]; then
  PDYf=$YYYYMMDD
  PDYfm1=$YYYYMMDDm1
  cycf=00	# 00Z forecast files are available ~02Z on WCOSS2
  cycfm1=18	# 18Z forecast files from the previous day
elif [ $HH -eq 08 -o $HH -eq 09 -o $HH -eq 10 -o $HH -eq 11 -o $HH -eq 12 -o $HH -eq 13 ]; then
  PDYf=$YYYYMMDD
  PDYfm1=$YYYYMMDD
  cycf=06	# 06Z forecast files are available ~08Z on WCOSS2
  cycfm1=00	# 00Z forecast files
elif [ $HH -eq 14 -o $HH -eq 15 -o $HH -eq 16 -o $HH -eq 17 -o $HH -eq 18 -o $HH -eq 19 ]; then
  PDYf=$YYYYMMDD
  PDYfm1=$YYYYMMDD
  cycf=12	# 12Z forecast files are available ~14Z on WCOSS2
  cycfm1=06	# 06Z forecast files
elif [ $HH -eq 20 -o $HH -eq 21 -o $HH -eq 22 -o $HH -eq 23 ]; then
  PDYf=$YYYYMMDD
  PDYfm1=$YYYYMMDD
  cycf=18	# 18Z forecast files are available ~20Z on WCOSS2
  cycfm1=12	# 12Z forecast files
elif [ $HH -eq 00 -o $HH -eq 01 ]; then
  PDYf=$YYYYMMDDm1
  PDYfm1=$YYYYMMDDm1
  cycf=18	# 18Z forecast files from the previous day are available ~20Z on WCOSS2
  cycfm1=12	# 12Z forecast files from the previous day
fi

# Hour of forecast period - if most recent files are not available, look back one cycle
if [ $HH -eq 00 -o $HH -eq 06 -o $HH -eq 12 -o $HH -eq 18 ]; then
  fhr=006	# The 6-hr forecast from cycf (defined above)
  fhrm1=012	# The 12-hr forecast from cycfm1 (defined above)
elif [ $HH -eq 01 -o $HH -eq 07 -o $HH -eq 13 -o $HH -eq 19 ]; then
  fhr=007	# The 7-hr forecast from cycf
  fhrm1=013	# The 13-hr forecast from cycfm1
elif [ $HH -eq 02 -o $HH -eq 08 -o $HH -eq 14 -o $HH -eq 20 ]; then
  fhr=002	# The 2-hr forecast from cycf
  fhrm1=008	# The 8-hr forecast from cycfm1
elif [ $HH -eq 03 -o $HH -eq 09 -o $HH -eq 15 -o $HH -eq 21 ]; then
  fhr=003	# The 3-hr forecast from cycf
  fhrm1=009	# The 9-hr forecast from cycfm1
elif [ $HH -eq 04 -o $HH -eq 10 -o $HH -eq 16 -o $HH -eq 22 ]; then
  fhr=004	# The 4-hr forecast from cycf
  fhrm1=010	# The 10-hr forecast from cycfm1
elif [ $HH -eq 05 -o $HH -eq 11 -o $HH -eq 17 -o $HH -eq 23 ]; then
  fhr=005	# The 5-hr forecast from cycf
  fhrm1=011	# The 11-hr forecast from cycfm1
fi

# Find the most recent FVCOM files
if [ "$MACHINE" = "WCOSS2" ]; then
  erie="${FVCOM_DIR}/leofs.${PDYf}/nos.leofs.fields.f${fhr}.${PDYf}.t${cycf}z.nc"
  mh="${FVCOM_DIR}/lmhofs.${PDYf}/nos.lmhofs.fields.f${fhr}.${PDYf}.t${cycf}z.nc"
  sup="${FVCOM_DIR}/lsofs.${PDYf}/nos.lsofs.fields.f${fhr}.${PDYf}.t${cycf}z.nc"
  ont="${FVCOM_DIR}/loofs.${PDYf}/nos.loofs.fields.f${fhr}.${PDYf}.t${cycf}z.nc"

  erie2="${FVCOM_DIR}/leofs.${PDYfm1}/nos.leofs.fields.f${fhrm1}.${PDYfm1}.t${cycfm1}z.nc"
  mh2="${FVCOM_DIR}/lmhofs.${PDYfm1}/nos.lmhofs.fields.f${fhrm1}.${PDYfm1}.t${cycfm1}z.nc"
  sup2="${FVCOM_DIR}/lsofs.${PDYfm1}/nos.lsofs.fields.f${fhrm1}.${PDYfm1}.t${cycfm1}z.nc"
  ont2="${FVCOM_DIR}/loofs.${PDYfm1}/nos.loofs.fields.f${fhrm1}.${PDYfm1}.t${cycfm1}z.nc"

else

  erie="${FVCOM_DIR}/leofs/nos.leofs.fields.f${fhr}.${PDYf}.${cycf}z.nc"
  mh="${FVCOM_DIR}/lmhofs/nos.lmhofs.fields.f${fhr}.${PDYf}.${cycf}z.nc"
  sup="${FVCOM_DIR}/lsofs/nos.lsofs.fields.f${fhr}.${PDYf}.${cycf}z.nc"
  ont="${FVCOM_DIR}/loofs/nos.loofs.fields.f${fhr}.${PDYf}.${cycf}z.nc"

  erie2="${FVCOM_DIR}/leofs/nos.leofs.fields.f${fhrm1}.${PDYfm1}.${cycfm1}z.nc"
  mh2="${FVCOM_DIR}/lmhofs/nos.lmhofs.fields.f${fhrm1}.${PDYfm1}.${cycfm1}z.nc"
  sup2="${FVCOM_DIR}/lsofs/nos.lsofs.fields.f${fhrm1}.${PDYfm1}.${cycfm1}z.nc"
  ont2="${FVCOM_DIR}/loofs/nos.loofs.fields.f${fhrm1}.${PDYfm1}.${cycfm1}z.nc"
fi

if [[ -e "$erie" && -e "$mh" && -e "$sup" && -e "$ont" ]]; then
  output_erie=$erie
  output_mh=$mh
  output_sup=$sup
  output_ont=$ont
elif [[ -e "$erie2" && -e "$mh2" && -e "$sup2" && -e "$ont2" ]]; then
  output_erie=$erie2
  output_mh=$mh2
  output_sup=$sup2
  output_ont=$ont2
else
  message_txt="WARNING: No FVCOM data is available."
  print_info_msg "${message_txt}"
  if [ ! -z "${MAILTO}" ] && [ "${MACHINE}" = "WCOSS2" ]; then
    echo "${message_txt}" | mail.py ${MAILTO}
  fi
fi

# names of missing input files to the Python script
siglay0_tmp1="erie_siglay0_missing.nc"
siglay0_tmp2="lmhofs_siglay0_missing.nc"
siglay0_tmp3="sup_siglay0_missing.nc"
siglay0_tmp4="ont_siglay0_missing.nc"

ilake=1
ilake_use=0
for fn in $output_erie $output_mh $output_sup $output_ont
do
   ilake_use=`expr $ilake_use + 1`
   echo 'subsetting surface layer only using nowcast file'
   echo $fn

   ncks -O -d siglay,0 -d siglev,0 $fn siglay0_tmp${ilake}.nc

   if [ $ilake -eq 1 ]; then siglay0_tmp1=siglay0_tmp${ilake}.nc; fi
   if [ $ilake -eq 2 ]; then siglay0_tmp2=siglay0_tmp${ilake}.nc; fi
   if [ $ilake -eq 3 ]; then siglay0_tmp3=siglay0_tmp${ilake}.nc; fi
   if [ $ilake -eq 4 ]; then siglay0_tmp4=siglay0_tmp${ilake}.nc; fi
   ls -l siglay0_tmp${ilake}.nc
   samplefn=siglay0_tmp${ilake}.nc
   ilake=`expr $ilake + 1`
done

echo $ilake_use' fvcom output files found - proceed...'

# extract GL mask variables
echo 'Copying a file for GL mask on RRFS grid ...'
cp ${FIXLAM}/${CRES}_fvcom_mask.nc ./tmp.nc	# RRFS CONUS

# get time info
echo 'getting time information from a sample FVCOM output file...'
echo $samplefn
ncks -O -h -v time,Times $samplefn time.nc
ncrename -O -h -d time,Time time.nc # rename
ncks -h -A time.nc tmp.nc # append
ncdump -v Times tmp.nc | tail -52
rm time.nc

# add a variable container for tsfc
echo 'adding variables (blank for now) to output file ...'
ncap2 -O -h -s 'twsfc[$Time,$lat,$lon]=glmask' tmp.nc out_fv3grid.nc
ncatted -O -h -a long_name,twsfc,o,c,water_surface_temperature out_fv3grid.nc
ncatted -O -h -a units,twsfc,o,c,degC out_fv3grid.nc
ncatted -O -h -a description,twsfc,o,c,"water surface temperature" out_fv3grid.nc
ncap2 -O -h -s 'tisfc[$Time,$lat,$lon]=glmask' out_fv3grid.nc out_fv3grid.nc
ncatted -O -h -a long_name,twsfc,o,c,water_surface_temperature out_fv3grid.nc
ncatted -O -h -a long_name,tisfc,o,c,ice_surface_temperature out_fv3grid.nc
ncatted -O -h -a units,tisfc,o,c,degC out_fv3grid.nc
ncatted -O -h -a description,tisfc,o,c,"ice surface temperature" out_fv3grid.nc
ncap2 -O -h -s 'aice[$Time,$lat,$lon]=glmask' out_fv3grid.nc out_fv3grid.nc
ncatted -O -h -a long_name,aice,o,c,ice_concentration out_fv3grid.nc
ncatted -O -h -a units,aice,o,c,- out_fv3grid.nc
ncatted -O -h -a description,aice,o,c,"ice fraction [0-1]" out_fv3grid.nc
ncap2 -O -h -s 'vice[$Time,$lat,$lon]=glmask' out_fv3grid.nc out_fv3grid.nc
ncatted -O -h -a long_name,vice,o,c,mean_ice_volume out_fv3grid.nc
ncatted -O -h -a units,vice,o,c,m out_fv3grid.nc
ncatted -O -h -a description,vice,o,c,"mean ice volume [m]" out_fv3grid.nc
ncap2 -O -h -s 'tsfc[$Time,$lat,$lon]=glmask' out_fv3grid.nc out_fv3grid.nc
ncatted -O -h -a long_name,tsfc,o,c,lake_skin_temperature out_fv3grid.nc
ncatted -O -h -a units,tsfc,o,c,degC out_fv3grid.nc
ncatted -O -h -a description,tsfc,o,c,"skin temperature of lake and ice surfaces (weighted-mean based on ice concentration)" out_fv3grid.nc

# edit mask attributes
ncatted -O -h -a description,glmask,o,c,'Great Lakes mask (1 if overwater 0 otherwise)' out_fv3grid.nc

# run interpolation script
echo 'now running the Python script for remapping ...'
echo $siglay0_tmp1 $siglay0_tmp2 $siglay0_tmp3 $siglay0_tmp4
python ${USHdir}/fvcom_remap.py $siglay0_tmp1 $siglay0_tmp2 $siglay0_tmp3 $siglay0_tmp4 $PREDEF_GRID_NAME > python.log
cat python.log
if [ "`tail -1 python.log`" != "fvcom_remap.py completed successfully" ]; then
  err_exit "WARNING: Problem with fvcom_remap.py - ABORT"
fi

# extract skin temp info
ncks -O -h -v geolon,geolat,glmask,twsfc,tisfc,aice,vice,tsfc,time,Times out_fv3grid.nc tsfc_fv3grid.nc
ncap2 -O -s 'geolon=double(geolon);geolat=double(geolat);time=double(time)' tsfc_fv3grid.nc tsfc_fv3grid.nc
echo 'skin temp info extracted'

mv tsfc_fv3grid.nc tsfc_fv3grid_${YYYYJJJHH}.nc

ncksopts='-4 --deflate 1'
echo
echo "compressing (${ncksopts})..."
ncks $ncksopts tsfc_fv3grid_${YYYYJJJHH}.nc tsfc_fv3grid_${YYYYJJJHH}2.nc
mv tsfc_fv3grid_${YYYYJJJHH}2.nc ${FVCOM_FILE}_${YYYYJJJHH}.nc

exit
