help([[
This module loads libraries for MPASSIT
]])

whatis([===[Loads libraries for MPASSIT ]===])
prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

load("stack-oneapi/2024.2.1")
load("stack-cray-mpich/8.1.32")

load("cmake/3.27.9")
load("esmf/8.8.0")

setenv("CMAKE_C_COMPILER", "mpicc")
setenv("CMAKE_CXX_COMPILER", "mpic++")
setenv("CMAKE_Fortran_COMPILER", "mpifort")
