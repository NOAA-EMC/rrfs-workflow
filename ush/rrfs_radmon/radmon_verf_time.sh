#!/bin/bash

echo "--> radmon_verf_time.sh"

#  Command line arguments.
export PDATE=${1:-${PDATE:?}}

radmon_err_rpt=${radmon_err_rpt:-${USHradmon}/radmon_err_rpt.sh}
report=report.txt
disclaimer=disclaimer.txt

diag_report=diag_report.txt
diag_hdr=diag_hdr.txt
diag=diag.txt

obs_err=obs_err.txt
obs_hdr=obs_hdr.txt
pen_err=pen_err.txt
pen_hdr=pen_hdr.txt

chan_err=chan_err.txt
chan_hdr=chan_hdr.txt
count_hdr=count_hdr.txt
count_err=count_err.txt

time_exec=radmon_time.x
err=0 

if [[ $USE_ANL -eq 1 ]]; then
   gesanl="ges anl"
else
   gesanl="ges"
fi


#--------------------------------------------------------------------
#   Copy extraction program and base files to working directory
#-------------------------------------------------------------------
$NCP ${GSI_MON_BIN}/${time_exec}  ./
#$NCP ${EXECDIR}/${time_exec}  ./
if [[ ! -s ./${time_exec} ]]; then
   err=8
fi

iyy=`echo $PDATE | cut -c1-4`
imm=`echo $PDATE | cut -c5-6`
idd=`echo $PDATE | cut -c7-8`
ihh=`echo $PDATE | cut -c9-10`
cyc=$ihh
CYCLE=$cyc

local_base="local_base"
if [[ $DO_DATA_RPT -eq 1 ]]; then

   if [[ -e ${base_file}.gz ]]; then
      $NCP ${base_file}.gz  ./${local_base}.gz
      ${UNCOMPRESS} ${local_base}.gz
   else
      $NCP ${base_file}  ./${local_base}
   fi

   if [[ ! -s ./${local_base} ]]; then
      echo "RED LIGHT: local_base file not found"
   else
      echo "Confirming local_base file is good = ${local_base}"
      tar -xf ./${local_base}
      echo "local_base is untarred"
   fi
fi

if [[ $err -eq 0 ]]; then
   ctr=0
   fail=0

#--------------------------------------------------------------------
#   Loop over each entry in SATYPE
#--------------------------------------------------------------------
   for type in ${SATYPE}; do

      if [[ ! -s ${type} ]]; then
         echo "ZERO SIZED:  ${type}"
         continue
      fi

      ctr=$((ctr+1))

      for dtype in ${gesanl}; do

         if [[ -e ./input ]]; then
             rm ./input
         fi

         if [[ $dtype == "anl" ]]; then
            time_file=time.${type}_anl.${PDATE}.ieee_d
            time_ctl=time.${type}_anl.ctl
         else
            time_file=time.${type}.${PDATE}.ieee_d
            time_ctl=time.${type}.ctl
         fi

#--------------------------------------------------------------------
#   Run program for given satellite/instrument
#--------------------------------------------------------------------
         nchanl=-999
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

         ./${time_exec} < input >>   stdout.${type} 2>>errfile
         if [[ $? -ne 0 ]]; then
            fail=$((fail+1))
         fi

#-------------------------------------------------------------------
#  move data, control, and stdout files to $TANKverf_rad and compress
#-------------------------------------------------------------------
         cat stdout.${type} >> stdout.time
         rm stdout.${type}

         if [[ -s ${time_file} ]]; then
            ${COMPRESS} ${time_file}
         fi

         if [[ -s ${time_ctl} ]]; then
            ${COMPRESS} ${time_ctl}
         fi
         
      done
   done


   ${USHradmon}/rstprod.sh

   tar_file=radmon_time.tar
   tar -cf $tar_file time*.ieee_d* time*.ctl*
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
      echo "fail, ctr = $fail, $ctr"
      err=10
   fi

fi



####################################################################
#-------------------------------------------------------------------
#  Begin error analysis and reporting
#-------------------------------------------------------------------
####################################################################

