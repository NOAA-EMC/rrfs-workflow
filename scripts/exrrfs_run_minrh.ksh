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
"fixminmax" \
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
#
#-----------------------------------------------------------------------
#
# A separate ${post_fhr} forecast hour variable is required for the post
# files, since they may or may not be three digits long, depending on the
# length of the forecast.
#
#-----------------------------------------------------------------------
#

DATA=$postprd_dir
export DATA=$postprd_dir
DATAminrh=$DATA/minrh_${fhr}
mkdir $DATAminrh

cd $DATAminrh

grids=hrrr
gridsarray=($grids)
num=${#gridsarray[@]}

#typeset Z2 hr one

if [[ $num -gt 10 ]] ; then
    echo "FATAL ERROR: Only ten grid naems may be specified.  User specified ${num}."
    exit
fi

#generate namelist input file, make sure that no grid in same domain is repeated twice
#also copy into workspace template files
Tur=no; Tak=no; Tpr=no; Thi=no; Tgu=no
echo "&gridsinfo" > gridsinfo_input
echo "     grids=${num}" >> gridsinfo_input
nn=0
while [[ $nn -lt $num ]] ; do
    let nnp1="nn+1"
    dname=${gridsarray[$nn]}
    echo "     gridnames($nnp1)=${dname}," >> gridsinfo_input
    Tur=yes
    run=rtma3d
	Tur=yes
	CYCLE=${PDY}0600
	CYCLEm1=${PDY}0500
        CYCLE_STOP=${PDYm1}1800

    hr=1 #hour number to go in output (from wgrib2) file name
    one=1
    while [[ $CYCLE -ge $CYCLE_STOP ]] ; do
	
	YYYY=`echo $CYCLE | cut -c 1-4`
	YYYYMM=`echo $CYCLE | cut -c 1-6`
	YYYYMMDD=`echo $CYCLE | cut -c 1-8`
	HH=`echo $CYCLE | cut -c 9-10`
        YYYYMMDDm1=`echo $CYCLEm1 | cut -c 1-8`
        HHm1=`echo $CYCLEm1 | cut -c 9-10`




	#find proper name of ges and analysis files to run wgrib2 on based on run and domain name
       #find proper name of ges and analysis files to run wgrib2 on based on run and domain name
        if [[ ${run} = "rtma3d" ]] ; then
            if [[ $dname == "hrrr" ]] ; then
                opsfile=${COMOUT_BASEDIR}/RTMA_NA.${YYYYMMDD}/${HH}/rtma.t${HH}z.prslev.f000.hrrr.grib2
                gesfile=${RRFS_PRODDIR}/rrfs.${YYYYMMDDm1}/${HHm1}/rrfs.t${HHm1}z.prslev.f001.conus_3km.grib2
                if [[ ! -e $opsfile ]] ; then
                  if [[ ! -d ${COMOUT_BASEDIR}/RTMA_NA.${YYYYMMDD}/${HH} ]]; then
                    mkdir -p ${COMOUT_BASEDIR}/RTMA_NA.${YYYYMMDD}/${HH}
                  fi
	          opsfile=$gesfile
	        fi
	    fi
        fi
	#now use wgrib2 to pull ges/analysis from the file
	#use run in binary filename, regardless of grid
	if [[ -s $gesfile ]] ; then
            if [ $hr -le 9 ]; then
	    tmpops=${run}_temp_anl_hour_0${hr}.bin
	    tmpges=${run}_temp_ges_hour_0${hr}.bin
	    dptops=${run}_dwpt_anl_hour_0${hr}.bin
	    dptges=${run}_dwpt_ges_hour_0${hr}.bin
	    else
	    tmpops=${run}_temp_anl_hour_${hr}.bin
            tmpges=${run}_temp_ges_hour_${hr}.bin
            dptops=${run}_dwpt_anl_hour_${hr}.bin
            dptges=${run}_dwpt_ges_hour_${hr}.bin
	    fi
	    wgrib2 $opsfile -match ":TMP:2 m above ground:" -ieee $tmpops
	    wgrib2 $gesfile -match ":TMP:2 m above ground:" -ieee $tmpges
	    wgrib2 $opsfile -match ":DPT:2 m above ground:" -ieee $dptops
	    wgrib2 $gesfile -match ":DPT:2 m above ground:" -ieee $dptges
	else
	    echo "WARNING: ${run} file unavailable for ${CYCLE}!";
	fi	
	CYCLE=`$MDATE -60 $CYCLE`
        hr=$(( $hr + $one ))
        if [ ${HH} -eq 06 ] ; then
            if [[ ${run} == "rtma3d" ]] ; then
                cp $gesfile gesfileus.grb2
            fi
        fi

done #$CYCLE -le $CYCLE_STOP (number of cycles to run)
    
    let nn="$nn+1"
done #$nn -lt $num (number of grids)


echo "/" >> gridsinfo_input

#make blend?  1=bgs only 2=anls only, 3=both
export bnum=2
cat <<EOF > blend_input
&blendinput
bnum=${bnum}
/
EOF

. prep_step

ln -sf ${run}.${PDYm1}.minrh_anl.dat fort.61
ln -sf ${run}.${PDYm1}.minrh_bg.dat fort.62

export pgm=rtma_minrh.exe

${EXECdir}/pgm  > $pgmout 2>&errfile
export err=$?; err_chk

#wgrib2 options: -set_byte 4 48 1 ensures we are dealing with succession of analyses
#-set_byte 4 47 3 ensures we are dealing with maximum value
#-set_date ${PDY}18 - must be start time, not end time

if [[ $Tur = yes ]] ; then
    if [[ $bnum -eq "2" || $bnum -eq "3" ]] ; then
	if [ -s $DATAminrh/${run}.${PDYm1}.minrh_anl.dat ] ; then
            wgrib2 $DATAminrh/gesfileus.grb2 -match ":RH:" -grib_out $DATAminrh/tempgribus.grb2
            wgrib2 $DATAminrh/tempgribus.grb2 -import_ieee rtma3d.${PDYm1}.minrh_anl.dat -set_date ${PDYm1}18 -set_var MINRH -set_ftime '12 hour fcst' -undefine_val 0 -grib_out $DATAminrh/${run}.${PDYm1}.minRH.grb2 
            cp $DATAminrh/${run}.${PDYm1}.minrh_anl.dat $DATAminrh/${run}.${PDYm1}.minrh_anl.dat
            cp $DATAminrh/${run}.${PDYm1}.minRH.grb2 ${comout}/rtma3d.minRH.grib2
	else
	    echo "WARNING: CONUS Min RH analysis not available from main program!"
	fi
    fi
    if [[ $bnum -eq "1" || $bnum -eq "3" ]] ; then
	if [ -s $DATAminrh/${run}..${PDYm1}.minrh_bg.dat ] ; then 
            wgrib2 $DATAminrh/gesfileus.grb2 -match ":RH:" -grib_out $DATAminrh/tempgribus.grb2
            wgrib2 $DATAminrh/tempgribus.grb2 -import_ieee rtma3d.${PDYm1}.minrh_bg.dat -set_date ${PDYm1}18 -set_var MINRH -set_ftime '12 hour fcst' -undefine_val 0 -grib_out $DATAminrh/${run}.${PDYm1}.minRH.grb2
            cp $DATAminrh/${run}.${PDYm1}.minrh_bg.dat $DATAminrh/${run}.${PDYm1}.minrh_bg.dat
	    cp $DATAminrh/${run}.${PDYm1}.minRH.grb2 ${comout}/rtma3d.minRH.grib2
	else
	    echo "WARNING: CONUS Min RH background no available from main program!"
	fi
    fi
fi





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
