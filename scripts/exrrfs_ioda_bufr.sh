#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1

# link the prepbufr file
${cpreq} "${OBSPATH}/${CDATE}.rap.t${cyc}z.prepbufr.tm00" prepbufr
cp "${OBSPATH}/${CDATE}.rap.t${cyc}z.gpsipw.tm00.bufr_d" ztdbufr
cp "${OBSPATH}/${CDATE}.rap.t${cyc}z.satwnd.tm00.bufr_d" satwndbufr
${cpreq} "${EXECrrfs}"/bufr2ioda.x .

# generate the namelist on the fly
REFERENCE_TIME="${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z"
yaml_list=(
#"prepbufr_adpsfc.yaml"
"prepbufr_adpupa.yaml"
"prepbufr_aircar.yaml"
#"prepbufr_aircft.yaml"
#"prepbufr_ascatw.yaml"
#"prepbufr_msonet.yaml"
#"prepbufr_proflr.yaml"
#"prepbufr_rassda.yaml"
#"prepbufr_sfcshp.yaml"
#"prepbufr_vadwnd.yaml"
)

if (( ${YAML_GEN_METHOD:-1} == 2 )); then
  # For YAML_GEN_METHOD=2 we can use all obs. vadwnd not yet ready.
  yaml_list=(
  "prepbufr_adpsfc.yaml"
  "prepbufr_adpupa.yaml"
  "prepbufr_aircar.yaml"
  "prepbufr_aircft.yaml"
  "prepbufr_ascatw.yaml"
  "prepbufr_msonet.yaml"
  "prepbufr_proflr.yaml"
  "prepbufr_rassda.yaml"
  "prepbufr_sfcshp.yaml"
  #"prepbufr_vadwnd.yaml"
  )
  # Copy empty ioda file to data/obs.
  # Use these as the default when bufr2ioda doesn't create a ioda.
  # Otherwise JEDI will crash due to missing ioda file
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_adpsfc.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_adpupa.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_aircar.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_aircft.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_ascatw.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_gpsipw.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_msonet.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_proflr.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_rassda.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_satwnd.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_sfcshp.nc
  ${cpreq} "${FIXrrfs}"/jedi/ioda_empty.nc ioda_vadwnd.nc
fi

# run bufr2ioda.x
for yaml in "${yaml_list[@]}"; do
 sed -e "s/@referenceTime@/${REFERENCE_TIME}/" "${PARMrrfs}/${yaml}" > "${yaml}"
 source prep_step
 ./bufr2ioda.x "${yaml}"
 # some data may not be available at all cycles, so we don't check whether bufr2ioda.x runs successfully
done

# --------------------------------------------------
# run python bufr2ioda tool for ZTD and AMV bufr obs
# --------------------------------------------------
if (( 1 == 2 )); then
HOMErdasapp=${HOMErrfs}/sorc/RDASApp/
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_ztd.py .
#${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_satwnd.py .
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda.json .

# pyioda libraries
PYIODALIB=$(echo "$HOMErdasapp"/build/lib/python3.*)
export PYTHONPATH=${PYIODALIB}:${PYTHONPATH}

# generate a JSON w CDATE from the template
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/gen_bufr2ioda_json.py .
./gen_bufr2ioda_json.py -t bufr2ioda.json -o bufr2ioda_0.json

./bufr2ioda_ztd.py -c bufr2ioda_0.json
#./bufr2ioda_satwnd.py -c bufr2ioda_0.json
fi

# run offline IODA tools
${cpreq} "${USHrrfs}"/offline_ioda_tweak.py .
for ioda_file in ioda*nc; do
  ./offline_ioda_tweak.py -o "${ioda_file}"
  base_name=$(basename "$ioda_file" .nc)
  mv  "${base_name}_llp.nc" "${base_name}.nc"
done

# file count sanity check and copy to COMOUT
if ls ./ioda*nc; then
  ${cpreq} "${DATA}"/ioda*.nc "${COMOUT}/ioda_bufr/${WGF}"
else
  echo "FATAL ERROR: no ioda files generated."
  err_exit # err_exit if no ioda files generated at the development stage
fi
