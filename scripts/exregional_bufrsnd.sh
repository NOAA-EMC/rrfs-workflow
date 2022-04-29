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

This is the ex-script for the task that runs the bufr-sounding 
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
"nwges_dir" \
"bufrsnd_dir" \
"comout" \
"fhr_dir" \
"fhr" \
"tmmark" \
"cycle_type" \
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
    module list
    export NODES=1
    export ntasks=28
    export ptile=28
    export threads=1
    export MP_LABELIO=yes
    export OMP_NUM_THREADS=$threads
    module unload netcdf/4.7.4
    module load NetCDF/4.5.0

    module list

    APRUNC="mpirun"
    APRUNS="time"
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
set -x
#
#-----------------------------------------------------------------------
#
# Remove any files from previous runs.
#
#-----------------------------------------------------------------------
#
rm_vrfy -f fort.*
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
dom=conus
NEST=${dom}
MODEL=fv3
FIXsar=/gpfs/dell6/emc/modeling/noscrub/emc.campara/fv3lamda/regional_workflow/fix/fix_sar/conus
FIXsar_C3359=/gpfs/dell6/emc/modeling/noscrub/emc.campara/fv3lamda/regional_workflow/fix/fix_sar_C3359
PARMfv3=/gpfs/dell6/emc/modeling/noscrub/emc.campara/fv3lamda/regional_workflow/parm


DATA=$bufrsnd_dir
EXECfv3=$EXECDIR
COMOUT=$comout

mkdir -p $DATA/bufrpost
cd $DATA/bufrpost

RUNLOC=${NEST}${MODEL}

export tmmark=tm00

echo FIXsar is $FIXsar
echo profdat file name is regional_${RUNLOC}_profdat


cp $FIXsar_C3359/regional_${RUNLOC}_profdat regional_profdat

OUTTYP=netcdf

model=FV3S

INCR=01
FHRLIM=60
#FHRLIM=1

let NFILE=1

START_DATE=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')

PDY=$cdate

YYYY=`echo $PDY | cut -c1-4`
MM=`echo $PDY | cut -c5-6`
DD=`echo $PDY | cut -c7-8`
CYCLE=$PDY$cyc

startd=$YYYY$MM$DD
startdate=$CYCLE

STARTDATE=${YYYY}-${MM}-${DD}_${cyc}:00:00
#endtime=`$NDATE $FHRLIM $CYCLE`
endtime=$(date +%Y%m%d%H -d "${START_DATE} +60 hours")

YYYY=`echo $endtime | cut -c1-4`
MM=`echo $endtime | cut -c5-6`
DD=`echo $endtime | cut -c7-8`

FINALDATE=${YYYY}-${MM}-${DD}_${cyc}:00:00

if [ -e sndpostdone00.tm00 ]
then

lasthour=`ls -1rt sndpostdone??.tm00 | tail -1 | cut -c 12-13`
typeset -Z2 lasthour

let "fhr=lasthour+1"
typeset -Z2 fhr

else

fhr=00

fi

echo starting with fhr $fhr

#cd $DATA/bufrpost


INPUT_DATA=$run_dir
########################################################

while [ $fhr -le $FHRLIM ]
do

#date=`$NDATE $fhr $CYCLE`
date=$(date +%Y%m%d%H -d "${START_DATE} +${fhr} hours")

let fhrold="$fhr - 1"

if [ $model == "FV3S" ]
then

OUTFILDYN=$INPUT_DATA/dynf0${fhr}.nc
OUTFILPHYS=$INPUT_DATA/phyf0${fhr}.nc

icnt=1


# wait for model restart file
while [ $icnt -lt 1000 ]
do
   if [ -s $INPUT_DATA/logf0${fhr} ]
   then
      break
   else
      icnt=$((icnt + 1))
      sleep 9
   fi
if [ $icnt -ge 200 ]
then
    msg="FATAL ERROR: ABORTING after 30 minutes of waiting for FV3S ${RUNLOC} FCST F${fhr} to end."
    exit
    #err_exit $msg
fi
done

else
  msg="FATAL ERROR: ABORTING due to bad model selection for this script"
  exit
  #err_exit $msg
fi

datestr=`date`
echo top of loop after found needed log file for $fhr at $datestr

cat > itag <<EOF
$OUTFILDYN
$OUTFILPHYS
$model
$OUTTYP
$STARTDATE
$NFILE
$INCR
$fhr
$OUTFILDYN
$OUTFILPHYS
EOF

