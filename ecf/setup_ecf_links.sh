#!/bin/bash
set -eux
module load prod_util

# Assume resource is using NCO production configuration
resource_config="EMC"
ECF_DIR=$(pwd)

# Function that loops over forecast hours and
# creates link between the master and target
function link_master_to_fhr(){
  tmpl=$1  # Name of the master template
  fhrs=$2  # Array of forecast hours
  for fhr in ${fhrs[@]}; do
    fhrchar=$(printf %03d $fhr)
    master=${tmpl}_master.ecf
    target=${tmpl}_f${fhrchar}.ecf
    rm -f $target
    ln -sf $master $target
  done
}

# $1: The value to replace the placeholder with (e.g., "006_15").
# $2: The name of the output file to create.
create_ecf_file() {
  local placeholder_value="$1"
  local output_filename="$2"
  echo "Creating ${output_filename}..."
  sed "s|@ecf_fhr@|${placeholder_value}|g" "${MASTER_FILE}" > "${output_filename}"
}

################################################################################################
################################################################################################

# Assign production resource version of the master file
cd $ECF_DIR/scripts/forecast/ensf
echo "Assign production resource version of the master files ..."
if [ ${resource_config} == "NCO" ]; then
  rm -f jrrfs_ensf_forecast_master.ecf
  ln -s jrrfs_ensf_forecast_master.ecf-prod-resource jrrfs_ensf_forecast_master.ecf
else
  rm -f jrrfs_ensf_forecast_master.ecf
  ln -s jrrfs_ensf_forecast_master.ecf-dev-resource jrrfs_ensf_forecast_master.ecf
fi

# point at proper resource fix file
cd ${ECF_DIR}/../fix/workflow/
echo "point at proper workflow.conf version..."
  rm -f ./det/workflow.conf ./enkf/workflow.conf ./ensf/workflow.conf ./firewx/workflow.conf
if [ ${resource_config} == "NCO" ]; then
  cpreq ./det/workflow.conf_prod ./det/workflow.conf
  cpreq ./enkf/workflow.conf_prod ./enkf/workflow.conf
  cpreq ./ensf/workflow.conf_prod ./ensf/workflow.conf
  cpreq ./firewx/workflow.conf_prod ./firewx/workflow.conf
else
  cpreq ./det/workflow.conf_dev ./det/workflow.conf
  cpreq ./enkf/workflow.conf_dev ./enkf/workflow.conf
  cpreq ./ensf/workflow.conf_dev ./ensf/workflow.conf
  cpreq ./firewx/workflow.conf_dev ./firewx/workflow.conf
fi

# det prdgen files
cd $ECF_DIR/scripts/product/det
echo "Copy det prdgen files ..."
rm -f jrrfs_det_prdgen_f*.ecf
MASTER_FILE="jrrfs_det_prdgen_master.ecf"
# =========================================================================
#  Generate Standard Forecast Files (short-range, 15-min intervals)
# =========================================================================
# Loop for hours 0-17 at 15-minute intervals.
for fhr in $(seq 0 17); do
  fhr_padded=$(printf "%03d" "${fhr}")
  for min in 00 15 30 45; do
    # The f000_00 file is a special case that gets renamed, so we skip creating it here.
    if [[ "${fhr_padded}" == "000" && "${min}" == "00" ]]; then
      continue
    fi
    hour_combo="${fhr_padded}_${min}_00"
    output_file="jrrfs_det_prdgen_f${hour_combo}.ecf"
    create_ecf_file "${hour_combo}" "${output_file}"
  done
done
# Handle the two special cases for the standard files.
create_ecf_file "000_00_36" "jrrfs_det_prdgen_f000_00_36.ecf"
create_ecf_file "018_00_00"    "jrrfs_det_prdgen_f018_00_00.ecf"
# =========================================================================
#  Generate Long-Range Forecast Files 
# =========================================================================
# Loop for hours 0-17 at 15-minute intervals for the "_long" files.
for fhr in $(seq 0 17); do
  fhr_padded=$(printf "%03d" "${fhr}")
  for min in 00 15 30 45; do
    # The f000_00 file is a special case that gets renamed, so we skip creating it here.
    if [[ "${fhr_padded}" == "000" && "${min}" == "00" ]]; then
      continue
    fi
    hour_combo="${fhr_padded}_${min}_00_long"
    output_file="jrrfs_det_prdgen_f${hour_combo}.ecf"
    create_ecf_file "${hour_combo}" "${output_file}"
  done
