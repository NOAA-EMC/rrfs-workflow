#!/bin/bash

echo "--> radmon_verf_angle.sh"

PDATE=${1:-${PDATE:?}}

if [[ $USE_ANL -eq 1 ]]; then
   gesanl="ges anl"
else
   gesanl="ges"
fi

err=0
angle_exec=radmon_angle.x

shared_scaninfo=${shared_scaninfo:-$FIXgdas/gdas_radmon_scaninfo.txt}
echo "shared_scaninfo = $shared_scaninfo"
scaninfo=scaninfo.txt

#--------------------------------------------------------------------
#   Copy extraction program and supporting files to working directory

$NCP ${GSI_MON_BIN}/${angle_exec}  ./
#$NCP ${EXECDIR}/${angle_exec}  ./
$NCP $shared_scaninfo  ./${scaninfo}

if [[ ! -s ./${angle_exec} || ! -s ./${scaninfo} ]]; then
   err=2
else
#--------------------------------------------------------------------
#   Run program for given time

   iyy=`echo $PDATE | cut -c1-4`
   imm=`echo $PDATE | cut -c5-6`
   idd=`echo $PDATE | cut -c7-8`
   ihh=`echo $PDATE | cut -c9-10`
  
   echo "iyy ===" $iyy
   echo "SATYPE ===" $SATYPE

   ctr=0
   fail=0

   for type in ${SATYPE}; do
      echo "type =" $type

      if [[ ! -s ${type} ]]; then
         echo "ZERO SIZED:  ${type}"
         continue
      fi

      for dtype in ${gesanl}; do

         ctr=$((ctr+1))

         if [[ $dtype == "anl" ]]; then
            angl_file=angle.${type}_anl.${PDATE}.ieee_d
            angl_ctl=$angle.{type}_anl.ctl
         else
            angl_file=angle.${type}.${PDATE}.ieee_d
            angl_ctl=angle.${type}.ctl
         fi

         if [[ -e ./input ]]; then
             rm ./input
         fi

         nchanl=-999
         echo "${type} =", ${type}
         echo "iyy="${iyy}
         echo "imm="${imm}
         echo "  idd= "${idd}
         echo "  ihh= "${ihh}
         echo "  incr= "${CYCLE_INTERVAL}
         echo "  nchanl= "${nchanl}
         echo "  suffix= "${RADMON_SUFFIX}
         echo "  gesanl= "${dtype}
         echo "  little_endian= "${LITTLE_ENDIAN}
         echo "  rad_area= "${RAD_AREA}
         echo "  netcdf= "${RADMON_NETCDF}

cat << EOF > input
 &INPUT
  satname='${type}',
  iyy=${iyy},
  imm=${imm},
  idd=${idd},
  ihh=${ihh},
  idhh=-720,
  incr=${CYCLE_INTERVAL},
  nchanl=${nchanl},
  suffix='${RADMON_SUFFIX}',
  gesanl='${dtype}',
  little_endian=${LITTLE_ENDIAN},
  rad_area='${RAD_AREA}',
  netcdf=${RADMON_NETCDF},
 /
EOF

         ./${angle_exec} < input >>   stdout.${type} 2>>errfile
         if [[ $? -ne 0 ]]; then
  	    fail=$((fail+1))
         fi
         
#-------------------------------------------------------------------
#  move data, control, and stdout files to $TANKverf_rad and compress
         cat stdout.${type} >> stdout.angle
         rm stdout.${type}

         if [[ -s ${angl_file} ]]; then
            ${COMPRESS} -f ${angl_file}
         fi

         if [[ -s ${angl_ctl} ]]; then
            ${COMPRESS} -f ${angl_ctl}
         fi 


      done    # for dtype in ${gesanl} loop

   done    # for type in ${SATYPE} loop


   ${USHradmon}/rstprod.sh

   echo TANKverf_rad = $TANKverf_rad
   
   tar_file=radmon_angle.tar 
   tar -cf $tar_file angle*.ieee_d* angle*.ctl*

   ${COMPRESS} ${tar_file}
   mv $tar_file.gz ${TANKverf_rad}/.

   if [[ $RAD_AREA = "rgn" ]]; then
      cwd=`pwd`
      cd ${TANKverf_rad}
      tar -xf ${tar_file}.gz
      rm ${tar_file}.gz
      cd ${cwd}
   fi   

   if [[ $fail -ge $ctr ]]; then
      err=3
   fi
fi

echo "<-- radmon_verf_angle.sh"
exit ${err}
