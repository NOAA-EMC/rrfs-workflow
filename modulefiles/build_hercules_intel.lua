help([[
This module loads libraries for building the RRFS workflow on
the MSU machine Hercules using Intel-2021.9.0
]])

whatis([===[Loads libraries needed for building the RRFS worfklow on Hercules ]===])

load("contrib")
load("noaatools")

prepend_path("MODULEPATH","/work/noaa/epic/role-epic/spack-stack/hercules/spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core")
load(pathJoin("stack-intel", os.getenv("stack_intel_ver") or "2021.9.0"))
load(pathJoin("stack-intel-oneapi-mpi", os.getenv("stack_impi_ver") or "2021.9.0"))
load("intel-oneapi-mkl/2022.2.1")
load(pathJoin("cmake", os.getenv("cmake_ver") or "3.23.1"))

load(pathJoin("jasper", os.getenv("jasper_ver") or "2.0.32"))
load(pathJoin("libpng", os.getenv("libpng_ver") or "1.6.37"))
load(pathJoin("parallelio", os.getenv("pio_ver") or "2.5.10"))
--loading parallelio will load netcdf_c, netcdf_fortran, hdf5, zlib, etc
load(pathJoin("esmf", os.getenv("esmf_ver") or "8.4.2"))
load(pathJoin("fms", os.getenv("fms_ver") or "2023.01"))

load(pathJoin("bacio", os.getenv("bacio_ver") or "2.4.1"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0"))
load(pathJoin("g2", os.getenv("g2_ver") or "3.4.5"))
load(pathJoin("g2tmpl", os.getenv("g2tmpl_ver") or "1.10.2"))
load(pathJoin("ip", os.getenv("ip_ver") or "4.3.0"))
load(pathJoin("sp", os.getenv("sp_ver") or "2.3.3"))

load(pathJoin("gftl-shared", os.getenv("gftl-shared_ver") or "1.5.0"))
--load(pathJoin("yafyaml", os.getenv("yafyaml_ver") or "0.5.1"))
load(pathJoin("mapl", os.getenv("mapl_ver") or "2.35.2-esmf-8.4.2"))
load(pathJoin("scotch", os.getenv("scotch_ver") or "7.0.4"))

--load(pathJoin("bufr", os.getenv("bufr_ver") or "12.0.0"))
load(pathJoin("gfsio", os.getenv("gfsio_ver") or "1.4.1"))
load(pathJoin("landsfcutil", os.getenv("landsfcutil_ver") or "2.4.1"))
load(pathJoin("nemsiogfs", os.getenv("nemsiogfs_ver") or "2.5.3"))
load(pathJoin("sigio", os.getenv("sigio_ver") or "2.3.2"))
load(pathJoin("sfcio", os.getenv("sfcio_ver") or "1.4.1"))
load(pathJoin("nemsio", os.getenv("nemsio_ver") or "2.5.4"))
--load(pathJoin("wrf_io", os.getenv("wrf_io_ver") or "1.2.0"))
load(pathJoin("ncio", os.getenv("ncio_ver") or "1.1.2"))
load(pathJoin("gsi-ncdiag", os.getenv("gsi-ncdiag_ver") or "1.1.1"))
load(pathJoin("w3emc", os.getenv("w3emc_ver") or "2.10.0"))
load(pathJoin("w3nco", os.getenv("w3nco_ver") or "2.4.1"))

load(pathJoin("nco", os.getenv("nco_ver") or "5.0.6"))
--load(pathJoin("prod_util", os.getenv("prod_util_ver") or "2.0.14"))
load(pathJoin("wgrib2", os.getenv("wgrib2_ver") or "3.1.1"))

prepend_path("MODULEPATH", "/work/noaa/rtrr/gge/hercules/lua")
load("prod_util/2.0.15")
load("wrf_io/1.2.0a")
load("bufr/11.7.0a")
load("gsi-ncdiag/1.1.2a")

unload("python/3.10.8")

setenv("CMAKE_C_COMPILER","mpiicc")
setenv("CMAKE_CXX_COMPILER","mpiicpc")
setenv("CMAKE_Fortran_COMPILER","mpiifort")
setenv("CMAKE_Platform","hercules.intel")
setenv("I_MPI_EXTRA_FILESYSTEM","ON")
