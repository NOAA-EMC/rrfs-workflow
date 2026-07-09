prepend_path("MODULEPATH", "/gpfs/f6/bil-fire8/world-shared/Benjamin.Koziol/mpas-aerosols/spack-stack/envs/mpas-aerosols/modules/Core")
prepend_path("MODULEPATH", "/gpfs/f6/bil-fire8/world-shared/Benjamin.Koziol/mpas-aerosols/spack-stack/envs/mpas-aerosols/modules/cray-mpich/8.1.32/intel-oneapi-compilers/2025.2.1")
prepend_path("MODULEPATH", "/gpfs/f6/bil-fire8/world-shared/Benjamin.Koziol/mpas-aerosols/spack-stack/envs/mpas-aerosols/modules/intel-oneapi-compilers/2025.2.1")

prepend_path("LD_LIBRARY_PATH", "/opt/intel/oneapi/mkl/2025.2/lib")

load("stack-intel-oneapi-compilers/2025.2.1")
load("stack-cray-mpich/8.1.32")

load("py-numpy/1.26.4")
load("esmf/8.9.1")
load("py-netcdf4/1.7.2")
load("py-pytest/8.2.1")
load("py-xarray/2024.7.0")
load("py-pydantic/2.10.1")
load("py-pydantic-settings/2.6.1")

load("Core/24.11")
load("nco/5.1.9")
