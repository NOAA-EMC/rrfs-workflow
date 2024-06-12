load("python_srw")

load(pathJoin("PrgEnv-intel", "8.1.0"))
load(pathJoin("intel", "19.1.3.304"))
load(pathJoin("craype", "2.7.13"))
load(pathJoin("cray-mpich", "8.1.7"))

setenv("HPC_OPT", "/apps/ops/para/libs")
prepend_path("MODULEPATH", "/apps/ops/para/libs/modulefiles/compiler/intel/19.1.3.304")
prepend_path("MODULEPATH", "/apps/ops/para/libs/modulefiles/mpi/intel/19.1.3.304/cray-mpich/8.1.7")

load(pathJoin("hdf5", "1.10.6"))
load(pathJoin("netcdf", "4.7.4"))
load(pathJoin("bacio", "2.4.1"))
load(pathJoin("g2", "3.4.5"))
load(pathJoin("ip", "3.3.3"))
load(pathJoin("sp", "2.3.3"))

load(pathJoin("libjpeg", "9c"))
load(pathJoin("cray-pals", "1.1.3"))
load(pathJoin("udunits", "2.2.28"))
load(pathJoin("gsl", "2.7"))
load(pathJoin("nco", "4.9.7"))
