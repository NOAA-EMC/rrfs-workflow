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

This is the ex-script for the task that runs a analysis with FV3 for the
specified cycle.
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
valid_args=( "cycle_dir" "cycle_type" "analworkdir" )
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
#
"WCOSS_C" | "WCOSS")
#
  module load NCO/4.7.0
  module list
  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np ${PE_MEMBER01}"
  ;;
#
"WCOSS_DELL_P3")
#
  module load NCO/4.7.0
  module list
  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np ${PE_MEMBER01}"
  ;;
#
"THEIA")
#
  ulimit -s unlimited
  ulimit -a
  np=${SLURM_NTASKS}
  APRUN="mpirun -np ${np}"
  ;;
#
"HERA")
  ulimit -s unlimited
  ulimit -a
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=300M
  APRUN="srun"
  ;;
#
"ORION")
  ulimit -s unlimited
  ulimit -a
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
  APRUN="srun"
  ;;
#
"JET")
  export OMP_NUM_THREADS=2
  export OMP_STACKSIZE=1024M
  ulimit -s unlimited
  ulimit -a
  APRUN="srun"
  ;;
#
"ODIN")
#
  module list

  ulimit -s unlimited
  ulimit -a
  APRUN="srun -n ${PE_MEMBER01}"
  ;;
#
esac
#
#-----------------------------------------------------------------------
#
# Extract from CDATE the starting year, month, day, and hour of the
# forecast.  These are needed below for various operations.
#
#-----------------------------------------------------------------------
#
START_DATE=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')

YYYYMMDDHH=$(date +%Y%m%d%H -d "${START_DATE}")
JJJ=$(date +%j -d "${START_DATE}")

YYYY=${YYYYMMDDHH:0:4}
MM=${YYYYMMDDHH:4:2}
DD=${YYYYMMDDHH:6:2}
HH=${YYYYMMDDHH:8:2}
YYYYMMDD=${YYYYMMDDHH:0:8}
#
#-----------------------------------------------------------------------
#
# go to working directory.
# define fix and background path
#
#-----------------------------------------------------------------------

cd_vrfy ${analworkdir}

fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}
if [ ${cycle_type} == "spinup" ]; then
  bkpath=${cycle_dir}/fcst_fv3lam_spinup/INPUT
else
  bkpath=${cycle_dir}/fcst_fv3lam/INPUT
fi
# decide background type
if [ -r "${bkpath}/phy_data.nc" ]; then
  BKTYPE=0              # warm start
else
  BKTYPE=1              # cold start
fi

print_info_msg "$VERBOSE" "FIX_GSI is $FIX_GSI"
print_info_msg "$VERBOSE" "fixgriddir is $fixgriddir"
print_info_msg "$VERBOSE" "default bkpath is $bkpath"
print_info_msg "$VERBOSE" "background type is is $BKTYPE"


#-----------------------------------------------------------------------
#
# Make a list of the latest GFS EnKF ensemble
#
#-----------------------------------------------------------------------

stampcycle=$(date -d "${START_DATE}" +%s)
minHourDiff=100
loops="009"    # or 009s for GFSv15
ens_type="nc"  # or nemsio for GFSv15
foundens="false"
cat "no ens found" >> filelist03

case $MACHINE in

