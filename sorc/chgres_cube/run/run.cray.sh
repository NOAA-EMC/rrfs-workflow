#!/bin/sh

#BSUB -oo log
#BSUB -eo log
#BSUB -q debug
#BSUB -J chgres_fv3
#BSUB -P FV3GFS-T2O
#BSUB -W 0:08
#BSUB -M 1000
#BSUB -extsched 'CRAYLINUX[]'

set -x

export NODES=1

WORK_DIR=/gpfs/hps3/stmp/George.Gayno/chgres_fv3
rm -fr $WORK_DIR
mkdir -p $WORK_DIR
cd $WORK_DIR

#cp /gpfs/hps3/emc/global/noscrub/George.Gayno/fv3gfs.git/fv3gfs/chgres_cube/run/config.C384.cray.nml ./fort.41
#cp /gpfs/hps3/emc/global/noscrub/George.Gayno/fv3gfs.git/fv3gfs/chgres_cube/run/config.C768.nest.cray.nml ./fort.41
cp /gpfs/hps3/emc/global/noscrub/George.Gayno/fv3gfs.git/fv3gfs/chgres_cube/run/config.C768.stretch.cray.nml ./fort.41
#cp /gpfs/hps3/emc/global/noscrub/George.Gayno/fv3gfs.git/fv3gfs/chgres_cube/run/config.C48.cray.nml ./fort.41

EXEC_DIR=/gpfs/hps3/emc/global/noscrub/George.Gayno/fv3gfs.git/fv3gfs/chgres_cube/exec

aprun -j 1 -n 6 -N 6  $EXEC_DIR/global_chgres.exe

exit
