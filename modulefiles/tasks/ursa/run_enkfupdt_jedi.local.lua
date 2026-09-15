-- Run JEDI (and run_jcb.py) in the environment RDASApp was built with (python 3.11), as WCOSS2 does,
-- not the python_srw conda env (python 3.8).
local rrfs_home = myFileName():match("(.*)/modulefiles/tasks/")
prepend_path("MODULEPATH", pathJoin(rrfs_home, "sorc/RDASApp/modulefiles"))
load("RDAS/ursa.intel")
