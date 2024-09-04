-- -*- lua -*-
-- Module file created by spack (https://github.com/spack/spack) on 2024-08-17 07:31:01.579527
--
-- prod-util@2.1.1%intel@2021.5.0~ipo build_system=cmake build_type=Release generator=make arch=linux-rocky8-core2/s72wb5t
--

whatis([[Name : prod-util]])
whatis([[Version : 2.1.1]])
whatis([[Target : core2]])
whatis([[Short description :  Product utilities for the NCEP models.]])

help([[Name   : prod-util]])
help([[Version: 2.1.1]])
help([[Target : core2]])
help()
help([[ Product utilities for the NCEP models. This is part of NOAA's NCEPLIBS
project.]])

prepend_path("PATH", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t/bin", ":")
prepend_path("CMAKE_PREFIX_PATH", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t/.", ":")
prepend_path("PATH", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t/bin", ":")
prepend_path("CMAKE_PREFIX_PATH", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t/.", ":")
setenv("prod_util_ROOT", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t")
setenv("MDATE", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t/bin/mdate")
setenv("NDATE", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t/bin/ndate")
setenv("NHOUR", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t/bin/nhour")
setenv("FSYNC", "/misc/contrib/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/prod-util-2.1.1-s72wb5t/bin/fsync_file")

