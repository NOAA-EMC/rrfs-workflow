help([[
This module loads python environement for running the RRFS workflow on
the NOAA RDHPC machine Hera
]])

whatis([===[Loads libraries needed for running the RRFS workflow on Hera ]===])

load("rocoto")

prepend_path("MODULEPATH", "/scratch1/NCEPDEV/nems/role.epic/spack-stack/spack-stack-1.5.1/envs/gsi-addon-env-rocky8/install/modulefiles/Core")
load(pathJoin("stack-intel", os.getenv("stack_intel_ver") or "2021.5.0"))
load(pathJoin("stack-intel-oneapi-mpi", os.getenv("stack_impi_ver") or "2021.5.1"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0"))

prepend_path("MODULEPATH","/contrib/miniconda3/modulefiles")
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.12.0"))

if mode() == "load" then
   LmodMsgRaw([===[Please do the following to activate conda:
       > conda activate regional_workflow
]===])
end
