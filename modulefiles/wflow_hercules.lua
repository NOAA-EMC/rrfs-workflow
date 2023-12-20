help([[
This module loads python environement for running RRFS workflow on
the MSU machine Hercules
]])

whatis([===[Loads libraries needed for running RRFS workflow on Hercules ]===])

load("contrib")
load("rocoto")

prepend_path("MODULEPATH","/work/noaa/epic/role-epic/spack-stack/hercules/spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core")
load(pathJoin("stack-intel", os.getenv("stack_intel_ver") or "2021.9.0"))
load(pathJoin("stack-intel-oneapi-mpi", os.getenv("stack_impi_ver") or "2021.9.0"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0"))

load("wget")

unload("python")
append_path("MODULEPATH","/work/noaa/epic/role-epic/contrib/hercules/miniconda3/modulefiles")
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.12.0"))

if mode() == "load" then
   LmodMsgRaw([===[Please do the following to activate conda:
       > conda activate workflow_tools
]===])
end