done
# NOTE: The original script had a bug here. It tried to rename a file that had already
# been moved and used an incorrect variable. The logic below corrects this by directly
# creating the intended special-case file.
create_ecf_file "000_00_36_long" "jrrfs_det_prdgen_f000_00_36_long.ecf"
# Loop for hours 18-84 at hourly intervals for the "_long" files.
for fhr in $(seq 18 84); do
  fhr_padded=$(printf "%03d" "${fhr}")
  hour_combo="${fhr_padded}_00_00_long"
  # Note: The placeholder for these files is just the hour, not the hour_minute combo.
  output_file="jrrfs_det_prdgen_f${hour_combo}.ecf"
  create_ecf_file "${hour_combo}" "${output_file}"
done

# det gempak files
cd $ECF_DIR/scripts/product/det
echo "Copy det gempak files ..."
rm -f jrrfs_det_gempak_f???.ecf
for fhrs in $(seq 0 60); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_det_gempak_master.ecf jrrfs_det_gempak_f${fhr_3d}.ecf
  sed -i -e "s|@gempak_ecf_fhr@|${fhr_3d}|g" jrrfs_det_gempak_f${fhr_3d}.ecf
done
for fhrs in $(seq 63 3 84); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_det_gempak_master.ecf jrrfs_det_gempak_f${fhr_3d}.ecf
  sed -i -e "s|@gempak_ecf_fhr@|${fhr_3d}|g" jrrfs_det_gempak_f${fhr_3d}.ecf
done

# ensf bufrsnd files
cd $ECF_DIR/scripts/product/ensf
echo "Copy ensf bufrsnd files ..."
rm -f jrrfs_ensf_bufrsnd_mem???.ecf
for fhrs in $(seq 1 5); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_ensf_bufrsnd_master.ecf jrrfs_ensf_bufrsnd_mem${fhr_3d}.ecf
  sed -i -e "s|@ensf_bufrsnd_fhr@|${fhr_3d}|g" jrrfs_ensf_bufrsnd_mem${fhr_3d}.ecf
done

# ensf prdgen files
cd $ECF_DIR/scripts/product/ensf
echo "Copy ensf prdgen files ..."
rm -f jrrfs_ensf_prdgen_mem???_f???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  for fhrs in $(seq 0 60); do
    fhr_3d=$( printf "%03d" "${fhrs}" )
    mem_hfr_combine=mem${mem_3d}_f${fhr_3d}
    cp jrrfs_ensf_prdgen_master.ecf jrrfs_ensf_prdgen_${mem_hfr_combine}.ecf
    sed -i -e "s|@ensf_prdgen_mem_fhr@|${mem_hfr_combine}|g" jrrfs_ensf_prdgen_${mem_hfr_combine}.ecf
  done
done

# firewx prdgen files
cd $ECF_DIR/scripts/product/firewx
echo "Copy firewx prdgen files ..."
rm -f jrrfs_firewx_prdgen_f???.ecf
for fhrs in $(seq 0 36); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_firewx_prdgen_master.ecf jrrfs_firewx_prdgen_f${fhr_3d}.ecf
  sed -i -e "s|@firewx_prdgen_fhr@|${fhr_3d}|g" jrrfs_firewx_prdgen_f${fhr_3d}.ecf
done

# det post files
cd $ECF_DIR/scripts/post/det
echo "Copy det post files ..."
rm -f jrrfs_det_post_f*
MASTER_FILE="jrrfs_det_post_master.ecf"
# =========================================================================
#  Generate Standard Forecast Files (short-range, 15-min intervals)
# =========================================================================
# Loop for hours 0-17 at 15-minute intervals.
for fhr in $(seq 0 17); do
  fhr_padded=$(printf "%03d" "${fhr}")
  for min in 00 15 30 45; do
    # The f000_00 file is a special case that gets renamed, so we skip creating it here.
    if [[ "${fhr_padded}" == "000" && "${min}" == "00" ]]; then
      continue
    fi
    hour_combo="${fhr_padded}_${min}_00"
    output_file="jrrfs_det_post_f${hour_combo}.ecf"
    create_ecf_file "${hour_combo}" "${output_file}"
  done
