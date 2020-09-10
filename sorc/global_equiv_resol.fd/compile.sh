#!/bin/bash

module purge
module load intel/18.1.163
module load netcdf/4.6.1
module load hdf5/1.10.4
module list

make
