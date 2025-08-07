help([[
This module loads libraries for building the RRFS workflow on
the NOAA RDHPC machine Gaea C6 using Intel-2023.2.0
]])

whatis([===[Loads libraries needed for building the RRFS workflow on Gaea C6 ]===])

prepend_path("MODULEPATH","/ncrc/proj/epic/spack-stack/c6/spack-stack-1.6.0/envs/gsi-addon/install/modulefiles/Core")
load(pathJoin("stack-intel", os.getenv("stack_intel_ver") or "2023.2.0"))
load(pathJoin("stack-cray-mpich", os.getenv("stack_impi_ver") or "8.1.29"))
load(pathJoin("stack-python", os.getenv("stack_python_ver") or "3.11.6"))
--load("DefApps/default")
--load(pathJoin("cmake", os.getenv("cmake_ver") or "3.27.9"))

load("rrfs_common")
load("cray-libsci/23.12.5")

--load(pathJoin("wgrib2", os.getenv("wgrib2_ver") or "2.0.8"))
--prepend_path("MODULEPATH", "/scratch2/BMC/rtrr/gge/lua")
--load("prod_util/2.0.15")

unload("g2tmpl/1.10.2")
setenv("g2tmpl_ROOT","/gpfs/f6/bil-fire10-oar/world-shared/mhu/rrfs/lib/g2tmpl.v1.12.0")

unload("fms/2023.04")
setenv("FMS_ROOT","/gpfs/f6/bil-fire10-oar/world-shared/mhu/rrfs/lib/fms.2024.01")

setenv("CC","cc")
setenv("FC","ftn")
setenv("CXX","CC")
setenv("CMAKE_C_COMPILER","cc")
setenv("CMAKE_Fortran_COMPILER","ftn")
setenv("CMAKE_CXX_COMPILER","CC")
setenv("CMAKE_Platform","gaea-c6.intel")
setenv("CRAY_CPU_TARGET","x86-64")
