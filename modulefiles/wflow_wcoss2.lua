help([[
This module loads python environement for running the RRFS workflow on
the NOAA operational machine WCOSS2 (Cactus/Dogwood)"
]])

whatis([===[Loads libraries needed for running the RRFS workflow on WCOSS2 ]===])

load(pathJoin("intel", os.getenv("intel_ver")))
load(pathJoin("python", os.getenv("python_ver")))

prepend_path("MODULEPATH", os.getenv("modulepath_mpi"))
load(pathJoin("crtm", os.getenv("crtm_ver")))

prepend_path("MODULEPATH","/apps/ops/test/nco/modulefiles")
load(pathJoin("core/rocoto", os.getenv("rocoto_ver")))

