help([[
This module loads libraries for rrfs-workflow
]])

whatis([===[Loads libraries for rrfs-workflow ]===])
prepend_path("MODULEPATH", "/work/noaa/epic/role-epic/spack-stack/orion/spack-stack-1.6.0/envs/unified-env-rocky9/install/modulefiles/Core")

load("stack-intel/2021.9.0")
load("stack-intel-oneapi-mpi/2021.9.0")
load("intel-oneapi-compilers/2023.1.0")
load("intel-oneapi-mpi/2021.9.0")
load("cmake/3.23.1")
load("parallel-netcdf/1.12.2")
load("parallelio/2.5.10")
load("jasper/2.0.32")

setenv("PIO", os.getenv("parallelio_ROOT"))

setenv("CMAKE_C_COMPILER", "mpiicc")
setenv("CMAKE_CXX_COMPILER", "mpiicpc")
setenv("CMAKE_Fortran_COMPILER", "mpiifort")
