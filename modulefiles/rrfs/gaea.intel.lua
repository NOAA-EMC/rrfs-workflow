help([[
This module loads libraries for rrfs-workflow
]])

whatis([===[Loads libraries for rrfs-workflow ]===])
prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.6.0/envs/unified-env/install/modulefiles/Core")

load("stack-intel/2023.2.0")
load("stack-cray-mpich/8.1.29")
load("cmake/3.23.1")
load("parallel-netcdf/1.12.2")
load("parallelio/2.5.10")

setenv("PIO", os.getenv("parallelio_ROOT"))

setenv("CMAKE_C_COMPILER", "cc")
setenv("CMAKE_CXX_COMPILER", "CC")
setenv("CMAKE_Fortran_COMPILER", "fn")
