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
  parmdir=$7

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

  mkdir -p ${data}/ifi-304m
  mkdir -p ${data}/wmo

  ifi_outdir=${data}/ifi-304m
  wmo_outdir=${data}/wmo

  #-- ICPRB
  
  wgrib2 ${data}/${fnamei} -s | grep ":ICPRB:" | grep -F -f ${FIXprdgen}/rrfs.ifi.sub304m.params | \
  wgrib2 -i ${data}/${fnamei} -GRIB ${ifi_outdir}/${fname1}

  #-- sipd
  
  wgrib2 ${data}/${fnamei} -s | grep ":SIPD:"  | grep -F -f ${FIXprdgen}/rrfs.ifi.sub304m.params | \
  wgrib2 -i ${data}/${fnamei} -GRIB ${ifi_outdir}/${fname2}

  #-- icesev
  
  # wgrib2 ${data}/${fnamei} -s | grep ":ICESEV:"  | grep -F -f ${FIXprdgen}/rrfs.ifi.sub304m.params | \
  wgrib2 ${data}/${fnamei} -s | grep ":var discipline=0 master_table=2 parmcat=19 parm=37:" | grep -F -f ${FIXprdgen}/rrfs.ifi.sub304m.params | \
  wgrib2 -i ${data}/${fnamei} -GRIB ${ifi_outdir}/${fname3}

  #================================================================
  #-- add WMO header
  
  parm_dir=${parmdir}/wmo

  #-- icprb

  parmfile=${parm_dir}/grib2.rrfs.ifi.icprb.${fhr}      # parm file w/ header info
  infile=${ifi_outdir}/${fname1}
  outfile=${wmo_outdir}/grib2.ifi_icprb.t${cyc}z.f${fcst}.ak3km

  export FORT11=${infile}             # input file 
  export FORT12=                      # optional index file
  export FORT51=${outfile}            # output file w/ headers

  tocgrib2 < $parmfile 1>outfile.icprb.f${fhr}.$$

  #-- sipd
  
  parmfile=${parm_dir}/grib2.rrfs.ifi.sipd.${fhr}      # parm file w/ header info
  infile=${ifi_outdir}/${fname2}
  outfile=${wmo_outdir}/grib2.ifi_sipd.t${cyc}z.f${fcst}.ak3km

  export FORT11=${infile}             # input file 
  export FORT12=                      # optional index file
  export FORT51=${outfile}            # output file w/ headers

  tocgrib2 < $parmfile 1>outfile.sipd.f${fhr}.$$

  #-- icesev

  parmfile=${parm_dir}/grib2.rrfs.ifi.icesev.${fhr}      # parm file w/ header info
  infile=${ifi_outdir}/${fname3}
  outfile=${wmo_outdir}/grib2.ifi_icesev.t${cyc}z.f${fcst}.ak3km

  export FORT11=${infile}               # input file 
  export FORT12=                        # optional index file
  export FORT51=${outfile}              # output file w/ headers

  tocgrib2 < $parmfile 1>outfile.icesev.f${fhr}.$$

