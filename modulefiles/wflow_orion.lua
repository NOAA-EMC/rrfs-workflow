help([[
This module loads python environement for running RRFS workflow on
the MSU machine Orion
]])

whatis([===[Loads libraries needed for running RRFS workflow on Orion ]===])

load("contrib")
load("rocoto")
load("wget")

prepend_path("MODULEPATH","/work/noaa/epic/role-epic/spack-stack/orion/spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core")
load(pathJoin("stack-intel", os.getenv("stack_intel_ver") or "2022.0.2"))
load(pathJoin("stack-intel-oneapi-mpi", os.getenv("stack_impi_ver") or "2021.5.1"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0"))

unload("python")
append_path("MODULEPATH","/work/noaa/epic/role-epic/contrib/orion/miniconda3/modulefiles")
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.12.0"))

if mode() == "load" then
   LmodMsgRaw([===[Please do the following to activate conda:
       > conda activate workflow_tools
]===])
end

