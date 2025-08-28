#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHrrfs/source_util_funcs.sh
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

This is the ex-script for the task that runs the bufr-sounding 
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
    ncores=$(( NNODES_BUFRSND*PPN_BUFRSND ))
    APRUNC="mpiexec -n ${ncores} -ppn ${PPN_BUFRSND}"
    APRUNS="time"
    ;;

  "HERA")
    APRUNC="srun --export=ALL"
    APRUNS="time"
    ;;

  "ORION")
    APRUNC="srun --export=ALL"
    APRUNS="time"
    ;;

  "HERCULES")
    APRUNC="srun --export=ALL"
    APRUNS="time"
    ;;

  "JET")
    APRUNC="srun --export=ALL"
    APRUNS="time"
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
mkdir -p $DATA/bufrpost
cd $DATA/bufrpost

NSTAT=1950

cpreq -p ${FIX_BUFRSND}/${PREDEF_GRID_NAME}/rrfs_profdat.${NSTAT} regional_profdat

OUTTYP=netcdf

model=FV3S

INCR=01
FHRLIM=${FHRLIM}

let NFILE=1

START_DATE=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')

PDY=$CDATE

YYYY=`echo $PDY | cut -c1-4`
MM=`echo $PDY | cut -c5-6`
DD=`echo $PDY | cut -c7-8`
CYCLE=$PDY$cyc

startd=$YYYY$MM$DD
startdate=$CYCLE

STARTDATE=${YYYY}-${MM}-${DD}_${cyc}:00:00
endtime=$(date +%Y%m%d%H -d "${START_DATE} +${FHRLIM} hours")

YYYY=`echo $endtime | cut -c1-4`
MM=`echo $endtime | cut -c5-6`
DD=`echo $endtime | cut -c7-8`

FINALDATE=${YYYY}-${MM}-${DD}_${cyc}:00:00

if [ -e sndpostdone00.tm00 ]; then
  lasthour=`ls -1rt sndpostdone??.tm00 | tail -1 | cut -c 12-13`
  typeset -Z2 lasthour

  let "fhr=$(( ${fhr#0} + 1 ))"
  if [ $fhr -le 10 ]; then
     fhr=$(printf "%02d" $fhr)
  fi
else
  fhr=00
fi

echo starting with fhr $fhr

########################################################
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

while [ $fhr -le $FHRLIM ]
do

  date=$(date +%Y%m%d%H -d "${START_DATE} +${fhr} hours")

  let "fhrold=$(( ${fhr#0} - 1 ))"
  if [ $fhrold -le 10 ]; then
     fhrold=$(printf "%02d" $fhrold)
  fi

  LOGFILE=log.atm.f0${fhr}
  if [ $model = "FV3S" ]; then

    if [ ${nsout_min} -ge 60 ]; then
      OUTFILDYN=${shared_forecast_output_data}/dynf0${fhr}.nc
      OUTFILPHYS=${shared_forecast_output_data}/phyf0${fhr}.nc
      LOGFILE=log.atm.f0${fhr}
    else
      if [ ${fhr} -eq 00 ]; then
        SUBOUTFILDYN=${shared_forecast_output_data}/dynf0${fhr}-00-36.nc
        SUBOUTFILPHYS=${shared_forecast_output_data}/phyf0${fhr}-00-36.nc
        LOGFILE=log.atm.f0${fhr}-00-36
      else
        SUBOUTFILDYN=${shared_forecast_output_data}/dynf0${fhr}-00-00.nc
        SUBOUTFILPHYS=${shared_forecast_output_data}/phyf0${fhr}-00-00.nc
        LOGFILE=log.atm.f0${fhr}-00-00
      fi
      OUTFILDYN=${shared_forecast_output_data}/dynf0${fhr}.nc
      OUTFILPHYS=${shared_forecast_output_data}/phyf0${fhr}.nc
      ln -s ${SUBOUTFILDYN} ${OUTFILDYN}
      ln -s ${SUBOUTFILPHYS} ${OUTFILPHYS}
    fi

    icnt=1

    # wait for model restart file
    while [ $icnt -lt 1000 ]
    do
      if [ -s ${shared_forecast_output_data}/${LOGFILE} ]; then
        break
      else
        icnt=$((icnt + 1))
        sleep 9
      fi
      if [ $icnt -ge 200 ]; then
        err_exit "ABORTING after 30 minutes of waiting for RRFS FCST F${fhr} to end."
      fi
    done

  else
    err_exit "ABORTING due to bad model selection for this script."
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
$NSTAT
$OUTFILDYN
$OUTFILPHYS
EOF

