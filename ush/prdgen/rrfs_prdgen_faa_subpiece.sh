#!/bin/bash
set -ex
       
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
USHrrfs=$8
fixdir=$9
parmdir=${10}

# FAA request variable to be extracted from UPP output

#-- remove the leading 0"
ifhr=$(expr ${fhr:0:3} + 0)    ## (eg. f013-15-00)
ifmn=${fhr:4:2}
ifhrmn=${ifhr}${ifmn}

# Grid 91 for the IFI AK 
  grid_specs_91="nps:210:60 181.429:1649:2976.000000 40.530:1105:2976.000000"

# Grid 130 for the GTG & ICING process
  grid_specs_130="lambert:265:25.000000 233.862000:451:13545.000000 16.281000:337:13545.000000"

# 13km Rotated Lat Lon   
  grid_specs_rrfs_13km="rot-ll:247.0:-35.0:0.0 -61.0:1127:0.1083 -37.0:684:0.1083"

# CONUS_3km Lambert Conformal
  grid_specs_rrfs="lambert:-97.5:38.500000 237.280472:1799:3000 21.138115:1059:3000"

# Grid 195: 2.5 km Mercator Puerto Rico domain
  grid_specs_195="mercator:20 284.5:544:2500:297.491 15.0:310:2500:22.005"

# Grid 237: Puerto Rico FAA Regional Grid (Lambert Conformal)
  grid_specs_237="lambert:253:50.000000 285.720000:54:32463.410000 16.201000:47:32463.410000"

##########################################################
##== Start to generate customerized data ====

