help([[
  This module loads libraries required for building and running UPP
  on the NOAA RDHPC machine Gaea using Intel-2023.2.0.
]])

whatis([===[Loads libraries needed for building the UPP on Gaea ]===])

prepend_path("MODULEPATH", "/gpfs/f7/arfs-gsl/world-shared/spack-stack/1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

stack_intel_ver=os.getenv("stack_intel_ver") or "2024.2.1"
load(pathJoin("stack-oneapi", stack_intel_ver))

stack_cray_mpich_ver=os.getenv("stack_cray_mpich_ver") or "8.1.32"
load(pathJoin("stack-cray-mpich", stack_cray_mpich_ver))

cmake_ver=os.getenv("cmake_ver") or "3.27.9"
load(pathJoin("cmake", cmake_ver))

load("upp_common")

unload("darshan-runtime")
unload("cray-libsci/24.11.0")

setenv("CC","cc")
setenv("CXX","CC")
setenv("FC","ftn")

setenv("CMAKE_Platform","gaea.intel")
