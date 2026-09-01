#!/usr/bin/env bash
# shellcheck disable=SC2154,SC1091
declare -rx PS4='+${SECONDS}s $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
set -x

cpreq=${cpreq:-cpreq}
#prefix=${EXTRN_MDL_SOURCE%_NCO} # remove the trailing '_NCO' if any
#
# enter the run directory
#
cd "${DATA}" || exit 1

if [[ " ${RECENTER_CYCS:-99} " != *" ${cyc} "* ]]; then
  echo "INFO: No recentering at this cycle - ${cyc}"
  exit 0
fi

#
# link the control member
#

controlfile_init="${UMBRELLA_PREP_CONTROL_IC_DATA}/init.nc"
controlfile_mpasout="${UMBRELLA_PREP_CONTROL_IC_DATA}/mpasout.nc"
if [[ -s "${controlfile_init}" ]] ; then
  controlfile="${controlfile_init}"
elif [[ -s "${controlfile_mpasout}" ]] ; then
  controlfile="${controlfile_mpasout}"
else
  echo "! Warning: Cannot find control background: ${controlfile_init} or ${controlfile_mpasout}"
  exit 0
fi

ln -sf "${controlfile}"  ./mpasout_control.nc
${cpreq} "${controlfile}"  ./mpasout_mean.nc

#
# Determine cold/warm start and use the appropriate ensemble files/varlist
#

if [[ -s "${UMBRELLA_PREP_IC_DATA}/mem001/init.nc" ]]; then
  initial_file='init.nc'
else
  initial_file='mpasout.nc'
fi

#
# Determine how to update members:
# 
# For variables specified in varlist1:
# member_updated = member_orig + (control - ensemble_mean)
# 
# For variables not specified in varlist1:
# RECENTER_TEMPLATE:
#  = CONTROL: use the control member values for all ensemble members
#  = MEMBER : retain the original member values.
#

if [[ "${RECENTER_TEMPLATE}" == "CONTROL" ]]; then
# Use control file as the output template
  varlist1="rho qv theta u"
  filename_out="rec_$(basename "${controlfile}")"

  export CMDFILE="${DATA}/poescript_cp"
  : > "${CMDFILE}"
  
  for i in $(seq -w 001 "${ENS_SIZE}"); do
    echo "cp ${controlfile}  ${UMBRELLA_PREP_IC_DATA}/mem${i}/${filename_out}"  >> "${CMDFILE}"
  done
  
  ${cpreq} "${EXECrrfs}"/rank_run.x .
  ${MPI_RUN_CMD} ./rank_run.x "${CMDFILE}"
  export err=$?
  
  if (( err != 0 )) ; then
    echo "Error: copying control to members failed with error code ${err} "
    err_exit
  fi
  
elif [[ "${RECENTER_TEMPLATE}" == "MEMBER" ]]; then
# Use original member file as the output template
  if [[ -s "${UMBRELLA_PREP_IC_DATA}/mem001/init.nc" ]]; then
    varlist1="rho qv qc qr qi qs qg theta u tslb smois"
  else
    varlist1="pressure_p rho qv qc qr qi qs qg ni nr ng nc nifa nwfa volg surface_pressure theta smois sh2o tslb q2 u uReconstructZonal uReconstructMeridional refl10cm w"
  fi
  
  filename_out="rec_$(basename "${initial_file}")"
  
else
  echo "ERROR: RECENTER_TEMPLATE must be CONTROL or MEMBER"
  exit 1
fi

numvar1=$(wc -w <<< "${varlist1}")

#
# link ensemble members as input/output
#
for i in $(seq -w 001 "${ENS_SIZE}"); do
  if [[ ! -s "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}" ]]; then
    echo "ERROR: Missing ${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}"
    exit 1
  fi
  ln -snf "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}" mpasin_mem"${i}".nc
  ln -snf "${UMBRELLA_PREP_IC_DATA}/mem${i}/${filename_out}" mpasout_mem"${i}".nc
done

#
# generate the namelist.ens
#
cat << EOF > namelist.ens
&setup
  ens_size=${ENS_SIZE},
  filebase='mpasin'
  filebase_out='mpasout'
  filetail(1)='.nc'
  numvar(1)=${numvar1}
  varlist(1)="${varlist1}"
  l_write_mean=.true.
  l_recenter=.true.
/
EOF

# run mpasjedi_enkf.x
export pgm="gen_ensmean_recenter.exe"
${cpreq} "${EXECrrfs}"/${pgm} .
source prep_step
${MPI_RUN_CMD} ./${pgm} log.out
# check the status
export err=$?
err_chk

# Replace the ensemble files if using control as the template
if [[ "${RECENTER_TEMPLATE}" == "CONTROL" ]] && (( err == 0 )); then
  for i in $(seq -w 001 "${ENS_SIZE}"); do
	updated_file="${filename_out#rec_}"
    if [[ ! -s "${UMBRELLA_PREP_IC_DATA}/mem${i}/${filename_out}" ]]; then
      echo "ERROR: Updated member file not found:"
      echo "  ${UMBRELLA_PREP_IC_DATA}/mem${i}/${filename_out}"
      exit 1
    fi
	rm -f "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}_old"
    mv "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}" \
       "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}_old"
	rm -f "${UMBRELLA_PREP_IC_DATA}/mem${i}/${updated_file}"
    mv "${UMBRELLA_PREP_IC_DATA}/mem${i}/${filename_out}" \
       "${UMBRELLA_PREP_IC_DATA}/mem${i}/${updated_file}"
  done
fi

#
