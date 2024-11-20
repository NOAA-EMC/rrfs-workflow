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
#scan_release_det_bufrsnd_long="NO"
scan_release_enkf_make_lbcs="NO"
scan_release_ensf_make_lbcs="NO"
scan_release_enkf_make_ics="NO"
#scan_release_ensf_recenter="NO"
#scan_release_enkf_save_restart_long="NO"
#scan_release_ensf_bufrsnd="NO"
scan_release_enkf_observer_gsi_spinup_ensmean="NO"
scan_release_enkf_save_restart_spinup="NO"
scan_release_enkf_save_restart_ensinit="NO"

if [ ${cyc} == "00" ]; then
  scan_release_det_make_lbcs="YES"
  scan_release_enkf_make_lbcs="YES"
  scan_release_ensf_make_lbcs="YES"
  scan_release_det_post_long="YES"
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
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "05" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "06" ]; then
  scan_release_det_make_lbcs="YES"
  scan_release_enkf_make_lbcs="YES"
  scan_release_ensf_make_lbcs="YES"
  scan_release_det_post_long="YES"
  scan_release_save_restart_long="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "07" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
  scan_release_enkf_make_ics="YES"
  scan_release_enkf_observer_gsi_spinup_ensmean="YES"
  scan_release_enkf_save_restart_spinup="YES"
  scan_release_enkf_save_restart_ensinit="yes"
fi

if [ ${cyc} == "08" ]; then
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
  scan_release_det_make_lbcs="YES"
  scan_release_enkf_make_lbcs="YES"
  scan_release_ensf_make_lbcs="YES"
  scan_release_det_post_long="YES"
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
  scan_release_det_make_lbcs="YES"
  scan_release_enkf_make_lbcs="YES"
  scan_release_ensf_make_lbcs="YES"
  scan_release_det_post_long="YES"
  scan_release_save_restart_long="YES"
  scan_release_save_restart_spinup_f001="YES"
fi

if [ ${cyc} == "19" ]; then
  scan_release_det_post="YES"
  scan_release_save_restart_f1="YES"
  scan_release_save_restart_f2="YES"
  scan_release_save_restart_spinup_f001="YES"
  scan_release_enkf_make_ics="YES"
  scan_release_enkf_observer_gsi_spinup_ensmean="YES"
  scan_release_enkf_save_restart_spinup="YES"
  scan_release_enkf_save_restart_ensinit="yes"
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

#-----------------------------------------------------------------------
# Process files and directories level dependency scan
#-----------------------------------------------------------------------