if [ $((${ifmn#0})) -eq 0 ]; then    # exact hour, hourly (eg. f012)

  #-- fcst string in wgrib2 inv file. Set to "" for all ins & ave
  fcstvar1="${ifhr} hour fcst"

  #-- hourly average instead of accumulation from "0"
  if [ ${ifhr} = 0 ] ; then
    jfhr=0
  else    
    let jfhr=${ifhr}-1
  fi 

  fcstvar2="${jfhr}-${ifhr} hour acc fcst"

  #-- replace undifined variables in "*parmas" files in /fix/prdgen
  sed "s/FCSTVARS1/${fcstvar1}/" ${fixdir}/rrfs.prslev-FAA130.params > rrfs.prslev-FAA130.params
  sed -i "s/FCSTVARS2/${fcstvar2}/" rrfs.prslev-FAA130.params

  sed "s/FCSTVARS1/${fcstvar1}/" ${fixdir}/rrfs.prslev-FAA237.params > rrfs.prslev-FAA237.params
  sed -i "s/FCSTVARS2/${fcstvar2}/" rrfs.prslev-FAA237.params

  sed "s/FCSTVARS1/${fcstvar1}/" ${fixdir}/rrfs.prslev-rrfs13km.params > rrfs.prslev-rrfs13km.params
  sed -i "s/FCSTVARS2/${fcstvar2}/" rrfs.prslev-rrfs13km.params

  sed "s/FCSTVARS1/${fcstvar1}/" ${fixdir}/rrfs.prslev-rrfs3km.params > rrfs.prslev-rrfs3km.params
  sed -i "s/FCSTVARS2/${fcstvar2}/" rrfs.prslev-rrfs3km.params

# FAA requested ATM

  if [[ -f ${COMOUT}/${prslev} ]]; then

    #-- GRID 130: CONUS 13km
    if [ $ifhr -le 21 ]; then
      wgrib2 ${COMOUT}/${prslev} | grep -F -f rrfs.prslev-FAA130.params | \
      wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_130} rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.conus.grib2
      mv rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.conus.grib2 ${COMOUT}
      wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.conus.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.conus.grib2.idx

      #-- add wmo header
      infile=rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.conus.grib2
      ${USHrrfs}/rrfs.wmo-header.sh WARP ${fhr} ${cyc} ${infile} 130 ${parmdir} ${COMOUT}
    fi

    #-- 3km Rotated Lat Lon (subset of the original RRFS output)
    if [ $ifhr -le 15 ]; then
      wgrib2 ${COMOUT}/${prslev} | grep -F -f rrfs.prslev-rrfs3km.params | \
      wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
         -grib  rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2
      mv rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2 ${COMOUT}
      wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2.idx

      #-- add wmo header
      infile=rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2
      ${USHrrfs}/rrfs.wmo-header.sh AWIPS ${fhr} ${cyc} ${infile} na3km ${parmdir} ${COMOUT}
    fi

    #-- 13km Rotated Lat Lon
    if [ $ifhr -le 18 ]; then
      wgrib2 ${COMOUT}/${prslev} | grep -F -f rrfs.prslev-rrfs13km.params | \
      wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_rrfs_13km} rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.na.grib2
      mv rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.na.grib2 ${COMOUT}
      wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.na.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.na.grib2.idx

      #-- additional process for adding fields to the sub-hourly
      
      export ifhrmn=$(printf "%02d" $ifhrmn)
      wgrib2 ${COMOUT}/${prslev} -s | egrep '(:VIL:entire atmosphere:|:RETOP:)' | \
      wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_rrfs_13km} rrfs.t${cyc}z.prslevfaa.subh.13km.f${ifhrmn}00.na.grib2
      mv rrfs.t${cyc}z.prslevfaa.subh.13km.f${ifhrmn}00.na.grib2 ${COMOUT}
    fi

    #-- GRID 237: PR 32 km
    if [ $ifhr -le 12 ]; then
      wgrib2 ${COMOUT}/${prslev} | grep -F -f rrfs.prslev-FAA237.params | \
      wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_237} rrfs.t${cyc}z.prslevfaa.32km.f${fhr}.pr.grib2
      mv rrfs.t${cyc}z.prslevfaa.32km.f${fhr}.pr.grib2 ${COMOUT}
    fi
  fi

  if [[ -f ${COMOUT}/${natlev} ]]; then

    #-- GRID 130
    #wgrib2 ${COMOUT}/${natlev} -s | grep "hybrid level:" | grep -F -f ${fixdir}/rrfs.natlev-FAA130.params | \
    #wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
    #   -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    #   -new_grid_interpolation bilinear \
    #   -new_grid ${grid_specs_130} rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.conus.grib2
    #mv rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.conus.grib2 ${COMOUT}

    #-- 13km Rotated Lat Lon
    if [ $ifhr -le 6 ]; then
      wgrib2 ${COMOUT}/${natlev} -s | grep "hybrid level:" | grep -F -f ${fixdir}/rrfs.natlev-FAA130.params | \
      wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_rrfs_13km} rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.na.grib2

      wgrib2 ${COMOUT}/${natlev} -s | grep ":LTNG:entire atmosphere:" | \
      wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_rrfs_13km} rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.na.tmp.grib2
      cat rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.na.tmp.grib2 >> rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.na.grib2
      rm rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.na.tmp.grib2
      mv rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.na.grib2 ${COMOUT}
      wgrib2 ${COMOUT}/rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.na.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.na.grib2.idx
    fi

    #-- GRID 237
    if [ $ifhr -le 12 ]; then
      #wgrib2 ${COMOUT}/${natlev} -s | grep "hybrid level:" | grep -F -f ${fixdir}/rrfs.natlev-FAA130.params | \
      #wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
      #   -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
      #   -new_grid_interpolation bilinear \
      #   -new_grid ${grid_specs_237} rrfs.t${cyc}z.natlevfaa.32km.f${fhr}.pr.grib2

      wgrib2 ${COMOUT}/${natlev} -s | grep ":LTNG:entire atmosphere:" | \
      wgrib2 -i ${COMOUT}/${natlev} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_237} rrfs.t${cyc}z.natlevfaa.32km.f${fhr}.pr.tmp.grib2
      #cat rrfs.t${cyc}z.natlevfaa.32km.f${fhr}.pr.tmp.grib2 >> rrfs.t${cyc}z.natlevfaa.32km.f${fhr}.pr.grib2
      cat rrfs.t${cyc}z.natlevfaa.32km.f${fhr}.pr.tmp.grib2 >> ${COMOUT}/rrfs.t${cyc}z.prslevfaa.32km.f${fhr}.pr.grib2
      wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslevfaa.32km.f${fhr}.pr.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslevfaa.32km.f${fhr}.pr.grib2.idx

      rm rrfs.t${cyc}z.natlevfaa.32km.f${fhr}.pr.tmp.grib2
      #mv rrfs.t${cyc}z.natlevfaa.32km.f${fhr}.pr.grib2 ${COMOUT}
      
      #-- add wmo header
      infile=rrfs.t${cyc}z.prslevfaa.f${fhr}.pr32km.grib2
      ${USHrrfs}/rrfs.wmo-header.sh WARP ${fhr} ${cyc} ${infile} 237 ${parmdir} ${COMOUT}

    fi 
  fi

  #if [[ -f ${COMOUT}/rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.conus.grib2  || -f ${COMOUT}/rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.conus.grib2 ]]; then
  #  cat ${COMOUT}/rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.conus.grib2 ${COMOUT}/rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.conus.grib2 \
  #      > ${COMOUT}/rrfs.t${cyc}z.13km.f${fhr}.conus.grib2
  #  rm ${COMOUT}/rrfs.t${cyc}z.prslevfaa.13km.f${fhr}.conus.grib2 ${COMOUT}/rrfs.t${cyc}z.natlevfaa.13km.f${fhr}.conus.grib2
  #  wgrib2 ${COMOUT}/rrfs.t${cyc}z.13km.f${fhr}.conus.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.13km.f${fhr}.conus.grib2.idx
  #fi

  #if [[ -f ${COMOUT}/rrfs.t${cyc}z.prslev.13km.f${fhr}.rotll.faa.grib2  || -f ${COMOUT}/rrfs.t${cyc}z.natlev.13km.f${fhr}.rotll.faa.grib2 ]]; then
  #  cat ${COMOUT}/rrfs.t${cyc}z.prslev.13km.f${fhr}.rotll.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.13km.f${fhr}.rotll.faa.grib2 \
  #      > ${COMOUT}/rrfs.t${cyc}z.13km.f${fhr}.rotll.faa.grib2
  #  rm ${COMOUT}/rrfs.t${cyc}z.prslev.13km.f${fhr}.rotll.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.13km.f${fhr}.rotll.faa.grib2
  #  wgrib2 ${COMOUT}/rrfs.t${cyc}z.13km.f${fhr}.rotll.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.13km.f${fhr}.rotll.faa.grib2.idx
  #fi

  #if [[ -f ${COMOUT}/rrfs.t${cyc}z.prslev.32km.f${fhr}.pr.faa.grib2  || -f ${COMOUT}/rrfs.t${cyc}z.natlev.32km.f${fhr}.pr.faa.grib2 ]]; then
  #  cat ${COMOUT}/rrfs.t${cyc}z.prslev.32km.f${fhr}.pr.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.32km.f${fhr}.pr.faa.grib2 \
  #      > ${COMOUT}/rrfs.t${cyc}z.32km.f${fhr}.pr.faa.grib2
  #  rm ${COMOUT}/rrfs.t${cyc}z.prslev.32km.f${fhr}.pr.faa.grib2 ${COMOUT}/rrfs.t${cyc}z.natlev.32km.f${fhr}.pr.faa.grib2
  #  wgrib2 ${COMOUT}/rrfs.t${cyc}z.32km.f${fhr}.pr.faa.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.32km.f${fhr}.pr.faa.grib2.idx
  #fi

