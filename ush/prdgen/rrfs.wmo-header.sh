#!/bin/bash
set -x

# ---- Add wmo header to grib2 file ----------------------

case_type="$1"
case="${case_type}"
fhr="$2"
cyc="$3"
file="$4"
gridid="$5"
parmdir="$6"
data="$7"

mkdir -p "${data}/wmo"

wmo_outdir="${data}/wmo"

. prep_step

err=0

#---------------------------------------------------------------
#-- process WMO header

if [[ "${case_type}" == "AWIPS" ]]; then
  echo "PLACING HEADERS for t${cyc}z f${fhr}, RUNNING TOCGRIB2"

  parm_dir="${parmdir}/wmo"
  parmfile="grib2.awips.rrfs.${fhr}"

  #-- remove ".grib2"
  infile="${file}"
  infilex="${infile%.grib2}"
  outfile="grib2.${infilex}"

  export FORT11="${data}/${infile}"           # input file
  export FORT12=""                            # optional index file
  export FORT51="${wmo_outdir}/${outfile}"    # output file w/ headers

  tocgrib2 < "${parm_dir}/${parmfile}" > "outfile.${gridid}.f${fhr}.$$"
  err=$?

elif [[ "${case_type}" == "WARP" ]]; then
  echo "PLACING HEADERS for t${cyc}z f${fhr}, RUNNING TOCGRIB2"

  parm_dir="${parmdir}/wmo"
  parmfile="grib2.faa.warp${gridid}.rrfs.${fhr}"

  #-- remove ".grib2"
  infile="${file}"
  infilex="${infile%.grib2}"
  outfile="grib2.${infilex}"

  export FORT11="${data}/${infile}"            # input file
  export FORT12=""                             # optional index file
  export FORT51="${wmo_outdir}/${outfile}"     # output file w/ headers

  tocgrib2 < "${parm_dir}/${parmfile}" > "outfile.${gridid}.f${fhr}.$$"
  err=$?

fi

exit "${err}"