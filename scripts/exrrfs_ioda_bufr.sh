#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}

# link the prepbufr file
${cpreq} ${OBSPATH}/${CDATE}.rap.t${cyc}z.prepbufr.tm00 prepbufr
${cpreq} ${OBSPATH}/${CDATE}.rap.t${cyc}z.gpsipw.tm00.bufr_d ztdbufr
${cpreq} ${OBSPATH}/${CDATE}.rap.t${cyc}z.satwnd.tm00.bufr_d satwndbufr
${cpreq} ${EXECrrfs}/bufr2ioda.x .

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

# run bufr2ioda.x for prepbufr data
# ---------------------------------
for yaml in ${yaml_list[@]}; do
 sed -e "s/@referenceTime@/${REFERENCE_TIME}/" ${PARMrrfs}/${yaml} > ${yaml}
 source prep_step
 ./bufr2ioda.x ${yaml}
 # some data may not be available at all cycles, so we don't check whether bufr2ioda.x runs successfully
done

# run python bufr2ioda tool for ZTD and AMV obs
# ---------------------------------------------
DIR_ROOT=${HOMErrfs}/sorc/RDASApp/
${cpreq} ${DIR_ROOT}/rrfs-test/IODA/python/bufr2ioda_ztd.py .
#${cpreq} ${DIR_ROOT}/rrfs-test/IODA/python/bufr2ioda_satwnd.py .
${cpreq} ${DIR_ROOT}/rrfs-test/IODA/python/bufr2ioda.json .

USH_IODA=$DIR_ROOT/rrfs-test/IODA/python/
BUFRJSONGEN=$USH_IODA/gen_bufr2ioda_json.py

# pyioda libraries
PYIODALIB=`echo $DIR_ROOT/build/lib/python3.*`
export PYTHONPATH=${PYIODALIB}:${PYTHONPATH}

# generate a JSON w CDATE from the template
${BUFRJSONGEN} -t bufr2ioda.json -o bufr2ioda_0.json

 python bufr2ioda_ztd.py -c bufr2ioda_0.json
#python bufr2ioda_satwnd.py -c bufr2ioda_0.json

# run offline IODA tools
${cpreq} ${HOMErrfs}/sorc/RDASApp/rrfs-test/IODA/offline_add_var_to_ioda.py .
ioda_files=$(ls ioda*nc)
for ioda_file in ${ioda_files[@]}; do
  ./offline_add_var_to_ioda.py -o ${ioda_file}
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

