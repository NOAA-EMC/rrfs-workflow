#!/usr/bin/env bash
# shellcheck disable=SC2154,SC1091
declare -rx PS4='+ $(basename ${BASH_SOURCE[0]:-${FUNCNAME[0]:-"Unknown"}})[${LINENO}]: '
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
# determine cold or warm start cycles and use correct ensemble files and different varlist
#
if [[ -s "${UMBRELLA_PREP_IC_DATA}/mem001/init.nc" ]]; then
  initial_file='init.nc'
  varlist1="rho qv theta u"
else
  initial_file='mpasout.nc'
  varlist1="pressure_p rho qv qc qr qi qs qg ni nr ng nc nifa nwfa volg surface_pressure theta tslb q2 u uReconstructZonal uReconstructMeridional refl10cm w"
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
controlfile="${UMBRELLA_PREP_CONTROL_IC_DATA}/${initial_file}"
if [ -s "${controlfile}" ] ; then
  ln -sf "${controlfile}"  ./mpasout_control.nc
  ${cpreq} "${controlfile}"  ./mpasout_mean.nc
else
  err_exit "Cannot find control background: ${controlfile}"
fi

#
# generate the namelist.ens
#
cat << EOF > namelist.ens
&setup
  ens_size=${ENS_SIZE},
  filebase='mpasout'
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
#
