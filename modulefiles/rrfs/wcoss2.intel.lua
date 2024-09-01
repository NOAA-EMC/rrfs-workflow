help([[
This loads libraries for building the RRFS workflow on the 
NOAA operational machine WCOSS2 (Catcus/Dogwood)
]])

whatis([===[Loads libraries needed for building the RRFS workflow on WCOSS2 ]===])

load(pathJoin("envvar", os.getenv("envvar_ver")))

load(pathJoin("PrgEnv-intel", os.getenv("PrgEnv_intel_ver")))
load(pathJoin("intel", os.getenv("intel_ver")))
load(pathJoin("craype", os.getenv("craype_ver")))
load(pathJoin("cray-mpich", os.getenv("cray_mpich_ver")))
load(pathJoin("cmake", os.getenv("cmake_ver")))

prepend_path("MODULEPATH", os.getenv("modulepath_compiler"))
prepend_path("MODULEPATH", os.getenv("modulepath_mpi"))

load(pathJoin("jasper", os.getenv("jasper_ver")))
load(pathJoin("zlib", os.getenv("zlib_ver")))
load(pathJoin("libpng", os.getenv("libpng_ver")))
load(pathJoin("pnetcdf", os.getenv("pnetcdf_ver")))
load(pathJoin("pio", os.getenv("pio_ver")))

load(pathJoin("wgrib2", os.getenv("wgrib2_ver")))

setenv("PNETCDF",os.getenv("modulepath_pnetcdf"))

setenv("CMAKE_C_COMPILER","mpiicc")
setenv("CMAKE_CXX_COMPILER", "mpiicpc")
setenv("CMAKE_Fortran_COMPILER", "mpiifort")
