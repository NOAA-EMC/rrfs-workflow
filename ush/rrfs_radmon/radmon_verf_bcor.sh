#!/bin/bash
echo "--> radmon_verf_bcor.sh"

export PDATE=${1:-${PDATE:?}}

bcor_exec=radmon_bcor.x
err=0

if [[ $USE_ANL -eq 1 ]]; then
   gesanl="ges anl"
else
   gesanl="ges"
fi

#--------------------------------------------------------------------
#   Copy extraction program to working directory

$NCP ${GSI_MON_BIN}/${bcor_exec}  ./${bcor_exec}
#$NCP ${EXECDIR}/${bcor_exec}  ./${bcor_exec}
if [[ ! -s ./${bcor_exec} ]]; then
   err=6
else


#--------------------------------------------------------------------
#   Run program for given time

   iyy=`echo $PDATE | cut -c1-4`
   imm=`echo $PDATE | cut -c5-6`
   idd=`echo $PDATE | cut -c7-8`
   ihh=`echo $PDATE | cut -c9-10`

   ctr=0
   fail=0

   for type in ${SATYPE}; do

      for dtype in ${gesanl}; do

         ctr=$((ctr+1))

         if [[ $dtype == "anl" ]]; then
            bcor_file=bcor.${type}_anl.${PDATE}.ieee_d
            bcor_ctl=bcor.${type}_anl.ctl
            input_file=${type}_anl
         else
            bcor_file=bcor.${type}.${PDATE}.ieee_d
            bcor_ctl=bcor.${type}.ctl
            input_file=${type}
         fi

         if [[ -e ./input ]]; then
             rm ./input
         fi

      # Check for 0 length input file here and avoid running 
      # the executable if $input_file doesn't exist or is 0 bytes
      #
         if [[ -s $input_file ]]; then
            nchanl=-999

cat << EOF > input
 &INPUT
  satname='${type}',
  iyy=${iyy},
  imm=${imm},
  idd=${idd},
  ihh=${ihh},
  idhh=-720,
  incr=6,
  nchanl=${nchanl},
  suffix='${RADMON_SUFFIX}',
  gesanl='${dtype}',
  little_endian=${LITTLE_ENDIAN},
  rad_area='${RAD_AREA}',
  netcdf=${RADMON_NETCDF},
 /
EOF
   
            ./${bcor_exec} < input >> stdout.${type} 2>>errfile
            if [[ $? -ne 0 ]]; then
               fail=$((fail+1))
            fi
 

#-------------------------------------------------------------------
#  move data, control, and stdout files to $TANKverf_rad and compress
#
            cat stdout.${type} >> stdout.bcor
            rm stdout.${type}
 
            if [[ -s ${bcor_file} ]]; then
               ${COMPRESS} ${bcor_file}
            fi

            if [[ -s ${bcor_ctl} ]]; then
               ${COMPRESS} ${bcor_ctl}
            fi

         fi
      done  # dtype in $gesanl loop
   done     # type in $SATYPE loop


   ${USHradmon}/rstprod.sh
   tar_file=radmon_bcor.tar

   tar -cf $tar_file bcor*.ieee_d* bcor*.ctl*
   ${COMPRESS} ${tar_file}
   mv $tar_file.${Z} ${TANKverf_rad}/.

   if [[ $RAD_AREA = "rgn" ]]; then
      cwd=`pwd`
      cd ${TANKverf_rad}
      tar -xf ${tar_file}.gz
      rm ${tar_file}.gz
      cd ${cwd}
   fi

   if [[ $fail -ge $ctr ]]; then
      err=7
   fi
fi

echo "<-- radmon_verf_bcor.sh"
exit ${err}

