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


prepend_path("PATH", "/apps/ops/prod/nco/core/prod_util.v2.0.14/ush", ":")
prepend_path("CMAKE_PREFIX_PATH", "/apps/ops/prod/nco/core/prod_util.v2.0.14/.", ":")
setenv("prod_util_ROOT", "/apps/ops/prod/nco/core/prod_util.v2.0.14")
setenv("MDATE", "/apps/ops/prod/nco/core/prod_util.v2.0.14/exec/mdate")
setenv("NDATE", "/apps/ops/prod/nco/core/prod_util.v2.0.14/exec/ndate")
setenv("NHOUR", "/apps/ops/prod/nco/core/prod_util.v2.0.14/exec/nhour")
setenv("FSYNC", "/apps/ops/prod/nco/core/prod_util.v2.0.14/exec/fsync_file")