done
# Handle the two special cases for the standard files.
create_ecf_file "000_00_36" "jrrfs_det_post_f000_00_36.ecf"
create_ecf_file "018_00_00"    "jrrfs_det_post_f018_00_00.ecf"
# =========================================================================
#  Generate Long-Range Forecast Files
# =========================================================================
# Loop for hours 0-17 at 15-minute intervals for the "_long" files.
for fhr in $(seq 0 17); do
  fhr_padded=$(printf "%03d" "${fhr}")
  for min in 00 15 30 45; do
    # The f000_00 file is a special case that gets renamed, so we skip creating it here.
    if [[ "${fhr_padded}" == "000" && "${min}" == "00" ]]; then
      continue
    fi
    hour_combo="${fhr_padded}_${min}_00_long"
    output_file="jrrfs_det_post_f${hour_combo}.ecf"
    create_ecf_file "${hour_combo}" "${output_file}"
  done
done

# NOTE: The original script had a bug here. It tried to rename a file that had already
# been moved and used an incorrect variable. The logic below corrects this by directly
# creating the intended special-case file.
create_ecf_file "000_00_36_long" "jrrfs_det_post_f000_00_36_long.ecf"
# Loop for hours 18-84 at hourly intervals for the "_long" files.
for fhr in $(seq 18 84); do
  fhr_padded=$(printf "%03d" "${fhr}")
  hour_combo="${fhr_padded}_00_00_long"
  # Note: The placeholder for these files is just the hour, not the hour_minute combo.
  output_file="jrrfs_det_post_f${hour_combo}.ecf"
  create_ecf_file "${hour_combo}" "${output_file}"
done 

# ensf post files
cd $ECF_DIR/scripts/post/ensf
echo "Copy ensf post files ..."
rm -f jrrfs_ensf_post_mem*
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  for fhrs in $(seq 0 60); do
    fhr_3d=$( printf "%03d" "${fhrs}" )
    mem_hfr_combine=mem${mem_3d}_f${fhr_3d}
    cp jrrfs_ensf_post_master.ecf jrrfs_ensf_post_${mem_hfr_combine}.ecf
    sed -i -e "s|@ensf_post_mem_fhr@|${mem_hfr_combine}|g" jrrfs_ensf_post_${mem_hfr_combine}.ecf
  done
done

# firewx post files
cd $ECF_DIR/scripts/post/firewx
echo "Copy firewx post files ..."
rm -f jrrfs_firewx_post_f*
for fhrs in $(seq 0 36); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_firewx_post_master.ecf jrrfs_firewx_post_f${fhr_3d}.ecf
  sed -i -e "s|@firewx_post_fhr@|${fhr_3d}|g" jrrfs_firewx_post_f${fhr_3d}.ecf
done

# det ics lbcs files
cd $ECF_DIR/scripts/ics/det
echo "Copy det ics lbcs files ..."
rm -f jrrfs_det_make_lbcs_??.ecf
for fhrs in $(seq 0 84); do
  fhr_2d=$( printf "%02d" "${fhrs}" )
  cp jrrfs_det_make_lbcs_master.ecf jrrfs_det_make_lbcs_${fhr_2d}.ecf
  sed -i -e "s|@det_make_lbcs_fhr@|${fhr_2d}|g" jrrfs_det_make_lbcs_${fhr_2d}.ecf
done

# firewx ics lbcs files
cd $ECF_DIR/scripts/ics/firewx
echo "Copy firewx ics lbcs files ..."
for fhrs in $(seq 1 35); do
  fhr_2d=$( printf "%02d" "${fhrs}" )
  rm -f jrrfs_firewx_make_lbcs_${fhr_2d}.ecf
  cp jrrfs_firewx_make_lbcs_master.ecf jrrfs_firewx_make_lbcs_${fhr_2d}.ecf
  sed -i -e "s|@firewx_make_lbcs_fhr@|${fhr_2d}|g" jrrfs_firewx_make_lbcs_${fhr_2d}.ecf
done

# enkf ics blend ics files
cd $ECF_DIR/scripts/ics/enkf
echo "Copy enkf ics blend ics files ..."
rm -f jrrfs_enkf_blend_ics_mem???.ecf
for fhrs in $(seq 1 30); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_enkf_blend_ics_master.ecf jrrfs_enkf_blend_ics_mem${fhr_3d}.ecf
  sed -i -e "s|@enkf_blend_ics_member@|${fhr_3d}|g" jrrfs_enkf_blend_ics_mem${fhr_3d}.ecf
