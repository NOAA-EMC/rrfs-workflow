load("python_srw")

prepend_path("MODULEPATH", os.getenv("modulepath_compiler"))
prepend_path("MODULEPATH", os.getenv("modulepath_mpi"))

load(pathJoin("netcdf", os.getenv("netcdf_ver")))