"WCOSS_C" | "WCOSS" | "WCOSS_DELL_P3")

  for loop in $loops; do
    for timelist in $(ls ${ENKF_FCST}/enkfgdas.*/*/atmos/mem080/gdas*.atmf${loop}.${ens_type}); do
      availtimeyyyymmdd=$(echo ${timelist} | cut -d'/' -f9 | cut -c 10-17)
      availtimehh=$(echo ${timelist} | cut -d'/' -f10)
      availtime=${availtimeyyyymmdd}${availtimehh}
      avail_time=$(echo "${availtime}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
      avail_time=$(date -d "${avail_time}")

      stamp_avail=$(date -d "${avail_time} ${loop} hours" +%s)

      hourDiff=$(echo "($stampcycle - $stamp_avail) / (60 * 60 )" | bc);
      if [[ ${stampcycle} -lt ${stamp_avail} ]]; then
         hourDiff=$(echo "($stamp_avail - $stampcycle) / (60 * 60 )" | bc);
      fi

      if [[ ${hourDiff} -lt ${minHourDiff} ]]; then
         minHourDiff=${hourDiff}
         enkfcstname=gdas.t${availtimehh}z.atmf${loop}
         eyyyymmdd=$(echo ${availtime} | cut -c1-8)
         ehh=$(echo ${availtime} | cut -c9-10)
         foundens="true"
      fi
    done
  done

  if [ ${foundens} = "true" ]
  then
    ls ${ENKF_FCST}/enkfgdas.${eyyyymmdd}/${ehh}/atmos/mem???/${enkfcstname}.nc > filelist03
  fi

  ;;
"JET" | "HERA")

  for loop in $loops; do
    for timelist in $(ls ${ENKF_FCST}/*.gdas.t*z.atmf${loop}.mem080.${ens_type}); do
      availtimeyy=$(basename ${timelist} | cut -c 1-2)
      availtimeyyyy=20${availtimeyy}
      availtimejjj=$(basename ${timelist} | cut -c 3-5)
      availtimemm=$(date -d "${availtimeyyyy}0101 +$(( 10#${availtimejjj} - 1 )) days" +%m)
      availtimedd=$(date -d "${availtimeyyyy}0101 +$(( 10#${availtimejjj} - 1 )) days" +%d)
      availtimehh=$(basename ${timelist} | cut -c 6-7)
      availtime=${availtimeyyyy}${availtimemm}${availtimedd}${availtimehh}
      avail_time=$(echo "${availtime}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
      avail_time=$(date -d "${avail_time}")

      stamp_avail=$(date -d "${avail_time} ${loop} hours" +%s)

      hourDiff=$(echo "($stampcycle - $stamp_avail) / (60 * 60 )" | bc);
      if [[ ${stampcycle} -lt ${stamp_avail} ]]; then
         hourDiff=$(echo "($stamp_avail - $stampcycle) / (60 * 60 )" | bc);
      fi

      if [[ ${hourDiff} -lt ${minHourDiff} ]]; then
         minHourDiff=${hourDiff}
         enkfcstname=${availtimeyy}${availtimejjj}${availtimehh}00.gdas.t${availtimehh}z.atmf${loop}
         foundens="true"
      fi
    done
  done

  if [ $foundens = "true" ]; then
    ls ${ENKF_FCST}/${enkfcstname}.mem0??.${ens_type} >> filelist03
  fi

esac

#
#-----------------------------------------------------------------------
#
# set default values for namelist
#
#-----------------------------------------------------------------------

ifsatbufr=.false.
ifsoilnudge=.false.
ifhyb=.false.

# Determine if hybrid option is available
memname='atmf009'
nummem=$(more filelist03 | wc -l)
nummem=$((nummem - 3 ))
if [[ ${nummem} -ge ${HYBENSMEM_NMIN} ]]; then
  print_info_msg "$VERBOSE" "Do hybrid with ${memname}"
  ifhyb=.true.
  print_info_msg "$VERBOSE" " Cycle ${YYYYMMDDHH}: GSI hybrid uses ${memname} with n_ens=${nummem}" 
else
  print_info_msg "$VERBOSE" " Cycle ${YYYYMMDDHH}: GSI does pure 3DVAR."
  print_info_msg "$VERBOSE" " Hybrid needs at least ${HYBENSMEM_NMIN} ${memname} ensembles, only ${nummem} available"
fi

#
#-----------------------------------------------------------------------
#
# link or copy background and grib configuration files
#
#  Using ncks to add phis (terrain) into cold start input background. 
#           it is better to change GSI to use the terrain from fix file.
#  Adding radar_tten array to fv3_tracer. Should remove this after add this array in
#           radar_tten converting code.
#-----------------------------------------------------------------------

ln_vrfy -snf ${fixgriddir}/fv3_akbk                     fv3_akbk
ln_vrfy -snf ${fixgriddir}/fv3_grid_spec                fv3_grid_spec

if [ ${BKTYPE} -eq 1 ]; then  # cold start uses background from INPUT
  ln_vrfy -snf ${bkpath}/gfs_data.tile7.halo0.nc        gfs_data.tile7.halo0.nc_b
  ln_vrfy -snf ${fixgriddir}/phis.nc                    phis.nc
  ncks -A -v  phis               phis.nc           gfs_data.tile7.halo0.nc_b

  ln_vrfy -snf ${bkpath}/sfc_data.tile7.halo0.nc        fv3_sfcdata
  ln_vrfy -snf gfs_data.tile7.halo0.nc_b                fv3_dynvars
  ln_vrfy -s fv3_dynvars                           fv3_tracer

  fv3lam_bg_type=1
else                          # cycle uses background from restart
  ln_vrfy  -snf ${bkpath}/fv_core.res.tile1.nc             fv3_dynvars
  ln_vrfy  -snf ${bkpath}/fv_tracer.res.tile1.nc           fv3_tracer
  ln_vrfy  -snf ${bkpath}/sfc_data.nc                      fv3_sfcdata
  fv3lam_bg_type=0
fi

# update times in coupler.res to current cycle time
cp_vrfy ${fixgriddir}/fv3_coupler.res          coupler.res
sed -i "s/yyyy/${YYYY}/" coupler.res
sed -i "s/mm/${MM}/"     coupler.res
sed -i "s/dd/${DD}/"     coupler.res
sed -i "s/hh/${HH}/"     coupler.res

#
#-----------------------------------------------------------------------
#
# link observation files
# copy observation files to working directory 
#
#-----------------------------------------------------------------------
obs_source=rap
if [[ ${HH} -eq '00' || ${HH} -eq '12' ]]; then
  obs_source=rap_e
fi

case $MACHINE in

"WCOSS_C" | "WCOSS" | "WCOSS_DELL_P3")
   obsfileprefix=${obs_source}
   obspath_tmp=${OBSPATH}/${obs_source}.${YYYYMMDD}
  ;;
"JET" | "HERA")
   obsfileprefix=${YYYYMMDDHH}.${obs_source}
   obspath_tmp=${OBSPATH}
  ;;
"ORION" )
   obs_source=rap
   #obsfileprefix=${YYYYMMDDHH}.${obs_source}               # rap observation from JET.
   obsfileprefix=${obs_source}.${YYYYMMDD}/${obs_source}    # observation from operation.
   obspath_tmp=${OBSPATH}
  ;;
*)
   obsfileprefix=${obs_source}
   obspath_tmp=${OBSPATH}
esac


obs_files_source[0]=${obspath_tmp}/${obsfileprefix}.t${HH}z.prepbufr.tm00
obs_files_target[0]=prepbufr

obs_files_source[1]=${obspath_tmp}/${obsfileprefix}.t${HH}z.satwnd.tm00.bufr_d
obs_files_target[1]=satwndbufr

obs_files_source[2]=${obspath_tmp}/${obsfileprefix}.t${HH}z.nexrad.tm00.bufr_d
obs_files_target[2]=l2rwbufr

obs_number=${#obs_files_source[@]}
for (( i=0; i<${obs_number}; i++ ));
do
  obs_file=${obs_files_source[$i]}
  obs_file_t=${obs_files_target[$i]}
  if [ -r "${obs_file}" ]; then
    ln -s "${obs_file}" "${obs_file_t}"
  else
    print_info_msg "$VERBOSE" "Warning: ${obs_file} does not exist!"
  fi
done

#-----------------------------------------------------------------------
#
# Create links to fix files in the FIXgsi directory.
# Set fixed files
#   berror   = forecast model background error statistics
#   specoef  = CRTM spectral coefficients
#   trncoef  = CRTM transmittance coefficients
#   emiscoef = CRTM coefficients for IR sea surface emissivity model
#   aerocoef = CRTM coefficients for aerosol effects
#   cldcoef  = CRTM coefficients for cloud effects
#   satinfo  = text file with information about assimilation of brightness temperatures
#   satangl  = angle dependent bias correction file (fixed in time)
#   pcpinfo  = text file with information about assimilation of prepcipitation rates
#   ozinfo   = text file with information about assimilation of ozone data
#   errtable = text file with obs error for conventional data (regional only)
#   convinfo = text file with information about assimilation of conventional data
#   bufrtable= text file ONLY needed for single obs test (oneobstest=.true.)
#   bftab_sst= bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)
#
#-----------------------------------------------------------------------

ANAVINFO=${FIX_GSI}/${ANAVINFO_FN}
CONVINFO=${FIX_GSI}/${CONVINFO_FN}
HYBENSINFO=${FIX_GSI}/${HYBENSINFO_FN}
OBERROR=${FIX_GSI}/${OBERROR_FN}
BERROR=${FIX_GSI}/${BERROR_FN}

SATINFO=${FIX_GSI}/global_satinfo.txt
OZINFO=${FIX_GSI}/global_ozinfo.txt
PCPINFO=${FIX_GSI}/global_pcpinfo.txt
ATMS_BEAMWIDTH=${FIX_GSI}/atms_beamwidth.txt

# Fixed fields
cp_vrfy ${ANAVINFO} anavinfo
cp_vrfy ${BERROR}   berror_stats
cp_vrfy $SATINFO    satinfo
cp_vrfy $CONVINFO   convinfo
cp_vrfy $OZINFO     ozinfo
cp_vrfy $PCPINFO    pcpinfo
cp_vrfy $OBERROR    errtable
cp_vrfy $ATMS_BEAMWIDTH atms_beamwidth.txt
cp_vrfy ${HYBENSINFO} hybens_info

# Get aircraft reject list and surface uselist
if [ -r ${AIRCRAFT_REJECT}/current_bad_aircraft.txt ]; then
  cp_vrfy ${AIRCRAFT_REJECT}/current_bad_aircraft.txt current_bad_aircraft
else
  print_info_msg "$VERBOSE" "Warning: gsd aircraft reject list does not exist!" 
fi

if [ -r ${FIX_GSI}/gsd_sfcobs_provider.txt ]; then
  cp_vrfy ${FIX_GSI}/gsd_sfcobs_provider.txt gsd_sfcobs_provider.txt
else
  print_info_msg "$VERBOSE" "Warning: gsd surface observation provider does not exist!" 
fi

gsd_sfcobs_uselist="gsd_sfcobs_uselist.txt"
for use_list in "${SFCOBS_USELIST}/current_mesonet_uselist.txt" \
                "${SFCOBS_USELIST}/gsd_sfcobs_uselist.txt"
do 
  if [ -r $use_list ] ; then
    cp_vrfy $use_list  $gsd_sfcobs_uselist
    print_info_msg "$VERBOSE" "Use surface obs uselist: $use_list "
    break
  fi
done
if [ ! -r $use_list ] ; then 
  print_info_msg "$VERBOSE" "Warning: gsd surface observation uselist does not exist!" 
fi

#-----------------------------------------------------------------------
#
# CRTM Spectral and Transmittance coefficients
#
#-----------------------------------------------------------------------
CRTMFIX=${FIX_CRTM}
emiscoef_IRwater=${CRTMFIX}/Nalli.IRwater.EmisCoeff.bin
emiscoef_IRice=${CRTMFIX}/NPOESS.IRice.EmisCoeff.bin
emiscoef_IRland=${CRTMFIX}/NPOESS.IRland.EmisCoeff.bin
emiscoef_IRsnow=${CRTMFIX}/NPOESS.IRsnow.EmisCoeff.bin
emiscoef_VISice=${CRTMFIX}/NPOESS.VISice.EmisCoeff.bin
emiscoef_VISland=${CRTMFIX}/NPOESS.VISland.EmisCoeff.bin
emiscoef_VISsnow=${CRTMFIX}/NPOESS.VISsnow.EmisCoeff.bin
emiscoef_VISwater=${CRTMFIX}/NPOESS.VISwater.EmisCoeff.bin
emiscoef_MWwater=${CRTMFIX}/FASTEM6.MWwater.EmisCoeff.bin
aercoef=${CRTMFIX}/AerosolCoeff.bin
cldcoef=${CRTMFIX}/CloudCoeff.bin

ln -s ${emiscoef_IRwater} Nalli.IRwater.EmisCoeff.bin
ln -s $emiscoef_IRice ./NPOESS.IRice.EmisCoeff.bin
ln -s $emiscoef_IRsnow ./NPOESS.IRsnow.EmisCoeff.bin
ln -s $emiscoef_IRland ./NPOESS.IRland.EmisCoeff.bin
ln -s $emiscoef_VISice ./NPOESS.VISice.EmisCoeff.bin
ln -s $emiscoef_VISland ./NPOESS.VISland.EmisCoeff.bin
ln -s $emiscoef_VISsnow ./NPOESS.VISsnow.EmisCoeff.bin
ln -s $emiscoef_VISwater ./NPOESS.VISwater.EmisCoeff.bin
ln -s $emiscoef_MWwater ./FASTEM6.MWwater.EmisCoeff.bin
ln -s $aercoef  ./AerosolCoeff.bin
ln -s $cldcoef  ./CloudCoeff.bin


# Copy CRTM coefficient files based on entries in satinfo file
for file in $(awk '{if($1!~"!"){print $1}}' ./satinfo | sort | uniq) ;do
   ln -s ${CRTMFIX}/${file}.SpcCoeff.bin ./
   ln -s ${CRTMFIX}/${file}.TauCoeff.bin ./
done

## satellite bias correction
#if [ ${FULLCYC} -eq 1 ]; then
#   latest_bias=${DATAHOME_PBK}/satbias/satbias_out_latest
#   latest_bias_pc=${DATAHOME_PBK}/satbias/satbias_pc.out_latest
#   latest_radstat=${DATAHOME_PBK}/satbias/radstat.rap_latest
#fi

# cp $latest_bias ./satbias_in
# cp $latest_bias_pc ./satbias_pc
# cp $latest_radstat ./radstat.rap
# listdiag=`tar xvf radstat.rap | cut -d' ' -f2 | grep _ges`
# for type in $listdiag; do
#       diag_file=`echo $type | cut -d',' -f1`
#       fname=`echo $diag_file | cut -d'.' -f1`
#       date=`echo $diag_file | cut -d'.' -f2`
#       gunzip $diag_file
#       fnameanl=$(echo $fname|sed 's/_ges//g')
#       mv $fname.$date $fnameanl
# done
#
#mv radstat.rap  radstat.rap.for_this_cycle

#-----------------------------------------------------------------------
#
# Build the GSI namelist on-the-fly
#    most configurable paramters take values from settings in config.sh
#                                             (var_defns.sh in runtime)
#
#-----------------------------------------------------------------------
# 
. ${FIX_GSI}/gsiparm.anl.sh
cat << EOF > gsiparm.anl
$gsi_namelist
EOF

#
#-----------------------------------------------------------------------
#
# Copy the GSI executable to the run directory.
#
#-----------------------------------------------------------------------
#
gsi_exec="${EXECDIR}/gsi.x"

if [ -f $gsi_exec ]; then
  print_info_msg "$VERBOSE" "
Copying the GSI executable to the run directory..."
  cp_vrfy ${gsi_exec} ${analworkdir}/gsi.x
else
  print_err_msg_exit "\
The GSI executable specified in GSI_EXEC does not exist:
  GSI_EXEC = \"$gsi_exec\"
Build GSI and rerun."
fi
#
#-----------------------------------------------------------------------
#
# Set and export variables.
#
#-----------------------------------------------------------------------
#

#
#-----------------------------------------------------------------------
#
# Run the GSI.  Note that we have to launch the forecast from
# the current cycle's run directory because the GSI executable will look
# for input files in the current directory.
#
#-----------------------------------------------------------------------
#
# comment out for testing
$APRUN ./gsi.x < gsiparm.anl > stdout 2>&1 || print_err_msg_exit "\
Call to executable to run GSI returned with nonzero exit code."


#-----------------------------------------------------------------------
#
# Copy analysis results to INPUT for model forecast.
#
#-----------------------------------------------------------------------
#
#
#if [ ${BKTYPE} -eq 1 ]; then  # cold start, put analysis back to current INPUT 
#  cp_vrfy ${analworkdir}/fv3_dynvars                  ${bkpath}/gfs_data.tile7.halo0.nc
#  cp_vrfy ${analworkdir}/fv3_sfcdata                  ${bkpath}/sfc_data.tile7.halo0.nc
#else                          # cycling
#  cp_vrfy ${analworkdir}/fv3_dynvars             ${bkpath}/fv_core.res.tile1.nc
#  cp_vrfy ${analworkdir}/fv3_tracer              ${bkpath}/fv_tracer.res.tile1.nc
#  cp_vrfy ${analworkdir}/fv3_sfcdata             ${bkpath}/sfc_data.nc
#fi

#-----------------------------------------------------------------------
# Loop over first and last outer loops to generate innovation
# diagnostic files for indicated observation types (groups)
#
# NOTE:  Since we set miter=2 in GSI namelist SETUP, outer
#        loop 03 will contain innovations with respect to 
#        the analysis.  Creation of o-a innovation files
#        is triggered by write_diag(3)=.true.  The setting
#        write_diag(1)=.true. turns on creation of o-g
#        innovation files.
#-----------------------------------------------------------------------
#

netcdf_diag=${netcdf_diag:-".false."}
binary_diag=${binary_diag:-".true."}

loops="01 03"
for loop in $loops; do

case $loop in
  01) string=ges;;
  03) string=anl;;
   *) string=$loop;;
esac

#  Collect diagnostic files for obs types (groups) below
if [ $binary_diag = ".true." ]; then
   listall="conv hirs2_n14 msu_n14 sndr_g08 sndr_g11 sndr_g11 sndr_g12 sndr_g13 sndr_g08_prep sndr_g11_prep sndr_g12_prep sndr_g13_prep sndrd1_g11 sndrd2_g11 sndrd3_g11 sndrd4_g11 sndrd1_g12 sndrd2_g12 sndrd3_g12 sndrd4_g12 sndrd1_g13 sndrd2_g13 sndrd3_g13 sndrd4_g13 hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua imgr_g08 imgr_g11 imgr_g12 pcp_ssmi_dmsp pcp_tmi_trmm sbuv2_n16 sbuv2_n17 sbuv2_n18 omi_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 hirs4_metop-a amsua_n18 amsua_metop-a mhs_n18 mhs_metop-a amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 iasi_metop-a"
   for type in $listall; do
      count=$(ls pe*.${type}_${loop} | wc -l)
      if [[ $count -gt 0 ]]; then
         $(cat pe*.${type}_${loop} > diag_${type}_${string}.${YYYYMMDDHH})
      fi
   done
fi

if [ $netcdf_diag = ".true." ]; then
   listallnc="conv_ps conv_q conv_t conv_uv"

   cat_exec="${EXECDIR}/ncdiag_cat.x"

   if [ -f $cat_exec ]; then
      print_info_msg "$VERBOSE" "
        Copying the ncdiag_cat executable to the run directory..."
      cp_vrfy ${cat_exec} ${analworkdir}/ncdiag_cat.x
   else
      print_err_msg_exit "\
        The ncdiag_cat executable specified in cat_exec does not exist:
        cat_exec = \"$cat_exec\"
        Build GSI and rerun."
   fi

   for type in $listallnc; do
      count=$(ls pe*.${type}_${loop}.nc4 | wc -l)
      if [[ $count -gt 0 ]]; then
         ./ncdiag_cat.x -o ncdiag_${type}_${string}.nc4.${YYYYMMDDHH} pe*.${type}_${loop}.nc4
      fi
   done
fi

done

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
ANALYSIS GSI completed successfully!!!

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