done

# enkf ics make ics files
cd $ECF_DIR/scripts/ics/enkf
echo "Copy enkf ics make ics files ..."
rm -f jrrfs_enkf_make_ics_mem???.ecf
for fhrs in $(seq 1 30); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_enkf_make_ics_master.ecf jrrfs_enkf_make_ics_mem${fhr_3d}.ecf
  sed -i -e "s|@enkf_make_ics_member@|${fhr_3d}|g" jrrfs_enkf_make_ics_mem${fhr_3d}.ecf
done

# enkf ics make lbcs files
cd $ECF_DIR/scripts/ics/enkf
echo "Copy enkf ics make lbcs files ..."
rm -f jrrfs_enkf_make_lbcs_??_mem???.ecf
for grp in $(seq 0 11); do
  grp_2d=$( printf "%02d" "${grp}" )
  for mem in $(seq 1 30); do
    mem_3d=$( printf "%03d" "${mem}" )
    mem_hfr_combine=${grp_2d}_mem${mem_3d}
    cp jrrfs_enkf_make_lbcs_master.ecf jrrfs_enkf_make_lbcs_${mem_hfr_combine}.ecf
    sed -i -e "s|@enkf_make_lbcs_grp_mem@|${mem_hfr_combine}|g" jrrfs_enkf_make_lbcs_${mem_hfr_combine}.ecf
  done
done

# ensf ics make lbcs files
cd $ECF_DIR/scripts/ics/ensf
echo "Copy ensf ics make lbcs files ..."
rm -f jrrfs_ensf_make_lbcs_??_mem???.ecf
for grp in $(seq 0 9); do
  grp_2d=$( printf "%02d" "${grp}" )
  for mem in $(seq 1 5); do
    mem_3d=$( printf "%03d" "${mem}" )
    mem_hfr_combine=${grp_2d}_mem${mem_3d}
    cp jrrfs_ensf_make_lbcs_master.ecf jrrfs_ensf_make_lbcs_${mem_hfr_combine}.ecf
    sed -i -e "s|@ensf_make_lbcs_grp_mem@|${mem_hfr_combine}|g" jrrfs_ensf_make_lbcs_${mem_hfr_combine}.ecf
  done
done

# enkf forecast enkf_forecast_mem??? files
cd $ECF_DIR/scripts/forecast/enkf
echo "Copy enkf forecast member files ..."
rm -f jrrfs_enkf_forecast_mem???.ecf
for fhrs in $(seq 1 30); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_enkf_forecast_master.ecf jrrfs_enkf_forecast_mem${fhr_3d}.ecf
  sed -i -e "s|@enkf_forecast_member@|${fhr_3d}|g" jrrfs_enkf_forecast_mem${fhr_3d}.ecf
done

# enkf ensinit fcst files
cd $ECF_DIR/scripts/forecast/enkf
echo "Copy enkf ensinit fcst files ..."
rm -f jrrfs_enkf_forecast_ensinit_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_forecast_ensinit_master.ecf jrrfs_enkf_forecast_ensinit_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_forecast_ensinit_member@|${mem_3d}|g" jrrfs_enkf_forecast_ensinit_mem${mem_3d}.ecf
done

# enkf forecast long files
cd $ECF_DIR/scripts/forecast/enkf
echo "Copy enkf forecast long files ..."
rm -f jrrfs_enkf_forecast_long_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_forecast_long_master.ecf jrrfs_enkf_forecast_long_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_forecast_long_member@|${mem_3d}|g" jrrfs_enkf_forecast_long_mem${mem_3d}.ecf
done

# enkf forecast spinup files
cd $ECF_DIR/scripts/forecast/enkf
echo "Copy enkf forecast spinup files ..."
rm -f jrrfs_enkf_forecast_spinup_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_forecast_spinup_master.ecf jrrfs_enkf_forecast_spinup_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_forecast_spinup_member@|${mem_3d}|g" jrrfs_enkf_forecast_spinup_mem${mem_3d}.ecf
done

