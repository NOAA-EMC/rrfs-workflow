help([[
This module loads libraries for building the RRFS workflow on
the NOAA RDHPC machine Ursa using Intel oneAPI 2024.2.1
]])

whatis([===[Loads libraries needed for building the RRFS workflow on Ursa ]===])

prepend_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")
load(pathJoin("stack-oneapi", os.getenv("stack_oneapi_ver") or "2024.2.1"))
load(pathJoin("stack-intel-oneapi-mpi", os.getenv("stack_impi_ver") or "2021.13"))
load(pathJoin("intel-oneapi-mkl", os.getenv("mkl_ver") or "2024.2.1"))
load(pathJoin("cmake", os.getenv("cmake_ver") or "3.27.9"))

-- Put Intel MPI's Fortran module dir on CPATH so plain ifort finds mpi.mod (e.g. GSI's mgbf).
-- Since Intel MPI 2021.11 mpi.mod lives in include/mpi, which the MPI module no longer adds.
prepend_path("CPATH", pathJoin(os.getenv("I_MPI_ROOT") or "", "include/mpi"))

-- scotch is only built under the gcc branch of this oneAPI stack; append so oneAPI builds of everything else win
append_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/intel-oneapi-mpi/2021.13-haww6b3/gcc/12.4.0")

load("rrfs_common")

-- Point CMake at a local bufr 11.7.0 (the WCOSS2 version) instead of the loaded bufr 12.1.0, which
-- no longer builds the bufr_d library GSI links. <pkg>_ROOT is searched before CMAKE_PREFIX_PATH.
setenv("bufr_ROOT","/scratch4/BMC/rtrr/rrfs_lib/bufr.11.7.0")
setenv("BUFR_ROOT","/scratch4/BMC/rtrr/rrfs_lib/bufr.11.7.0")

-- oneAPI 2024 dropped icc/icpc, so use the icx/icpx MPI wrappers (Fortran stays on ifort)
setenv("CMAKE_C_COMPILER","mpiicx")
setenv("CMAKE_CXX_COMPILER","mpiicpx")
setenv("CMAKE_Fortran_COMPILER","mpiifort")
setenv("CMAKE_Platform","ursa.intel")
