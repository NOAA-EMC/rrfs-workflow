#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}

# link the prepbufr file
${cpreq} ${OBSPATH}/${CDATE}.rap.t${cyc}z.prepbufr.tm00 prepbufr
${cpreq} ${EXECrrfs}/bufr2ioda.x .

# generate the namelist on the fly
REFERENCE_TIME="${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z"
yaml_list=(
#"prepbufr_adpsfc.yaml"
"prepbufr_adpupa.yaml"
"prepbufr_aircar.yaml"
#"prepbufr_aircft.yaml"
#"prepbufr_ascatw.yaml"
#"prepbufr_gpsipw.yaml"
#"prepbufr_msonet.yaml"
#"prepbufr_proflr.yaml"
#"prepbufr_rassda.yaml"
#"prepbufr_satwnd.yaml"
#"prepbufr_sfcshp.yaml"
#"prepbufr_vadwnd.yaml"
)

if (( ${YAML_GEN_METHOD:-1} == 2 )); then
  # Copy empty ioda file to data/obs.
  # Use these as the default when bufr2ioda doesn't create a ioda.
  # Otherwise JEDI will crash due to missing ioda file
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_adpsfc.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_adpupa.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_aircar.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_aircft.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_ascatw.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_gpsipw.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_msonet.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_proflr.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_rassda.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_satwnd.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_sfcshp.nc
  ${cpreq} ${FIXrrfs}/jedi/ioda_empty.nc ioda_vadwnd.nc
fi

# run bufr2ioda.x
for yaml in ${yaml_list[@]}; do
 sed -e "s/@referenceTime@/${REFERENCE_TIME}/" ${PARMrrfs}/${yaml} > ${yaml}
 source prep_step
 ./bufr2ioda.x ${yaml}
 # some data may not be available at all cycles, so we don't check whether bufr2ioda.x runs successfully
done

# run offline IODA tools
${cpreq} ${USHrrfs}/offline_ioda_tweak.py .
ioda_files=$(ls ioda*nc)
for ioda_file in ${ioda_files[@]}; do
  ./offline_ioda_tweak.py -o ${ioda_file}
  base_name=$(basename "$ioda_file" .nc)
  mv  ${base_name}_llp.nc ${base_name}.nc
done

# file count sanity check and copy to COMOUT
ls ./ioda*nc
if (( $? == 0 )); then
  ${cpreq} ${DATA}/ioda*.nc ${COMOUT}/ioda_bufr/${WGF}
else
  echo "FATAL ERROR: no ioda files generated."
  err_exit # err_exit if no ioda files generated at the development stage
fi

