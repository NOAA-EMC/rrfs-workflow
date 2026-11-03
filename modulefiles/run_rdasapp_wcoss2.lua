help([[
Load the oneAPI runtime libraries required by RDASApp executables on WCOSS2.
Load this module after the operational RRFS modules so the matching Fortran
runtime takes precedence over the Intel 19 runtime.
]])

whatis("Loads the WCOSS2 RDASApp oneAPI runtime libraries")

-- Match the runtime selected by RDASApp/modulefiles/RDAS/wcoss2.intel.lua.
prepend_path("MODULEPATH", "/apps/ops/test/spack-stack-nco-1.9/modulefiles/Core")
load("stack-oneapi/2024.2.1")
load("intel-oneapi-runtime/2024.2.1")

-- RDASApp links MKL from this oneAPI installation, rather than Intel 19's MKL.
prepend_path("LD_LIBRARY_PATH", "/pe/oneapi/mkl/2024.2/lib")
