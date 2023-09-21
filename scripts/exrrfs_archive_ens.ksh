#!/bin/ksh --login

module load hpss

day=$(date -u "+%d" -d "-1 day")
month=$(date -u "+%m" -d "-1 day")
year=$(date -u "+%Y" -d "-1 day")

. ${GLOBAL_VAR_DEFNS_FP}

cd ${COMOUT_BASEDIR}
set -A XX $(ls -d ${RUN}.$year$month$day/* | sort)
runcount=${#XX[*]}

if [[ $runcount -gt 0 ]];then

  hsi mkdir -p $ARCHIVEDIR/$year/$month/$day

  for onerun in ${XX[*]}; do

    echo "Archive files from ${onerun}"
    hour=${onerun##*/}
#
#-------------------------------------------------------------------------
#
# Archiving python graphics
#
#-------------------------------------------------------------------------
#
    if [ "$(ls ${COMOUT_BASEDIR}/${onerun}/pyprd)" ]; then
      echo "Python Graphics..."
      mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/pyprd
      cp -rsv ${COMOUT_BASEDIR}/${onerun}/pyprd/* $COMOUT_BASEDIR/stage/$year$month$day$hour/pyprd
    fi
#
#-------------------------------------------------------------------------
#
# Archiving ncl graphics
#
#-------------------------------------------------------------------------
#
    if [ "$(ls ${COMOUT_BASEDIR}/${onerun}/nclprd)" ]; then
      echo "NCL Graphics..."
      mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/nclprd
      cp -rsv ${COMOUT_BASEDIR}/${onerun}/nclprd/* $COMOUT_BASEDIR/stage/$year$month$day$hour/nclprd
    fi
#
#-------------------------------------------------------------------------
#
# Archiving ensprod
#
#-------------------------------------------------------------------------
#
    if [ "$(ls ${COMOUT_BASEDIR}/${onerun}/ensprod)" ]; then
      echo "ensprod..."
      mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/ensprod
      cp -rsv ${COMOUT_BASEDIR}/${onerun}/ensprod/* $COMOUT_BASEDIR/stage/$year$month$day$hour/ensprod
    fi
#
#-------------------------------------------------------------------------
#
# Archiving EnKF diag files 
#
#-------------------------------------------------------------------------
#
    if [[ -d ${CYCLE_BASEDIR}/$year$month$day$hour/enkfupdt ]];then
      echo "EnKF Diag ..."
      mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/enkfupdt
      cp ${CYCLE_BASEDIR}/$year$month$day$hour/enkfupdt/std* $COMOUT_BASEDIR/stage/$year$month$day$hour/enkfupdt
      cp ${CYCLE_BASEDIR}/$year$month$day$hour/enkfupdt/enkf.nml $COMOUT_BASEDIR/stage/$year$month$day$hour/enkfupdt
    fi
#
#-------------------------------------------------------------------------
#
# Archiving INPUT/ files
#
#-------------------------------------------------------------------------
#
    if [[ -d ${CYCLE_BASEDIR}/$year$month$day$hour/recenter/fcst_fv3lam/INPUT ]];then
      echo "Re-center Diag ..."
      mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/recenter/fcst_fv3lam/INPUT
      cp ${CYCLE_BASEDIR}/$year$month$day$hour/recenter/fcst_fv3lam/INPUT/std* $COMOUT_BASEDIR/stage/$year$month$day$hour/recenter/fcst_fv3lam/INPUT
      cp ${CYCLE_BASEDIR}/$year$month$day$hour/recenter/fcst_fv3lam/INPUT/fv3sar_tile1_dynvar $COMOUT_BASEDIR/stage/$year$month$day$hour/recenter/fcst_fv3lam/INPUT
      cp ${CYCLE_BASEDIR}/$year$month$day$hour/recenter/fcst_fv3lam/INPUT/fv3sar_tile1_tracer $COMOUT_BASEDIR/stage/$year$month$day$hour/recenter/fcst_fv3lam/INPUT
      cp ${CYCLE_BASEDIR}/$year$month$day$hour/recenter/fcst_fv3lam/INPUT/fv3sar_tile1_phyvar $COMOUT_BASEDIR/stage/$year$month$day$hour/recenter/fcst_fv3lam/INPUT
    fi
#
#-------------------------------------------------------------------------
#
# Archiving GRIB-2 forecast data 
#
#-------------------------------------------------------------------------
#
    for imem in  $(seq 1 $nens) ; do

      ensmem="mem"$(printf %04i $imem)
    
      set -A YY $(ls -d ${COMOUT_BASEDIR}/${onerun}/${ensmem}/*bg*tm*)
      postcount=${#YY[*]}
      echo $postcount
      if [[ $postcount -gt 0 ]];then
        echo "GRIB-2 for ${ensmem} ..."
        mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/${ensmem}/postprd
        cp -rsv ${COMOUT_BASEDIR}/${onerun}/${ensmem}/*bg*tm* $COMOUT_BASEDIR/stage/$year$month$day$hour/${ensmem}/postprd 
      fi

      if [[ -e ${CYCLE_BASEDIR}/$year$month$day$hour/${ensmem}/fcst_fv3lam/INPUT/gfs_data.tile7.halo0.nc ]]; then
         echo "INPUT  for ${ensmem} ..."
         mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/${ensmem}/fcst_fv3lam/input
         cp -rsv ${CYCLE_BASEDIR}/$year$month$day$hour/${ensmem}/fcst_fv3lam/INPUT $COMOUT_BASEDIR/stage/$year$month$day$hour/${ensmem}/fcst_fv3lam/input
         cp -rsv ${CYCLE_BASEDIR}/$year$month$day$hour/${ensmem}/fcst_fv3lam/input.nml $COMOUT_BASEDIR/stage/$year$month$day$hour/${ensmem}/fcst_fv3lam/input 
         cp -rsv ${CYCLE_BASEDIR}/$year$month$day$hour/${ensmem}/fcst_fv3lam/model_configure $COMOUT_BASEDIR/stage/$year$month$day$hour/${ensmem}/fcst_fv3lam/input 
      fi

    done

#
#-------------------------------------------------------------------------
#
# Archiving restart and input data from NWGES 
#
#-------------------------------------------------------------------------
#
    for imem in  $(seq 1 $nens) ; do

      ensmem="mem"$(printf %04i $imem)
    
      set -A YY $(ls -d ${NWGES_BASEDIR}/$year$month$day$hour/${ensmem}/*)
      postcount=${#YY[*]}
      echo $postcount
      if [[ $postcount -gt 0 ]];then
        echo "NWGES (fcst_fv3lam, observer_gsi) for ${ensmem} ..."
        mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/nwges/${ensmem}
        cp -rsv ${NWGES_BASEDIR}/$year$month$day$hour/${ensmem}/* $COMOUT_BASEDIR/stage/$year$month$day$hour/nwges/${ensmem} 
      fi

    done
#
#-------------------------------------------------------------------------
#
# Archiving GSI diag files from observer runs
#
#-------------------------------------------------------------------------
#
    for imem in  $(seq 1 $nens) ensmean; do
      if [ ${imem} == "ensmean" ]; then 
         ensmem="ensmean"
      else    
         ensmem="mem"$(printf %04i $imem)
      fi
      if [[ -d ${CYCLE_BASEDIR}/$year$month$day$hour/$ensmem/observer_gsi ]];then
         echo "GSI Diag for $ensmem ..."
         mkdir -p $COMOUT_BASEDIR/stage/$year$month$day$hour/$ensmem/observer_gsi
         cp -rsv ${CYCLE_BASEDIR}/$year$month$day$hour/$ensmem/observer_gsi/diag* $COMOUT_BASEDIR/stage/$year$month$day$hour/$ensmem/observer_gsi
         cp -rsv ${CYCLE_BASEDIR}/$year$month$day$hour/$ensmem/observer_gsi/stdout $COMOUT_BASEDIR/stage/$year$month$day$hour/$ensmem/observer_gsi
         cp -rsv ${CYCLE_BASEDIR}/$year$month$day$hour/$ensmem/observer_gsi/gsiparm.anl $COMOUT_BASEDIR/stage/$year$month$day$hour/$ensmem/observer_gsi
      fi
    done

#
#-------------------------------------------------------------------------
#
# Using htar to put the staged data to HPSS 
#
#-------------------------------------------------------------------------
#
    if [[ -e ${COMOUT_BASEDIR}/stage/$year$month$day$hour ]];then
      cd ${COMOUT_BASEDIR}/stage
      htar -chvf $ARCHIVEDIR/$year/$month/$day/$year$month$day$hour.tar $year$month$day$hour
      rm -rf $year$month$day$hour
    fi

  done
fi
#
#-------------------------------------------------------------------------
#
# Remove the staged data on disk
#
#-------------------------------------------------------------------------
#
rmdir $COMOUT_BASEDIR/stage

dateval=$(date)
echo "Completed archive at "$dateval
exit 0