# GTG process
  
  #-- GRID 130: CONUS 13km
  #if [[ -f ${COMOUT}/${aviati} ]]; then
  #  if [ $ifhr -le 21 ]; then
  #    # wgrib2 ${COMOUT}/${aviati} -s | egrep '(:EDPARM:|:CATEDR:|:MWTURB:|:CITEDR:)' | \
  #    wgrib2 ${COMOUT}/${aviati} -s | egrep '(:EDPARM:|:CATEDR:|:MWTURB:|:var discipline=0 master_table=2 parmcat=19 parm=50:)' | \
  #    wgrib2 -i ${COMOUT}/${aviati} -set_bitmap 1 -set_grib_type c3 \
  #       -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
  #       -new_grid_interpolation bilinear \
  #       -new_grid ${grid_specs_130} GTG_grid_130.grib2
  #    mv GTG_grid_130.grib2 ${COMOUT}/rrfs.t${cyc}z.aviati.13km.f${fhr}.conus.grib2
  #    wgrib2 ${COMOUT}/rrfs.t${cyc}z.aviati.13km.f${fhr}.conus.grib2  -s > ${COMOUT}/rrfs.t${cyc}z.aviati.13km.f${fhr}.conus.grib2.idx
  #  fi
  #fi

  #-- CONUS_3km Lambert Conformal
  if [[ -f ${COMOUT}/${aviati} ]]; then
    if [ $ifhr -le 21 ]; then
      # wgrib2 ${COMOUT}/${aviati} -s | egrep '(:MXEDPRM:|:EDPARM:|:CATEDR:|:MWTURB:|:CITEDR:)' | \
      wgrib2 ${COMOUT}/${aviati} -s | egrep '(:MXEDPRM:|:EDPARM:|:CATEDR:|:MWTURB:|:var discipline=0 master_table=2 parmcat=19 parm=50:)' | \
      wgrib2 -i ${COMOUT}/${aviati} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_rrfs} GTG_grid_conus3km.grib2
      mv GTG_grid_conus3km.grib2 ${COMOUT}/rrfs.t${cyc}z.aviati.3km.f${fhr}.conus.grib2
      wgrib2 ${COMOUT}/rrfs.t${cyc}z.aviati.3km.f${fhr}.conus.grib2  -s > ${COMOUT}/rrfs.t${cyc}z.aviati.3km.f${fhr}.conus.grib2.idx
    fi
  fi

