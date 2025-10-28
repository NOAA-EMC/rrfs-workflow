help([[
This module loads libraries for rrfs-workflow
]])

--whatis([===[Loads libraries for rrfs-workflow ]===])
prepend_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.9.1/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

load("stack-oneapi/2024.2.1")
load("stack-intel-oneapi-mpi/2021.13")

load("cmake/3.27.9")
load("parallel-netcdf/1.12.3")
load("parallelio/2.6.2")
load("jasper/2.0.32")
load("libpng/1.6.37")

setenv("CMAKE_C_COMPILER", "mpiicc")
setenv("CMAKE_CXX_COMPILER", "mpiicpc")
setenv("CMAKE_Fortran_COMPILER", "mpiifort")
--setenv("SERIAL_CC", "icx")
-- note for future upgrade
--setenv("CMAKE_C_COMPILER", "mpiicx")
--setenv("CMAKE_CXX_COMPILER", "mpiicpx")
--setenv("CMAKE_Fortran_COMPILER", "mpiifx")

if mode() == "load" then
  --setenv("PNETCDF", os.getenv("PARALLEL_NETCDF_ROOT"))
  setenv("PNETCDF", os.getenv("parallel_netcdf_ROOT"))
end
if mode() == "unload" then
  unsetenv("PNETCDF")
end
