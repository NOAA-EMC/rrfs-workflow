help([[
This module loads libraries for rrfs-workflow
]])

whatis([===[Loads libraries for rrfs-workflow ]===])
prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

load("stack-oneapi/2024.2.1")
load("stack-cray-mpich/8.1.32")
load("cmake/3.27.9")
load("parallel-netcdf/1.12.3")
load("parallelio/2.6.2")
load("libpng/1.6.37")

if mode() == "load" then
  setenv("PIO", os.getenv("parallelio_ROOT"))
end
if mode() == "unload" then
  unsetenv("PIO")
end

setenv("CMAKE_C_COMPILER", "mpicc")
setenv("CMAKE_CXX_COMPILER", "mpic++")
setenv("CMAKE_Fortran_COMPILER", "mpifort")
