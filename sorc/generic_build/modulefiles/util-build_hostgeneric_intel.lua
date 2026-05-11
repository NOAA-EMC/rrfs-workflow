help([[
This module loads libraries for rrfs-workflow
]])

whatis([===[Loads libraries for rrfs-workflow ]===])
prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

load("stack-oneapi/2024.2.1")
load("stack-cray-mpich/8.1.32")
load("cmake/3.27.9")

load("parallelio/2.6.2")
load("jasper/2.0.32")
load("libpng/1.6.37")
load("g2/3.5.1")
load("g2tmpl/1.13.0")
load("w3emc/2.10.0")
load("w3nco/2.4.1")
load("wgrib2/3.6.0")
load("ncio/1.1.2")
load("nco/5.2.4")
load("bufr/12.1.0")

setenv("CMAKE_C_COMPILER", "mpicc")
setenv("CMAKE_CXX_COMPILER", "mpic++")
setenv("CMAKE_Fortran_COMPILER", "mpifort")
