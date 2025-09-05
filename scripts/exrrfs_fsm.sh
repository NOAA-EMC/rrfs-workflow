#!/bin/bash
set -x
#-----------------------------------------------------------------------
# This is RRFS file server management job for ecflow workflow
# Scan and set ecflow trigger event for file level dependency
# Designed to be used on all cycles
# 
# Lin Gan
# EMC/EIB 
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Configure cycle dependency switch
#-----------------------------------------------------------------------

#case $WGF in
#  "det")
#    # Deterministic
#    echo "RRFS File Service Manager (FSM) is now proceed with Workflow Group Family (WGF) is Deterministic (det)"
#    RUN_WGF=rrfs
#    ;;
#  "enkf")
#    # Deterministic
#    echo "RRFS File Service Manager (FSM) is now proceed with Workflow Group Family (WGF) is ENKF (enkf)"
#    RUN_WGF=enkfrrfs
#    ;;
#  "ensf")
#    # Deterministic
#    echo "RRFS File Service Manager (FSM) is now proceed with Workflow Group Family (WGF) is ENKF Forecast (ensf)"
#    RUN_WGF=refs
#    ;;
#  "det")
#    # Deterministic
#    echo "RRFS File Service Manager (FSM) is now proceed with Workflow Group Family (WGF) is Fire Weather (firewx)"
#    RUN_WGF=firewx
#    ;;
#esac

