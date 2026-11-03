help([[
Load the RDASApp WCOSS2 environment for JEDI analysis tasks.
]])

local rrfs_home = os.getenv("HOMErrfs")
if not rrfs_home then
  LmodError("HOMErrfs must be set before loading analysis_jedi.local")
end

-- Remove the workflow virtual environment so RDASApp's Python packages stay active.
local rrfs_pythonve_ver = os.getenv("rrfs_pythonve_ver")
if rrfs_pythonve_ver then
  local rrfs_ve_module = pathJoin("ve/rrfs", rrfs_pythonve_ver)
  if isloaded(rrfs_ve_module) then
    unload(rrfs_ve_module)
  end
end

-- Use the same RDASApp stack Python and libraries used by the application build.
prepend_path("MODULEPATH", pathJoin(rrfs_home, "sorc/RDASApp/modulefiles"))
load("RDAS/wcoss2.intel")