ln -sf $DATA/bufrpost/regional_profdat     fort.19
ln -sf $DATA/bufrpost/profilm.c1.${tmmark} fort.79
ln -sf ./itag                              fort.11

  export pgm="rrfs_bufr.exe"
  . prep_step

  ${APRUNC} ${EXECrrfs}/$pgm >>$pgmout 2>errfile
  export err=$?; err_chk
  mv errfile errfile_rrfs_bufr

  echo DONE $fhr at `date`

  mv $DATA/bufrpost/profilm.c1.${tmmark} $DATA/profilm.c1.${tmmark}.f${fhr}
  echo done > $DATA/sndpostdone${fhr}.${tmmark}

  cat $DATA/profilm.c1.${tmmark}  $DATA/profilm.c1.${tmmark}.f${fhr} > $DATA/profilm_int
  mv $DATA/profilm_int $DATA/profilm.c1.${tmmark}

  fhr=`expr $fhr + $INCR`

  if [ $fhr -lt 10 ]; then
    fhr=0$fhr
  fi

done

cd $DATA

########################################################
# SNDP code
########################################################

export pgm=rrfs_sndp

cpreq -p ${FIX_BUFRSND}/regional_sndp.parm.mono $DATA/regional_sndp.parm.mono
cpreq -p ${FIX_BUFRSND}/regional_bufr.tbl $DATA/regional_bufr.tbl

ln -sf $DATA/regional_sndp.parm.mono fort.11
ln -sf $DATA/regional_bufr.tbl       fort.32
ln -sf $DATA/profilm.c1.${tmmark}    fort.66
ln -sf $DATA/class1.bufr             fort.78

echo here model $model

nlev=65

FCST_LEN_HRS=$FHRLIM
echo "$nlev $NSTAT $FCST_LEN_HRS" > itag

export pgm="rrfs_sndp.exe"
. prep_step

${APRUNS} ${EXECrrfs}/$pgm < itag >>$pgmout 2>errfile
export err=$?; err_chk
mv errfile errfile_rrfs_sndp

SENDCOM=YES

if [ "${SENDCOM}" = "YES" ]; then
  cp $DATA/class1.bufr $COMOUT/rrfs.t${cyc}z.class1.bufr
  cp $DATA/profilm.c1.${tmmark} ${COMOUT}/rrfs.t${cyc}z.profilm.c1
fi

# remove bufr file breakout directory in $COMOUT if it exists

if [ -d ${COMOUT}/bufr.${cyc} ]; then
  cd $COMOUT
  rm -r bufr.${cyc}
  cd $DATA
fi

rm stnmlist_input

cat <<EOF > stnmlist_input
1
$DATA/class1.bufr
${COMOUT}/bufr.${cyc}/bufr
EOF

mkdir -p ${COMOUT}/bufr.${cyc}

# export FORT20=$DATA/class1.bufr
ln -sf $DATA/class1.bufr fort.20

export DIRD=${COMOUT}/bufr.${cyc}/bufr

echo "before stnmlist.exe"

export pgm="rrfs_stnmlist.exe"
. prep_step

${APRUNS} ${EXECrrfs}/$pgm < stnmlist_input >>$pgmout 2>errfile
export err=$?; err_chk
mv errfile errfile_rrfs_stnmlist

echo "after stnmlist.exe"

echo ${COMOUT}/bufr.${cyc} > ${COMOUT}/bufr.${cyc}/bufrloc

cd ${COMOUT}/bufr.${cyc}

# Tar and gzip the individual bufr files and send them to /com
tar -cf - . | /usr/bin/gzip > ../rrfs.t${cyc}z.bufrsnd.tar.gz

cpreq -p $GEMPAK_FIX/snrrfs.prm snrrfs.prm
cpreq -p $GEMPAK_FIX/sfrrfs.prm_aux sfrrfs.prm_aux
cpreq -p $GEMPAK_FIX/sfrrfs.prm sfrrfs.prm

mkdir -p $COMOUT/gempak

#  Set input file name.
INFILE=$COMOUT/rrfs.t${cyc}z.class1.bufr
export INFILE

outfilbase=rrfs_${PDY}${cyc}

namsnd << EOF > /dev/null
SNBUFR   = $INFILE
SNOUTF   = ${outfilbase}.snd
SFOUTF   = ${outfilbase}.sfc+
SNPRMF   = snrrfs.prm
SFPRMF   = sfrrfs.prm
TIMSTN   = 85/$NSTAT
r

exit
EOF

print_info_msg "
========================================================================
BUFR-sounding -processing completed successfully.

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

