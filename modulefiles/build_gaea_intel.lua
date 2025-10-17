help([[
This module loads libraries for building the RRFS workflow on
the NOAA RDHPC machine Gaea C6 using Intel-2023.2.0
]])

whatis([===[Loads libraries needed for building the RRFS workflow on Gaea C6]===])

prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.2/envs/ue-intel-2023.2.0/install/modulefiles/Core")
prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/modulefiles")

stack_intel_ver=os.getenv("stack_intel_ver") or "2023.2.0"
load(pathJoin("stack-intel", stack_intel_ver))

stack_cray_mpich_ver=os.getenv("stack_cray_mpich_ver") or "8.1.30"
load(pathJoin("stack-cray-mpich", stack_cray_mpich_ver))

stack_python_ver=os.getenv("stack_python_ver") or "3.11.7"
load(pathJoin("stack-python", stack_python_ver))

cmake_ver=os.getenv("cmake_ver") or "3.27.9"
load(pathJoin("cmake", cmake_ver))

load("rrfs_common")

nccmp_ver=os.getenv("nccmp_ver") or "1.9.0.1"
load(pathJoin("nccmp", nccmp_ver))

unload("darshan-runtime")
unload("cray-libsci")

setenv("CC","cc")
setenv("CXX","CC")
setenv("FC","ftn")
setenv("CMAKE_Platform","gaeac6.intel")