if [[ $DO_DATA_RPT -eq 1 ]]; then
echo "STARTING DATA_RPT"

#---------------------------
#  build report disclaimer 
#
   cat << EOF > ${disclaimer}


*********************** WARNING ***************************
THIS IS AN AUTOMATED EMAIL.  REPLIES TO SENDER WILL NOT BE
RECEIVED.  PLEASE DIRECT REPLIES TO edward.safford@noaa.gov
*********************** WARNING ***************************
EOF


#-------------------------------------------------------------------
#  Check for missing diag files 
#
   tmp_satype="./tmp_satype.txt"
   echo ${SATYPE} > ${tmp_satype}
   ${USHradmon}/radmon_diag_ck.sh  --rad ${radstat} --sat ${tmp_satype} --out ${diag}

   if [[ -s ${diag} ]]; then
      cat << EOF > ${diag_hdr}

  Problem Reading Diagnostic File
   

  Problems were encountered reading the diagnostic file for
  the following sources:

EOF

      cat ${diag_hdr} >> ${diag_report}
      cat ${diag} >> ${diag_report}

      echo >> ${diag_report}

      rm ${diag_hdr}
   fi 

#-------------------------------------------------------------------
#  move warning notification to TANKverf
#
   if [[ -s ${diag} ]]; then
      lines=`wc -l <${diag}`
      echo "lines in diag = $lines"   
   
      if [[ $lines -gt 0 ]]; then
         cat ${diag_report}
         cp ${diag}  ${TANKverf_rad}/bad_diag.${PDATE}
      else
         rm ${diag_report}
      fi
   fi



   #----------------------------------------------------------------
   #  Identify bad_pen and bad_chan files for this cycle and 
   #   previous cycle

   bad_pen=bad_pen.${PDATE}
   bad_chan=bad_chan.${PDATE}
   low_count=low_count.${PDATE}

#   qdate=`$NDATE -${CYCLE_INTERVAL} $PDATE`
#   pday=`echo $qdate | cut -c1-8`
   
   prev_bad_pen=bad_pen.${P_PDY}${p_cyc}
   prev_bad_chan=bad_chan.${P_PDY}${p_cyc}
   prev_low_count=low_count.${P_PDY}${p_cyc}

   prev_bad_pen=${TANKverf_radM1}/${prev_bad_pen}
   prev_bad_chan=${TANKverf_radM1}/${prev_bad_chan}
   prev_low_count=${TANKverf_radM1}/${prev_low_count}

   if [[ -s $bad_pen ]]; then
      echo "pad_pen        = $bad_pen"
   fi
   if [[ -s $prev_bad_pen ]]; then
      echo "prev_pad_pen   = $prev_bad_pen"
   fi

   if [[ -s $bad_chan ]]; then
      echo "bad_chan       = $bad_chan"
   fi
   if [[ -s $prev_bad_chan ]]; then
      echo "prev_bad_chan  = $prev_bad_chan"
   fi
   if [[ -s $low_count ]]; then
      echo "low_count = $low_count"
   fi 
   if [[ -s $prev_low_count ]]; then
      echo "prev_low_count = $prev_low_count"
   fi 

   do_pen=0
   do_chan=0
   do_cnt=0

   if [[ -s $bad_pen && -s $prev_bad_pen ]]; then
      do_pen=1
   fi

   if [[ -s $low_count && -s $prev_low_count ]]; then
      do_cnt=1
   fi

   #--------------------------------------------------------------------  
   # avoid doing the bad_chan report for REGIONAL_RR sources -- because
   # they run hourly they often have 0 count channels for off-hour runs.
   #
   if [[ -s $bad_chan && -s $prev_bad_chan && REGIONAL_RR -eq 0 ]]; then
      do_chan=1
   fi

   #--------------------------------------------------------------------
   #  Remove extra spaces in new bad_pen & low_count files
   #
   gawk '{$1=$1}1' $bad_pen > tmp.bad_pen
   mv -f tmp.bad_pen $bad_pen

   gawk '{$1=$1}1' $low_count > tmp.low_count
   mv -f tmp.low_count $low_count

   echo " do_pen, do_chan, do_cnt = $do_pen, $do_chan, $do_cnt"
   echo " diag_report = $diag_report "
   if [[ $do_pen -eq 1 || $do_chan -eq 1 || $do_cnt -eq 1 || -s ${diag_report} ]]; then

      if [[ $do_pen -eq 1 ]]; then   

         echo "calling radmon_err_rpt for pen"
         ${radmon_err_rpt} ${prev_bad_pen} ${bad_pen} pen ${qdate} \
		${PDATE} ${diag_report} ${pen_err}
      fi

      if [[ $do_chan -eq 1 ]]; then   

         echo "calling radmon_err_rpt for chan"
         ${radmon_err_rpt} ${prev_bad_chan} ${bad_chan} chan ${qdate} \
		${PDATE} ${diag_report} ${chan_err}
      fi

      if [[ $do_cnt -eq 1 ]]; then   

         echo "calling radmon_err_rpt for cnt"
         ${radmon_err_rpt} ${prev_low_count} ${low_count} cnt ${qdate} \
		${PDATE} ${diag_report} ${count_err}
      fi

      #-------------------------------------------------------------------
      #  put together the unified error report with any obs, chan, and
      #  penalty problems and mail it

      if [[ -s ${obs_err} || -s ${pen_err} || -s ${chan_err} || -s ${count_err} || -s ${diag_report} ]]; then

         echo DOING ERROR REPORTING

         cat << EOF > $report
