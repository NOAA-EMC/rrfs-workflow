#!/bin/bash
set -x

#-----------------------------------------------------------------------
# RRFS det and ensf post job manager
# 00 | 06 | 12 | 18:
#   det_post_long && ensf_post
# Other cycles:
#   det_post 
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Configure cycle dependency switch
#-----------------------------------------------------------------------

# scan switches
if [ ${WGF} == "det" ]; then
  scan_release_ensf_post="NO"
  if [[ "$cyc" =~ ^(00|06|12|18)$ ]]; then
    scan_release_det_post_long="YES" 
    scan_release_det_post="NO"

    for fhr in $(seq 0 84); do
      fhr_2d=$( printf "%02d" ${fhr} )
      fhr_3d=$( printf "%03d" ${fhr} )
      if [ $(($fhr)) -le 17 ]; then
        for sub_fhr in 00 15 30 45; do
          if [ ${fhr_2d} == "00" ] && [ ${sub_fhr} == "00" ]; then
            array_element_scan_release_det_post_long[${fhr}0036]="NO"
          else
            array_element_scan_release_det_post_long[${fhr}${sub_fhr}00]="NO"
          fi
        done
      else
        array_element_scan_release_det_post_long[${fhr}0000]="NO"
      fi
    done
  else
    scan_release_det_post_long="NO"
    scan_release_det_post="YES"

    for fhr in $(seq 0 18); do
      fhr_2d=$( printf "%02d" ${fhr} )
      fhr_3d=$( printf "%03d" ${fhr} )
      if [ $(($fhr)) -le 17 ]; then
        for sub_fhr in 00 15 30 45; do
          if [ ${fhr_2d} == "00" ] && [ ${sub_fhr} == "00" ]; then
            array_element_scan_release_det_post[${fhr}0036]="NO"
          else
            array_element_scan_release_det_post[${fhr}${sub_fhr}00]="NO"
          fi
        done
      else
        array_element_scan_release_det_post[${fhr}0000]="NO"
      fi
    done
  fi
