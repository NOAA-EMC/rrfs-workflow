--prepend_path("MODULEPATH","/usw/conda/modulefiles")
--load(pathJoin("miniforge"))

unload("python/3.11.6")

setenv("SRW_ENV", "/gpfs/f6/bil-fire10-oar/world-shared/mhu/miniconda/envs/interpol_esmpy")
