#!/bin/ksh
###################################################################
echo "--------------------------------------------------------------"
echo "exrrfs_nawips - convert RRFS NCEP GRIB files into GEMPAK Grids"
echo "--------------------------------------------------------------"
#####################################################################

set -xa

RUNTYPE=$1
GRIB=$2
GRIB1=$3
finc=$4
fend=$5

cd $DATA/$RUNTYPE

msg="Begin job for $job"
postmsg "$msg"

export PS4='GEMPAK_T$SECONDS + '

NAGRIB_TABLE=${NAMFIXgem}/nagrib.tbl
utilfix_nam=${HOMEnam}/util/fix_grib2
NAGRIB=nagrib2

cp $NAMFIXgem/hrrr_g2varsncep1.tbl g2varsncep1.tbl
cp $NAMFIXgem/hrrr_g2varswmo2.tbl g2varswmo2.tbl
cp $NAMFIXgem/hrrr_g2vcrdncep1.tbl g2vcrdncep1.tbl
cp $NAMFIXgem/hrrr_g2vcrdwmo2.tbl g2vcrdwmo2.tbl

entry=`grep "^$RUNTYPE " $NAGRIB_TABLE | awk 'index($1,"#") != 1 {print $0}'`

if [ "$entry" != "" ] ; then
  cpyfil=`echo $entry  | awk 'BEGIN {FS="|"} {print $2}'`
  garea=`echo $entry   | awk 'BEGIN {FS="|"} {print $3}'`
  gbtbls=`echo $entry  | awk 'BEGIN {FS="|"} {print $4}'`
  maxgrd=`echo $entry  | awk 'BEGIN {FS="|"} {print $5}'`
  kxky=`echo $entry    | awk 'BEGIN {FS="|"} {print $6}'`
  grdarea=`echo $entry | awk 'BEGIN {FS="|"} {print $7}'`
  proj=`echo $entry    | awk 'BEGIN {FS="|"} {print $8}'`
  output=`echo $entry  | awk 'BEGIN {FS="|"} {print $9}'`
else
  cpyfil=gds
  garea=dset
  gbtbls=
  maxgrd=4999
  kxky=
  grdarea=
  proj=
  output=T
fi  
pdsext=no

