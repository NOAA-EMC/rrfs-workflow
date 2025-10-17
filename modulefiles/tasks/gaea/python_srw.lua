unload("python")

prepend_path("MODULEPATH","/usw/conda/modulefiles")
load(pathJoin("miniforge"))
setenv("SRW_ENV", "/gpfs/f6/bil-fire10-oar/world-shared/mhu/miniconda/envs/interpol_esmpy")