elif [ ${WGF} == "ensf" ]; then
  scan_release_ensf_post="YES"
  scan_release_det_post_long="NO" 
  scan_release_det_post="NO"

  for mem in $(seq 1 5); do
    for fhr in $(seq 0 60); do
      fhr_3d=$( printf "%03d" ${fhr} )
      memuse=$( printf "%03d" ${mem} )
      search_str=${memuse}${fhr_3d}00
      array_element_scan_release_ensf_post[$((10#$search_str))]="NO"
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
  
  #### release_det_post_long
  if [ ${scan_release_det_post_long} == "YES" ]; then
    echo "Proceeding with scan_release_det_post_long"
    source_file_found="YES"
    umbrella_forecast_data=${umbrella_forecast_data_base}/output
    # fhr cover 000~084
    for fhr in $(seq 0 84); do
      fhr_2d=$( printf "%02d" ${fhr} )
      fhr_3d=$( printf "%03d" ${fhr} )

      # 000~017 have every 15 minutes
      if [ $(($fhr)) -le 17 ]; then
        for sub_fhr in 00 15 30 45; do
          # check for f000-00-36
          if [ $fhr -eq 0 ] && [ $sub_fhr == "00" ] && \
             [ ${array_element_scan_release_det_post_long[${fhr}0036]} == "NO" ]; then
            if [ -s "${umbrella_forecast_data}/log.atm.f${fhr_3d}-${sub_fhr}-36" ]; then
              array_element_scan_release_det_post_long[${fhr}0036]="found"
              ecflow_client --event release_det_post_f${fhr_3d}_00_36_long
              ic=1
            else
              source_file_found="NO"
            fi
            continue
          else # from f000-15-00 to f017-45-00
            if [ ${array_element_scan_release_det_post_long[${fhr}${sub_fhr}00]} == "NO" ]; then
              if [ -s "${umbrella_forecast_data}/log.atm.f${fhr_3d}-${sub_fhr}-00" ]; then
                array_element_scan_release_det_post_long[${fhr}${sub_fhr}00]="found"
                ecflow_client --event release_det_post_f${fhr_3d}_${sub_fhr}_00_long
                ic=1
                continue
              else
                source_file_found="NO"
              fi
            fi
          fi
        done
      else # f018-00-00 and beyong. Starting from f018, no sub hour data.
        if [ ${array_element_scan_release_det_post_long[${fhr}0000]} == "NO" ]; then
          if [ -s "${umbrella_forecast_data}/log.atm.f${fhr_3d}-00-00" ]; then
            array_element_scan_release_det_post_long[${fhr}0000]="found"
            ecflow_client --event release_det_post_f${fhr_3d}_00_00_long
            ic=1
            continue
          else
            source_file_found="NO"
          fi
        fi
      fi
    done
    if [ ${source_file_found} == "YES" ]; then
      scan_release_det_post_long="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_det_post_long

  #### release_det_post
  if [ ${scan_release_det_post} == "YES" ]; then
    echo "Proceeding with scan_release_det_post"
    source_file_found="YES"
    umbrella_forecast_data=${umbrella_forecast_data_base}/output
    # fhr cover 000~018
    for fhr in $(seq 0 18); do
      fhr_2d=$( printf "%02d" ${fhr} )
      fhr_3d=$( printf "%03d" ${fhr} )

      # 000~017 have every 15 minutes
      if [ $(($fhr)) -le 17 ]; then
        for sub_fhr in 00 15 30 45; do
          # check for f000-00-36
          if [ $fhr -eq 0 ] && [ $sub_fhr == "00" ] && \
             [ ${array_element_scan_release_det_post[${fhr}0036]} == "NO" ]; then
            if [ -s "${umbrella_forecast_data}/log.atm.f${fhr_3d}-${sub_fhr}-36" ]; then
              array_element_scan_release_det_post[${fhr}0036]="found"
              ecflow_client --event release_det_post_f${fhr_3d}_00_36
              ic=1
            else
              source_file_found="NO"
            fi
            continue
          else # from f000-15-00 to f017-45-00
            if [ ${array_element_scan_release_det_post[${fhr}${sub_fhr}00]} == "NO" ]; then
              if [ -s "${umbrella_forecast_data}/log.atm.f${fhr_3d}-${sub_fhr}-00" ]; then
                array_element_scan_release_det_post[${fhr}${sub_fhr}00]="found"
                ecflow_client --event release_det_post_f${fhr_3d}_${sub_fhr}_00
                ic=1
                continue
              else
                source_file_found="NO"
              fi
            fi
          fi
        done
      else # f018-00-00
        if [ ${array_element_scan_release_det_post[${fhr}0000]} == "NO" ]; then
          if [ -s "${umbrella_forecast_data}/log.atm.f${fhr_3d}-00-00" ]; then
            array_element_scan_release_det_post[${fhr}0000]="found"
            ecflow_client --event release_det_post_f${fhr_3d}_00_00
            ic=1
            continue
          else
            source_file_found="NO"
          fi
        fi
      fi
    done
    if [ ${source_file_found} == "YES" ]; then
      scan_release_det_post="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_det_post

  #### release_ensf_post
  if [ ${scan_release_ensf_post} == "YES" ]; then
    echo "Proceeding with scan_release_ensf_post"
    source_file_found="YES"
    # mems 1-5
    for mem in $(seq 1 5); do
      memuse=$( printf "%03d" ${mem} )
      umbrella_forecast_data=${umbrella_forecast_data_base}/m${memuse}/output/
    # fhr cover 000~060
      for fhr in $(seq 0 60); do
        fhr_3d=$( printf "%03d" ${fhr} )
        if [ -s "${umbrella_forecast_data}/log.atm.f${fhr_3d}" ]; then
          search_str=${memuse}${fhr_3d}00
          if [ ${array_element_scan_release_ensf_post[$((10#$search_str))]} == "NO" ]; then
            array_element_scan_release_ensf_post[$((10#$search_str))]="found"
            ecflow_client --event release_ensf_post_mem${memuse}_f${fhr_3d}
            it=1
            continue
          fi
        else
          source_file_found="NO"
        fi
      done
    done
    if [ ${source_file_found} == "YES" ]; then
      scan_release_ensf_post="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_ensf_post

  #### sleep and wait
  # The counter, ic, is reset when a new log file arrives.
  if [ $ic -eq $SLEEP_LOOP_MAX ]; then
    echo " *** FATAL ERROR: ${cyc}z ${WGF} forecast output files not available after ${SLEEP_TIME} seconds."
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
