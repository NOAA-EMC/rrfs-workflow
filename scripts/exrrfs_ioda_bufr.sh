#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2153,SC2154
declare -rx PS4='+${SECONDS}s $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x
cpreq=${cpreq:-cpreq}

cd "${DATA}" || exit 1

# link the prepbufr file
${cpreq} "${OBSPATH}/${FILE_PREPBUFR}" prepbufr
cp "${OBSPATH}/${FILE_ZTD}" ztdbufr
cp "${OBSPATH}/${FILE_SATWND}" satwndbufr
cp "${OBSPATH}/${FILE_ABI}" abibufr
cp "${OBSPATH}/${FILE_ATMS}" atmsbufr
cp "${OBSPATH}/${FILE_CRISFS}" crisfsbufr
cp "${OBSPATH}/${FILE_IASI}" iasibufr
${cpreq} "${EXECrrfs}"/bufr2ioda.x .
${cpreq} "${EXECrrfs}"/bufr2netcdf.x .

# generate the namelist on the fly
REFERENCE_TIME="${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z"
yaml_list=(
"prepbufr_adpsfc.yaml"
#"prepbufr_adpupa.yaml"
"prepbufr_aircar.yaml"
"prepbufr_aircft.yaml"
"prepbufr_ascatw.yaml"
"prepbufr_msonet.yaml"
"prepbufr_proflr.yaml"
"prepbufr_rassda.yaml"
"prepbufr_sfcshp.yaml"
"prepbufr_vadwnd.yaml"
#"bufr2ioda_cris-fsr.yaml"
)

# run bufr2ioda.x
for yaml in "${yaml_list[@]}"; do
 sed -e "s/@referenceTime@/${REFERENCE_TIME}/" "${PARMrrfs}/${yaml}" > "${yaml}"
 source prep_step
 ./bufr2ioda.x "${yaml}"
 # some data may not be available at all cycles, so we don't check whether bufr2ioda.x runs successfully
done

# --------------------------------------------------
# run  bufr2ioda tool for atms bufr obs
# --------------------------------------------------
${cpreq} "${FIXrrfs}/jedi/atms_beamwidth.txt" .
${cpreq} "${PARMrrfs}/bufr_atms_mapping.yaml" .
input_file="atmsbufr"
output_file="ioda_atms_{splits/satId}.nc"
yaml="bufr_atms_mapping.yaml"
if [[ -s "${input_file}" ]]; then
  ./bufr2netcdf.x "${input_file}" "${yaml}" "${output_file}"
else
  echo "Input file ${input_file} does not exist."
fi

# ---------------------------------------------------------------------
# run bufr2netcdf tool for cris-fsr regular feed(crisfrbufr) bufr obs
# ---------------------------------------------------------------------
${cpreq} "${PARMrrfs}/bufr2netcdf_cris-fsr.yaml" .
input_file="crisfsbufr"
output_file="ioda_crisf4_{splits/satId}.nc"
yaml="bufr2netcdf_cris-fsr.yaml"
if [[ -s "${input_file}" ]]; then
  ./bufr2netcdf.x "${input_file}" "${yaml}" "${output_file}"
else
  echo "Input file ${input_file} does not exist."
fi

# -------------------------------------------------------------------
# run bufr2netcdf tool for cris-fsr DB feed (crsfdbbufr) bufr obs
# -------------------------------------------------------------------
${cpreq} "${PARMrrfs}/bufr2netcdf_cris-fsr.yaml" .
input_file="crsfdbbufr"
output_file="ioda_crsfdb_{splits/satId}.nc"
yaml="bufr2netcdf_cris-fsr.yaml"
if [[ -s "${input_file}" ]]; then
  ./bufr2netcdf.x "${input_file}" "${yaml}" "${output_file}"
else
  echo "Input file ${input_file} does not exist."
fi

# --------------------------------------------------
# run bufr2netcdf tool for mtiasi bufr obs
# --------------------------------------------------
${cpreq} "${PARMrrfs}/bufr2netcdf_mtiasi.yaml" .
input_file="iasibufr"
output_file="ioda_mtiasi_{splits/satId}.nc"
yaml="bufr2netcdf_mtiasi.yaml"
if [[ -s "${input_file}" ]]; then
  ./bufr2netcdf.x "${input_file}" "${yaml}" "${output_file}"
else
  echo "Input file ${input_file} does not exist."
fi

# run python bufr2ioda tool for ZTD and AMV bufr obs
# --------------------------------------------------
HOMErdasapp=${HOMErrfs}/sorc/RDASApp/
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_adpupa_prepbufr.json .
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_adpupa_prepbufr.py .
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_ztd.py .
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_satwnd_amv_goes.json .
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_satwnd_amv_goes.py .
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda.json .
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_gsrcsr.json .
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/bufr2ioda_gsrcsr.py .
${cpreq} "${USHrrfs}"/run_bufr2ioda_gsrcsr.sh .

# pyioda libraries
PYIODALIB=$(echo "${HOMErdasapp}"/build/lib/python3.*)
WXFLOWLIB=${USHrrfs}/wxflow/src
export PYTHONPATH="${WXFLOWLIB}:${PYIODALIB}:${PYTHONPATH}"

# generate a JSON w CDATE from the template and convert to IODA
${cpreq} "${HOMErdasapp}"/rrfs-test/IODA/python/gen_bufr2ioda_json.py .
# ADPUPA
./gen_bufr2ioda_json.py -t bufr2ioda_adpupa_prepbufr.json -o bufr2ioda_adpupa_prepbufr_0.json
./bufr2ioda_adpupa_prepbufr.py -c bufr2ioda_adpupa_prepbufr_0.json

# ZTD
if [[ -s ztdbufr ]]; then
  ./gen_bufr2ioda_json.py -t bufr2ioda.json -o bufr2ioda_0.json
  ./bufr2ioda_ztd.py -c bufr2ioda_0.json
fi

# SATWND
if [[ -s satwndbufr ]]; then
  ./gen_bufr2ioda_json.py -t bufr2ioda_satwnd_amv_goes.json -o bufr2ioda_satwnd_amv_goes_0.json
  ./bufr2ioda_satwnd_amv_goes.py -c bufr2ioda_satwnd_amv_goes_0.json
fi

# GSRCSR (ABI)
if [[ -s abibufr ]]; then
  ln -sf abibufr "rap.t${cyc}z.gsrcsr.tm00.bufr_d"
  ./run_bufr2ioda_gsrcsr.sh "${CDATE}" rap "${DATA}" "${DATA}" "${DATA}" "${HOMErdasapp}"
  cp "rap.t${cyc}z.abi_g16.tm00.nc" "ioda_abi_g16.nc"
  cp "rap.t${cyc}z.abi_g18.tm00.nc" "ioda_abi_g18.nc"
fi

if [[ "${VAD_THINNING:-FALSE}" == "TRUE" ]]; then
# run offline IODA tools
${cpreq} "${USHrrfs}"/offline_vad_thinning.py .
# Run vadwnd superobbing and thinning offline tool.
./offline_vad_thinning.py -i ioda_vadwnd.nc -o ioda_vadwnd_thinned.nc
mv ioda_vadwnd_thinned.nc ioda_vadwnd.nc
fi

# file count sanity check and copy to COMOUT
if ls ./ioda*nc; then
  ${cpreq} "${DATA}"/ioda*.nc "${COMOUT}/ioda_bufr/${WGF}"
else
  echo "FATAL ERROR: no ioda files generated."
  err_exit # err_exit if no ioda files generated at the development stage
fi
