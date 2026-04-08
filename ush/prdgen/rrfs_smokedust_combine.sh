################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         rrfs_smokedust_combine.sh
# Script description:  To generate the HYSPLIT look-alike smoke products for the Rapid Refresh Model
#
# Author:      M Hu, G Manikin /  GSL, EMC         Date: 2021-12-06
#
# Script history log:
# 2021-12-06  M Hu, G Manikin  -- new script
# 2022-06-17  B Blake          -- Send smoke output to COMOUT and add DBN alerts
# 2026-03-26  B Blake          -- adapted script for RRFS

set -xa

mkdir -p ${DATA}/smoke_dust
cd ${DATA}/smoke_dust

# Smoke files
for grid in 227 198 196
do
    for type in sfc pbl
    do    
        export OUTPUTfile=rrfs.t${cyc}z.smoke.${type}.1hr_${grid}.grib2
        cat ${umbrella_post_data}/rrfs.t${cyc}z.smoke.${type}.f0*.${grid}.grib2 > ${OUTPUTfile}

        if [[ $SENDCOM = "YES" ]] ; then
            cpreq -p ${OUTPUTfile} ${COMOUT}
            wgrib2 ${OUTPUTfile} -s > ${COMOUT}/${OUTPUTfile}.idx
        fi

        if [ "$SENDDBN" == "YES" ]; then
            ${DBNROOT}/bin/dbn_alert MODEL RRFS_DET $job $COMOUT/${OUTPUTfile}
            ${DBNROOT}/bin/dbn_alert MODEL RRFS_DET_IDX $job $COMOUT/${OUTPUTfile}.idx
        fi
    done
done

# Dust files
for type in sfc pbl
do
    export OUTPUTfile=rrfs.t${cyc}z.dust.${type}.1hr_227.grib2
    cat ${umbrella_post_data}/rrfs.t${cyc}z.dust.${type}.f0*.227.grib2 > ${OUTPUTfile}


    if [[ $SENDCOM = "YES" ]] ; then
        cpreq -p ${OUTPUTfile} ${COMOUT}
        wgrib2 ${OUTPUTfile} -s > ${COMOUT}/${OUTPUTfile}.idx
    fi

    if [ "$SENDDBN" == "YES" ]; then
        ${DBNROOT}/bin/dbn_alert MODEL RRFS_DET $job $COMOUT/${OUTPUTfile}
        ${DBNROOT}/bin/dbn_alert MODEL RRFS_DET_IDX $job $COMOUT/${OUTPUTfile}.idx
    fi
    cd ../
done
