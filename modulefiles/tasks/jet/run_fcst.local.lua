prepend_path("MODULEPATH","/contrib/miniconda3/modulefiles")
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.5.12"))

setenv("SRW_ENV", "/home/Johana.Romero-Alvarez/miniconda3/envs/interpol_esmpy")
