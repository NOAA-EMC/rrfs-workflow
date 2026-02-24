#!/bin/bash
set -x

#-----------------------------------------------------------------------
# RRFS enkf save_restart job manager
# Even cycles only.
#-----------------------------------------------------------------------

####################################
# Specify Timeout Behavior of Post
#
# SLEEP_TIME - Amount of time to wait for
#              any new file before exiting
# SLEEP_INT  - Amount of time to wait between
#              checking for files
####################################
export SLEEP_TIME=2500
export SLEEP_INT=15


#-----------------------------------------------------------------------
# Configure cycle dependency switch
#-----------------------------------------------------------------------

# scan switches
if [ ${WGF} == "enkf" ]; then
  scan_release_enkf_save_restart="YES"

  for mem in $(seq 1 30); do
    for fhr in $(seq 1 3); do
      mem_3d=$( printf "%03d" ${mem} )
      search_str=${mem_3d}${fhr}
      array_element_scan_release_enkf_save_restart[$((10#$search_str))]="NO"
    done
  done
else
  err_exit "FATAL ERROR: WGF is not set."
fi

SLEEP_LOOP_MAX=`expr $SLEEP_TIME / $SLEEP_INT`
#-----------------------------------------------------------------------
# Process files and directories level dependency scan
#-----------------------------------------------------------------------

proceed_trigger_scan="YES"
ic=1
while [ $proceed_trigger_scan == "YES" ]; do
  proceed_trigger_scan="NO"
  
  #### release_enkf_save_restart
  if [ ${scan_release_enkf_save_restart} == "YES" ]; then
    echo "Proceeding with scan_release_enkf_save_restart"
    source_file_found="YES"
    umbrella_forecast_data=${umbrella_forecast_data_base}
    for mem in $(seq 1 30); do
      mem_3d=$( printf "%03d" ${mem} )
      umbrella_forecast_data=${umbrella_forecast_data_base}/m${mem_3d}/RESTART
      for fhr in $(seq 1 3); do
        Restart_cyc=$($NDATE +${fhr} $PDY$cyc)
        date_to_check=${Restart_cyc:0:8}
        cyc_to_check=${Restart_cyc:8:2}
        search_str=${mem_3d}${fhr}
        if [ ${array_element_scan_release_enkf_save_restart[$((10#$search_str))]} == "NO" ]; then

          if [ -s "${umbrella_forecast_data}/${date_to_check}.${cyc_to_check}0000.coupler.res" ]; then
            array_element_scan_release_enkf_save_restart[$((10#$search_str))]="found"
            ecflow_client --event release_enkf_save_restart_mem${mem_3d}_f${fhr}
            ic=1
            continue
          else
            source_file_found="NO"
          fi
        fi
      done
    done
    if [ ${source_file_found} == "YES" ]; then
      scan_release_enkf_save_restart="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_enkf_save_restart

  #### sleep and wait
  # The counter, ic, is reset when a new log file arrives.
  if [ $ic -eq $SLEEP_LOOP_MAX ]; then
    echo " *** FATAL ERROR: ${cyc}z ${WGF} forecast RESTART files not available after ${SLEEP_TIME} seconds."
    echo " *** Check ${umbrella_forecast_data}"
      export err=9
      err_chk
  fi 

  if [ $proceed_trigger_scan == "YES" ]; then
    ic=`expr $ic + 1`
    sleep $SLEEP_INT
  fi
done                 # proceed_trigger_scan

exit 0
