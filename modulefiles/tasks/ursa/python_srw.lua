prepend_path("MODULEPATH","/contrib/miniconda/modulefiles")
load(pathJoin("miniconda", os.getenv("miniconda_ver") or "25.3.1"))

setenv("SRW_ENV", "/scratch4/BMC/wrfruc/mhu/miniconda/envs/interpol_esmpy")
