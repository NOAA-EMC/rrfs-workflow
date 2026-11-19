#!/bin/bash
set -x

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. "${USHrrfs}/source_util_funcs.sh"
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
# should consist of a set of name-value pairs of the form arg1=\"value1\",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( "INPUT_DATA" "FIXLAM" "FVCOM_DIR" "YYYYJJJHH" "YYYYMMDD" "YYYYMMDDm1" "HH" )
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
dir="${INPUT_DATA}/fvcom_remap"

if [[ ! -d "${dir}" ]]; then
  mkdir -p "${dir}" && chmod 775 "${dir}"
fi
cd "${dir}" || exit 1

# FVCOM output files
# PDY and cycle of forecast period - if most recent files are not available, look back one cycle
case "${HH}" in
  02|03|04|05|06|07|2|3|4|5|6|7)
    PDYf="${YYYYMMDD}"
    PDYfm1="${YYYYMMDDm1}"
    cycf="00"	# 00Z forecast files are available ~02Z on WCOSS2
    cycfm1="18"	# 18Z forecast files from the previous day
    ;;
  08|09|10|11|12|13|8|9)
    PDYf="${YYYYMMDD}"
    PDYfm1="${YYYYMMDD}"
    cycf="06"	# 06Z forecast files are available ~08Z on WCOSS2
    cycfm1="00"	# 00Z forecast files
    ;;
  14|15|16|17|18|19)
    PDYf="${YYYYMMDD}"
    PDYfm1="${YYYYMMDD}"
    cycf="12"	# 12Z forecast files are available ~14Z on WCOSS2
    cycfm1="06"	# 06Z forecast files
    ;;
  20|21|22|23)
    PDYf="${YYYYMMDD}"
    PDYfm1="${YYYYMMDD}"
    cycf="18"	# 18Z forecast files are available ~20Z on WCOSS2
    cycfm1="12"	# 12Z forecast files
    ;;
  00|01|0|1)
    PDYf="${YYYYMMDDm1}"
    PDYfm1="${YYYYMMDDm1}"
    cycf="18"	# 18Z forecast files from the previous day are available ~20Z on WCOSS2
    cycfm1="12"	# 12Z forecast files from the previous day
    ;;
esac

# Hour of forecast period - if most recent files are not available, look back one cycle
case "${HH}" in
  00|06|12|18|0|6)
    fhr="006"	# The 6-hr forecast from cycf (defined above)
    fhrm1="012"	# The 12-hr forecast from cycfm1 (defined above)
    ;;
  01|07|13|19|1|7)
    fhr="007"	# The 7-hr forecast from cycf
    fhrm1="013"	# The 13-hr forecast from cycfm1
    ;;
  02|08|14|20|2|8)
    fhr="002"	# The 2-hr forecast from cycf
    fhrm1="008"	# The 8-hr forecast from cycfm1
    ;;
  03|09|15|21|3|9)
    fhr="003"	# The 3-hr forecast from cycf
    fhrm1="009"	# The 9-hr forecast from cycfm1
    ;;
  04|10|16|22|4)
    fhr="004"	# The 4-hr forecast from cycf
    fhrm1="010"	# The 10-hr forecast from cycfm1
    ;;
  05|11|17|23|5)
    fhr="005"	# The 5-hr forecast from cycf
    fhrm1="011"	# The 11-hr forecast from cycfm1
    ;;
esac

# Find the most recent FVCOM files, using WCOSS option by default
#
erie="${FVCOM_DIR}/leofs.${PDYf}/leofs.t${cycf}z.${PDYf}.fields.f${fhr}.nc"
mh="${FVCOM_DIR}/lmhofs.${PDYf}/lmhofs.t${cycf}z.${PDYf}.fields.f${fhr}.nc"
sup="${FVCOM_DIR}/lsofs.${PDYf}/lsofs.t${cycf}z.${PDYf}.fields.f${fhr}.nc"
ont="${FVCOM_DIR}/loofs.${PDYf}/loofs.t${cycf}z.${PDYf}.fields.f${fhr}.nc"

erie2="${FVCOM_DIR}/leofs.${PDYfm1}/leofs.t${cycfm1}z.${PDYfm1}.fields.f${fhrm1}.nc"
mh2="${FVCOM_DIR}/lmhofs.${PDYfm1}/lmhofs.t${cycfm1}z.${PDYfm1}.fields.f${fhrm1}.nc"
sup2="${FVCOM_DIR}/lsofs.${PDYfm1}/lsofs.t${cycfm1}z.${PDYfm1}.fields.f${fhrm1}.nc"
ont2="${FVCOM_DIR}/loofs.${PDYfm1}/loofs.t${cycfm1}z.${PDYfm1}.fields.f${fhrm1}.nc"