# IFI icing process
   
  if [[ -f ${COMOUT}/${ififip} ]]; then

    #-- GRID 130: CONUS 13km
    #if [ $ifhr -le 21 ]; then
    #  # wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:ICESEV:)' | \
    #  wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
    #  wgrib2 -i ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
    #     -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    #     -new_grid_interpolation neighbor \
    #     -new_grid ${grid_specs_130} IFI_grid_130.grib2
    #  mv IFI_grid_130.grib2 ${COMOUT}/rrfs.t${cyc}z.ififip.13km.f${fhr}.conus.grib2
    #  wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.13km.f${fhr}.conus.grib2  -s > ${COMOUT}/rrfs.t${cyc}z.ififip.13km.f${fhr}.conus.grib2.idx

    #  #-- subset IFI data at every 304 m only at certain forcast hour
    #  if [ $ifhr = 1 -o  $ifhr = 2 -o  $ifhr = 3 -o  $ifhr = 6 -o  $ifhr = 9 -o  $ifhr = 12 -o  $ifhr = 15 -o  $ifhr = 18 ]; then
    #    IFIFILE=rrfs.t${cyc}z.ififip.13km.f${fhr}.conus.grib2
    #    IFIDOMAIN=conus13km
    #    ${USHrrfs}/rrfs_subset_ifi_304m.sh $fhr $cyc ${COMOUT} ${IFIFILE} ${IFIDOMAIN} ${fixdir} ${parmdir}
    #  fi
    #fi

    #-- CONUS_3km Lambert Conformal
    if [ $ifhr -le 21 ]; then
      # wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:ICESEV:)' | \
      wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
      wgrib2 -i ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation neighbor \
         -new_grid ${grid_specs_rrfs} IFI_grid_conus3km.grib2
      mv IFI_grid_conus3km.grib2 ${COMOUT}/rrfs.t${cyc}z.ififip.3km.f${fhr}.conus.grib2
      wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.3km.f${fhr}.conus.grib2  -s > ${COMOUT}/rrfs.t${cyc}z.ififip.3km.f${fhr}.conus.grib2.idx

      #-- subset IFI data at every 304 m only at certain forcast hour
      if [ $ifhr = 1 -o  $ifhr = 2 -o  $ifhr = 3 -o  $ifhr = 6 -o  $ifhr = 9 -o  $ifhr = 12 -o  $ifhr = 15 -o  $ifhr = 18 ]; then
        IFIFILE=rrfs.t${cyc}z.ififip.3km.f${fhr}.conus.grib2
        IFIDOMAIN=conus3km
        ${USHrrfs}/rrfs_subset_ifi_304m.sh $fhr $cyc ${COMOUT} ${IFIFILE} ${IFIDOMAIN} ${fixdir} ${parmdir}
      fi
    fi

    #-- 13km Rotated Lat Lon
    #wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:ICESEV:)' | \
    # wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
    #wgrib2 -i ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
    #   -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    #   -new_grid_interpolation neighbor \
    #   -new_grid ${grid_specs_rrfs_13km} IFI_rotll_130.grib2
    #mv IFI_rotll_130.grib2 ${COMOUT}/rrfs.t${cyc}z.ififip.13km.f${fhr}.rotll.grib2
    #wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.13km.f${fhr}.rotll.grib2  -s > ${COMOUT}/rrfs.t${cyc}z.ififip.13km.f${fhr}.rotll.grib2.idx

    #-- GRID 91: AK 3km
    if [ $ifhr -le 18 ]; then
      # wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:ICESEV:)' | \
      wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
      wgrib2 ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation neighbor \
         -new_grid ${grid_specs_91}  rrfs.t${cyc}z.ififip.3km.f${fhr}.ak.grib2
      mv rrfs.t${cyc}z.ififip.3km.f${fhr}.ak.grib2 ${COMOUT}
      wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.3km.f${fhr}.ak.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.ififip.3km.f${fhr}.ak.grib2.idx

      #-- subset IFI data at every 304 m only at certain forcast hour
      if [ $ifhr = 1 -o  $ifhr = 2 -o  $ifhr = 3 -o  $ifhr = 6 -o  $ifhr = 9 -o  $ifhr = 12 -o  $ifhr = 15 -o  $ifhr = 18 ]; then
        IFIFILE=rrfs.t${cyc}z.ififip.3km.f${fhr}.ak.grib2
        IFIDOMAIN=ak3km
        ${USHrrfs}/rrfs_subset_ifi_304m.sh $fhr $cyc ${COMOUT} ${IFIFILE} ${IFIDOMAIN} ${fixdir} ${parmdir}
      fi
    fi

    #-- GRID 237: PR 32km
    #wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:ICESEV:)' | \
    # wgrib2 ${COMOUT}/${ififip} -s | egrep '(:ICPRB:|:SIPD:|:var discipline=0 master_table=2 parmcat=19 parm=37:)' | \
    #wgrib2 ${COMOUT}/${ififip} -set_bitmap 1 -set_grib_type c3 \
    #   -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    #   -new_grid_interpolation neighbor \
    #   -new_grid ${grid_specs_237}  rrfs.t${cyc}z.ififip.32km.f${fhr}.pr.grib2
    #mv rrfs.t${cyc}z.ififip.32km.f${fhr}.pr.grib2 ${COMOUT}
    #wgrib2 ${COMOUT}/rrfs.t${cyc}z.ififip.32km.f${fhr}.pr.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.ififip.32km.f${fhr}.pr.grib2.idx
    
  fi

else     # sub-hourly upp data  (eg. f013-15-00)

  if [[ -f ${COMOUT}/${prslev} ]]; then

    #-- 13km Rotated Lat Lon
    if [ $ifhrmn -le 1800 ]; then
      export ifhrmn=$(printf "%04d" $ifhrmn)
      wgrib2 ${COMOUT}/${prslev} -s | egrep '(:VIL:entire atmosphere:|:RETOP:)' | \
      wgrib2 -i ${COMOUT}/${prslev} -set_bitmap 1 -set_grib_type c3 \
         -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
         -new_grid_interpolation bilinear \
         -new_grid ${grid_specs_rrfs_13km} rrfs.t${cyc}z.prslevfaa.subh.13km.f${ifhrmn}.na.grib2
      mv rrfs.t${cyc}z.prslevfaa.subh.13km.f${ifhrmn}.na.grib2 ${COMOUT}
    fi
  fi
fi
