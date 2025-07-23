#!/bin/ksh
###################################################################
echo "--------------------------------------------------------------"
echo "exrrfs_nawips - convert RRFS NCEP GRIB files into GEMPAK Grids"
echo "--------------------------------------------------------------"
#####################################################################

set -xa

RUNTYPE=$1
GRIB=$2
finc=$3
fend=$4

cd $DATA/$RUNTYPE

# Hourly GEMPAK files created until this hour, then 3 hourly
HOURLY_LIMIT=48

msg="Begin job for $job"
postmsg "$msg"

export PS4='GEMPAK_T$SECONDS + '

# RRFSFIXgem=${HOMErrfs}/util/fix_grib2
NAGRIB=nagrib2

cp $RRFSFIXgem/rrfs_g2varsncep1.tbl g2varsncep1.tbl
cp $RRFSFIXgem/rrfs_g2varswmo2.tbl g2varswmo2.tbl
cp $RRFSFIXgem/rrfs_g2vcrdncep1.tbl g2vcrdncep1.tbl
cp $RRFSFIXgem/rrfs_g2vcrdwmo2.tbl g2vcrdwmo2.tbl

cpyfil=gds
garea=dset
gbtbls=""
maxgrd=4999
kxky=""
grdarea=""
proj=""
output=T
  
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
   rrfs_conus) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_conus_mag) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_conus_cam) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_hawaii) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr3}.hi.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
   rrfs_prico) GRIBIN=$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr3}.pr.grib2
                GEMGRD=${RUNTYPE}_${PDY}${cyc}f${fhr3} ;;
  esac

  if [ $RUNTYPE = "rrfs_alaska" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.alaska.grib2.idx
  elif [ $RUNTYPE = "rrfs_conus" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2.idx
  elif [ $RUNTYPE = "rrfs_conus_mag" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2.idx
  elif [ $RUNTYPE = "rrfs_conus_cam" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2.idx
  elif [ $RUNTYPE = "rrfs_hawaii" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr3}.hi.grib2.idx
  elif [ $RUNTYPE = "rrfs_prico" ] ; then
    GRIBIN_chk=$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr3}.pr.grib2.idx
  else
    GRIBIN_chk=$GRIBIN
  fi


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

  case $RUNTYPE in
   rrfs_alaska)
         $WGRIB2 -s $GRIBIN | grep -f $RRFSFIXgem/rrfs.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   rrfs_conus)
         $WGRIB2 $GRIBIN | grep "REFD:263 K" | grep max | $WGRIB2 -i -grib tempref263k $GRIBIN
         $WGRIB2 tempref263k -set_byte 4 11 198 -grib tempmaxref263k
         $WGRIB2 -s $GRIBIN | grep -f $RRFSFIXgem/rrfs.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         cat temp tempmaxref263k > grib$fhr
     ;;
   rrfs_conus_mag)
         $WGRIB2 -s $GRIBIN | grep -f $RRFSFIXgem/rrfs.parmlist_mag|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   rrfs_conus_cam)
         $WGRIB2 $GRIBIN | grep "REFD:263 K" | grep max | $WGRIB2 -i -grib tempref263k $GRIBIN
         $WGRIB2 tempref263k -set_byte 4 11 198 -grib tempmaxref263k
         cat $GRIBIN tempmaxref263k > grib$fhr
     ;;
   rrfs_hawaii)
         $WGRIB2 -s $GRIBIN | grep -f $RRFSFIXgem/rrfs.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
     ;;
   rrfs_prico)
         $WGRIB2 -s $GRIBIN | grep -f $RRFSFIXgem/rrfs.parmlist|$WGRIB2 -i -grib temp $GRIBIN
         mv temp grib$fhr
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
       if [ $RUNTYPE = "rrfs" -a $fhcnt3 -ne 0 ] ; then
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





   if [ $RUNTYPE = "rrfs_alaska" -a $fhcnt -lt ${HOURLY_LIMIT} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_conus" -a $fhcnt -lt ${HOURLY_LIMIT} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_conus_mag" -a $fhcnt -lt ${HOURLY_LIMIT} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_conus_cam" -a $fhcnt -lt ${HOURLY_LIMIT} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_hawaii" -a $fhcnt -lt ${HOURLY_LIMIT} ] ; then
     let fhcnt=fhcnt+1
   elif [ $RUNTYPE = "rrfs_prico" -a $fhcnt -lt ${HOURLY_LIMIT} ] ; then
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
