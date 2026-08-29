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
# Determine cold/warm start and use the appropriate ensemble files/varlist
#
l_recenter=.false.
l_reconstruct=.false.

if [[ "${RECENTER_METHOD}" == "RECONSTRUCT" ]]; then
  varlist1="rho qv theta u"
  l_reconstruct=.true.
elif [[ "${RECENTER_METHOD}" == "RECENTER" ]]; then
  l_recenter=.true.

  if [[ -s "${UMBRELLA_PREP_IC_DATA}/mem001/init.nc" ]]; then
    varlist1="rho qv qc qr qi qs qg theta u tslb smois"
  else
    varlist1="pressure_p rho qv qc qr qi qs qg ni nr ng nc nifa nwfa volg surface_pressure theta smois sh2o tslb q2 u uReconstructZonal uReconstructMeridional refl10cm w"
  fi
else
  echo "Error: recenter mode not defined!"
  exit 1
fi

# Select initial file
if [[ -s "${UMBRELLA_PREP_IC_DATA}/mem001/init.nc" ]]; then
  initial_file='init.nc'
else
  initial_file='mpasout.nc'
fi

numvar1=$(wc -w <<< "${varlist1}")

#
# link ensemble members
#
for i in $(seq -w 001 "${ENS_SIZE}"); do
  ln -snf "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}" mpasout_mem"${i}".nc
done

#-----------------------------------------------------------------------
#
# link the control member
#
#-----------------------------------------------------------------------
#
controlfile_init="${UMBRELLA_PREP_CONTROL_IC_DATA}/init.nc"
controlfile_mpasout="${UMBRELLA_PREP_CONTROL_IC_DATA}/mpasout.nc"
if [[ -s "${controlfile_init}" ]] ; then
  controlfile="${controlfile_init}"
  reconstruct_file="init_construct.nc"
elif [[ -s "${controlfile_mpasout}" ]] ; then
  controlfile="${controlfile_mpasout}"
  reconstruct_file="mpasout_construct.nc"
else
  echo "! Warning: Cannot find control background: ${controlfile_init} or ${controlfile_mpasout}"
  exit 0
fi

ln -sf "${controlfile}"  ./mpasout_control.nc
${cpreq} "${controlfile}"  ./mpasout_mean.nc

#-----------------------------------------------------------------------
#
# Copy the control member to each member directory for reconstruction
#
#-----------------------------------------------------------------------
if [[ "${RECENTER_METHOD}" == "RECONSTRUCT" ]]; then
  export CMDFILE="${DATA}/poescript_cp"
  mkdir -p "$(dirname "${CMDFILE}")"
  : > "${CMDFILE}"
  for i in $(seq -w 001 "${ENS_SIZE}"); do
    echo "cp ${controlfile}  ${UMBRELLA_PREP_IC_DATA}/mem${i}/${reconstruct_file}"  >> "${CMDFILE}"
  done
  ${cpreq} "${EXECrrfs}"/rank_run.x .
  ${MPI_RUN_CMD} ./rank_run.x "${CMDFILE}"
  export err=$?
  if (( err != 0 )) ; then
    echo "copying control to members failed with error code ${err} "
    err_exit
  else
    for i in $(seq -w 001 "${ENS_SIZE}"); do
      ln -sf "${UMBRELLA_PREP_IC_DATA}/mem${i}/${reconstruct_file}"  "./mpasout_construct_mem${i}.nc"
    done
  fi
fi
#
# generate the namelist.ens
#
cat << EOF > namelist.ens
&setup
  ens_size=${ENS_SIZE},
  filebase='mpasout'
  filebase_reconstruct='mpasout_construct'
  filetail(1)='.nc'
  numvar(1)=${numvar1}
  varlist(1)="${varlist1}"
  l_write_mean=.true.
  l_recenter=${l_recenter}
  l_reconstruct=${l_reconstruct}
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

# Replace the original ensemble files only after successful reconstruction
if [[ "${RECENTER_METHOD}" == "RECONSTRUCT" ]] && (( err == 0 )); then
  for i in $(seq -w 001 "${ENS_SIZE}"); do

    final_file="${reconstruct_file/_construct/}"

    if [[ ! -s "${UMBRELLA_PREP_IC_DATA}/mem${i}/${reconstruct_file}" ]]; then
      echo "ERROR: Reconstruction file not found:"
      echo "  ${UMBRELLA_PREP_IC_DATA}/mem${i}/${reconstruct_file}"
      exit 1
    fi

#    rm -f "./mpasout_construct_mem${i}.nc"

    mv "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}" \
       "${UMBRELLA_PREP_IC_DATA}/mem${i}/${initial_file}_old"

    mv "${UMBRELLA_PREP_IC_DATA}/mem${i}/${reconstruct_file}" \
       "${UMBRELLA_PREP_IC_DATA}/mem${i}/${final_file}"

  done
fi

#
