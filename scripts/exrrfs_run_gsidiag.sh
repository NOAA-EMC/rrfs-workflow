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
valid_args=( "gsi_type" "mem_type" \
             "satbias_dir" )
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
#
"WCOSS2")
#
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export OMP_STACKSIZE=1G
  export OMP_NUM_THREADS=1
  ncores=$(( NNODES_RUN_GSIDIAG*PPN_RUN_GSIDIAG ))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_RUN_GSIDIAG} --cpu-bind core --depth ${OMP_NUM_THREADS}"
  ;;
#
"HERA")
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=300M
  APRUN="srun --export=ALL"
  ;;
#
"ORION")
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
  APRUN="srun --export=ALL"
  ;;
#
"HERCULES")
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
  APRUN="srun --export=ALL"
  ;;
#
"JET")
  export OMP_NUM_THREADS=2
  export OMP_STACKSIZE=1024M
  APRUN="srun --export=ALL"
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
# skip if gsi_type is OBSERVER
#-----------------------------------------------------------------------
#
if [ "${gsi_type}" = "OBSERVER" ]; then
   echo "Observer should not run this job"
   exit 0
fi
#
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
  numfile_rad_bin=0
  numfile_dbz_bin=0
  numfile_cnv=0
  numfile_rad=0
  numfile_dbz=0
  if [ $binary_diag = ".true." ]; then
    listall="hirs2_n14 msu_n14 sndr_g08 sndr_g11 sndr_g11 sndr_g12 sndr_g13 sndr_g08_prep sndr_g11_prep sndr_g12_prep sndr_g13_prep sndrd1_g11 sndrd2_g11 sndrd3_g11 sndrd4_g11 sndrd1_g15 sndrd2_g15 sndrd3_g15 sndrd4_g15 sndrd1_g13 sndrd2_g13 sndrd3_g13 sndrd4_g13 hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 amsua_n18 amsua_n19 amsua_metop-a amsua_metop-b amsua_metop-c amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua imgr_g08 imgr_g11 imgr_g12 pcp_ssmi_dmsp pcp_tmi_trmm conv sbuv2_n16 sbuv2_n17 sbuv2_n18 omi_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 hirs4_metop-a mhs_n18 mhs_n19 mhs_metop-a mhs_metop-b mhs_metop-c amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 iasi_metop-a iasi_metop-b iasi_metop-c seviri_m08 seviri_m09 seviri_m10 seviri_m11 cris_npp atms_npp ssmis_f17 cris-fsr_npp cris-fsr_n20 atms_n20 abi_g16 abi_g18 atms_n21 cris-fsr_n21"
    if [ -r ${analworkdir_conv} ]; then
      cd ${analworkdir_conv}

      for type in $listall; do
         count=$(ls pe*.${type}_${loop} | wc -l)
         if [[ $count -gt 0 ]]; then
            $(cat pe*.${type}_${loop} > diag_${type}_${string}.${YYYYMMDDHH})
            echo "diag_${type}_${string}.${YYYYMMDDHH}" >> listrad_bin
            numfile_rad_bin=`expr ${numfile_rad_bin} + 1`
         fi
      done
    fi

    listall="radardbz"
    if [ -r ${analworkdir_dbz} ]; then
      cd ${analworkdir_dbz}

      for type in $listall; do
         count=$(ls pe*.${type}_${loop} | wc -l)
         if [[ $count -gt 0 ]]; then
            $(cat pe*.${type}_${loop} > diag_${type}_${string}.${YYYYMMDDHH})
            echo "diag_${type}_${string}.${YYYYMMDDHH}" >> listdbz_bin
            numfile_dbz_bin=`expr ${numfile_dbz_bin} + 1`
         fi
      done
    fi
  fi

  if [ $netcdf_diag = ".true." ]; then
    export pgm="nc_diag_cat.x"

    listall_cnv="conv_ps conv_q conv_t conv_uv conv_pw conv_rw conv_sst"
    listall_rad="hirs2_n14 msu_n14 sndr_g08 sndr_g11 sndr_g11 sndr_g12 sndr_g13 sndr_g08_prep sndr_g11_prep sndr_g12_prep sndr_g13_prep sndrd1_g11 sndrd2_g11 sndrd3_g11 sndrd4_g11 sndrd1_g15 sndrd2_g15 sndrd3_g15 sndrd4_g15 sndrd1_g13 sndrd2_g13 sndrd3_g13 sndrd4_g13 hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 amsua_n18 amsua_n19 amsua_metop-a amsua_metop-b amsua_metop-c amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua imgr_g08 imgr_g11 imgr_g12 pcp_ssmi_dmsp pcp_tmi_trmm conv sbuv2_n16 sbuv2_n17 sbuv2_n18 omi_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 hirs4_metop-a mhs_n18 mhs_n19 mhs_metop-a mhs_metop-b mhs_metop-c amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 iasi_metop-a iasi_metop-b iasi_metop-c seviri_m08 seviri_m09 seviri_m10 seviri_m11 cris_npp atms_npp ssmis_f17 cris-fsr_npp cris-fsr_n20 atms_n20 abi_g16 abi_g18 atms_n21 cris-fsr_n21"

    if [ -r ${analworkdir_conv} ]; then
      cd ${analworkdir_conv}

      for type in $listall_cnv; do
         count=$(ls pe*.${type}_${loop}.nc4 | wc -l)
         if [[ $count -gt 0 ]]; then
            . prep_step   
            ${APRUN} $pgm -o diag_${type}_${string}.${YYYYMMDDHH}.nc4 pe*.${type}_${loop}.nc4 >>$pgmout >errfile
            export err=$?; err_chk
	    mv errfile errfile_nc_diag_cat_$type

            gzip diag_${type}_${string}.${YYYYMMDDHH}.nc4
            cp diag_${type}_${string}.${YYYYMMDDHH}.nc4.gz ${COMOUT}
            echo "diag_${type}_${string}.${YYYYMMDDHH}.nc4.gz" >> listcnv
            numfile_cnv=`expr ${numfile_cnv} + 1`
         fi
      done

      for type in $listall_rad; do
         count=$(ls pe*.${type}_${loop}.nc4 | wc -l)
         if [[ $count -gt 0 ]]; then
            ${APRUN} $pgm -o diag_${type}_${string}.${YYYYMMDDHH}.nc4 pe*.${type}_${loop}.nc4 >>$pgmout >errfile
            export err=$?; err_chk
            mv errfile errfile_nc_diag_cat_$type

            gzip diag_${type}_${string}.${YYYYMMDDHH}.nc4
            cp diag_${type}_${string}.${YYYYMMDDHH}.nc4.gz ${COMOUT}
            echo "diag_${type}_${string}.${YYYYMMDDHH}.nc4.gz" >> listrad
            numfile_rad=`expr ${numfile_rad} + 1`
         else
            echo 'No diag_' ${type} 'exist'
         fi
      done
    fi

    listall="conv_dbz conv_fed"
    if [ -r ${analworkdir_dbz} ]; then
      cd ${analworkdir_dbz}

      for type in $listall; do
         count=$(ls pe*.${type}_${loop}.nc4 | wc -l)
         if [[ $count -gt 0 ]]; then
	    . prep_step
            ${APRUN} $pgm -o diag_${type}_${string}.${YYYYMMDDHH}.nc4 pe*.${type}_${loop}.nc4 >>$pgmout >errfile
            export err=$?; err_chk
	    mv errfile errfile_nc_diag_cat_$type

            gzip diag_${type}_${string}.${YYYYMMDDHH}.nc4 
            cp diag_${type}_${string}.${YYYYMMDDHH}.nc4.gz ${COMOUT}
            echo "diag_${type}_${string}.${YYYYMMDDHH}.nc4.gz" >> listdbz
            numfile_dbz=`expr ${numfile_dbz} + 1`
         fi
      done
    fi
  fi
