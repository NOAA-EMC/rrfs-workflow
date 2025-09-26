help([[
This module loads python environement for running the RRFS workflow on
the NOAA RDHPC machine Jet
]])

whatis([===[Loads libraries needed for running the RRFS workflow on Jet ]===])

load("rocoto")

prepend_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.6.0/envs/gsi-addon-intel/install/modulefiles/Core")
load(pathJoin("stack-intel", os.getenv("stack_intel_ver") or "2021.5.0"))
load(pathJoin("stack-intel-oneapi-mpi", os.getenv("stack_impi_ver") or "2021.5.1"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0"))

if mode() == "load" then
   LmodMsgRaw([===[Please do the following to activate conda:
       > source /mnt/lfs5/BMC/wrfruc/mhu/miniconda/bin/activate
]===])
end
