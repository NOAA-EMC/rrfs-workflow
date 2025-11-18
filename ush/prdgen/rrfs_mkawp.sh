#! /bin/sh

#################################################################################
####  UNIX Script Documentation Block
#
# Script name:         rrfs_mkawp.sh
# Script description:  To generate the AWIPS products for the RRFS
#
# Author:      B Blake /  EMC         Date: 2025-07-23
#
# Script history log:
# 2014-06-30  G Manikin  - adapted for HRRR
# 2018-01-24  B Blake - HRRRv3
# 2025-07-23  B Blake - adapted for RRFSv1
#################################################################################

set -xa

fhr=$1

#runRRFS="000 001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 016 017 018 019 020 021 022 023 024 025 026 027 028 029 030 031 032 033 034 035 036 037 038 039 040 041 042 043 044 045 046 047 048 049 050 051 052 053 054 055 056 057 058 059 060 063 066 069 072 075 078 081 084"
runRRFS="000 003 006 009 012 015 018 021 024 027 030 033 036 039 042 045 048 051 054 057 060 063 066 069 072 075 078 081 084"
if  echo $runRRFS |grep $fhr;
then
  # Processing AWIPS grid (RRFS 3-km North America grid)
  export INPUTfile=${COMOUT}/rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2

  # Only grab records that need WMO headers for AWIPS
  # Split into 2 parts - one for wind speed records, one for everything else
  $WGRIB2 ${INPUTfile} | grep -F -f ${PARMrrfs}/wmo/rrfsparams_3km | $WGRIB2 -i ${INPUTfile} -new_grid_winds grid -set_grib_type same -grib rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2
  $WGRIB2 ${INPUTfile} | grep -F -f ${PARMrrfs}/wmo/rrfsparams_3km_wind | $WGRIB2 -i ${INPUTfile} -new_grid_winds grid -set_grib_type same -grib rrfs.t${cyc}z.prslev.3km.f${fhr}.na.wind.grib2

  # Run tocgrib2 twice and cat the files together

  export pgm="tocgrib2"
  . prep_step

  # All records not including wind speed
  export FORT11=rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2
  export FORT51=grib2.t${cyc}z.awprrfs_f${fhr}
  $TOCGRIB2 < $PARMrrfs/wmo/grib2_awips_rrfs_f${fhr}
  export err=$?; err_chk

  # Wind speed records
  export FORT11=rrfs.t${cyc}z.prslev.3km.f${fhr}.na.wind.grib2
  export FORT51=grib2.t${cyc}z.awprrfs_f${fhr}_wind
  $TOCGRIB2 < $PARMrrfs/wmo/grib2_awips_rrfs_f${fhr}_wind
  export err=$?; err_chk

  cat grib2.t${cyc}z.awprrfs_f${fhr} grib2.t${cyc}z.awprrfs_f${fhr}_wind > grib2.t${cyc}z.awprrfs_f${fhr}_${cyc}

  cpreq -p grib2.t${cyc}z.awprrfs_f${fhr}_${cyc} ${COMOUT}/wmo

# DBN alerts from HRRR script - someone can modify this for RRFS later
#  if [ $SENDDBN_NTC = YES -a $fhr -le 18 ]
#  then
#    $DBNROOT/bin/dbn_alert NTC_LOW $NET $job $WMO/grib2.${cycle}.awphrrr184_f${fhr}_${cyc}
#  fi

else
  echo "An AWIPS file will not be generated for forecast hour ${fhr}."
  exit
fi

if [ $err -eq 0 ]; then
  echo "AWIPS file was generated successfully for forecast hour ${fhr}!"
else
  err_exit "AWIPS file was not generated successfully for forecast hour ${fhr}.  :("
fi


exit
