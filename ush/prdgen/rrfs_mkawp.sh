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
# 2026-06-02  B Blake - add RRFS 13-km grid
#################################################################################

set -xa

fhr=$1
inputfile=$2
gridspacing=$3

runRRFS="000 003 006 009 012 015 018 021 024 027 030 033 036 039 042 045 048 051 054 057 060 066 072 078 084"
if  echo $runRRFS |grep $fhr;
then
  # Processing AWIPS grid (RRFS North America grid - 3 km or 13 km)
  export INPUTfile=${COMOUT}/rrfs.t${cyc}z.${inputfile}.${gridspacing}.f${fhr}.na.grib2

  # Only grab records that need WMO headers for AWIPS
  $WGRIB2 ${INPUTfile} | grep -F -f ${PARMrrfs}/wmo/rrfsparams_${gridspacing} | $WGRIB2 -i ${INPUTfile} -new_grid_winds grid -set_grib_type same -grib rrfs.t${cyc}z.${inputfile}.${gridspacing}.f${fhr}.na.grib2

  # Run tocgrib2

  export pgm="tocgrib2"
  . prep_step

  export FORT11=rrfs.t${cyc}z.${inputfile}.${gridspacing}.f${fhr}.na.grib2
  export FORT51=grib2.rrfs.t${cyc}z.${gridspacing}.f${fhr}.na
  $TOCGRIB2 < $PARMrrfs/wmo/grib2_rrfs_${gridspacing}_f${fhr}_na
  export err=$?; err_chk

  cpreq -p grib2.rrfs.t${cyc}z.${gridspacing}.f${fhr}.na ${COMOUT}/wmo

 if [ $SENDDBN_NTC = YES ]
 then
   $DBNROOT/bin/dbn_alert NTC_LOW $NET $job ${COMOUT}/wmo/grib2.rrfs.t${cyc}z.${gridspacing}.f${fhr}.na
 fi

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
