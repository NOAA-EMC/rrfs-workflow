help([[
This module loads python environement for running the RRFS workflow on
the NOAA RDHPC machine Ursa
]])

whatis([===[Loads libraries needed for running the RRFS workflow on Ursa ]===])

load("rocoto")

prepend_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")
load(pathJoin("stack-oneapi", os.getenv("stack_oneapi_ver") or "2024.2.1"))
load(pathJoin("stack-intel-oneapi-mpi", os.getenv("stack_impi_ver") or "2021.13"))
load(pathJoin("stack-python", os.getenv("stack_python_ver") or "3.11.7"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0.1"))

load("py-jinja2")
load("py-pyyaml")
load("py-f90nml")
load("py-numpy")
load("py-netcdf4")
