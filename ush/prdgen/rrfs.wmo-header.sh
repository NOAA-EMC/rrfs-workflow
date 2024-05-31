#!/bin/bash
#

set -xv

# ---- Add wmo header to grib2 file ----------------------
#

case=$1
fhr=$2
cyc=$3
file=$4
gridid=$5
parmdir=$6
data=$7

#-- remove the leading 0"

mkdir -p ${data}/wmo

wmo_outdir=${data}/wmo

#--------------------------------------------------------------- 
#-- process WMO header

if [ "${case}" == "AWIPS" ]; then
  echo "PLACING HEADERS for t${cyc}z f${fhr}, RUNNING TOCGRIB2"

  parm_dir=${parmdir}/wmo
  parmfile=grib2.awips.rrfs.${fhr}

  #-- remove ".grib2"
  
  suffix=".grib2"
  string=${file}
  infilex=${string::${#string}-${#suffix}}
 
  infile=${file}
  outfile=grib2.$infilex

  export FORT11=${data}/${infile}           # input file
  export FORT12=                            # optional index file
  export FORT51=${wmo_outdir}/${outfile}    # output file w/ headers

  tocgrib2 < ${parm_dir}/$parmfile 1>outfile.${gridid}.f${fhr}.$$

elif [ "${case}" == "WARP" ]; then
  echo "PLACING HEADERS for t${cyc}z f${fhr}, RUNNING TOCGRIB2"

  parm_dir=${parmdir}/wmo
  parmfile=grib2.faa.warp${gridid}.rrfs.${fhr}

  #-- remove ".grib2"
    
  suffix=".grib2"
  string=${file}
  infilex=${string::${#string}-${#suffix}}

  infile=${file}
  outfile=grib2.$infilex

  export FORT11=${data}/${infile}            # input file
  export FORT12=                             # optional index file
  export FORT51=${wmo_outdir}/${outfile}     # output file w/ headers

  tocgrib2 < ${parm_dir}/$parmfile 1>outfile.${gridid}.f${fhr}.$$

fi

exit 0
