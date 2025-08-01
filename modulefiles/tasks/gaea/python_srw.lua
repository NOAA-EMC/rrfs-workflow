--prepend_path("MODULEPATH","/usw/conda/modulefiles")
--load(pathJoin("miniforge"))

unload("python/3.11.6")

setenv("SRW_ENV", "/ncrc/home2/Ming.Hu/miniconda/envs/interpol_esmpy")
