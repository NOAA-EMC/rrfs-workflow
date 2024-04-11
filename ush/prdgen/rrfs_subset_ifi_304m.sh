#!/bin/bash
#

set -xv

# ---- Get grib data at certain record # ----------------------
#
#  subset IFI for each variable at every 304 m & separate files 
#

  fhr=$1
  cyc=$2
  data=$3
  fnamei=$4
  gridid=$5
  FIXprdgen=$6

  #-- remove the leading 0"
  ifhr=$(expr $fhr + 0)

  if [ $ifhr -lt 10 ]; then
    fcst=$(printf "%02d" $ifhr)
  else
    fcst=$ifhr
  fi

#--------------------------------------------------------------- 
#-- process WMO data

  fname1=grib2.ifi.t${cyc}z.f${fcst}.${gridid}
  fname2=grib2.ifi.t${cyc}z.sld.f${fcst}.${gridid}
  fname3=grib2.ifi.t${cyc}z.sev.f${fcst}.${gridid}

  mkdir -p ${data}/wmo

  wgrib2 ${data}/${fnamei} -s | grep ":ICPRB:" | grep -F -f ${FIXprdgen}/rrfs.ifi.sub304m.params | \
  wgrib2 -i ${data}/${fnamei} -GRIB ${data}/wmo/${fname1}

  wgrib2 ${data}/${fnamei} -s | grep ":SIPD:"  | grep -F -f ${FIXprdgen}/rrfs.ifi.sub304m.params | \
  wgrib2 -i ${data}/${fnamei} -GRIB ${data}/wmo/${fname2}

  # wgrib2 ${data}/${fnamei} -s | grep ":ICESEV:"  | grep -F -f ${FIXprdgen}/rrfs.ifi.sub304m.params | \
  wgrib2 ${data}/${fnamei} -s | grep ":var discipline=0 master_table=2 parmcat=19 parm=37:" | grep -F -f ${FIXprdgen}/rrfs.ifi.sub304m.params | \
  wgrib2 -i ${data}/${fnamei} -GRIB ${data}/wmo/${fname3}
