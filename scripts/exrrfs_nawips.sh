#!/bin/ksh
###################################################################
echo "----------------------------------------------------"
echo "exnawips - convert NCEP GRIB files into GEMPAK Grids"
echo "----------------------------------------------------"
echo "History: Mar 2000 - First implementation of this new script."
echo "S Lilly: May 2008 - add logic to make sure that all of the "
echo "                    data produced from the restricted ECMWF"
echo "                    data on the CCS is properly protected."
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
   nam12) GRIBIN1=$COMIN/${model}.${cycle}.${GRIB1}${fhr}${EXT}.grib2 ;;
   nam12carib) GRIBIN1=$COMIN/${model}.${cycle}.${GRIB1}${fhr}${EXT}.grib2 ;;
   nam_alaskanest) GRIBIN=$COMIN/${model}.${cycle}.alaskanest.${GRIB}${fhr}${EXT}.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   nam_conusnest) GRIBIN=$COMIN/${model}.${cycle}.conusnest.${GRIB}${fhr}${EXT}.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   nam_conusnest_mag) GRIBIN=$COMIN/${model}.${cycle}.conusnest.${GRIB}${fhr}${EXT}.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   nam_conusnest_cam) GRIBIN=$COMIN/${model}.${cycle}.conusnest.${GRIB}${fhr}${EXT}.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   nam_hawaiinest) GRIBIN=$COMIN/${model}.${cycle}.hawaiinest.${GRIB}${fhr}${EXT}.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   nam_priconest) GRIBIN=$COMIN/${model}.${cycle}.priconest.${GRIB}${fhr}${EXT}.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
  esac

  if [ $RUNTYPE = "nam12" ] ; then
    GRIBIN_chk=$GRIBIN
    GRIBIN_chk1=$GRIBIN1
  elif [ $RUNTYPE = "nam_alaskanest" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.alaskanest.${GRIB}${fhr}${EXT}.grib2.idx
  elif [ $RUNTYPE = "nam_conusnest" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.conusnest.${GRIB}${fhr}${EXT}.grib2.idx
  elif [ $RUNTYPE = "nam_conusnest_mag" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.conusnest.${GRIB}${fhr}${EXT}.grib2.idx
  elif [ $RUNTYPE = "nam_conusnest_cam" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.conusnest.${GRIB}${fhr}${EXT}.grib2.idx
  elif [ $RUNTYPE = "nam_hawaiinest" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.hawaiinest.${GRIB}${fhr}${EXT}.grib2.idx
  elif [ $RUNTYPE = "nam_priconest" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.priconest.${GRIB}${fhr}${EXT}.grib2.idx
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
   nam_alaskanest)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/nam_alaskanest.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   nam_conusnest)
         $WGRIB2 $GRIBIN | grep "REFD:263 K" | grep max | $WGRIB2 -i -grib tempref263k $GRIBIN
         $WGRIB2 tempref263k -set_byte 4 11 198 -grib tempmaxref263k
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/nam_conusnest.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         cat temp tempmaxref263k > grib$fhr
     ;;
   nam_conusnest_mag)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/nam_conusnest.parmlist_mag|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   nam_conusnest_cam)
         $WGRIB2 $GRIBIN | grep "REFD:263 K" | grep max | $WGRIB2 -i -grib tempref263k $GRIBIN
         $WGRIB2 tempref263k -set_byte 4 11 198 -grib tempmaxref263k
         cat $GRIBIN tempmaxref263k > grib$fhr
     ;;
   nam_hawaiinest)
         $WGRIB2 -s $GRIBIN | grep -f $utilfix_nam/nam_hawaiinest.parmlist|$WGRIB2 -i -grib temp $GRIBIN
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

  #
  # Create ZAGL level products for the 40 km NAM grid and the ruc
  #
  if [ "$RUNTYPE" = "nam40" ] ; then
    gdvint << EOF
     GDFILE   = $GEMGRD
     GDOUTF   = $GEMGRD
     GDATTIM  = f${fhr}
     GVCORD   = pres/zagl
     GLEVEL   = 500-9000-500
     MAXGRD   = 5000
     GAREA    = $garea
     VCOORD   = mslv;esfc
     l
     r
EOF
  fi

  #
  # Create theta level products for the 90 and 40 km NAM grids
  #
  if [ "$RUNTYPE" = "nam40" -o "$RUNTYPE" = "nam" ] ; then
    gdvint << EOF
     GDFILE   = $GEMGRD
     GDOUTF   = $GEMGRD
     GDATTIM  = f${fhr}
     GVCORD   = pres/thta
     GLEVEL   = 270-330-3
     MAXGRD   = 5000
     GAREA    = $garea
     VCOORD   = /l
     l
     r
EOF
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





   if [ $RUNTYPE = "nam" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_PARENT} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam12" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_PARENT} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam32" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_PARENT} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam40" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_PARENT} ]; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam_alaskanest" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_NEST} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam_conusnest" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_NEST} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam_conusnest_mag" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_NEST} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam_conusnest_cam" -a $fhcnt -lt ${PRDGENSWITCH_HOUR_NEST} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "nam_hawaiinest" -a $fhcnt -lt 36 ] ; then
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
echo "**************JOB $RUNTYPE NAWIPS COMPLETED NORMALLY ON THE IBM"
echo "**************JOB $RUNTYPE NAWIPS COMPLETED NORMALLY ON THE IBM"
echo "**************JOB $RUNTYPE NAWIPS COMPLETED NORMALLY ON THE IBM"
set -x
#####################################################################

msg='Job completed normally.'
echo $msg
postmsg "$msg"

############################### END OF SCRIPT #######################
