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

runRRFS="000 001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 016 017 018 019 020 021 022 023 024 025 026 027 028 029 030 031 032 033 034 035 036 037 038 039 040 041 042 043 044 045 046 047 048 049 050 051 052 053 054 055 056 057 058 059 060 063 066 069 072 075 078 081 084"
if  echo $runRRFS |grep $fhr;
then
  # Processing AWIPS grid (RRFS 3-km North America grid)

  export FORT11=${COMOUT}/rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2
  export FORT12=${COMOUT}/rrfs.t${cyc}z.prslev.3km.f${fhr}.na.grib2.idx
  export FORT51=grib2.t${cyc}z.awprrfs_f${fhr}_${cyc}

  export pgm="tocgrib2"
  . prep_step

  $TOCGRIB2 < $PARMrrfs/wmo/grib2_awips_rrfs_f${fhr} # >> $pgmout 2> errfile
  export err=$?; err_chk

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

if [ $err -ne 0 ]; then
  echo "AWIPS file was generated successfully for forecast hour ${fhr}!"
else
  err_exit "AWIPS file was not generated successfully for forecast hour ${fhr}.  :("
fi

exit
