#!/bin/bash
set -x

machine=${1:-"odin"}

if [ $machine = "cray" ]; then
:
elif [ $machine = "theia" ]; then
:
elif  [ $machine = "odin" ]; then
:
else

    echo "machine $machine is unsupported, ABORT!"
    exit 1

fi

#source ../../modulefiles/module-setup.sh.inc
export MOD_PATH="/home/larissa.reames/modulefiles"
module use /home/larissa.reames/modulefiles
module load modulefile.gfsnc2nemsio.$machine

#LIBnetcdf="$NETCDF_DIR/lib -lnetcdff -lnetcdf" # --flibs"
#INCnetcdf="$NETCDF_DIR/include" # --flags"
#export NETCDF_LDFLAGS=$LIBnetcdf
#export NETCDF_INCLUDE=$INCnetcdf
export FCMP="ifort"
export FFLAGS="-g -O2 -traceback -qopenmp"
export NEMSIO_LIB="/home/larissa.reames/external/nemsio/libs -lnemsio_4"
export BACIO_LIB4="/home/larissa.reames/external/bacio/libs -lbacio_4"
export W3NCO_LIBd="/home/larissa.reames/external/w3nco/libs -lw3nco"
export NEMSIO_INC="/home/larissa.reames/external/nemsio/incmod_4/nemsio"
export HDF5_LIB="/opt/cray/pe/hdf5-parallel/1.10.0.3/INTEL/16.0/lib -lhdf5 -lhdf5_hl"
export MPI_LIB="/opt/cray/pe/mpt/7.6.2/gni/mpich-intel/16.0/lib -lmpich -lmpichf90 -lmpichf90_intel"
export MPI_INC="/opt/cray/pe/mpt/7.6.2/gni/mpich-intel/16.0/include"
export PMI_LIB="/opt/cray/pe/pmi/5.0.12/lib64 -lpmi"
export NETCDF_LDFLAGS="/opt/cray/pe/netcdf-hdf5parallel/4.4.1.1.3/INTEL/16.0/lib/ -lnetcdff -lnetcdf"
export NETCDF_INCLUDE="/opt/cray/pe/netcdf-hdf5parallel/4.4.1.1.3/INTEL/16.0/include"
echo $NETCDF_LDFLAGS
echo $FCMP
echo $FFLAGS
$FCMP $FFLAGS -c kinds.f90
$FCMP $FFLAGS -c constants.f90
$FCMP $FFLAGS -I $NETCDF_INCLUDE -I $NEMSIO_INC  -c grb2nemsio_module.f90
$FCMP $FFLAGS -I $NETCDF_INCLUDE -I $NEMSIO_INC  -I $MPI_INC-I. -o grb2nemsio.x grb2nemsio_main.f90 grb2nemsio_module.o -L $NETCDF_LDFLAGS -L $NEMSIO_LIB -L $BACIO_LIB4 -L $W3NCO_LIBd -L $HDF5_LIB -L $MPI_LIB -L $PMI_LIB
#mv fv3nc2nemsio.x ../../exec/.
rm -f *.o *.mod

exit 0