maxtries=720
fhcnt=$fstart
while [ $fhcnt -le $fend ] ; do
  if [ $fhcnt -ge 100 ] ; then
    typeset -Z3 fhr
  else
    typeset -Z2 fhr
  fi
  fhr=$fhcnt
  fhcnt3=`expr $fhr % 3`

  fhr3=$fhcnt
  typeset -Z3 fhr3
  GRIBIN=$COMIN/${model}.${cycle}.${GRIB}${fhr}${EXT}.grib2
  GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3}

  case $RUNTYPE in
   rrfs_alaska) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.ak.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_conus) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.3km.${fhr3}.conus.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_conus_mag) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.3km.${fhr3}.conus.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_conus_cam) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.3km.${fhr3}.conus.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_hawaii) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.2p5km.${fhr3}.hi.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_prico) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.2p5km.${fhr3}.pr.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
  esac

  if [ $RUNTYPE = "rrfs_alaska" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr}.alaska.grib2.idx
  elif [ $RUNTYPE = "rrfs_conus" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr}.conus.grib2.idx
  elif [ $RUNTYPE = "rrfs_conus_mag" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr}.conus.grib2.idx
  elif [ $RUNTYPE = "rrfs_conus_cam" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr}.conus.grib2.idx
  elif [ $RUNTYPE = "rrfs_hawaii" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr}.hi.grib2.idx
  elif [ $RUNTYPE = "nam_priconest" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr}.pr.grib2.idx
  else
    GRIBIN_chk=$GRIBIN
  fi

  if [ $RUNTYPE = "nam12" ] ; then

  icnt=1
  while [ $icnt -lt 1000 ]
  do
    if [[ -r $GRIBIN_chk && -r $GRIBIN_chk1 ]] ; then
      sleep 20
      break
    else
      let "icnt=icnt+1"
      sleep 20
    fi
    if [ $icnt -ge $maxtries ]
    then
      msg="ABORTING after 2 hours of waiting for F$fhr to end."
      err_exit $msg
    fi
  done

  else

  icnt=1
  while [ $icnt -lt 1000 ]
  do
    if [ -r $GRIBIN_chk ] ; then
      # JY sleep 20
      sleep 5
      break
    else
      let "icnt=icnt+1"
      sleep 20
    fi
    if [ $icnt -ge $maxtries ]
    then
      msg="ABORTING after 2 hours of waiting for F$fhr to end."
      err_exit $msg
    fi
  done

  fi

  case $RUNTYPE in
   rrfs_alaska)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/rrfs_alaska.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   rrfs_conus)
         $WGRIB2 $GRIBIN | grep "REFD:263 K" | grep max | $WGRIB2 -i -grib tempref263k $GRIBIN
         $WGRIB2 tempref263k -set_byte 4 11 198 -grib tempmaxref263k
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/rrfs_conus.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         cat temp tempmaxref263k > grib$fhr
     ;;
   rrfs_conus_mag)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/rrfs_conus.parmlist_mag|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   rrfs_conus_cam)
         $WGRIB2 $GRIBIN | grep "REFD:263 K" | grep max | $WGRIB2 -i -grib tempref263k $GRIBIN
         $WGRIB2 tempref263k -set_byte 4 11 198 -grib tempmaxref263k
         cat $GRIBIN tempmaxref263k > grib$fhr
     ;;
   rrfs_hawaii)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/rrfs_hawaii.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   nam_priconest)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/nam_priconest.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   nam64)
         $WGRIB2 $GRIBIN | grep -f $NAMFIXgem/nam64.awc.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         $COPYGB2 -g "255 3 175 139 1000 -145500 8 -107000 64926 64926 0 64 50000 50000" -x temp grib$fhr
     ;;
   nam12carib)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/nam_nam12carib_parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   nam32)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/nam_grid151.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   nam12)
       if [ $fhcnt3 -eq 0 ] ; then
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/wrf4spc12.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         $WGRIB2 -s $GRIBIN1 | grep -f $utilfix_nam/wrf4spc12.parmlist_1|$WGRIB2 -i -grib temp1 $GRIBIN1
         cat temp temp1 > grib$fhr
       else
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/wrf4spc12_hourly.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         $WGRIB2 -s $GRIBIN1 | grep -f $utilfix_nam/wrf4spc12_hourly.parmlist_1|$WGRIB2 -i -grib temp1 $GRIBIN1
         cat temp temp1 > grib$fhr
       fi
     ;;
   *)
     cp $GRIBIN grib$fhr
  esac

  export pgm="nagrib2 F$fhr"
  startmsg

  $NAGRIB << EOF
   GBFILE   = grib$fhr
   INDXFL   = 
   GDOUTF   = $GEMGRD
   PROJ     = $proj
   GRDAREA  = $grdarea
   KXKY     = $kxky
   MAXGRD   = $maxgrd
   CPYFIL   = $cpyfil
   GAREA    = $garea
   OUTPUT   = $output
   GBTBLS   = $gbtbls
   GBDIAG   = 
   PDSEXT   = $pdsext
  l
  r
EOF
  export err=$?;err_chk

  #####################################################
  # GEMPAK DOES NOT ALWAYS HAVE A NON ZERO RETURN CODE
  # WHEN IT CAN NOT PRODUCE THE DESIRED GRID.  CHECK
  # FOR THIS CASE HERE.
  #####################################################
  if [ $model != "ukmet_early" ] ; then
    ls -l $GEMGRD
    export err=$?;export pgm="GEMPAK CHECK FILE";err_chk
  fi

  if [ "$NAGRIB" = "nagrib2" ] ; then
    gpend
  fi


  if [ $SENDCOM = "YES" ] ; then
     cpfs $GEMGRD $COMAWP/$GEMGRD
     if [ $SENDDBN = "YES" ] ; then
       if [ $RUNTYPE = "nam" -a $fhcnt3 -ne 0 ] ; then
         $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE_2} $job \
            $COMAWP/$GEMGRD
       else
         $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE} $job \
           $COMAWP/$GEMGRD
       fi
     else
       echo "##### DBN_ALERT_TYPE is: ${DBN_ALERT_TYPE} #####"
     fi
  fi





   if [ $RUNTYPE = "rrfs_alaska" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_NEST} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_conus" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_NEST} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_conus_mag" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_NEST} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_conus_cam" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_NEST} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_hawaii" -a $fhcnt -lt 36 ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam_priconest" -a $fhcnt -lt 36 ] ; then
     let fhcnt=fhcnt+1
   else
    let fhcnt=fhcnt+finc
   fi
done

#####################################################################
# GOOD RUN
set +x
echo "**************JOB $RUNTYPE NAWIPS COMPLETED NORMALLY"
echo "**************JOB $RUNTYPE NAWIPS COMPLETED NORMALLY"
echo "**************JOB $RUNTYPE NAWIPS COMPLETED NORMALLY"
set -x
#####################################################################

msg='Job completed normally.'
echo $msg
postmsg "$msg"

############################### END OF SCRIPT #######################
