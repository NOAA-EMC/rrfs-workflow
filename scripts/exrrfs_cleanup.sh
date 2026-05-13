#!/bin/bash

set -x

#####################################################
# pre cycle cleanup
#####################################################
if [ "${CLEAN_MODE}" == "pre" ]; then
  echo "Performing pre-cycle cleanup to rename any existing shared workding dir for cyc $cyc."
  for old_dir in ${DATAROOT}/rrfs_*_${cyc}_${rrfs_ver_2d}_${envir}; do
    if [ -d "$old_dir" ]; then
      mv ${old_dir} ${old_dir}_$$
    fi
  done
  echo "Pre-cycle cleanup complated."
fi

#####################################################
# post cycle cleanup
#####################################################

if [ "${CLEAN_MODE}" == "post" ]; then
  echo "Performing post-cycle cleanup for cyc $cyc."

  # cleanup shared working directory
  if [ "${KEEP_TMP^^}" != YES ]; then
    echo "Cleaning up shared workding directories for cyc $cyc ."
    if ls ${DATAROOT}/rrfs_*_${cyc}_${rrfs_ver_2d}_${envir} >/dev/null 2>&1; then
      rm -rf ${DATAROOT}/rrfs_*_${cyc}_${rrfs_ver_2d}_${envir}
    fi
  else
    echo "\$KEEP_TMP is set to YES. Skipping tmp cleanup."
  fi

  # cleanup restart files for the current cycle
  if [ "${KEEP_RESTART^^}" != YES ]; then
    # remove RESTART files for the current cycle only
    # 1h restart from CYCm1
    # 2h restart from CYCm2
    # 3h restart from CYCm3
    Restart_1h=$($NDATE -01 $PDY$cyc)
    Restart_2h=$($NDATE -02 $PDY$cyc)
    Restart_3h=$($NDATE -03 $PDY$cyc)

    # rrfs
    if [ "${KEEP_DET_RESTART^^}" != YES ]; then
      echo "Cleaning up det RESTART files for cyc $cyc ."

      # for Restart_cyc in $Restart_1h $Restart_2h $Restart_3h; do
      # 20260508 - Keep 1h restart files

      for Restart_cyc in $Restart_2h $Restart_3h; do
        date_to_remove=${Restart_cyc:0:8}
        cyc_to_remove=${Restart_cyc:8:2}
        com_to_remove=${COMIN}/rrfs.${date_to_remove}/${cyc_to_remove}/forecast/RESTART
        if ls ${com_to_remove}/${PDY}.${cyc}0000.* >/dev/null 2>&1; then
           rm ${com_to_remove}/${PDY}.${cyc}0000.*
        fi
      done
    fi
  
    # enkf
    if [ "${KEEP_ENKF_RESTART^^}" != YES ]; then
      echo "Cleaning up enkf RESTART files for cyc $cyc ."

      # for Restart_cyc in $Restart_1h $Restart_2h $Restart_3h; do
      # 20260508 - Keep 1h restart files

      for Restart_cyc in $Restart_2h $Restart_3h; do
        date_to_remove=${Restart_cyc:0:8}
        cyc_to_remove=${Restart_cyc:8:2}
        for imem in {01..30}; do
          com_to_remove=${COMIN}/enkfrrfs.${date_to_remove}/${cyc_to_remove}/m0${imem}/forecast/RESTART
          if ls ${com_to_remove}/${PDY}.${cyc}0000.* >/dev/null 2>&1; then
             rm ${com_to_remove}/${PDY}.${cyc}0000.*
          fi
        done
      done
    fi
  else
    echo "\$KEEP_RESTART is set to YES. Skipping RESTART cleanup."
  fi

  echo "Post-cycle cleanup completed."
fi