. ${GLOBAL_VAR_DEFNS_FP}
RRFS_Current_PDY=${PDY}
RRFS_Current_cyc=${cyc}
cdate=${PDY}${cyc}
RRFS_previous_PDY=$(echo $($NDATE -1 ${cdate}) | cut -c1-8)
RRFS_previous_cyc=$(echo $($NDATE -1 ${cdate}) | cut -c9-10)
RRFS_next_1_PDY=$(echo $($NDATE +1 ${cdate}) | cut -c1-8)
RRFS_next_1_cyc=$(echo $($NDATE +1 ${cdate}) | cut -c9-10)
RRFS_next_2_PDY=$(echo $($NDATE +2 ${cdate}) | cut -c1-8)
RRFS_next_2_cyc=$(echo $($NDATE +2 ${cdate}) | cut -c9-10)
current_PDY_6hr_fmt=${PDY}
if [ $((10#$RRFS_Current_cyc)) -ge 0 ] && [ $((10#$RRFS_Current_cyc)) -le 5 ]; then
  current_cyc_6hr_fmt="00"
fi
if [ $((10#$RRFS_Current_cyc)) -ge 6 ] && [ $((10#$RRFS_Current_cyc)) -le 11 ]; then
  current_cyc_6hr_fmt="06"
fi
if [ $((10#$RRFS_Current_cyc)) -ge 12 ] && [ $((10#$RRFS_Current_cyc)) -le 17 ]; then
  current_cyc_6hr_fmt="12"
fi
if [ $((10#$RRFS_Current_cyc)) -ge 18 ] && [ $((10#$RRFS_Current_cyc)) -le 23 ]; then
  current_cyc_6hr_fmt="18"
fi
prior_PDY_6hr_fmt=${RRFS_previous_PDY}
if [ $((10#$RRFS_previous_cyc)) -ge 0 ] && [ $((10#$RRFS_previous_cyc)) -le 5 ]; then
  previous_cyc_6hr_fmt="00"
fi
if [ $((10#$RRFS_previous_cyc)) -ge 6 ] && [ $((10#$RRFS_previous_cyc)) -le 11 ]; then
  previous_cyc_6hr_fmt="06"
fi
if [ $((10#$RRFS_previous_cyc)) -ge 12 ] && [ $((10#$RRFS_previous_cyc)) -le 17 ]; then
  previous_cyc_6hr_fmt="12"
fi
if [ $((10#$RRFS_previous_cyc)) -ge 18 ] && [ $((10#$RRFS_previous_cyc)) -le 23 ]; then
  previous_cyc_6hr_fmt="18"
fi

# Time in second mark for scan_release_det_analysis_gsi
start_time_det_analysis_gsi=$(date +%s)

# Layout the default switches
scan_release_det_prep_cyc="YES"
scan_release_det_analysis_gsi="YES"
scan_release_enkf_prep_cyc="YES"
scan_release_det_make_ics="NO"
scan_release_det_make_lbcs="NO"
scan_release_save_restart_long="NO"
scan_release_save_restart_f1="NO"
scan_release_save_restart_f2="NO"
scan_release_save_restart_spinup_f001="NO"
scan_release_det_post_long="NO"
scan_release_det_post="NO"
scan_release_ensf_post="NO"
#scan_release_det_bufrsnd_long="NO"
scan_release_enkf_make_lbcs="NO"
scan_release_ensf_make_lbcs="NO"
scan_release_enkf_make_ics="NO"
#scan_release_ensf_recenter="NO"
#scan_release_enkf_save_restart_long="NO"
#scan_release_ensf_bufrsnd="NO"
scan_release_enkf_observer_gsi_ensmean="YES"
#scan_release_enkf_save_restart_spinup="NO"
scan_release_enkf_save_restart_ensinit="NO"

if [ ${cyc} == "00" ]; then
  scan_release_det_make_lbcs="YES"
  scan_release_enkf_make_lbcs="YES"
  #### Remove when ensf is ready #### scan_release_ensf_make_lbcs="YES"
  scan_release_ensf_make_lbcs="YES"
  scan_release_det_post_long="YES"
  scan_release_ensf_post="YES"
  scan_release_save_restart_long="YES"
fi

if [ ${cyc} == "01" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "02" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "03" ]; then
  scan_release_det_make_ics="YES"
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "04" ]; then
  scan_release_det_prep_cyc="NO"
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "05" ]; then
  scan_release_det_prep_cyc="NO"
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "06" ]; then
  scan_release_det_prep_cyc="NO"
  scan_release_det_make_lbcs="YES"
  scan_release_enkf_make_lbcs="YES"
  #### Remove when ensf is ready #### scan_release_ensf_make_lbcs="YES"
  scan_release_ensf_make_lbcs="YES"
  scan_release_det_post_long="YES"
  scan_release_ensf_post="YES"
  scan_release_save_restart_long="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "07" ]; then
  scan_release_det_prep_cyc="NO"
  scan_release_enkf_prep_cyc="NO"
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
  scan_release_enkf_make_ics="YES"
  #scan_release_enkf_observer_gsi_spinup_ensmean="YES"
  #scan_release_enkf_save_restart_spinup="YES"
  #scan_release_enkf_save_restart_ensinit="yes"
fi

if [ ${cyc} == "08" ]; then
  scan_release_det_prep_cyc="NO"
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "09" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "10" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "11" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "12" ]; then
  scan_release_det_prep_cyc="NO"
  scan_release_det_make_lbcs="YES"
  scan_release_enkf_make_lbcs="YES"
  #### Remove when ensf is ready #### scan_release_ensf_make_lbcs="YES"
  scan_release_ensf_make_lbcs="YES"
  scan_release_det_post_long="YES"
  scan_release_ensf_post="YES"
  scan_release_save_restart_long="YES"
  #scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "13" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "14" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "15" ]; then
  scan_release_det_make_ics="YES"
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "16" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "17" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "18" ]; then
  scan_release_det_prep_cyc="NO"
  scan_release_det_make_lbcs="YES"
  scan_release_enkf_make_lbcs="YES"
  #### Remove when ensf is ready #### scan_release_ensf_make_lbcs="YES"
  scan_release_ensf_make_lbcs="YES"
  scan_release_det_post_long="YES"
  scan_release_ensf_post="YES"
  scan_release_save_restart_long="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "19" ]; then
  scan_release_det_prep_cyc="NO"
  scan_release_enkf_prep_cyc="NO"
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
  scan_release_enkf_make_ics="YES"
  #scan_release_enkf_observer_gsi_spinup_ensmean="YES"
  #scan_release_enkf_save_restart_spinup="YES"
  #scan_release_enkf_save_restart_ensinit="yes"
fi

if [ ${cyc} == "20" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "21" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "22" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

if [ ${cyc} == "23" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
fi

# Initialize search array
#### declare -a array_element_scan_release_enkf_prep_cyc=( $(for i in {1..30}; do echo "NO"; done) )
for fhr in $(seq 1 30); do
  array_element_scan_release_enkf_prep_cyc[${fhr}]="NO"
done
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

for mem in $(seq 1 5); do
for fhr in $(seq 0 60); do
  fhr_3d=$( printf "%03d" ${fhr} )
  memuse=$( printf "%03d" ${mem} )
  search_str=${memuse}${fhr_3d}00
#      array_element_scan_release_ensf_post[${memuse}${fhr_3d}00]="NO"
      array_element_scan_release_ensf_post[$((10#$search_str))]="NO"
done
done

#-----------------------------------------------------------------------
# Save job running log files if it is run by developer
#-----------------------------------------------------------------------

#EMC_DEV=${EMC_DEV:-"NO"}
#if [ ${EMC_DEV} == "YES" ]; then
#  # Make a backup of the DATA for the next cycle of the previous day
## ONLY enable this option when there is no job running in current PDY ${RRFS_next_1_cyc}
##  cd ${DATAROOT}
##  backup_data=${PDYm1}${RRFS_next_1_cyc}_backup
##  mkdir ${backup_data}
##  mv rrfs_*_${RRFS_next_1_cyc}.????????.dbqs01 ./${backup_data}
##  mv rrfs_*_${RRFS_next_1_cyc}_${rrfs_ver} ./${backup_data}
#  # Make a backup for job log files
#  cd ${EMC_LOG_OUTPUT}  
#  backup_log=${PDYm1}${RRFS_next_1_cyc}
#  mkdir -p ${backup_log}
#  for file in rrfs_*_${RRFS_next_1_cyc}.o*; do
#    ct_ev=$(grep "PDY=${PDYm1}" ${file}| wc -l)
#    if [ ${ct_ev} -gt 0 ]; then
#      mv ${file} ${backup_log}
#    fi
#  done
#  cd $DATA
#fi

#-----------------------------------------------------------------------
# Process files and directories level dependency scan
#-----------------------------------------------------------------------

proceed_trigger_scan="YES"
while [ $proceed_trigger_scan == "YES" ]; do
  proceed_trigger_scan="NO"

  #### release_det_prep_cyc
  if [ ${scan_release_det_prep_cyc} == "YES" ]; then
    skip_this_scan="NO"
    echo "Proceeding with scan_release_det_prep_cyc"
    if [ -d ${COMrrfs}/rrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}/forecast/RESTART ]; then
      echo "Forecast RESTART directory found in regular cycle - looking for file"
      target_file_scan=${COMrrfs}/rrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}/forecast/RESTART/${PDY}.${cyc}0000.coupler.res
    elif [ -d ${COMrrfs}/rrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}_spinup/forecast/RESTART ]; then
      echo "Forecast RESTART directory found in spinup cycle - looking for file"
      target_file_scan=${COMrrfs}/rrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}_spinup/forecast/RESTART/${PDY}.${cyc}0000.coupler.res
    else
      skip_this_scan="YES"
    fi
    if [ ${skip_this_scan} == "NO" ] && [ -s ${target_file_scan} ]; then
      ecflow_client --event release_det_prep_cyc
      scan_release_det_prep_cyc="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_det_prep_cyc

  #### scan_release_det_make_ics
  if [ ${scan_release_det_make_ics} == "YES" ]; then
    echo "Proceeding with scan_release_det_make_ics"
    ops_gfs_inp_file=$(compath.py gfs/${gfs_ver})/gfs.${current_PDY_6hr_fmt}/${current_cyc_6hr_fmt}/atmos/gfs.t${current_cyc_6hr_fmt}z.logf003.txt
    if [ -s ${ops_gfs_inp_file} ]; then
      scan_release_det_make_ics="NO"
      ecflow_client --event release_det_make_ics
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### scan_release_det_make_ics

  #### scan_release_det_make_lbcs
  if [ ${scan_release_det_make_lbcs} == "YES" ]; then
    echo "Proceeding with scan_release_det_make_lbcs"
    ops_gfs_inp_file=$(compath.py gfs/${gfs_ver})/gfs.${RRFS_previous_PDY}/${previous_cyc_6hr_fmt}/atmos/gfs.t${previous_cyc_6hr_fmt}z.logf006.txt
    if [ -s ${ops_gfs_inp_file} ]; then
      scan_release_det_make_lbcs="NO"
      ecflow_client --event release_det_make_lbcs
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### scan_release_det_make_lbcs

  OBSPATH=${OBSPATH:-$(compath.py obsproc/${obsproc_ver})}
  obs_source=${OBSTYPE_SOURCE}
  #### release_det_analysis_gsi
  if [ ${scan_release_det_analysis_gsi} == "YES" ]; then
    echo "Proceeding with scan_release_det_analysis_gsi"
    source_file_found="NO"
    skip_this_scan="NO"
    # Example of target file: /lfs/h1/ops/prod/com/obsproc/v1.2/rap.20240610/rap.t00z.prepbufr.tm00
    obsproc_rrfs_inp_file=${OBSPATH}/${obs_source}.${RRFS_Current_PDY}/${obs_source}.t${RRFS_Current_cyc}z.prepbufr.tm00
    # /lfs/f2/t2o/ptmp/emc/ptmp/emc.lam/rrfs/v0.9.5/nwges/2024060923/mem0001~0030/fcst_fv3lam/RESTART/20240610.000000.coupler.res
    if [ -s ${obsproc_rrfs_inp_file} ]; then
      source_file_found="YES"
      echo "Proceeding with scan_release_det_analysis_gsi"      
      if [ -d ${COMrrfs}/enkfrrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}/m001/forecast/RESTART ]; then
        echo "Forecast RESTART directory found in regular cycle - looking for file"
        target_directory_scan=${COMrrfs}/enkfrrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}
      elif [ -d ${COMrrfs}/enkfrrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}_spinup/m001/forecast/RESTART ]; then
        echo "Forecast RESTART directory found in spinup cycle - looking for file"
        target_directory_scan=${COMrrfs}/enkfrrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}_spinup
      elif [ ! -d ${COMrrfs}/rrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}/forecast ]; then
        echo "Found the previous cycle running in spinup only mode - checking for spinup RESTART file"
        skip_this_scan="YES"
        source_file_found="YES"
      else
        skip_this_scan="YES"
        source_file_found="NO"
      fi
      #### Add time condition for check only 20 minutes - set to found if exist 20 minutes to use GFS enkf fcst data
      current_time_det_analysis_gsi=$(date +%s)
      elapsed_time=$((current_time_det_analysis_gsi - start_time_det_analysis_gsi))
      if ((elapsed_time > 1800)); then
        skip_this_scan="YES"
        source_file_found="YES"
        date
        echo "WARNING: GSI will be running in Degraded mode due to the enkf RESTART in previous cycle not found"
      fi
      if [ ${skip_this_scan} == "NO" ]; then
          for member_num in $(seq 1 30); do
            member_num_2d=$( printf "%02d" ${member_num} )
            target_file_scan=${target_directory_scan}/m0${member_num_2d}/forecast/RESTART/${RRFS_Current_PDY}.${RRFS_Current_cyc}0000.coupler.res
            if [ ! -s ${target_file_scan} ]; then
              source_file_found="NO"
              date
              echo "INFO the release_det_analysis_gsi does not find ${target_file_scan}"
              ls -lart ${target_directory_scan}/m0${member_num_2d}/forecast/RESTART
            fi
          done
      fi
    fi
    if [ ${source_file_found} == "YES" ]; then
      ecflow_client --event release_det_analysis_gsi
      scan_release_det_analysis_gsi="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_det_analysis_gsi

  #### release_enkf_make_lbcs
  if [ ${scan_release_enkf_make_lbcs} == "YES" ]; then
    echo "Proceeding with scan_release_enkf_make_lbcs"
    gefs_inp_dir=$(compath.py gefs/${gefs_ver})/gefs.${prior_PDY_6hr_fmt}/${previous_cyc_6hr_fmt}/atmos/pgrb2bp5
    file_count_tmp=$(ls ${gefs_inp_dir}/gep*.t${previous_cyc_6hr_fmt}z.pgrb2b.0p50.f006 ${gefs_inp_dir}/gep*.t${previous_cyc_6hr_fmt}z.pgrb2b.0p50.f009 ${gefs_inp_dir}/gep*.t${previous_cyc_6hr_fmt}z.pgrb2b.0p50.f012 ${gefs_inp_dir}/gep*.t${previous_cyc_6hr_fmt}z.pgrb2b.0p50.f015 ${gefs_inp_dir}/gep*.t${previous_cyc_6hr_fmt}z.pgrb2b.0p50.f018|wc -l)
    if [ ${file_count_tmp} -eq 150 ]; then
      ecflow_client --event release_enkf_make_lbcs
      scan_release_enkf_make_lbcs="NO"
    else
      echo "Production realtime gefs grib2 data only retain up to 4 days."
      proceed_trigger_scan="YES"
    fi
  fi 
  #### release_enkf_make_lbcs

  #### release_save_restart_long
  ## Process WGF is det
  if [ ${scan_release_save_restart_long} == "YES" ]; then
    echo "Proceeding with scan_release_save_restart_long for det"
    umbrella_forecast_data=${DATAROOT}/rrfs_forecast_${cyc}_${rrfs_ver}/det/RESTART
    restart_set_found=$(ls ${umbrella_forecast_data}/*coupler.res|wc -l)
    if [ ${restart_set_found} -ge 1 ]; then
      ecflow_client --event release_save_restart_long_1
    fi
    if [ ${restart_set_found} -ge 2 ]; then
      ecflow_client --event release_save_restart_long_2
    fi
    if [ ${restart_set_found} -ge 3 ]; then
      ecflow_client --event release_save_restart_long_12
    fi
    if [ ${restart_set_found} -ge 4 ]; then
      ecflow_client --event release_save_restart_long_24
    fi
    if [ ${restart_set_found} -ge 5 ]; then
      ecflow_client --event release_save_restart_long_36
    fi
    if [ ${restart_set_found} -ge 6 ]; then
      ecflow_client --event release_save_restart_long_48
      scan_release_save_restart_long="NO"
    else
      proceed_trigger_scan="YES"  
    fi
  fi
  #### release_save_restart_long

  #### release_save_restart_f1
  ## Process WGF is det
  if [ ${scan_release_save_restart_f1} == "YES" ]; then
    echo "Proceeding with scan_release_save_restart_f1 for det"
    umbrella_forecast_data=${DATAROOT}/rrfs_forecast_${cyc}_${rrfs_ver}/det/RESTART
    restart_set_found=$(ls ${umbrella_forecast_data}/${RRFS_next_1_PDY}.${RRFS_next_1_cyc}0000.coupler.res|wc -l)
    if [ ${restart_set_found} -ge 1 ]; then
      ecflow_client --event release_save_restart_f1
      scan_release_save_restart_f1="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_save_restart_f1

  #### release_save_restart_f2
  ## Process WGF is det
  if [ ${scan_release_save_restart_f2} == "YES" ]; then
    echo "Proceeding with scan_release_save_restart_f2 for det"
    umbrella_forecast_data=${DATAROOT}/rrfs_forecast_${cyc}_${rrfs_ver}/det/INPUT
    restart_set_found=$(ls ${umbrella_forecast_data}/gfs_ctrl.nc|wc -l)
    if [ ${restart_set_found} -ge 1 ]; then
      ecflow_client --event release_save_restart_f2
      scan_release_save_restart_f2="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_save_restart_f2

  #### release_save_restart_spinup_f001
  ## Process WGF is det
  if [ ${scan_release_save_restart_spinup_f001} == "YES" ]; then
    echo "Proceeding with scan_release_save_restart_spinup_f001 for det"
    umbrella_forecast_data=${DATAROOT}/rrfs_forecast_spinup_${cyc}_${rrfs_ver}/det/RESTART
    restart_set_found=$(ls ${umbrella_forecast_data}/${RRFS_next_1_PDY}.${RRFS_next_1_cyc}0000.coupler.res|wc -l)
    if [ ${restart_set_found} -ge 1 ]; then
      ecflow_client --event release_save_restart_spinup_f001
      scan_release_save_restart_spinup_f001="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_save_restart_spinup_f001

  #### release_det_post_long
  if [ ${scan_release_det_post_long} == "YES" ]; then
    echo "Proceeding with scan_release_det_post_long"
    source_file_found="YES"
    umbrella_forecast_data=${DATAROOT}/rrfs_forecast_${cyc}_${rrfs_ver}/det/output
    # fhr cover 000~084
    for fhr in $(seq 0 84); do
      fhr_2d=$( printf "%02d" ${fhr} )
      fhr_3d=$( printf "%03d" ${fhr} )
      # 000~017 have every 15 minutes
      if [ $(($fhr)) -le 17 ]; then
        for sub_fhr in 00 15 30 45; do
          fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}-${sub_fhr}-*| wc -l)
          if [ ${fc} -gt 0 ]; then
            if [ $fhr -eq 0 ] && [ $sub_fhr == "00" ]; then
              if [ ${array_element_scan_release_det_post_long[${fhr}0036]} == "NO" ]; then
                array_element_scan_release_det_post_long[${fhr}0036]="found"
                ecflow_client --event release_det_post_f000_00_36_long
              fi
            else
              if [ ${array_element_scan_release_det_post_long[${fhr}${sub_fhr}00]} == "NO" ]; then
                array_element_scan_release_det_post_long[${fhr}${sub_fhr}00]="found"
                ecflow_client --event release_det_post_f${fhr_3d}_${sub_fhr}_00_long
              fi
            fi
          else
            source_file_found="NO"
          fi
        done
      else
        fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}-*| wc -l)
        if [ ${fc} -gt 0 ]; then
          if [ ${array_element_scan_release_det_post_long[${fhr}0000]} == "NO" ]; then
            array_element_scan_release_det_post_long[${fhr}0000]="found"
            ecflow_client --event release_det_post_f${fhr_3d}_00_00_long
          fi
        else
          source_file_found="NO"
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

  #### release_ensf_post
  if [ ${scan_release_ensf_post} == "YES" ]; then
    echo "Proceeding with scan_release_ensf_post"
    source_file_found="YES"
    umbrella_forecast_data_base=${DATAROOT}/rrfs_forecast_${cyc}_${rrfs_ver}/ensf/
    # mems 1-5
    for mem in $(seq 1 5); do
      memuse=$( printf "%03d" ${mem} )
      umbrella_forecast_data=${umbrella_forecast_data_base}/m${memuse}/output/
    # fhr cover 000~060
      for fhr in $(seq 0 60); do
        fhr_3d=$( printf "%03d" ${fhr} )
        fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}*| wc -l)
        if [ ${fc} -gt 0 ]; then
          search_str=${memuse}${fhr_3d}00
          if [ ${array_element_scan_release_ensf_post[$((10#$search_str))]} == "NO" ]; then
            array_element_scan_release_ensf_post[$((10#$search_str))]="found"
            ecflow_client --event release_ensf_post_mem${memuse}_f${fhr_3d}
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

  #### release_det_post
  if [ ${scan_release_det_post} == "YES" ]; then
    echo "Proceeding with scan_release_det_post"
    source_file_found="YES"
    umbrella_forecast_data=${DATAROOT}/rrfs_forecast_${cyc}_${rrfs_ver}/det/output
    # fhr cover 000~018
    for fhr in $(seq 0 18); do
      fhr_2d=$( printf "%02d" ${fhr} )
      fhr_3d=$( printf "%03d" ${fhr} )
      # 000~017 have every 15 minutes
      if [ $(($fhr)) -le 17 ]; then
        for sub_fhr in 00 15 30 45; do
          fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}-${sub_fhr}-*| wc -l)
          if [ ${fc} -gt 0 ]; then
            if [ $fhr -eq 0 ] && [ $sub_fhr == "00" ]; then
              if [ ${array_element_scan_release_det_post[${fhr}0036]} == "NO" ]; then
                array_element_scan_release_det_post[${fhr}0036]="found"
                ecflow_client --event release_det_post_f000_00_36
              fi
            else
              if [ ${array_element_scan_release_det_post[${fhr}${sub_fhr}00]} == "NO" ]; then
                array_element_scan_release_det_post[${fhr}${sub_fhr}00]="found"
                ecflow_client --event release_det_post_f${fhr_3d}_${sub_fhr}_00
              fi
            fi
          else
            source_file_found="NO"
          fi
        done
      else
        fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}-*| wc -l)
        if [ ${fc} -gt 0 ]; then
          if [ ${array_element_scan_release_det_post[${fhr}0000]} == "NO" ]; then
            array_element_scan_release_det_post[${fhr}0000]="found"
            ecflow_client --event release_det_post_f${fhr_3d}_00_00
          fi
        else
          source_file_found="NO"
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

  #### release_ensf_make_lbcs
  if [ ${scan_release_ensf_make_lbcs} == "YES" ]; then
    echo "Proceeding with scan_release_ensf_make_lbcs"
    source_file_found="YES"
    # /lfs/h1/ops/prod/com/gefs/v12.3/gefs.20240609/18/atmos/pgrb2bp5/gep01.t18z.pgrb2b.0p50.f006
    gefs_pth=$(compath.py gefs/${gefs_ver})/gefs.${prior_PDY_6hr_fmt}/${previous_cyc_6hr_fmt}/atmos/pgrb2bp5
    for gp_num in $(seq 1 5); do
      for fhr in $(seq 6 3 66); do
        gp_num_2d=$( printf "%02d" ${gp_num} )
        fhr_3d=$( printf "%03d" ${fhr} )
        if [ ! -s ${gefs_pth}/gep${gp_num_2d}.t${previous_cyc_6hr_fmt}z.pgrb2b.0p50.f${fhr_3d} ]; then
          echo "INFO file not found: ${gefs_pth}/gep${gp_num_2d}.t${previous_cyc_6hr_fmt}z.pgrb2b.0p50.f${fhr_3d}"
          echo "Production realtime gefs grib2 data only retain upto 4 days."
          source_file_found="NO"
        fi
      done
    done
    if [ ${source_file_found} == "YES" ]; then
      ecflow_client --event release_ensf_make_lbcs
      scan_release_ensf_make_lbcs="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_ensf_make_lbcs

  #### release_enkf_prep_cyc
  if [ ${scan_release_enkf_prep_cyc} == "YES" ]; then
    echo "Proceeding with scan_release_enkf_prep_cyc"
    source_file_found="YES"
    for mem_num in $(seq 1 30); do
      mem_num_2d=$( printf "%02d" ${mem_num} )
      if [ ${cyc} == 08 ] || [ ${cyc} == 20 ]; then
        target_file_scan=${COMrrfs}/enkfrrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}_spinup/m0${mem_num_2d}/forecast/RESTART/${RRFS_Current_PDY}.${RRFS_Current_cyc}0000.coupler.res
      else
        target_file_scan=${COMrrfs}/enkfrrfs.${RRFS_previous_PDY}/${RRFS_previous_cyc}/m0${mem_num_2d}/forecast/RESTART/${RRFS_Current_PDY}.${RRFS_Current_cyc}0000.coupler.res
      fi
      if [ -s ${target_file_scan} ]; then
        if [ ! ${array_element_scan_release_enkf_prep_cyc[$mem_num]} == "found" ]; then
          array_element_scan_release_enkf_prep_cyc[$mem_num]="found"
          ecflow_client --event release_enkf_prep_cyc_mem0${mem_num_2d}
        fi
      else
        source_file_found="NO"
      fi
    done
    if [ ${source_file_found} == "YES" ]; then
      scan_release_enkf_prep_cyc="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_enkf_prep_cyc

  #### release_enkf_make_ics
  if [ ${scan_release_enkf_make_ics} == "YES" ]; then
    echo "Proceeding with scan_release_enkf_make_ics"
    source_file_found="YES"
    if [ ${cyc} == "07" ]; then
      enkfgdas_cyc=00
    else
      enkfgdas_cyc=12
    fi
    enkfgdas_pth=$(compath.py gfs/${gfs_ver})/enkfgdas.${RRFS_Current_PDY}/${enkfgdas_cyc}/atmos
    for mem_nu in $(seq 1 30); do
      mem_nu_3d=$( printf "%03d" ${mem_nu} )
      target_file_scan_atmf=${enkfgdas_pth}/mem${mem_nu_3d}/gdas.t${enkfgdas_cyc}z.atmf007.nc
      target_file_scan_sfcf=${enkfgdas_pth}/mem${mem_nu_3d}/gdas.t${enkfgdas_cyc}z.sfcf007.nc
      [[ ! -s ${target_file_scan_atmf} ]]&& source_file_found="NO"
      [[ ! -s ${target_file_scan_sfcf} ]]&& source_file_found="NO"
    done
    if [ ${source_file_found} == "YES" ]; then
      ecflow_client --event release_enkf_make_ics
      scan_release_enkf_make_ics="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_enkf_make_ics

  #### release_enkf_observer_gsi_ensmean
  if [ ${scan_release_enkf_observer_gsi_ensmean} == "YES" ]; then
    echo "Proceeding with scan_release_enkf_observer_gsi_ensmean"
    source_file_found="YES"
    if [ ${RRFS_Current_cyc} == 00 ] || [ ${RRFS_Current_cyc} == 12 ];then
      obsproc_rrfs_inp_file=${OBSPATH}/${obs_source}_e.${RRFS_Current_PDY}/${obs_source}_e.t${RRFS_Current_cyc}z.prepbufr.tm00
    else
      obsproc_rrfs_inp_file=${OBSPATH}/${obs_source}.${RRFS_Current_PDY}/${obs_source}.t${RRFS_Current_cyc}z.prepbufr.tm00
    fi
    [[ ! -s ${obsproc_rrfs_inp_file} ]]&& source_file_found="NO"
    if [ ${source_file_found} == "YES" ]; then
      ecflow_client --event release_enkf_observer_gsi_ensmean
      scan_release_enkf_observer_gsi_ensmean="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_enkf_observer_gsi_ensmean

  #### release_enkf_save_restart_spinup
#  if [ ${scan_release_enkf_save_restart_spinup} == "YES" ]; then
#    echo "Proceeding with scan_release_enkf_save_restart_spinup"
#    source_file_found="YES"
#    s_v=det
#    fg_restart_dirname=forecast_spinup
#    for mem_num in $(seq 1 30); do
#      mem_num_3d=$( printf "%03d" ${mem_num} )
#      umbrella_forecast_data=${DATAROOT}/${RUN}/enkf/${cdate}/m${mem_num_3d}/${fg_restart_dirname}/RESTART/${RRFS_next_1_PDY}.${RRFS_next_1_cyc}0000.coupler.res
#      if [ $(ls ${umbrella_forecast_data}|wc -l) -eq 1 ]; then
#        ecflow_client --event release_enkf_save_restart_spinup_mem${mem_num_3d}_f001
#      else
#        source_file_found="NO"
#      fi
#    done
#    if [ ${source_file_found} == "YES" ]; then
#      scan_release_enkf_save_restart_spinup="NO"
#    else
#      proceed_trigger_scan="YES"
#    fi
#  fi
  #### release_enkf_save_restart_spinup

  #### release_enkf_save_restart_ensinit
#  if [ ${scan_release_enkf_save_restart_ensinit} == "YES" ]; then
#    echo "Proceeding with scan_release_enkf_save_restart_ensinit"
#    source_file_found="YES"
#    s_v=det 
#    fg_restart_dirname=forecast_ensinit
#    for mem_num in $(seq 1 30); do
#      mem_num_3d=$( printf "%03d" ${mem_num} )
#      umbrella_forecast_data=${DATAROOT}/${RUN}/enkf/${cdate}/m${mem_num_3d}/${fg_restart_dirname}/RESTART/${RRFS_Current_PDY}.${RRFS_Current_cyc}0036.coupler.res
#      if [ $(ls ${umbrella_forecast_data}|wc -l) -eq 1 ]; then
#        ecflow_client --event release_enkf_save_restart_ensinit_mem${mem_num_3d}
#      else
#        source_file_found="NO"
#      fi
#    done
#    if [ ${source_file_found} == "YES" ]; then
#      scan_release_enkf_save_restart_ensinit="NO"
#    else
#      proceed_trigger_scan="YES"
#    fi
#  fi
#  #### release_enkf_save_restart_ensinit


  if [ $proceed_trigger_scan == "YES" ]; then
    sleep 15
  fi
done                 # proceed_trigger_scan

exit 0
