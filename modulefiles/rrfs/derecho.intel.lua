help([[
This module loads libraries for rrfs-workflow
]])

--whatis([===[Loads libraries for rrfs-workflow ]===])
prepend_path("MODULEPATH", "/glade/work/epicufsrt/contrib/spack-stack/derecho/modulefiles")
prepend_path("MODULEPATH", "/glade/work/epicufsrt/contrib/spack-stack/derecho/spack-stack-1.8.0/envs/ue-intel-2021.10.0/install/modulefiles/Core")

load("stack-intel/2021.10.0")
load("stack-cray-mpich/8.1.25")

load("cmake/3.27.9")
load("parallel-netcdf/1.12.3")
load("parallelio/2.6.2")
load("jasper/2.0.32")
load("libpng/1.6.37")

setenv("CMAKE_C_COMPILER", "mpicc")
setenv("CMAKE_CXX_COMPILER", "mpic++")
setenv("CMAKE_Fortran_COMPILER", "mpifort")

if mode() == "load" then
  --setenv("PNETCDF", os.getenv("PARALLEL_NETCDF_ROOT"))
  setenv("PNETCDF", os.getenv("parallel_netcdf_ROOT"))
end
if mode() == "unload" then
  unsetenv("PNETCDF")
end
