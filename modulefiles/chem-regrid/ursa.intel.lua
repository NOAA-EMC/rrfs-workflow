prepend_path("MODULEPATH", "/scratch3/NCEPDEV/stmp/Benjamin.Koziol/sandbox/spack-stack/envs/mpas-aerosols/modules/Core")
prepend_path("MODULEPATH", "/scratch3/NCEPDEV/stmp/Benjamin.Koziol/sandbox/spack-stack/envs/mpas-aerosols/modules/intel-oneapi-mpi/2021.17/intel-oneapi-compilers/2025.3.1")
prepend_path("MODULEPATH", "/scratch3/NCEPDEV/stmp/Benjamin.Koziol/sandbox/spack-stack/envs/mpas-aerosols/modules/intel-oneapi-compilers/2025.3.1")

load("stack-intel-oneapi-compilers/2025.3.1")
load("stack-intel-oneapi-mpi/2021.17")

load("hdf5/1.14.3")
load("esmf/8.9.1")
load("py-netcdf4/1.7.2")
load("py-pytest/8.2.1")
load("py-xarray/2024.7.0")
load("py-pydantic/2.10.1")
load("py-pydantic-settings/2.6.1")

load("nco")
