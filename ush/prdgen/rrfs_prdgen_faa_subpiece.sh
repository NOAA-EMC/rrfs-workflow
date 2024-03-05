#!/bin/bash
       
#     
#-----------------------------------------------------------------------
#

fhr=$1
cyc=$2
prslev=$3
natlev=$4
ififip=$5
aviati=$6
COMOUT=$7

# FAA request variable to be extracted from UPP output
  parmdir=${USHdir}/prdgen
  # parmdir=${USHdir}/prdgen/fix_file

# Grid 91 for the IFI AK 
  grid_specs_91="nps:210:60 181.429:1649:2976.000000 40.530:1105:2976.000000"

# Grid 130 for the GTG & ICING process
  grid_specs_130="lambert:265:25.000000 233.862000:451:13545.000000 16.281000:337:13545.000000"

# 13km Rotated Lat Lon   
  grid_specs_rrfs_13km="rot-ll:247.0:-35.0:0.0 -61.0:1127:0.1083 -37.0:684:0.1083"

# Grid 195: 2.5 km Mercator Puerto Rico domain
  grid_specs_195="mercator:20 284.5:544:2500:297.491 15.0:310:2500:22.005"

# Grid 237: Puerto Rico FAA Regional Grid (Lambert Conformal)
  grid_specs_237="lambert:253:50.000000 285.720000:54:32463.410000 16.201000:47:32463.410000"

