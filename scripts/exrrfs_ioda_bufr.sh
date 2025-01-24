#!/usr/bin/env bash
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]${id}: '
set -x
cpreq=${cpreq:-cpreq}

cd ${DATA}

# link the prepbufr file
${cpreq} ${OBSPATH}/${CDATE}.rap.t${cyc}z.prepbufr.tm00 prepbufr
${cpreq} ${EXECrrfs}/bufr2ioda.x .
execfile=${HOMErrfs}/sorc/RDASApp/build/bin/bufr2ioda.x

# generate the namelist on the fly
REFERENCE_TIME="${CDATE:0:4}-${CDATE:4:2}-${CDATE:6:2}T${CDATE:8:2}:00:00Z"
yaml_list=(
"prepbufr_aircraft.yaml"
#"prepbufr_ascatw.yaml"
#"prepbufr_gpsipw.yaml"
#"prepbufr_mesonet.yaml"
#"prepbufr_profiler.yaml"
#"prepbufr_rassda.yaml"
#"prepbufr_satwnd.yaml"
#"prepbufr_adpsfc.yaml"
"prepbufr_adpupa.yaml"
)

# run bufr2ioda.x
for yaml in ${yaml_list[@]}; do
 sed -e "s/@referenceTime@/${REFERENCE_TIME}/" ${PARMrrfs}/${yaml} > ${yaml}
 source prep_step
 ${MPI_RUN_CMD} ${execfile} ${yaml}
 # some data may not be available at all cycles, so we don't check whether bufr2ioda.x runs successfully
done

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
  ${cpreq} ${DATA}/ioda*.nc ${COMOUT}/ioda_bufr/
else
  echo "WARNING: no ioda files generated."
fi