if [[ -e "${erie}" && -e "${mh}" && -e "${sup}" && -e "${ont}" ]]; then
  output_erie="${erie}"
  output_mh="${mh}"
  output_sup="${sup}"
  output_ont="${ont}"
elif [[ -e "${erie2}" && -e "${mh2}" && -e "${sup2}" && -e "${ont2}" ]]; then
  output_erie="${erie2}"
  output_mh="${mh2}"
  output_sup="${sup2}"
  output_ont="${ont2}"
else
  message_txt="FATAL ERROR: Missing required FVCOM data from ${FVCOM_DIR}"
  err_exit "${message_txt}"
fi

# names of missing input files to the Python script
siglay0_tmp1="erie_siglay0_missing.nc"
siglay0_tmp2="lmhofs_siglay0_missing.nc"
siglay0_tmp3="sup_siglay0_missing.nc"
siglay0_tmp4="ont_siglay0_missing.nc"

ilake=1
ilake_use=0
for fn in "${output_erie}" "${output_mh}" "${output_sup}" "${output_ont}"; do
   (( ilake_use++ ))
   echo 'subsetting surface layer only using nowcast file'
   echo "${fn}"

   ncks -O -d siglay,0 -d siglev,0 "${fn}" "siglay0_tmp${ilake}.nc"

   if (( ilake == 1 )); then siglay0_tmp1="siglay0_tmp${ilake}.nc"; fi
   if (( ilake == 2 )); then siglay0_tmp2="siglay0_tmp${ilake}.nc"; fi
   if (( ilake == 3 )); then siglay0_tmp3="siglay0_tmp${ilake}.nc"; fi
   if (( ilake == 4 )); then siglay0_tmp4="siglay0_tmp${ilake}.nc"; fi
   ls -l "siglay0_tmp${ilake}.nc"
   samplefn="siglay0_tmp${ilake}.nc"
   (( ilake++ ))
done

echo "${ilake_use} fvcom output files found - proceed..."

# extract GL mask variables
echo 'Copying a file for GL mask on RRFS grid ...'
cpreq "${FIXLAM}/${CRES}_fvcom_mask.nc" ./tmp.nc	# RRFS CONUS

# get time info
echo 'getting time information from a sample FVCOM output file...'
echo "${samplefn}"
ncks -O -h -v time,Times "${samplefn}" time.nc
ncrename -O -h -d time,Time time.nc # rename
ncks -h -A time.nc tmp.nc # append
if ! (set -o pipefail; ncdump -v Times tmp.nc | tail -52); then
  echo "ERROR: failed to read Times from tmp.nc" >&2
  exit 1
fi
rm -f time.nc

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
echo "${siglay0_tmp1}" "${siglay0_tmp2}" "${siglay0_tmp3}" "${siglay0_tmp4}"
python "${USHrrfs}/fvcom_remap.py" "${siglay0_tmp1}" "${siglay0_tmp2}" "${siglay0_tmp3}" "${siglay0_tmp4}" "${PREDEF_GRID_NAME}" > python.log
cat python.log
python_last_line=$(tail -1 python.log) || {
  echo "ERROR: failed to read python.log" >&2
  exit 1
}
if [[ "${python_last_line}" != "fvcom_remap.py completed successfully" ]]; then
  err_exit "WARNING: Problem with fvcom_remap.py - ABORT"
fi

# extract skin temp info
ncks -O -h -v geolon,geolat,glmask,twsfc,tisfc,aice,vice,tsfc,time,Times out_fv3grid.nc tsfc_fv3grid.nc
ncap2 -O -s 'geolon=double(geolon);geolat=double(geolat);time=double(time)' tsfc_fv3grid.nc tsfc_fv3grid.nc
echo 'skin temp info extracted'

mv tsfc_fv3grid.nc "tsfc_fv3grid_${YYYYJJJHH}.nc"

ncksopts=( -4 --deflate 1 )
echo
echo "compressing (${ncksopts[*]})..."
ncks "${ncksopts[@]}" "tsfc_fv3grid_${YYYYJJJHH}.nc" "tsfc_fv3grid_${YYYYJJJHH}2.nc"
mv "tsfc_fv3grid_${YYYYJJJHH}2.nc" "${FVCOM_FILE}_${YYYYJJJHH}.nc"

exit