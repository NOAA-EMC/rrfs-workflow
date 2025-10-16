help([[
This module loads python environement for running the UFS SRW App on
the NOAA RDHPC machine Gaea C6
]])

whatis([===[Loads libraries needed for running the UFS SRW App on gaea c6 ]===])

prepend_path("MODULEPATH","/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.2/envs/ue-intel-2023.2.0/install/modulefiles/Core")
load(pathJoin("stack-intel", os.getenv("stack_intel_ver") or "2023.2.0"))
load(pathJoin("stack-cray-mpich", os.getenv("stack_impi_ver") or "8.1.30"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0.1"))

if mode() == "load" then
   LmodMsgRaw([===[Please do the following to activate conda:
       > source /gpfs/f6/bil-fire10-oar/world-shared/mhu/miniconda/bin/activate
]===])
end
