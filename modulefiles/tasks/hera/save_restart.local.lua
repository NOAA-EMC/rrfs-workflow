prepend_path("MODULEPATH","/contrib/miniconda3/modulefiles")
load(pathJoin("miniconda3", os.getenv("miniconda3_ver") or "4.5.12"))

setenv("SRW_ENV", "/scratch1/BMC/acomp/Johana/miniconda/envs/interpol_esmpy")