#export pgm=regional_bufr.x

#. prep_step

export FORT19="$DATA/bufrpost/regional_profdat"
export FORT79="$DATA/bufrpost/profilm.c1.${tmmark}"
export FORT11="itag"

#startmsg

${APRUNC} $EXECfv3/regional_bufr.x  > pgmout.log_${fhr} 2>&1
export err=$?
#err_chk

echo DONE $fhr at `date`

mv $DATA/bufrpost/profilm.c1.${tmmark} $DATA/profilm.c1.${tmmark}.f${fhr}
echo done > $DATA/sndpostdone${fhr}.${tmmark}

cat $DATA/profilm.c1.${tmmark}  $DATA/profilm.c1.${tmmark}.f${fhr} > $DATA/profilm_int
mv $DATA/profilm_int $DATA/profilm.c1.${tmmark}

fhr=`expr $fhr + $INCR`


if [ $fhr -lt 10 ]
then
fhr=0$fhr
fi

#wdate=`$NDATE ${fhr} $CYCLE`

done

cd $DATA

########################################################
############### SNDP code
########################################################

export pgm=hiresw_sndp_${RUNLOC}

cp $PARMfv3/regional_sndp.parm.mono $DATA/regional_sndp.parm.mono
cp $PARMfv3/regional_bufr.tbl $DATA/regional_bufr.tbl

export FORT11="$DATA/regional_sndp.parm.mono"
export FORT32="$DATA/regional_bufr.tbl"
export FORT66="$DATA/profilm.c1.${tmmark}"
export FORT78="$DATA/class1.bufr"

#startmsg

echo here RUNLOC  $RUNLOC
echo here MODEL $MODEL
echo here model $model

pgmout=sndplog

nlev=65
echo "${model} $nlev" > itag
${APRUNS} $EXECfv3/regional_sndp.x  < itag >> $pgmout 2>$pgmout
#export err=$?

SENDCOM=YES

if [ $SENDCOM == "YES" ]
then
cp $DATA/class1.bufr $COMOUT/rrfs.t${cyc}z.${RUNLOC}.class1.bufr
cp $DATA/profilm.c1.${tmmark} ${COMOUT}/rrfs.t${cyc}z.${RUNLOC}.profilm.c1
fi

# remove bufr file breakout directory in $COMOUT if it exists

if [ -d ${COMOUT}/bufr.${NEST}${MODEL}${cyc} ]
then
  cd $COMOUT
  rm -r bufr.${NEST}${MODEL}${cyc}
  cd $DATA
fi


rm stnmlist_input

cat <<EOF > stnmlist_input
1
$DATA/class1.bufr
${COMOUT}/bufr.${NEST}${MODEL}${cyc}/${NEST}${MODEL}bufr
EOF

  mkdir -p ${COMOUT}/bufr.${NEST}${MODEL}${cyc}

  export pgm=regional_stnmlist
# . prep_step

  export FORT20=$DATA/class1.bufr
  export DIRD=${COMOUT}/bufr.${NEST}${MODEL}${cyc}/${NEST}${MODEL}bufr

# startmsg
echo "before stnmlist.x"
date
pgmout=stnmlog
${APRUNS}  $EXECfv3/regional_stnmlist.x < stnmlist_input >> $pgmout 2>errfile
echo "after stnmlist.x"
date

  export err=$?

  echo ${COMOUT}/bufr.${NEST}${MODEL}${cyc} > ${COMOUT}/bufr.${NEST}${MODEL}${cyc}/bufrloc

#   cp class1.bufr.tm00 $COMOUT/${RUN}.${cyc}.class1.bufr

cd ${COMOUT}/bufr.${NEST}${MODEL}${cyc}

# Tar and gzip the individual bufr files and send them to /com
  tar -cf - . | /usr/bin/gzip > ../rrfs.t${cyc}z.${RUNLOC}.bufrsnd.tar.gz

#files=`ls`
#for fl in $files
#do
#${USHobsproc_shared_bufr_cword}/bufr_cword.sh unblk ${fl} ${fl}.unb
#${USHobsproc_shared_bufr_cword}/bufr_cword.sh block ${fl}.unb ${fl}.wcoss
#rm ${fl}.unb
#done

exit
#
print_info_msg "
========================================================================
BUFR-sounding -processing completed successfully.

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

