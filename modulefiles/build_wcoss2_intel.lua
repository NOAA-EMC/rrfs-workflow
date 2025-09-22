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
load(pathJoin("hdf5", os.getenv("hdf5_ver")))
load(pathJoin("netcdf", os.getenv("netcdf_ver")))
load(pathJoin("pio", os.getenv("pio_ver")))
load(pathJoin("esmf", os.getenv("esmf_ver")))
--load(pathJoin("fms", os.getenv("fms_ver")))
load(pathJoin("gftl-shared", os.getenv("gftl_shared_ver")))
load(pathJoin("mapl", os.getenv("mapl_ver")))

load(pathJoin("bacio", os.getenv("bacio_ver")))
load(pathJoin("crtm", os.getenv("crtm_ver")))
load(pathJoin("g2", os.getenv("g2_ver")))
--load(pathJoin("g2tmpl", os.getenv("g2tmpl_ver")))
load(pathJoin("ip", os.getenv("ip_ver")))
load(pathJoin("sp", os.getenv("sp_ver")))

load(pathJoin("bufr", os.getenv("bufr_ver")))
load(pathJoin("gfsio", os.getenv("gfsio_ver")))
load(pathJoin("landsfcutil", os.getenv("landsfcutil_ver")))
load(pathJoin("sigio", os.getenv("sigio_ver")))
load(pathJoin("sfcio", os.getenv("sfcio_ver")))
load(pathJoin("wrf_io", os.getenv("wrf_io_ver")))
load(pathJoin("ncdiag", os.getenv("ncdiag_ver")))
load(pathJoin("ncio", os.getenv("ncio_ver")))
load(pathJoin("wgrib2", os.getenv("wgrib2_ver")))
load(pathJoin("w3emc", os.getenv("w3emc_ver")))
load(pathJoin("w3nco", os.getenv("w3nco_ver")))
load(pathJoin("nemsio", os.getenv("nemsio_ver")))

prepend_path("MODULEPATH", os.getenv("modulepath_scotch"))
load(pathJoin("scotch", os.getenv("scotch_ver")))

prepend_path("MODULEPATH","/u/wen.meng/noscrub/ncep_post/g2tmpl/libs/modulefiles/compiler/intel/19.1.3.304")
load(pathJoin("g2tmpl", os.getenv("g2tmpl_ver")))

setenv("FMS_ROOT","/lfs/h2/emc/lam/noscrub/emc.lam/rrfs/lib/fms.2024.01/build")
setenv("FMS_VERSION","2024.01")

--setenv("FMS_ROOT","/lfs/h2/emc/lam/noscrub/emc.lam/rrfs/lib/fms.ParallelStartup")
--setenv("FMS_VERSION","2023.02")

setenv("CMAKE_C_COMPILER","cc")
setenv("CMAKE_CXX_COMPILER","CC")
setenv("CMAKE_Fortran_COMPILER","ftn")
setenv("CMAKE_Platform","wcoss2")
setenv("BLENDINGPYTHON","/apps/spack/python/3.8.6/intel/19.1.3.304/pjn2nzkjvqgmjw4hmyz43v5x4jbxjzpk/bin/python")
setenv("PYTHONPATH", "/apps/prod/python-modules/3.8.6/intel/19.1.3.304/lib/python3.8/site-packages:$PYTHONPATH")