done
#
#-----------------------------------------------------------------------
#
# cycling radiance bias corretion files
#
#-----------------------------------------------------------------------
#
if [ "${DO_RADDA}" = "TRUE" ]; then
  if [ "${CYCLE_TYPE}" = "spinup" ]; then
    spinup_or_prod_rrfs=spinup
  else
    spinup_or_prod_rrfs=prod
  fi

  if [ -r ${analworkdir_conv} ]; then
     cd ${analworkdir_conv}

     if [ ${numfile_cnv} -gt 0 ]; then
        tar -cvzf rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_cnvstat_nc `cat listcnv`
        cp ./rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_cnvstat_nc  ${satbias_dir}/rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_cnvstat
     fi
     if [ ${numfile_rad} -gt 0 ]; then
        tar -cvzf rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_radstat_nc `cat listrad`
        cp ./rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_radstat_nc  ${satbias_dir}/rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_radstat
     fi
     if [ ${numfile_rad_bin} -gt 0 ]; then
        tar -cvzf rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_radstat `cat listrad_bin`
        cp ./rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_radstat  ${satbias_dir}/rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_radstat
     fi

     # For EnVar DA  
     if [ -r ./satbias_out ]; then
       cp ./satbias_out ${satbias_dir}/rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_satbias
       cp ./satbias_out ${COMOUT}/rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_satbias
     fi
     if [ -r ./satbias_pc.out ]; then
       cp ./satbias_pc.out ${satbias_dir}/rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_satbias_pc
       cp ./satbias_pc.out ${COMOUT}/rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_satbias_pc
     fi
  fi

fi

#------------------------------------------------------------------------
# set up local dirs and run run radmon to generate radiance monitor data
#------------------------------------------------------------------------

if [ "${DO_RADMON}" = "TRUE" ]; then 
   if [ ! -f ${satbias_dir}/rrfs.${spinup_or_prod_rrfs}.${YYYYMMDDHH}_radstat ]; then
     echo "***radstat file for " ${YYYYMMDDHH} "is not existing, skipping radmon job***"
   else
     echo "Run EMC Radmon package to generate daily monitoring data for satellite"

     envir=${envir:-prod}
     REGIONAL_RR=${REGIONAL_RR:-1}

     export TANKverf=${TANKverf:-$NWGES_BASEDIR/radmon}
     export TANKverf_rad=$TANKverf/radmon.$PDY


     if [ ! -d $TANKverf_rad ]; then
       mkdir -p -m 775 $TANKverf_rad
     fi


     export RAD_AREA=${RAD_AREA:-rgn}
     export CYCLE_INTERVAL=${CYCLE_INTERVAL:-1}
     export DATA=${analworkdir_conv}/radmon
     export TANKverf_radM1=${TANKverf_radM1:-${TANKverf}/radmon.${PDY}}

     export GSI_MON_BIN=$EXECdir
     export FIXgdas=$FIX_GSI

     export RADMON_SUFFIX=rrfs
     export rgnHH=${PDY}${cyc}
     export biascr=${biascr:-${SATBIAS_DIR}/${RADMON_SUFFIX}.${CYCLE_TYPE}.${rgnHH}_satbias}
     export radstat=${radstat:-${SATBIAS_DIR}/${RADMON_SUFFIX}.${CYCLE_TYPE}.${rgnHH}_radstat}

     echo "radstat: $radstat"
     echo "biascr:  $biascr"

     export COMPRESS=gzip

     CLEAN_TANKVERF=1

     . $USHdir/rrfs_radmon/exrrfs_verfrad.sh ${PDY} ${cyc}
   fi
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
GSI diag completed successfully!!!

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

