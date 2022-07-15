#!/bin/ksh --login

module load hpss

currentime=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')
day=$(date +%d -d "${currentime} 24 hours ago")
month=$(date +%m -d "${currentime} 24 hours ago")
year=$(date +%Y -d "${currentime} 24 hours ago")

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

