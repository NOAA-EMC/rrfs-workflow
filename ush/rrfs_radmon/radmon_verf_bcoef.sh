#!/bin/bash
set -x

export PDATE="${1:-${PDATE:?}}"

err=0
bcoef_exec="rrfs_util_radmon_bcoef.x"

if [[ "${USE_ANL:-0}" -eq 1 ]]; then
   gesanl="ges anl"
else
   gesanl="ges"
fi

#--------------------------------------------------------------------
#   Copy extraction program and supporting files to working directory

${NCP} "${GSI_MON_BIN}/${bcoef_exec}" "./${bcoef_exec}"
#${NCP} "${EXECDIR}/${bcoef_exec}" "./${bcoef_exec}"
${NCP} "${biascr}" "./biascr.txt"

if [[ ! -s "./${bcoef_exec}" || ! -s ./biascr.txt ]]; then
   err=4
else

#--------------------------------------------------------------------
#   Run program for given time

   iyy="${PDATE:0:4}"
   imm="${PDATE:4:2}"
   idd="${PDATE:6:2}"
   ihh="${PDATE:8:2}"

   ctr=0
   fail=0

   nchanl=-999
   npredr=5

   for type in ${SATYPE}; do

      if [[ ! -s "${type}" ]]; then
         echo "ZERO SIZED:  ${type}"
         continue
      fi

      for dtype in ${gesanl}; do

         ctr=$((ctr+1))

         if [[ "${dtype}" == "anl" ]]; then
            bcoef_file="bcoef.${type}_anl.${PDATE}.ieee_d"
            bcoef_ctl="bcoef.${type}_anl.ctl"
         else
            bcoef_file="bcoef.${type}.${PDATE}.ieee_d"
            bcoef_ctl="bcoef.${type}.ctl"
         fi

         if [[ -e ./input ]]; then
             rm -f ./input
         fi

cat << EOF > input
 &INPUT
  satname='${type}',
  npredr=${npredr},
  nchanl=${nchanl},
  iyy=${iyy},
  imm=${imm},
  idd=${idd},
  ihh=${ihh},
  idhh=-720,
  incr=${CYCLE_INTERVAL},
  suffix='${RADMON_SUFFIX}',
  gesanl='${dtype}',
  little_endian=${LITTLE_ENDIAN},
  netcdf=${RADMON_NETCDF},
 /
EOF
         "./${bcoef_exec}" < input >> "stdout.${type}" 2>>errfile
         if [[ $? -ne 0 ]]; then
	    fail=$((fail+1))
         fi


#-------------------------------------------------------------------
#  move data, control, and stdout files to $TANKverf_rad and compress
#

         cat "stdout.${type}" >> stdout.bcoef
         rm -f "stdout.${type}"

         if [[ -s "${bcoef_file}" ]]; then
            ${COMPRESS} "${bcoef_file}"
         fi

         if [[ -s "${bcoef_ctl}" ]]; then
            ${COMPRESS} "${bcoef_ctl}"
         fi


      done  # dtype in $gesanl loop
   done     # type in $SATYPE loop


   "${USHradmon}/rstprod.sh"

   tar_file="radmon_bcoef.tar"
   tar -cf "${tar_file}" bcoef*.ieee_d* bcoef*.ctl*
   ${COMPRESS} "${tar_file}"
   mv "${tar_file}.${Z:-gz}" "${TANKverf_rad}/."

   if [[ "${RAD_AREA}" == "rgn" ]]; then
      cwd=$(pwd)
      cd "${TANKverf_rad}" || exit 1
      tar -xf "${tar_file}.gz"
      rm -f "${tar_file}.gz"
      cd "${cwd}" || exit 1
   fi

   if [[ "${fail}" -ge "${ctr}" ]]; then
      err=5
   fi
fi

exit "${err}"