# enkf save restart ensinit files
cd $ECF_DIR/scripts/forecast/enkf
echo "Copy enkf save restart ensinit files ..."
rm -f jrrfs_enkf_save_restart_ensinit_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_save_restart_ensinit_master.ecf jrrfs_enkf_save_restart_ensinit_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_save_restart_ensinit_member@|${mem_3d}|g" jrrfs_enkf_save_restart_ensinit_mem${mem_3d}.ecf
done

# enkf save restart long files
cd $ECF_DIR/scripts/forecast/enkf
echo "Copy enkf save restart long files ..."
rm -f jrrfs_enkf_save_restart_long_mem???_f1.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_save_restart_long_master.ecf jrrfs_enkf_save_restart_long_mem${mem_3d}_f1.ecf
  sed -i -e "s|@enkf_save_restart_long_member@|${mem_3d}|g" jrrfs_enkf_save_restart_long_mem${mem_3d}_f1.ecf
done

# enkf save restart files
cd $ECF_DIR/scripts/forecast/enkf
echo "Copy enkf save restart files ..."
rm -f jrrfs_enkf_save_restart_mem???_f1.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_save_restart_master.ecf jrrfs_enkf_save_restart_mem${mem_3d}_f1.ecf
done

# enkf save restart spinup files
cd $ECF_DIR/scripts/forecast/enkf
echo "Copy enkf save restart spinup files ..."
rm -f jrrfs_enkf_save_restart_spinup_mem???_f001.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_save_restart_spinup_master.ecf jrrfs_enkf_save_restart_spinup_mem${mem_3d}_f001.ecf
  sed -i -e "s|@enkf_save_restart_spinup_member@|${mem_3d}|g" jrrfs_enkf_save_restart_spinup_mem${mem_3d}_f001.ecf
done

# ensf forecast files
cd $ECF_DIR/scripts/forecast/ensf
echo "Copy ensf forecast files ..."
rm -f jrrfs_ensf_forecast_mem???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_ensf_forecast_master.ecf jrrfs_ensf_forecast_mem${mem_3d}.ecf
  sed -i -e "s|@ensf_forecast_member@|${mem_3d}|g" jrrfs_ensf_forecast_mem${mem_3d}.ecf
done

# enkf analysis nonvarcld files
cd $ECF_DIR/scripts/analysis/enkf
echo "Copy enkf analysis nonvarcld files ..."
rm -f jrrfs_enkf_analysis_nonvarcld_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_analysis_nonvarcld_master.ecf jrrfs_enkf_analysis_nonvarcld_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_analysis_nonvarcld_member@|${mem_3d}|g" jrrfs_enkf_analysis_nonvarcld_mem${mem_3d}.ecf
done

# enkf analysis nonvarcld spinup files
cd $ECF_DIR/scripts/analysis/enkf
echo "Copy enkf analysis nonvarcld spinup files ..."
rm -f jrrfs_enkf_analysis_nonvarcld_spinup_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_analysis_nonvarcld_spinup_master.ecf jrrfs_enkf_analysis_nonvarcld_spinup_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_analysis_nonvarcld_spinup_member@|${mem_3d}|g" jrrfs_enkf_analysis_nonvarcld_spinup_mem${mem_3d}.ecf
done

# enkf save da output files
cd $ECF_DIR/scripts/analysis/enkf
echo "Copy enkf save da output files ..."
rm -f jrrfs_enkf_save_da_output_mem???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_save_da_output_master.ecf jrrfs_enkf_save_da_output_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_save_da_output_member@|${mem_3d}|g" jrrfs_enkf_save_da_output_mem${mem_3d}.ecf
done

# ensf save da output files
cd $ECF_DIR/scripts/analysis/ensf
echo "Copy ensf save da output files ..."
rm -f jrrfs_ensf_save_da_output_mem???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_ensf_save_da_output_master.ecf jrrfs_ensf_save_da_output_mem${mem_3d}.ecf
  sed -i -e "s|@ensf_save_da_output_member@|${mem_3d}|g" jrrfs_ensf_save_da_output_mem${mem_3d}.ecf
done

# enkf observer gsi files
cd $ECF_DIR/scripts/prep/enkf
echo "Copy enkf observer gsi files ..."
rm -f jrrfs_enkf_observer_gsi_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_observer_gsi_master.ecf jrrfs_enkf_observer_gsi_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_observer_gsi_member@|${mem_3d}|g" jrrfs_enkf_observer_gsi_mem${mem_3d}.ecf
done

