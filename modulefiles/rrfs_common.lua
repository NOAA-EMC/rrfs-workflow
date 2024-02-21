whatis("Description: RRFS build environment common libraries")

help([[Load RRFS Model common libraries]])

load(pathJoin("jasper", os.getenv("jasper_ver") or "2.0.32"))
load(pathJoin("zlib", os.getenv("zlib_ver") or "1.2.13"))
load(pathJoin("libpng", os.getenv("libpng_ver") or "1.6.37"))
load(pathJoin("parallelio", os.getenv("pio_ver") or "2.5.10"))
--loading parallelio will load netcdf_c, netcdf_fortran, hdf5, zlib, etc
load(pathJoin("esmf", os.getenv("esmf_ver") or "8.5.0"))
load(pathJoin("fms", os.getenv("fms_ver") or "2023.02.01"))

load(pathJoin("bacio", os.getenv("bacio_ver") or "2.4.1"))
load(pathJoin("crtm", os.getenv("crtm_ver") or "2.4.0"))
load(pathJoin("g2", os.getenv("g2_ver") or "3.4.5"))
load(pathJoin("g2tmpl", os.getenv("g2tmpl_ver") or "1.10.2"))
load(pathJoin("ip", os.getenv("ip_ver") or "4.3.0"))
load(pathJoin("sp", os.getenv("sp_ver") or "2.3.3"))

load(pathJoin("gftl-shared", os.getenv("gftl-shared_ver") or "1.6.1"))
load(pathJoin("mapl", os.getenv("mapl_ver") or "2.40.3-esmf-8.5.0"))
load(pathJoin("scotch", os.getenv("scotch_ver") or "7.0.4"))

load(pathJoin("bufr", os.getenv("bufr_ver") or "11.7.0"))
load(pathJoin("sigio", os.getenv("sigio_ver") or "2.3.2"))
load(pathJoin("sfcio", os.getenv("sfcio_ver") or "1.4.1"))
load(pathJoin("nemsio", os.getenv("nemsio_ver") or "2.5.4"))
load(pathJoin("wrf-io", os.getenv("wrf_io_ver") or "1.2.0"))
load(pathJoin("ncio", os.getenv("ncio_ver") or "1.1.2"))
load(pathJoin("gsi-ncdiag", os.getenv("gsi-ncdiag_ver") or "1.1.2"))
load(pathJoin("w3emc", os.getenv("w3emc_ver") or "2.10.0"))
load(pathJoin("w3nco", os.getenv("w3nco_ver") or "2.4.1"))

load(pathJoin("nco", os.getenv("nco_ver") or "5.0.6"))
--load(pathJoin("prod_util", os.getenv("prod_util_ver") or "1.2.2"))
--load(pathJoin("wgrib2", os.getenv("wgrib2_ver") or "2.0.8"))
