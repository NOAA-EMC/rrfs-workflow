#!/bin/bash
set -x

# Run data extract/validation for regional radiance diag data
echo "---> exrrfs_vrfyrad.sh.ecf"

#  Command line arguments
export PDY="${1:-${PDY:?}}" 
export cyc="${2:-${cyc:?}}"

#################################################################################
# Set the required Directories 
#################################################################################

export FIXrrfs="${FIXrrfs:-${FIX_GSI}}"

#################################################################################

export USHradmon="${USHradmon:-${USHrrfs}/rrfs_radmon}"

#  Filenames
export satype_file="${satype_file:-rrfs_radmon_satype.txt}"

#  Other variables
export PDATE="${PDY}${cyc}"
export NCP="${NCP:-/bin/cp}"

export Z="${Z:-gz}"
export UNCOMPRESS="${UNCOMPRESS:-gunzip -f}"

###########################################################################
# ensure work and TANK dirs exist, verify radstat and biascr are available
echo "DATA dir = ${DATAradmon}"
if [[ ! -d "${DATAradmon}" ]]; then
   mkdir -p "${DATAradmon}"
fi
cd "${DATAradmon}" || exit 1
echo " radstat ${radstat}"

data_available=0
rc_angle=0
rc_bcoef=0
rc_bcor=0
rc_time=0

if [[ -s "${radstat}" && -s "${biascr}" ]]; then
   data_available=1                                         

   #------------------------------------------------------------------
   #  Copy data files file to local data directory.  
   #  Untar radstat file.  
   #------------------------------------------------------------------

   ${NCP} "${biascr}"  "./biascr.${PDATE}"
   ${NCP} "${radstat}" "./radstat.${PDATE}"

   tar -xf "radstat.${PDATE}"
   #rm radstat.$PDATE

   #------------------------------------------------------------------
   #  SATYPE is the list of expected satellite/instrument sources
   #  in the radstat file.  It should be stored in the $TANKverf 
   #  directory.  If it isn't there then use the $FIXrrfs copy.  In all 
   #  cases write it back out to the radmon.$PDY directory.  Add any
   #  new sources to the list before writing back out.
   #------------------------------------------------------------------
   radstat_files=( d*ges* )
   radstat_satype=""
   if [[ -e "${radstat_files[0]:-}" ]]; then
      printf -v radstat_file_list '%s\n' "${radstat_files[@]}"
      radstat_satype=$(awk -F_ '{ print $2 "_" $3 }' <<< "${radstat_file_list}")
   fi
   echo "radstat_satype = ${radstat_satype}"

   #------------------------------------------------------------------
   #  Look for the $satype_file from the info directory or $FIXrrfs
   #  in that order.  
   #------------------------------------------------------------------
   if [[ ! -e "${TANKverf}/info/${satype_file}" ]]; then
      if [[ -e "${FIXrrfs}/${satype_file}" ]]; then 
         export SATYPE
         SATYPE=$(cat "${FIXrrfs}/${satype_file}")
      else
         export SATYPE="${radstat_satype}"
      fi
   else
      export SATYPE
      SATYPE=$(cat "${TANKverf}/info/${satype_file}")
   fi

   #-------------------------------------------------------------
   #  Update the SATYPE if any new sat/instrument was 
   #  found in $radstat_satype. 
   #-------------------------------------------------------------
   satype_changes=0
   new_satype="${SATYPE}"
   for type in ${radstat_satype}; do
      type_found=$(echo "${SATYPE}" | grep -c "${type}" || true)

      if [[ "${type_found}" -eq 0 ]]; then
         echo "FOUND ${type} in radstat file but not in SATYPE list.  Adding it now."
         satype_changes=1
         new_satype="${new_satype} ${type}"
      fi
   done

   if [[ "${satype_changes}" -eq 1 ]]; then
      SATYPE="${new_satype}"
   fi
   export SATYPE="${SATYPE}"

   echo "SATYPE = ${SATYPE}"  
 
   #------------------------------------------------------------------
   # Determine bin or nc4 diag files, rename, and uncompress
   #------------------------------------------------------------------
   netcdf=".true."
   for type in ${SATYPE}; do
      if [[ -e "./diag_${type}_ges.${PDATE}.nc4.${Z}" ]]; then
         netcdf=".true."
         break
      fi
   done
   export RADMON_NETCDF="${netcdf}"

   for type in ${SATYPE}; do

      if [[ "${RADMON_NETCDF}" == ".true." ]]; then

         if [[ ! -e "./diag_${type}_ges.${PDATE}.nc4.${Z}" ]]; then
            satypes="${SATYPE// /$'\n'}"
            edited_satype=$(sed "/${type}/d" <<< "${satypes}")
            echo "REMOVED:  ${type} from SATYPE"
            export SATYPE="${edited_satype}"

         else 
            mv "./diag_${type}_ges.${PDATE}.nc4.${Z}" "${type}.${Z}"
            ${UNCOMPRESS} "./${type}.${Z}"
            mv ./diag_"${type}"_anl."${PDATE}".*"${Z}" "${type}_anl.${Z}"
            ${UNCOMPRESS} "./${type}_anl.${Z}"
         fi
   
      else	  
         if [[ ! -e "./diag_${type}_ges.${PDATE}.${Z}" ]]; then
            satypes="${SATYPE// /$'\n'}"
            edited_satype=$(sed "/${type}/d" <<< "${satypes}")
            echo "REMOVED:  ${type} from SATYPE"
            export SATYPE="${edited_satype}"
         else	
            mv "./diag_${type}_ges.${PDATE}.${Z}" "${type}.${Z}"
            ${UNCOMPRESS} "./${type}.${Z}"
            mv "./diag_${type}_anl.${PDATE}.${Z}" "${type}_anl.${Z}"
            ${UNCOMPRESS} "./${type}_anl.${Z}"
         fi
      fi

   done

   #------------------------------------------------------------------
   #   Run the child scripts.
   #------------------------------------------------------------------
   echo "PDATE === ${PDATE}"
   echo "PDATE SATYPE === ${SATYPE}"
   "${USHradmon}/radmon_verf_angle.sh" "${PDATE}"
   rc_angle=$?

   "${USHradmon}/radmon_verf_bcoef.sh" "${PDATE}"
   rc_bcoef=$?

   "${USHradmon}/radmon_verf_bcor.sh" "${PDATE}"
   rc_bcor=$?

   "${USHradmon}/radmon_verf_time.sh" "${PDATE}"
   rc_time=$?

   #--------------------------------------
   #  optionally run clean_tankdir script
   #
   if [[ "${CLEAN_TANKVERF:-0}" -eq 1 ]]; then
      "${USHradmon}/clean_tankdir.sh" rgn 20 
      rc_clean_tankdir=$?
      echo "rc_clean_tankdir = ${rc_clean_tankdir}"
   fi

fi

#####################################################################
# Postprocessing

err=0
if [[ "${data_available}" -ne 1 ]]; then
   err=1
elif [[ "${rc_angle}" -ne 0 ]]; then
   err="${rc_angle}"
elif [[ "${rc_bcoef}" -ne 0 ]]; then
   err="${rc_bcoef}"
elif [[ "${rc_bcor}" -ne 0 ]]; then
   err="${rc_bcor}"
elif [[ "${rc_time}" -ne 0 ]]; then
   err="${rc_time}"
fi

echo "<--- exrrfs_verfrad.sh.ecf"
exit "${err}"