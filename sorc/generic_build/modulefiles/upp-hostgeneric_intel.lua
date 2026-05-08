help([[
  This module loads libraries required for building and running UPP
  on the NOAA RDHPC machine Gaea using Intel-2023.2.0.
]])

whatis([===[Loads libraries needed for building the UPP on Gaea ]===])

prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.2/envs/ue-intel-2023.2.0/install/modulefiles/Core")
prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/modulefiles")

load("stack-intel/2023.2.0")
load("stack-cray-mpich/8.1.30")
load("cmake/3.27.9")
load("upp_common")
load("zlib/1.2.13")

unload("darshan-runtime")
unload("cray-libsci")

setenv("CC","cc")
setenv("CXX","CC")
setenv("FC","ftn")

setenv("CMAKE_Platform","gaea.intel")
