help([[
Load environment for running the RDAS application with Intel compilers and MPI.
]])

local pkgName    = myModuleName()
local pkgVersion = myModuleVersion()
local pkgNameVer = myModuleFullName()

prepend_path("MODULEPATH", '/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core')

load("stack-oneapi/2024.2.1")
load("stack-cray-mpich/8.1.32")
load("stack-python/3.11.7")
load("jedi-mpas-env/1.0.0")
load("jedi-fv3-env/1.0.0")
load("py-jinja2/3.1.4")

unload("cray-libsci/24.11.0")
setenv("CC","cc")
setenv("FC","ftn")
setenv("CXX","CC")

local mpiexec = '/usr/bin/srun'
local mpinproc = '-n'
setenv('MPIEXEC_EXEC', mpiexec)
setenv('MPIEXEC_NPROC', mpinproc)

whatis("Name: ".. pkgName)
whatis("Version: ".. pkgVersion)
whatis("Category: RDASApp")
whatis("Description: Load all libraries needed for RDASApp")
