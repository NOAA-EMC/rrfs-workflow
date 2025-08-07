--prepend_path("MODULEPATH","/contrib/miniconda3/modulefiles")
--load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.5.12"))

unload("python/3.11.6")
setenv("SRW_ENV", "/gpfs/f6/bil-fire10-oar/world-shared/mhu/miniconda/envs/interpol_esmpy")