# enkf observer gsi spinup files
cd $ECF_DIR/scripts/prep/enkf
echo "Copy enkf observer gsi spinup files ..."
rm -f jrrfs_enkf_observer_gsi_spinup_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_observer_gsi_spinup_master.ecf jrrfs_enkf_observer_gsi_spinup_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_observer_gsi_spinup_member@|${mem_3d}|g" jrrfs_enkf_observer_gsi_spinup_mem${mem_3d}.ecf
done

# enkf prep cyc files
cd $ECF_DIR/scripts/prep/enkf
echo "Copy enkf prep cyc files ..."
rm -f jrrfs_enkf_prep_cyc_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_prep_cyc_master.ecf jrrfs_enkf_prep_cyc_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_prep_cyc_member@|${mem_3d}|g" jrrfs_enkf_prep_cyc_mem${mem_3d}.ecf
done

# enkf prep cyc spinup files
cd $ECF_DIR/scripts/prep/enkf
echo "Copy enkf prep cyc spinup files ..."
rm -f jrrfs_enkf_prep_cyc_spinup_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_prep_cyc_spinup_master.ecf jrrfs_enkf_prep_cyc_spinup_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_prep_cyc_spinup_member@|${mem_3d}|g" jrrfs_enkf_prep_cyc_spinup_mem${mem_3d}.ecf
done

# enkf prep cyc spinup ensinit files
cd $ECF_DIR/scripts/prep/enkf
echo "Copy enkf prep cyc spinup ensinit files ..."
rm -f jrrfs_enkf_prep_cyc_spinup_ensinit_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_prep_cyc_spinup_ensinit_master.ecf jrrfs_enkf_prep_cyc_spinup_ensinit_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_prep_cyc_spinup_ensinit_member@|${mem_3d}|g" jrrfs_enkf_prep_cyc_spinup_ensinit_mem${mem_3d}.ecf
done

# ensf prep cyc files
cd $ECF_DIR/scripts/prep/ensf
echo "Copy ensf prep cyc files ..."
rm -f jrrfs_ensf_prep_cyc_mem???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_ensf_prep_cyc_master.ecf jrrfs_ensf_prep_cyc_mem${mem_3d}.ecf
  sed -i -e "s|@ensf_prep_cyc_member@|${mem_3d}|g" jrrfs_ensf_prep_cyc_mem${mem_3d}.ecf
done

# Create resource dependent files
if [ ${resource_config} == "NCO" ]; then
  cd $ECF_DIR/scripts/forecast/det
  for file in jrrfs_det_forecast jrrfs_det_forecast_long; do
    rm -f ${file}.ecf
    ln -s ${file}.ecf-prod-resource ${file}.ecf
  done
else
  cd $ECF_DIR/scripts/forecast/det
  for file in jrrfs_det_forecast jrrfs_det_forecast_long; do
    rm -f ${file}.ecf
    ln -s ${file}.ecf-dev-resource ${file}.ecf
  done
fi

if [ ${resource_config} == "EMC" ]; then
  # updates input.nml namelist files for 52 node configuration
  files="${ECF_DIR}/../parm/config/det/input.nml_18h ${ECF_DIR}/../parm/config/det/input.nml_restart_18h"
  # 53,128 --> 43,64
  #
  for fl in $files
  do
          cat $fl | sed s:53:43:g > ${fl}_new
          cat ${fl}_new | sed s:128:64:g > ${fl}
          rm -f ${fl}_new
  done
  
  files="${ECF_DIR}/../parm/config/det/input.nml_restart_long ${ECF_DIR}/../parm/config/det/input.nml_long"
  # 71,128 --> 43,64
  #
  for fl in $files
  do
          cat $fl | sed s:71:43:g > ${fl}_new
          cat ${fl}_new | sed s:128:64:g > ${fl}
          rm -f ${fl}_new
  done
  
  files="${ECF_DIR}/../parm/config/ensf/input.nml_restart_stoch_ensphy?"
  #
  # 45,128 --> 50,64
  #
  for fl in $files
  do
          cat $fl | sed s:45:50:g > ${fl}_new
          cat ${fl}_new | sed s:128:64:g > ${fl}
          rm -f ${fl}_new
  done
fi
