help([[
Load environment for running BOKEH.
]])

local pkgName    = myModuleName()
local pkgVersion = myModuleVersion()
local pkgNameVer = myModuleFullName()

conflict(pkgName)

prepend_path("MODULEPATH", '/gpfs/f6/bil-fire10-oar/world-shared/gge/Miniforge3/modulefiles')

load("Miniforge3/24.11.3-2")
load("bokeh/3.7.0")

whatis("Name: ".. pkgName)
whatis("Version: ".. pkgVersion)
whatis("Category: BOKEH")
whatis("Description: Load all libraries needed for BOKEH")