Radiance Monitor warning report
 
  Net:   ${RADMON_SUFFIX}
  Cycle: $PDATE

EOF

         if [[ -s ${diag_report} ]]; then
            echo OUTPUTING DIAG_REPORT
            cat ${diag_report} >> $report
         fi

         if [[ -s ${chan_err} ]]; then

            echo OUTPUTING CHAN_ERR

            cat << EOF > ${chan_hdr}
         
  The following channels report 0 observational counts over the past two cycles:
   
  Satellite/Instrument    Channel
  ====================    =======

EOF

            cat ${chan_hdr} >> $report
            cat ${chan_err} >> $report
 
         fi

         if [[ -s ${count_err} ]]; then

            cat << EOF > ${count_hdr}


         
  The following channels report abnormally low observational counts in the latest 2 cycles:
   
Satellite/Instrument              Obs Count          Avg Count
====================              =========          =========

EOF
              
            cat ${count_hdr} >> $report
            cat ${count_err} >> $report
         fi


         if [[ -s ${pen_err} ]]; then

            cat << EOF > ${pen_hdr} 


  Penalty values outside of the established normal range were found
  for these sensor/channel/regions in the past two cycles: 

  Questionable Penalty Values 
  ============ ======= ======      Cycle                 Penalty          Bound
                                   -----                 -------          -----
EOF
            cat ${pen_hdr} >> $report
            cat ${pen_err} >> $report
            rm -f ${pen_hdr} 
            rm -f ${pen_err}
         fi 

         echo  >> $report
         cat ${disclaimer} >> $report
         echo  >> $report
      fi

      #-------------------------------------------------------------------
      #  dump report to log file
      #
      if [[ -s ${report} ]]; then
         lines=`wc -l <${report}`
         if [[ $lines -gt 2 ]]; then
            cat ${report}

            $NCP ${report} ${TANKverf_rad}/warning.${PDATE}
         fi
      fi


   fi

   #-------------------------------------------------------------------
   #  copy new bad_pen, bad_chan, and low_count files to $TANKverf_rad
   #   
   if [[ -s ${bad_chan} ]]; then
      mv ${bad_chan} ${TANKverf_rad}/.
   fi

   if [[ -s ${bad_pen} ]]; then
      mv ${bad_pen} ${TANKverf_rad}/.
   fi

   if [[ -s ${low_count} ]]; then
      mv ${low_count} ${TANKverf_rad}/.
   fi


fi

   ################################################################################
   #-------------------------------------------------------------------
   #  end error reporting section
   #-------------------------------------------------------------------
   ################################################################################

echo "<-- radmon_verf_time.sh"
exit ${err}
