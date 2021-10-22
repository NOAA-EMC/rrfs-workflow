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

