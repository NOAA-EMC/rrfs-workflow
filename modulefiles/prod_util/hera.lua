-- -*- lua -*-
-- Module file created by spack (https://github.com/spack/spack) on 2025-01-27 23:01:25.166951
--
-- prod-util@2.1.1%intel@2021.5.0~ipo build_system=cmake build_type=Release generator=make arch=linux-rocky8-haswell/4vpcrpl
--

whatis([[Name : prod-util]])
whatis([[Version : 2.1.1]])
whatis([[Target : haswell]])
whatis([[Short description :  Product utilities for the NCEP models.]])

help([[Name   : prod-util]])
help([[Version: 2.1.1]])
help([[Target : haswell]])
help()
help([[ Product utilities for the NCEP models. This is part of NOAA's NCEPLIBS
project.]])

prepend_path("PATH", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl/bin", ":")
prepend_path("CMAKE_PREFIX_PATH", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl/.", ":")
prepend_path("PATH", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl/bin", ":")
prepend_path("CMAKE_PREFIX_PATH", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl/.", ":")
setenv("prod_util_ROOT", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl")
setenv("MDATE", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl/bin/mdate")
setenv("NDATE", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl/bin/ndate")
setenv("NHOUR", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl/bin/nhour")
setenv("FSYNC", "/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-4vpcrpl/bin/fsync_file")