proceed_trigger_scan="YES"
while [ $proceed_trigger_scan == "YES" ]; do
  proceed_trigger_scan="NO"
  #### release_det_prep_cyc
  if [ ${scan_release_det_prep_cyc} == "YES" ]; then
    echo "Proceeding with scan_release_det_prep_cyc"
    # fg_restart_dirname=fcst_fv3lam
    # YYYYMMDDHHmInterv=$($NDATE -1 ${PDY}${cyc})
    # YYYYMMDDHHmInterv=${RRFS_previous_PDY}${RRFS_previous_cyc}
    if [ -d ${GESROOT}/${RUN}.${RRFS_previous_PDY}/${RRFS_previous_cyc}/forecast ]; then
      fg_restart_dirname=forecast
    else
      fg_restart_dirname=forecast_spinup
    fi
    target_file_scan=${GESROOT}/${RUN}.${RRFS_previous_PDY}/${RRFS_previous_cyc}/${fg_restart_dirname}/RESTART/${PDY}.${cyc}0000.coupler.res
    if [ -s ${target_file_scan} ]; then
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
    source_file_found="NO"
    ops_gfs_inp_file=$(compath.py gfs/${gfs_ver})/gfs.${current_PDY_6hr_fmt}/${current_cyc_6hr_fmt}/atmos/gfs.t${current_cyc_6hr_fmt}z.logf003.txt
    if [ -s ${ops_gfs_inp_file} ]; then
      source_file_found="YES"
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
    source_file_found="NO"
    ops_gfs_inp_file=$(compath.py gfs/${gfs_ver})/gfs.${RRFS_previous_PDY}/${previous_cyc_6hr_fmt}/atmos/gfs.t${previous_cyc_6hr_fmt}z.logf006.txt
    if [ -s ${ops_gfs_inp_file} ]; then
      source_file_found="YES"
      scan_release_det_make_lbcs="NO"
      ecflow_client --event release_det_make_lbcs
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### scan_release_det_make_lbcs
  #### release_det_analysis_gsi
  if [ ${scan_release_det_analysis_gsi} == "YES" ]; then
    echo "Proceeding with scan_release_det_analysis_gsi"
    source_file_found="NO"
    # /lfs/h1/ops/prod/com/obsproc/v1.2/rap.20240610/rap.t00z.prepbufr.tm00
    obsproc_rap_inp_file=$(compath.py obsproc/${obsproc_ver})/rap.${current_PDY_6hr_fmt}/rap.t${current_cyc_6hr_fmt}z.prepbufr.tm00
    # /lfs/f2/t2o/ptmp/emc/ptmp/emc.lam/rrfs/v0.9.5/nwges/2024060923/mem0001~0030/fcst_fv3lam/RESTART/20240610.000000.coupler.res
    if [ -s ${obsproc_rap_inp_file} ]; then
      source_file_found="YES"
      # fg_restart_dirname=forecast
      if [ -d ${GESROOT}/${RUN}.${RRFS_previous_PDY}/${RRFS_previous_cyc}/m001/forecast ]; then
        fg_restart_dirname=forecast
      else
        fg_restart_dirname=forecast_spinup
      fi
      #YYYYMMDDHHmInterv=$($NDATE -1 ${PDY}${cyc})
      #Interv_PDY=$(echo $YYYYMMDDHHmInterv | cut -c1-8)
      #Interv_cyc=$(echo $YYYYMMDDHHmInterv | cut -c9-10)
      # NWGES_BASEDIR/${YYYYMMDDHHmInterv}
      for member_num in $(seq 1 30); do
        member_num_2d=$( printf "%02d" ${member_num} )
        target_file_scan=${GESROOT}/${RUN}.${RRFS_previous_PDY}/${RRFS_previous_cyc}/m0${member_num_2d}/${fg_restart_dirname}/RESTART/${RRFS_Current_PDY}.${RRFS_Current_cyc}0000.coupler.res
        [[ ! -s ${target_file_scan} ]]&& source_file_found="NO"
      done
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
  if [ ${scan_release_save_restart_long} == "YES" ]; then
    echo "Proceeding with scan_release_save_restart_long"
    # /lfs/h2/emc/stmp/lin.gan/rrfs/ecflow_rrfs/rrfs/v1.0/2024061000/fcst_fv3lam/log.atm.f029*
    # s_v=$(echo $rrfs_ver|cut -c1-4)
    s_v=det
    fg_restart_dirname=forecast
    umbrella_forecast_data=${DATAROOT}/${RUN}/${s_v}/${cdate}/${fg_restart_dirname}
    source_file_found="YES"
    if [ $(ls ${umbrella_forecast_data}/log.atm.f001-*|wc -l) -eq 4 ]; then
      ecflow_client --event release_save_restart_long_1
    else
      source_file_found="NO"
    fi
    if [ $(ls ${umbrella_forecast_data}/log.atm.f002-*|wc -l) -eq 4 ]; then
      ecflow_client --event release_save_restart_long_2
    else
      source_file_found="NO"
    fi
    if [ $(ls ${umbrella_forecast_data}/log.atm.f012-*|wc -l) -eq 4 ]; then
      ecflow_client --event release_save_restart_long_12
    else
      source_file_found="NO"
    fi
    if [ $(ls ${umbrella_forecast_data}/log.atm.f024-*|wc -l) -eq 1 ]; then
      ecflow_client --event release_save_restart_long_24
    else
      source_file_found="NO"
    fi
    if [ $(ls ${umbrella_forecast_data}/log.atm.f036-*|wc -l) -eq 1 ]; then
      ecflow_client --event release_save_restart_long_36
    else
      source_file_found="NO"
    fi
    if [ $(ls ${umbrella_forecast_data}/log.atm.f048-*|wc -l) -eq 1 ]; then
      ecflow_client --event release_save_restart_long_48
    else
      source_file_found="NO"
    fi
    if [ ${source_file_found} == "YES" ]; then 
      scan_release_save_restart_long="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_save_restart_long
  #### release_save_restart_f1
  if [ ${scan_release_save_restart_f1} == "YES" ]; then
    echo "Proceeding with scan_release_save_restart_f1"
    # /lfs/h2/emc/stmp/lin.gan/rrfs/ecflow_rrfs/rrfs/v1.0/2024061000/fcst_fv3lam/log.atm.f029*
    # s_v=$(echo $rrfs_ver|cut -c1-4)
    s_v=det
    fg_restart_dirname=forecast
    umbrella_forecast_data=${DATAROOT}/${RUN}/det/${cdate}/${fg_restart_dirname}
    source_file_found="YES"
    # if [ $(ls ${umbrella_forecast_data}/log.atm.f001-*|wc -l) -eq 4 ]; then
    # RRFS_next_PDY
    if [ $(ls ${umbrella_forecast_data}/RESTART/${RRFS_next_1_PDY}.${RRFS_next_1_cyc}0000.coupler.res|wc -l) -eq 1 ]; then
      ecflow_client --event release_save_restart_f1
    else
      source_file_found="NO"
    fi
    if [ ${source_file_found} == "YES" ]; then
      scan_release_save_restart_f1="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_save_restart_f1
  #### release_save_restart_f2
  if [ ${scan_release_save_restart_f2} == "YES" ]; then
    echo "Proceeding with scan_release_save_restart_f2"
    # /lfs/h2/emc/stmp/lin.gan/rrfs/ecflow_rrfs/rrfs/v1.0/2024061000/fcst_fv3lam/log.atm.f029*
    # s_v=$(echo $rrfs_ver|cut -c1-4)
    s_v=det
    fg_restart_dirname=forecast
    umbrella_forecast_data=${DATAROOT}/${RUN}/det/${cdate}/${fg_restart_dirname}
    source_file_found="YES"
    # if [ $(ls ${umbrella_forecast_data}/log.atm.f001-*|wc -l) -eq 4 ]; then
    if [ $(ls ${umbrella_forecast_data}/RESTART/${RRFS_next_2_PDY}.${RRFS_next_2_cyc}0000.coupler.res|wc -l) -eq 1 ]; then
      ecflow_client --event release_save_restart_f2
    else
      source_file_found="NO"
    fi
    if [ ${source_file_found} == "YES" ]; then
      scan_release_save_restart_f2="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_save_restart_f2
  #### release_save_restart_spinup_f001
  if [ ${scan_release_save_restart_spinup_f001} == "YES" ]; then
    echo "Proceeding with scan_release_save_restart_spinup_f001"
    fg_restart_dirname=forecast_spinup
    umbrella_forecast_data=${DATAROOT}/${RUN}/det/${cdate}/${fg_restart_dirname}
    source_file_found="YES"
    target_file_scan=${umbrella_forecast_data}/RESTART/${RRFS_next_1_PDY}.${RRFS_next_1_cyc}0000.coupler.res
    if [ $(ls ${target_file_scan}|wc -l) -eq 1 ]; then
      ecflow_client --event release_save_restart_spinup_f001
      scan_release_save_restart_spinup_f001="NO"
    else
      source_file_found="NO"
      proceed_trigger_scan="YES"
    fi
    if [ ${source_file_found} == "YES" ]; then
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
    # s_v=$(echo $rrfs_ver|cut -c1-4)
    s_v=det
    fg_restart_dirname=forecast
    umbrella_forecast_data=${DATAROOT}/${RUN}/${s_v}/${cdate}/${fg_restart_dirname}
    # fhr cover 000~060
    for fhr in $(seq 0 60); do
      fhr_2d=$( printf "%02d" ${fhr} )
      fhr_3d=$( printf "%03d" ${fhr} )
      # 000~017 have every 15 minutes
      if [ $(($fhr)) -le 17 ]; then
        for sub_fhr in 00 15 30 45; do
          fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}-${sub_fhr}-*| wc -l)
          if [ ${fc} -gt 0 ]; then
            if [ $fhr -eq 0 ] && [ $sub_fhr -eq 0 ]; then
              ecflow_client --event release_det_post_f000_00_36_long
            else
              ecflow_client --event release_det_post_f${fhr_3d}_${sub_fhr}_00_long
            fi
          else
            source_file_found="NO"
          fi
        done
      else
        fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}-*| wc -l)
        if [ ${fc} -gt 0 ]; then
          ecflow_client --event release_det_post_f${fhr_3d}_00_00_long
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
  #### release_det_post
  if [ ${scan_release_det_post} == "YES" ]; then
    echo "Proceeding with scan_release_det_post"
    source_file_found="YES"
    # s_v=$(echo $rrfs_ver|cut -c1-4)
    s_v=det
    fg_restart_dirname=forecast
    umbrella_forecast_data=${DATAROOT}/${RUN}/det/${cdate}/${fg_restart_dirname}
    # fhr cover 000~018
    for fhr in $(seq 0 18); do
      fhr_2d=$( printf "%02d" ${fhr} )
      fhr_3d=$( printf "%03d" ${fhr} )
      # 000~017 have every 15 minutes
      if [ $(($fhr)) -le 17 ]; then
        for sub_fhr in 00 15 30 45; do
          fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}-${sub_fhr}-*| wc -l)
          if [ ${fc} -gt 0 ]; then
            if [ $fhr -eq 0 ] && [ $sub_fhr -eq 0 ]; then
              ecflow_client --event release_det_post_f000_00_36
            else
              ecflow_client --event release_det_post_f${fhr_3d}_${sub_fhr}_00
            fi
          else
            source_file_found="NO"
          fi
        done
      else
        fc=$(ls ${umbrella_forecast_data}/log.atm.f${fhr_3d}-*| wc -l)
        if [ ${fc} -gt 0 ]; then
          ecflow_client --event release_det_post_f${fhr_3d}_00_00
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
    if [ -d ${GESROOT}/${RUN}.${RRFS_previous_PDY}/${RRFS_previous_cyc}/m001/forecast ]; then
      fg_restart_dirname=forecast
    else
      fg_restart_dirname=forecast_spinup
    fi
    for mem_num in $(seq 1 30); do
      mem_num_2d=$( printf "%02d" ${mem_num} )
      target_file_scan=${GESROOT}/${RUN}.${RRFS_previous_PDY}/${RRFS_previous_cyc}/m0${mem_num_2d}/${fg_restart_dirname}/RESTART/${RRFS_Current_PDY}.${RRFS_Current_cyc}0000.coupler.res
      if [ -s ${target_file_scan} ]; then
        ecflow_client --event release_enkf_prep_cyc_mem0${mem_num_2d}
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
    if [ ${cyc} = "07" ]; then
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
  #### release_enkf_observer_gsi_spinup_ensmean
  if [ ${scan_release_enkf_observer_gsi_spinup_ensmean} == "YES" ]; then
    echo "Proceeding with scan_release_enkf_observer_gsi_spinup_ensmean"
    source_file_found="YES"
    obsproc_rap_inp_file=$(compath.py obsproc/${obsproc_ver})/rap.${current_PDY_6hr_fmt}/rap.t${current_cyc_6hr_fmt}z.prepbufr.tm00
    [[ ! -s ${obsproc_rap_inp_file} ]]&& source_file_found="NO"
    if [ ${source_file_found} == "YES" ]; then
      ecflow_client --event release_enkf_observer_gsi_spinup_ensmean
      scan_release_enkf_observer_gsi_spinup_ensmean="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_enkf_observer_gsi_spinup_ensmean
  #### release_enkf_save_restart_spinup
  if [ ${scan_release_enkf_save_restart_spinup} == "YES" ]; then
    echo "Proceeding with scan_release_enkf_save_restart_spinup"
    source_file_found="YES"
    s_v=det
    fg_restart_dirname=forecast_spinup
    for mem_num in $(seq 1 30); do
      mem_num_3d=$( printf "%03d" ${mem_num} )
      umbrella_forecast_data=${DATAROOT}/${RUN}/enkf/${cdate}/m${mem_num_3d}/${fg_restart_dirname}/RESTART/${RRFS_next_1_PDY}.${RRFS_next_1_cyc}0000.coupler.res
      if [ $(ls ${umbrella_forecast_data}|wc -l) -eq 1 ]; then
        ecflow_client --event release_enkf_save_restart_spinup_mem${mem_num_3d}_f001
      else
        source_file_found="NO"
      fi
    done
    if [ ${source_file_found} == "YES" ]; then
      scan_release_enkf_save_restart_spinup="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_enkf_save_restart_spinup
  #### release_enkf_save_restart_ensinit
  if [ ${scan_release_enkf_save_restart_ensinit} == "YES" ]; then
    echo "Proceeding with scan_release_enkf_save_restart_ensinit"
    source_file_found="YES"
    s_v=det 
    fg_restart_dirname=forecast_ensinit
    for mem_num in $(seq 1 30); do
      mem_num_3d=$( printf "%03d" ${mem_num} )
      umbrella_forecast_data=${DATAROOT}/${RUN}/enkf/${cdate}/m${mem_num_3d}/${fg_restart_dirname}/RESTART/${RRFS_Current_PDY}.${RRFS_Current_cyc}0036.coupler.res
      if [ $(ls ${umbrella_forecast_data}|wc -l) -eq 1 ]; then
        ecflow_client --event release_enkf_save_restart_ensinit_mem${mem_num_3d}
      else
        source_file_found="NO"
      fi
    done
    if [ ${source_file_found} == "YES" ]; then
      scan_release_enkf_save_restart_ensinit="NO"
    else
      proceed_trigger_scan="YES"
    fi
  fi
  #### release_enkf_save_restart_ensinit


  [[ $proceed_trigger_scan == "YES" ]]&& sleep 6

done                 # proceed_trigger_scan

exit 0