# FAA requested ATM

  if [[ -f ${COMOUT}/${prslev} ]]; then

    #-- GRID 130: CONUS 13km
    wgrib2 ${COMOUT}/${prslev} | grep -F -f ${parmdir}/rrfs.prslev-FAA130.params | \
    wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation bilinear \
       -new_grid ${grid_specs_130} rrfs.t${cyc}z.prslev.f${fhr}.conus_13km.faa.grib2
    mv rrfs.t${cyc}z.prslev.f${fhr}.conus_13km.faa.grib2 ${COMOUT}
    wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.conus_13km.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.conus_13km.faa.grib2.idx

    #-- 13km Rotated Lat Lon
    wgrib2 ${COMOUT}/${prslev} | grep -F -f ${parmdir}/rrfs.prslev-rrfs13km.params | \
    wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation bilinear \
       -new_grid ${grid_specs_rrfs_13km} rrfs.t${cyc}z.prslev.f${fhr}.rotate_13km.faa.grib2
    mv rrfs.t${cyc}z.prslev.f${fhr}.rotate_13km.faa.grib2 ${COMOUT}
    wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.rotate_13km.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.rotate_13km.faa.grib2.idx

    #-- GRID 237: PR 32 km
    wgrib2 ${COMOUT}/${prslev} | grep -F -f ${parmdir}/rrfs.prslev-FAA237.params | \
    wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation bilinear \
       -new_grid ${grid_specs_237} rrfs.t${cyc}z.prslev.f${fhr}.pr_32km.faa.grib2
    mv rrfs.t${cyc}z.prslev.f${fhr}.pr_32km.faa.grib2 ${COMOUT}
  fi

  if [[ -f ${COMOUT}/${natlev} ]]; then

    #-- GRID 130
    #wgrib2 ${COMOUT}/${natlev} -s | grep "hybrid level:" | grep -F -f ${parmdir}/rrfs.natlev-FAA130.params | \
    #wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
    #   -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    #   -new_grid_interpolation bilinear \
    #   -new_grid ${grid_specs_130} rrfs.t${cyc}z.natlev.f${fhr}.conus_13km.faa.grib2
    #mv rrfs.t${cyc}z.natlev.f${fhr}.conus_13km.faa.grib2 ${COMOUT}

    #-- 13km Rotated Lat Lon
    wgrib2 ${COMOUT}/${natlev} -s | grep "hybrid level:" | grep -F -f ${parmdir}/rrfs.natlev-FAA130.params | \
    wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation bilinear \
       -new_grid ${grid_specs_rrfs_13km} rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.faa.grib2

    wgrib2 ${COMOUT}/${natlev} -s | grep ":LTNG:entire atmosphere:" | \
    wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation bilinear \
       -new_grid ${grid_specs_rrfs_13km} rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.tmp.grib2
    cat rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.tmp.grib2 >> rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.faa.grib2
    rm rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.tmp.grib2
    mv rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.faa.grib2 ${COMOUT}
    wgrib2 ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.faa.grib2.idx

    #-- GRID 237
    #wgrib2 ${COMOUT}/${natlev} -s | grep "hybrid level:" | grep -F -f ${parmdir}/rrfs.natlev-FAA130.params | \
    #wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
    #   -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    #   -new_grid_interpolation bilinear \
    #   -new_grid ${grid_specs_237} rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.faa.grib2

    wgrib2 ${COMOUT}/${natlev} -s | grep ":LTNG:entire atmosphere:" | \
    wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation bilinear \
       -new_grid ${grid_specs_237} rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.tmp.grib2
    #cat rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.tmp.grib2 >> rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.faa.grib2
    cat rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.tmp.grib2 >> ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.pr_32km.faa.grib2
    wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.pr_32km.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.pr_32km.faa.grib2.idx

    rm rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.tmp.grib2
    #mv rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.faa.grib2 ${COMOUT}
  fi

  #if [[ -f ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.conus_13km.faa.grib2  || -f ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.conus_13km.faa.grib2 ]]; then
  #  cat ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.conus_13km.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.conus_13km.faa.grib2 \
  #      > ${COMOUT}/rrfs.t${cyc}z.f${fhr}.conus_13km.faa.grib2
  #  rm ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.conus_13km.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.conus_13km.faa.grib2
  #  wgrib2 ${COMOUT}/rrfs.t${cyc}z.f${fhr}.conus_13km.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.f${fhr}.conus_13km.faa.grib2.idx
  #fi

  #if [[ -f ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.rotate_13km.faa.grib2  || -f ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.faa.grib2 ]]; then
  #  cat ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.rotate_13km.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.faa.grib2 \
  #      > ${COMOUT}/rrfs.t${cyc}z.f${fhr}.rotate_13km.faa.grib2
  #  rm ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.rotate_13km.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.rotate_13km.faa.grib2
  #  wgrib2 ${COMOUT}/rrfs.t${cyc}z.f${fhr}.rotate_13km.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.f${fhr}.rotate_13km.faa.grib2.idx
  #fi

  #if [[ -f ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.pr_32km.faa.grib2  || -f ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.faa.grib2 ]]; then
  #  cat ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.pr_32km.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.faa.grib2 \
  #      > ${COMOUT}/rrfs.t${cyc}z.f${fhr}.pr_32km.faa.grib2
  #  rm ${COMOUT}/rrfs.t${cyc}z.prslev.f${fhr}.pr_32km.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.f${fhr}.pr_32km.faa.grib2
  #  wgrib2 ${COMOUT}/rrfs.t${cyc}z.f${fhr}.pr_32km.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.f${fhr}.pr_32km.faa.grib2.idx
  #fi

  # GTG process

  if [[ -f ${COMOUT}/${aviati} ]]; then
   # wgrib2 ${COMOUT}/${aviati} -s | egrep '(:EDPARM:|:CATEDR:|:MWTURB:|:CITEDR:)' | wgrib2 -i -grib inputs.grib_naGTG ${COMOUT}/${aviati}
    wgrib2 ${COMOUT}/${aviati} -s | egrep '(:EDPARM:|:CATEDR:|:MWTURB:|:var discipline=0 master_table=2 parmcat=19 parm=50:)' | \
    wgrib2 -i ${COMOUT}/${aviati} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation bilinear \
       -new_grid ${grid_specs_130} GTG_grid_130.grib2
    mv GTG_grid_130.grib2 ${COMOUT}/rrfs.t${cyc}z.aviati.f${fhr}.conus_13km.grib2
    wgrib2 ${COMOUT}/rrfs.t${cyc}z.aviati.f${fhr}.conus_13km.grib2  -s > ${COMOUT}/rrfs.t${cyc}z.aviati.f${fhr}.conus_13km.grib2.idx
  fi

  # IFI icing process
   
  if [[ -f ${COMOUT}/${ififip} ]]; then

    #-- GRID 130: CONUS 13km
    # wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:ICESEV:)' | wgrib2 -i -grib inputs.grib_naIFI ${COMOUT}/${ififip}
    wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
    wgrib2 -i ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation neighbor \
       -new_grid ${grid_specs_130} IFI_grid_130.grib2
    mv IFI_grid_130.grib2 ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.conus_13km.grib2
    wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.conus_13km.grib2  -s > ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.conus_13km.grib2.idx

    #-- 13km Rotated Lat Lon
    #wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
    #wgrib2 -i ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
    #   -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    #   -new_grid_interpolation neighbor \
    #   -new_grid ${grid_specs_rrfs_13km} IFI_rotate_130.grib2
    #mv IFI_rotate_130.grib2 ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.rotate_13km.grib2
    #wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.rotate_13km.grib2  -s > ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.rotate_13km.grib2.idx

    #-- GRID 91: AK 3km
    wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
    wgrib2 ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation neighbor \
       -new_grid ${grid_specs_91}  rrfs.t${cyc}z.ififip.f${fhr}.ak_3km.grib2
    mv rrfs.t${cyc}z.ififip.f${fhr}.ak_3km.grib2 ${COMOUT}
    wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.ak_3km.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.ak_3km.grib2.idx

    #-- GRID 237: PR 32km
    wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
    wgrib2 ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
       -new_grid_interpolation neighbor \
       -new_grid ${grid_specs_237}  rrfs.t${cyc}z.ififip.f${fhr}.pr_32km.grib2
    mv rrfs.t${cyc}z.ififip.f${fhr}.pr_32km.grib2 ${COMOUT}
    wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.pr_32km.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.ififip.f${fhr}.pr_32km.grib2.idx
  fi
