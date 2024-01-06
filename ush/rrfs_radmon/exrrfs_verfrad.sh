#/bin/bash

# Run data extract/validation for regional radiance diag data
echo "---> exnam_vrfyrad.sh.ecf"

#  Command line arguments
export PDY=${1:-${PDY:?}} 
export cyc=${2:-${cyc:?}}

#################################################################################
# Set the required Directories 
#################################################################################

export FIXnam=${FIXnam:-${FIX_GSI}}

#################################################################################

export USHradmon=${USHradmon:-${USHdir}/rrfs_radmon}

#  Filenames
export satype_file=${satype_file:-rrfs_radmon_satype.txt}

#  Other variables
export PDATE=${PDY}${cyc}
export NCP=${NCP:-/bin/cp}

export Z=${Z:-"gz"}
export UNCOMPRESS=${UNCOMPRESS:-"gunzip -f"}

#  NOTE for namrr:  the contents of the t00z.radstat.tm06-tm01 are stored
#  in the _next_ day's radmon.[yyyymmdd] file to match the way the radstat
#  files are created.  
#    The pattern is for radmon.20160318:
#       t00z.radstat.tm06  contents is dated 2016031718
#       t00z.radstat.tm05  contents is dated 2016031719
#           . . .
#       t00z.radstat.tm01  contents is dated 2016031723
#       t00z.radstat.tm00  contents is dated 2016031800

###########################################################################
# ensure work and TANK dirs exist, verify radstat and biascr are available
echo "DATA dir =", $DATA
if [[ ! -d ${DATA} ]]; then
   mkdir $DATA
fi
cd $DATA
echo " radstat " $radstat

data_available=0
if [[ -s ${radstat} && -s ${biascr} ]]; then
   data_available=1                                         

   #------------------------------------------------------------------
   #  Copy data files file to local data directory.  
   #  Untar radstat file.  
   #------------------------------------------------------------------

   ${NCP} ${biascr}  ./biascr.${PDATE}
   ${NCP} ${radstat} ./radstat.${PDATE}

   tar -xf radstat.${PDATE}
   #rm radstat.$PDATE

   #------------------------------------------------------------------
   #  SATYPE is the list of expected satellite/instrument sources
   #  in the radstat file.  It should be stored in the $TANKverf 
   #  directory.  If it isn't there then use the $FIXnam copy.  In all 
   #  cases write it back out to the radmon.$PDY directory.  Add any
   #  new sources to the list before writing back out.
   #------------------------------------------------------------------
   radstat_satype=`ls d*ges* | awk -F_ '{ print $2 "_" $3 }'`
   echo 'radstat_satype= ' $radstat_satype

   #------------------------------------------------------------------
   #  Look for the $satype_file from the info directory or $FIXnam
   #  in that order.  
   #------------------------------------------------------------------
   if [[ ! -e ${TANKverf}/info/${satype_file} ]]; then
      if [[ -e ${FIXnam}/${satype_file} ]]; then 
         export SATYPE=`cat ${FIXnam}/${satype_file}`
      else
         export SATYPE=${radstat_satype}
      fi
   else
      export SATYPE=`cat ${TANKverf}/info/${satype_file}`
   fi

   #-------------------------------------------------------------
   #  Update the SATYPE if any new sat/instrument was 
   #  found in $radstat_satype. 
   #-------------------------------------------------------------
   satype_changes=0
   new_satype=${SATYPE}
   for type in ${radstat_satype}; do
      test=`echo ${SATYPE} | grep ${type} | wc -l`

      if [[ ${test} -eq 0 ]]; then
         echo "FOUND ${type} in radstat file but not in SATYPE list.  Adding it now."
         satype_changes=1
         new_satype="${new_satype} ${type}"
      fi
   done

   if [[ ${satype_changes} -eq 1 ]]; then
      SATYPE=${new_satype}
   fi
   export SATYPE=${SATYPE}

   echo "SATYPE = $SATYPE"  
 
   #------------------------------------------------------------------
   # Determine bin or nc4 diag files, rename, and uncompress
   #------------------------------------------------------------------
   netcdf=.true.
   for type in ${SATYPE}; do
      if [[ -e ./diag_${type}_ges.${PDATE}.nc4.${Z} ]]; then
         netcdf=.true.; break
      fi
   done
   export RADMON_NETCDF=$netcdf

   for type in ${SATYPE}; do

      if [[ ${RADMON_NETCDF} == ".true." ]]; then

         if [[ ! -e ./diag_${type}_ges.${PDATE}.nc4.${Z} ]]; then
            edited_satype="$(echo $SATYPE | tr ' ' '\n' | sed "/${type}/d")"
            echo "REMOVED:  $type from SATYPE"
            export SATYPE=${edited_satype}

         else 
            mv ./diag_${type}_ges.${PDATE}.nc4.${Z} ${type}.${Z}
            ${UNCOMPRESS} ./${type}.${Z}
            mv ./diag_${type}_anl.${PDATE}.*${Z} ${type}_anl.${Z}
            ${UNCOMPRESS} ./${type}_anl.${Z}
         fi
   
      else	  
         if [[ ! -e ./diag_${type}_ges.${PDATE}.${Z} ]]; then
            edited_satype="$(echo $SATYPE | tr ' ' '\n' | sed "/${type}/d")"
            echo "REMOVED:  $type from SATYPE"
            export SATYPE=${edited_satype}
         else	
            mv ./diag_${type}_ges.${PDATE}.${Z} ${type}.${Z}
            ${UNCOMPRESS} ./${type}.${Z}
            mv ./diag_${type}_anl.${PDATE}.${Z} ${type}_anl.${Z}
            ${UNCOMPRESS} ./${type}_anl.${Z}
         fi
      fi

   done

   #------------------------------------------------------------------
   #   Run the child sccripts.
   #------------------------------------------------------------------
   echo "PDATE === " ${PDATE}
   echo "PDATE SATYPE=== " ${SATYPE}
   ${USHradmon}/radmon_verf_angle.sh ${PDATE}
   rc_angle=$?

   ${USHradmon}/radmon_verf_bcoef.sh ${PDATE}
   rc_bcoef=$?

   ${USHradmon}/radmon_verf_bcor.sh ${PDATE}
   rc_bcor=$?

   ${USHradmon}/radmon_verf_time.sh ${PDATE}
   rc_time=$?

   #--------------------------------------
   #  optionally run clean_tankdir script
   #
   if [[ ${CLEAN_TANKVERF} -eq 1 ]]; then
      ${USHradmon}/clean_tankdir.sh rgn 20 
      rc_clean_tankdir=$?
      echo "rc_clean_tankdir = $rc_clean_tankdir"
   fi

fi

#####################################################################
# Postprocessing

err=0
if [[ ${data_available} -ne 1 ]]; then
   err=1
elif [[ $rc_angle -ne 0 ]]; then
   err=$rc_angle
elif [[ $rc_bcoef -ne 0 ]]; then
   err=$rc_bcoef
elif [[ $rc_bcor -ne 0 ]]; then
   err=$rc_bcor
elif [[ $rc_time -ne 0 ]]; then
   err=$rc_time
fi

echo "<--- exnam_vrfyrad.sh.ecf"
exit ${err}

