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

-- Same libraries as versions/build.ver for WCOSS2, at the closest versions spack-stack 1.9.3 provides
load(pathJoin("jasper", os.getenv("jasper_ver") or "2.0.32"))
load(pathJoin("zlib", os.getenv("zlib_ver") or "1.2.13"))
load(pathJoin("libpng", os.getenv("libpng_ver") or "1.6.37"))
load(pathJoin("libjpeg", os.getenv("libjpeg_ver") or "2.1.0"))
load(pathJoin("hdf5", os.getenv("hdf5_ver") or "1.14.3"))
load(pathJoin("netcdf-c", os.getenv("netcdf_c_ver") or "4.9.2"))
load(pathJoin("netcdf-fortran", os.getenv("netcdf_fortran_ver") or "4.6.1"))
load(pathJoin("parallel-netcdf", os.getenv("pnetcdf_ver") or "1.12.3"))
load(pathJoin("parallelio", os.getenv("pio_ver") or "2.6.2"))
load(pathJoin("esmf", os.getenv("esmf_ver") or "8.8.0"))
load(pathJoin("fms", os.getenv("fms_ver") or "2024.02"))
load(pathJoin("gftl-shared", os.getenv("gftl_shared_ver") or "1.9.0"))

load(pathJoin("bacio", os.getenv("bacio_ver") or "2.4.1"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0.1"))
load(pathJoin("g2", os.getenv("g2_ver") or "3.5.1"))
load(pathJoin("g2c", os.getenv("g2c_ver") or "2.1.0"))
load(pathJoin("g2tmpl", os.getenv("g2tmpl_ver") or "1.13.0"))
load(pathJoin("ip", os.getenv("ip_ver") or "5.1.0"))
load(pathJoin("sp", os.getenv("sp_ver") or "2.5.0"))

load(pathJoin("bufr", os.getenv("bufr_ver") or "12.1.0"))
load(pathJoin("gfsio", os.getenv("gfsio_ver") or "1.4.2"))
load(pathJoin("sigio", os.getenv("sigio_ver") or "2.3.3"))
load(pathJoin("sfcio", os.getenv("sfcio_ver") or "1.4.2"))
load(pathJoin("wrf-io", os.getenv("wrf_io_ver") or "1.2.0"))
load(pathJoin("gsi-ncdiag", os.getenv("ncdiag_ver") or "1.1.2"))
load(pathJoin("ncio", os.getenv("ncio_ver") or "1.1.2"))
load(pathJoin("wgrib2", os.getenv("wgrib2_ver") or "3.6.0"))
load(pathJoin("w3emc", os.getenv("w3emc_ver") or "2.10.0"))
load(pathJoin("w3nco", os.getenv("w3nco_ver") or "2.4.1"))
load(pathJoin("nemsio", os.getenv("nemsio_ver") or "2.5.4"))

-- oneAPI 2024 dropped icc/icpc, so use the icx/icpx MPI wrappers (Fortran stays on ifort)
setenv("CMAKE_C_COMPILER","mpiicx")
setenv("CMAKE_CXX_COMPILER","mpiicpx")
setenv("CMAKE_Fortran_COMPILER","mpiifort")
setenv("CMAKE_Platform","ursa.intel")
