load(pathJoin("cfp", os.getenv("cfp_ver")))

load(pathJoin("PrgEnv-intel", os.getenv("PrgEnv_intel_ver")))
load(pathJoin("intel", os.getenv("intel_ver")))
load(pathJoin("craype", os.getenv("craype_ver")))
load(pathJoin("python", os.getenv("python_ver")))
load(pathJoin("prod_util", os.getenv("prod_util_ver")))
load(pathJoin("cray-mpich", os.getenv("cray_mpich_ver")))
load(pathJoin("cray-pals", os.getenv("cray_pals_ver")))

prepend_path("MODULEPATH", os.getenv("modulepath_compiler"))
prepend_path("MODULEPATH", os.getenv("modulepath_mpi"))

load(pathJoin("hdf5", os.getenv("hdf5_ver")))
load(pathJoin("netcdf", os.getenv("netcdf_ver")))
load(pathJoin("wgrib2", os.getenv("wgrib2_ver")))

prepend_path("MODULEPATH","/lfs/h2/emc/eib/save/hang.lei/forgdit/nco_wcoss2/install2/modulefiles/compiler/intel/19.1.3.304")
load(pathJoin("grib_util", os.getenv("grib_util_ver")))

load(pathJoin("udunits", os.getenv("udunits_ver")))
load(pathJoin("gsl", os.getenv("gsl_ver")))
load(pathJoin("nco", os.getenv("nco_ver")))
