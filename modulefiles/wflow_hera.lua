help([[
This module loads python environement for running the RRFS workflow on
the NOAA RDHPC machine Hera
]])

whatis([===[Loads libraries needed for running the RRFS workflow on Hera ]===])

load("rocoto")
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0"))

prepend_path("MODULEPATH","/scratch1/NCEPDEV/nems/role.epic/miniconda3/modulefiles")
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.12.0"))

if mode() == "load" then
   LmodMsgRaw([===[Please do the following to activate conda:
       > conda activate workflow_tools
]===])
end
