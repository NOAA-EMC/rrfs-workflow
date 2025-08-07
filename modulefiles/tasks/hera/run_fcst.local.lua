prepend_path("MODULEPATH","/contrib/miniconda3/modulefiles")
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.5.12"))

setenv("SRW_ENV", "/scratch4/BMC/wrfruc/mhu/miniconda/envs/interpol_esmpy")
