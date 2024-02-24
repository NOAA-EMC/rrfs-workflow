help([[
This module loads libraries for building the RRFS workflow on
the MSU machine Orion using Intel-2022.1.2
]])

whatis([===[Loads libraries needed for building the RRFS worfklow on Orion ]===])

load("contrib")
load("noaatools")

prepend_path("MODULEPATH", "/work/noaa/epic/role-epic/spack-stack/orion/spack-stack-1.5.1/envs/gsi-addon/install/modulefiles/Core")
load(pathJoin("stack-intel", os.getenv("stack_intel_ver") or "2022.0.2"))
load(pathJoin("stack-intel-oneapi-mpi", os.getenv("stack_impi_ver") or "2021.5.1"))
load(pathJoin("cmake", os.getenv("cmake_ver") or "3.23.1"))

load("rrfs_common")
load(pathJoin("wgrib2", os.getenv("wgrib2_ver") or "2.0.8"))

prepend_path("MODULEPATH", "/work/noaa/rtrr/gge/lua")
load("prod_util/2.0.15")

unload("python/3.10.8")

setenv("CMAKE_C_COMPILER","mpiicc")
setenv("CMAKE_CXX_COMPILER","mpiicpc")
setenv("CMAKE_Fortran_COMPILER","mpiifort")
setenv("CMAKE_Platform","orion.intel")
