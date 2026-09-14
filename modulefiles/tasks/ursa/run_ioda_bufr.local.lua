-- Run the python bufr2ioda converters in the environment RDASApp was built with (python 3.11),
-- not the python_srw conda env (python 3.8), which can't load RDASApp's pyioda/bufr bindings.
local rrfs_home = myFileName():match("(.*)/modulefiles/tasks/")
prepend_path("MODULEPATH", pathJoin(rrfs_home, "sorc/RDASApp/modulefiles"))
load("RDAS/ursa.intel")

-- The offline_domain_check*/offline_vad_thinning scripts also need matplotlib, shapely and cartopy,
-- which the RDASApp environment doesn't provide
load("py-matplotlib/3.7.4")
load("py-shapely/2.0.6")
load("py-cartopy/0.24.1")

-- Point cartopy at local Natural Earth shapefiles for the domain-check plots; compute nodes can't download them
setenv("CARTOPY_DATA_DIR", "/scratch3/NCEPDEV/nems/role.epic/ursa/UFS_SRW_data/develop/NaturalEarth")
