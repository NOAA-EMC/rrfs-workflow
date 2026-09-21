help([[
This module loads the run-time environment for RRFS ecflow jobs on
the NOAA RDHPC machine Ursa using Intel oneAPI 2024.2.1
]])

whatis([===[Loads the run-time environment for RRFS ecflow jobs on Ursa ]===])

-- Versions are pinned here on purpose: the ecf job cards export the WCOSS2 versions from
-- versions/run.ver, and picking those up through os.getenv() made Lmod fail on Ursa.
prepend_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")
load(pathJoin("stack-oneapi", "2024.2.1"))
load(pathJoin("stack-intel-oneapi-mpi", "2021.13"))
load(pathJoin("intel-oneapi-mkl", "2024.2.1"))

-- Shared libraries the RRFS executables link, at the versions build_ursa_intel.lua builds against
load(pathJoin("zlib", "1.2.13"))
load(pathJoin("libpng", "1.6.37"))
load(pathJoin("libjpeg", "2.1.0"))
load(pathJoin("jasper", "2.0.32"))
load(pathJoin("hdf5", "1.14.3"))
load(pathJoin("netcdf-c", "4.9.2"))
load(pathJoin("netcdf-fortran", "4.6.1"))
load(pathJoin("parallel-netcdf", "1.12.3"))
load(pathJoin("parallelio", "2.6.2"))
load(pathJoin("esmf", "8.8.0"))
load(pathJoin("g2c", "2.1.0"))
load(pathJoin("crtm", "2.4.0.1"))
load(pathJoin("udunits", "2.2.28"))
load(pathJoin("gsl", "2.8"))

-- NCEPLIBS the executables link at run time (bufr provides libbufr_4.so)
load(pathJoin("bufr", "12.1.0"))

-- nc_diag_cat.x for the analysis diagnostics job; the ecf cards load this as ncdiag-A on WCOSS2
load(pathJoin("gsi-ncdiag", "1.1.2"))

-- Utilities the job scripts call (prod_util provides compath.py, ndate, cpreq, err_chk, ...)
load(pathJoin("prod_util", "2.1.1"))
load(pathJoin("nco", "5.2.4"))
load(pathJoin("wgrib2", "3.6.0"))
load(pathJoin("grib-util", "1.4.0"))

-- Python for the ush/ helpers. lib/raymond.so (blending) is built with this python and numpy,
-- so it must be imported with them too.
load(pathJoin("stack-python", "3.11.7"))
load("py-numpy")
load("py-netcdf4")
load("py-pyyaml")
load("py-jinja2")
load("py-f90nml")
load("py-xarray")
load("py-scipy")
load("py-pandas")
load("py-matplotlib")
