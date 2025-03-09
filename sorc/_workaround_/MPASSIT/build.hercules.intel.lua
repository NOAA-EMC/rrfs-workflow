help([[
This module loads libraries for MPASSIT
]])

whatis([===[Loads libraries for rrfs-workflow ]===])
prepend_path("MODULEPATH", "/work/noaa/epic/role-epic/spack-stack/hercules/spack-stack-1.6.0/envs/unified-env/install/modulefiles/Core")

load("stack-intel/2021.9.0")
load("stack-intel-oneapi-mpi/2021.9.0")
load("cmake/3.23.1")
load("parallel-netcdf/1.12.2")
load("libszip/2.1.1")
load("hdf5/1.14.0")
load("netcdf-c/4.9.2")
load("netcdf-cxx/4.2")
load("netcdf-fortran/4.6.1")
load("jasper/2.0.32")
load("libpng/1.6.37")
load("esmf/8.6.0")

setenv("PIO", os.getenv("parallelio_ROOT"))

setenv("CMAKE_C_COMPILER", "mpiicc")
setenv("CMAKE_CXX_COMPILER", "mpiicpc")
setenv("CMAKE_Fortran_COMPILER", "mpiifort")
