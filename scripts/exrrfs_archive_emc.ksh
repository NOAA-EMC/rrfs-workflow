#!/bin/bash

set -x

currentime=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
day=$(date +%d -d "${currentime} 0 hours ago")
month=$(date +%m -d "${currentime} 0 hours ago")
year=$(date +%Y -d "${currentime} 0 hours ago")
hour=$(date +%H -d "${currentime} 0 hours ago")

. ${GLOBAL_VAR_DEFNS_FP}

echo $CDATE
echo $currentime
echo $year $month $day $hour
cd ${COMOUT_BASEDIR}/${RUN}.$year$month$day/$hour

files0=`ls -1 rrfs.*.testbed*`
files1=`ls -1 rrfs.*.prslev*`
files2=`ls -1 rrfs.*.natlev*`

runcount=${#files0}

echo $runcount

if [[ $runcount -gt 0 ]];then
  hsi mkdir -p $ARCHIVEDIR/rh$year/$year$month/$year$month$day/$hour/prod
  htar -chvf $ARCHIVEDIR/rh$year/$year$month/$year$month$day/$hour/prod/rrfs.t${hour}z.prslev.conus.grib2.tar rrfs.t${hour}z.prslev.f*.conus.grib2
  htar -chvf $ARCHIVEDIR/rh$year/$year$month/$year$month$day/$hour/prod/rrfs.t${hour}z.natlev.conus.grib2.tar rrfs.t${hour}z.natlev.f*.conus.grib2
  htar -chvf $ARCHIVEDIR/rh$year/$year$month/$year$month$day/$hour/prod/rrfs.t${hour}z.testbed.conus.grib2.tar rrfs.t${hour}z.testbed.f*.conus.grib2
fi

files3=`ls -1 rrfs.*.conusfv3*`
runcount3=${#files3}
if [[ $runcount3 -gt 0 ]];then
  htar -chvf $ARCHIVEDIR/rh$year/$year$month/$year$month$day/$hour/prod/rrfs.t${hour}z.conus.bufrsnd.tar rrfs.t${hour}z.conusfv3.bufrsnd.tar.gz rrfs.t${hour}z.conusfv3.class1.bufr rrfs.t${hour}z.conusfv3.profilm.c1
fi

files4=`ls -1 rrfs.*.fits*`
runcount4=${#files4}
if [[ $runcount4 -gt 0 ]];then
  htar -chvf $ARCHIVEDIR/rh$year/$year$month/$year$month$day/$hour/prod/rrfs.t${hour}z.fits.tar rrfs.t${hour}z.fit*.tm00
fi

fitdir=${COMOUT_BASEDIR}/${RUN}.$year$month$day/${hour}_spinup
if [ -d $fitdir ];then
   cd $fitdir
   files5=`ls -1 rrfs.*.fits*`
   runcount5=${#files5}
   if [[ $runcount5 -gt 0 ]];then
     htar -chvf $ARCHIVEDIR/rh$year/$year$month/$year$month$day/$hour/prod/rrfs.t${hour}z.fits.spinup.tar rrfs.t${hour}z.fit*.tm00
   fi
fi

exit


exit
#!/bin/ksh --login

module load hpss

day=`date -u "+%d" -d "-1 day"`
month=`date -u "+%m" -d "-1 day"`
year=`date -u "+%Y" -d "-1 day"`

. ${GLOBAL_VAR_DEFNS_FP}

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
      htar -chvf $ARCHIVEDIR/$year/$month/$day/$year$month$day$hour.tar $year$month$day$hour
      rm -rf $year$month$day$hour
    fi

  done
fi

rmdir $COMOUT_BASEDIR/stage

dateval=`date`
echo "Completed archive at "$dateval
exit 0

