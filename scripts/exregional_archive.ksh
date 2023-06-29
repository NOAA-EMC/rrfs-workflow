#!/bin/ksh --login
module load hpss
set -u -x

. ${GLOBAL_VAR_DEFNS_FP}

if [[ "${NET}" = "RTMA"* ]]; then #archive RTMA runs
<< FORTEST #comment out "FORTEST" lines to do offline tests
PDY=20230224
cyc=00
CYCLE_DIR=/tmp/gge/rtma
CDATE=$PDY$cyc
BASEDIR=/lfs4/BMC/nrtrr/NCO_dirs/rtma.v0.3.0
RUN=RTMA_CONUS
cd $CYCLE_DIR
ln -snf $BASEDIR/stmp/$CDATE/* .
COMROOT=$BASEDIR/com
COMOUT_BASEDIR=$BASEDIR/com/prod
ARCHIVEDIR=/BMC/wrfruc/5year/rtma_b
FORTEST
#
  YYYY=${PDY:0:4}
  MM=${PDY:4:2}
  DD=${PDY:6:2}

  workdir=$CYCLE_DIR/archive
  rm -rf $workdir
  mkdir -p $workdir
  cd $workdir
  mkdir -p bkg com.prod rundir
  
  #bkg
  cd bkg
  ln -snf $CYCLE_DIR/fcst_fv3lam/INPUT/bk_fv_core.res.tile1.nc .
  ln -snf $CYCLE_DIR/fcst_fv3lam/INPUT/bk_phy_data.nc .
  ln -snf $CYCLE_DIR/fcst_fv3lam/INPUT/bk_sfc_data.nc .
  ln -snf $CYCLE_DIR/fcst_fv3lam/INPUT/bk_fv_tracer.res.tile1.nc .
  zip -9 fv3_dynvars.zip bk_fv_core.res.tile1.nc &
  zip -9 fv3_phyvars.zip bk_phy_data.nc &
  zip -9 fv3_tracer.zip bk_fv_tracer.res.tile1.nc &
  zip -9 fv3_sfcdata.zip bk_sfc_data.nc &
  cd ..
  
  #log
  ln -snf ${COMROOT}/logs/$RUN.$PDY/$cyc  logs
  zip -9 logs.zip logs/* &

  #rundir
  cd rundir
  mkdir -p gsi process_bufr process_radarref/00
    cd gsi
    ln -snf $CYCLE_DIR/anal_conv_gsi/* .
    rm -rf pe0* *eff.bin diag* gsi.x fv3_tracer fv3*vars fv3_sfcdata obs_input.00*
    cd ..
    zip -9 gsi.zip gsi/* &

    cd process_bufr
    ln -snf $CYCLE_DIR/process_bufr/*  .
    rm -rf *.exe
    cd ..
    zip -9 process_bufr.zip process_bufr/*  &

    cd process_radarref/00
    ln -snf $CYCLE_DIR/process_radarref/00/*  .
    rm -rf *.exe
    cd ../..
    zip -9 process_radarref.zip process_radarref/*/*  &
  cd ..

  #com.prod
  cd com.prod
  COMOUT="${COMOUT_BASEDIR}/$RUN.$PDY/$cyc"
  ln -snf $COMOUT/* .
  rm -rf ${RUN}*.grib2 BG*0 #remove duplicate links
  cd ..
  zip -9 com.prod.zip com.prod/* &

  wait

  #remove links
  rm -rf bkg/bk_*.nc #remove the link
  rm -rf logs
  rm -rf rundir/{gsi,process_bufr,process_radarref}
  rm -rf com.prod

  #check whether HPSS is accessible
  timeout 10s hsi ls    1>/dev/null 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "HPSS is not accessible, exit"
    exit 1
  fi

  hsi mkdir -p ${ARCHIVEDIR}/$YYYY/$MM/$DD
  htar -cvf ${ARCHIVEDIR}/$YYYY/$MM/$DD/$CDATE.tar *
  
  cd ..
  rm -rf $workdir

  exit 0
fi

#------------------------------ RRFS ------------------------------#
currentime=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
day=$(date +%d -d "${currentime} 24 hours ago")
month=$(date +%m -d "${currentime} 24 hours ago")
year=$(date +%Y -d "${currentime} 24 hours ago")

cd ${COMOUT_BASEDIR}
set -A XX `ls -d ${RUN}.$year$month$day/* | sort -r`
runcount=${#XX[*]}
if [[ $runcount -gt 0 ]];then

  hsi mkdir -p $ARCHIVEDIR/$year/$month/$day

  for onerun in ${XX[*]};do

    echo "Archive files from ${onerun}"
    hour=${onerun##*/}

    if [[ -e ${COMOUT_BASEDIR}/${onerun}/nclprd/full/files.zip ]];then
      echo "Graphics..."
      mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/nclprd
      cp -rsv ${COMOUT_BASEDIR}/${onerun}/nclprd/* $COMOUT_BASEDIR/stage/$year$month$day$hour/nclprd
    fi

    set -A YY `ls -d ${COMOUT_BASEDIR}/${onerun}/*bg*tm*`
    postcount=${#YY[*]}
    echo $postcount
    if [[ $postcount -gt 0 ]];then
      echo "GRIB-2..."
      mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/postprd
      cp -rsv ${COMOUT_BASEDIR}/${onerun}/*bg*tm* $COMOUT_BASEDIR/stage/$year$month$day$hour/postprd 
    fi

    if [[ -e ${COMOUT_BASEDIR}/stage/$year$month$day$hour ]];then
      cd ${COMOUT_BASEDIR}/stage
      htar -chvf $ARCHIVEDIR/$year/$month/$day/post_$year$month$day$hour.tar $year$month$day$hour
      rm -rf $year$month$day$hour
    fi

  done
fi

rmdir $COMOUT_BASEDIR/stage

cd ${NWGES_BASEDIR}
set -A YY `ls -d ${year}${month}${day}?? | sort -r`
runcount=${#YY[*]}
if [[ $runcount -gt 0 ]];then

  hsi mkdir -p $ARCHIVEDIR/$year/$month/$day

  for onerun in ${YY[*]};do
     hour=$(echo $onerun | cut -c9-10 )
     htar -chvf $ARCHIVEDIR/$year/$month/$day/nwges_${onerun} ${onerun}
  done

fi


dateval=`date`
echo "Completed archive at "$dateval
exit 0

