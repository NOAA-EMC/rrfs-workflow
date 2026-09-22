#!/bin/bash
# Must be run from $PACKAGEHOME/ecf
set -eux
# prod_util provides cpreq; on Ursa it comes from modulefiles/run_ursa.lua (spack-stack)
if [[ "$(hostname -f)" == *"ufe"* ]]; then
  module use "$(pwd)/../modulefiles"
  module load run_ursa
else
  module load prod_util
fi

ECF_DIR=$(pwd)
# On Ursa the shared settings file supplies RESOURCE_CONFIG and FIX_RRFS_DIR; elsewhere (WCOSS2)
# the NCO production resources stay the default.
if [[ "$(hostname -f)" == *"ufe"* ]] && [ -f "${ECF_DIR}/defs/ursa_config.sh" ]; then
  # shellcheck source=/dev/null
  . "${ECF_DIR}/defs/ursa_config.sh"
fi
resource_config=${RESOURCE_CONFIG:-NCO}

# On Ursa, build fix/ as links into a copy of the WCOSS2 fix tree (FIX_RRFS_DIR overrides it).
# workflow/ is a local directory because the workflow.conf step below writes into it.
if [[ "$(hostname -f)" == *"ufe"* ]]; then
  fix_src=${FIX_RRFS_DIR}
  fix_dir=${ECF_DIR}/../fix
  mkdir -p ${fix_dir}
  for src in ${fix_src}/*; do
    name=$(basename ${src})
    [ "${name}" = "workflow" ] && continue
    ln -snf ${src} ${fix_dir}/${name}
  done
  for wgf in det enkf ensf firewx; do
    mkdir -p ${fix_dir}/workflow/${wgf}
    ln -sf ${fix_src}/workflow/${wgf}/workflow.conf_prod ${fix_dir}/workflow/${wgf}/workflow.conf_prod
    ln -sf ${fix_src}/workflow/${wgf}/workflow.conf_dev ${fix_dir}/workflow/${wgf}/workflow.conf_dev
  done
fi

# Create tmp file for git exclude
tmp_exclude="${ECF_DIR}/exclude_list.tmp"

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

add_to_tmpfile() {
  local exclude_file="$1"
  echo ${exclude_file} >> ${tmp_exclude}
  echo "Added ${exclude_file} to ${tmp_exclude}"
}

################################################################################################
################################################################################################

# Assign production resource version of the master file
cd $ECF_DIR/scripts/ensf/forecast
echo "Assign production resource version of the master files ..."
if [ ${resource_config} == "NCO" ]; then
  rm -f jrrfs_ensf_forecast_master.ecf
  ln -s jrrfs_ensf_forecast_master.ecf-prod-resource jrrfs_ensf_forecast_master.ecf
  add_to_tmpfile "$ECF_DIR/scripts/ensf/forecast/jrrfs_ensf_forecast_master.ecf"
else
  rm -f jrrfs_ensf_forecast_master.ecf
  ln -s jrrfs_ensf_forecast_master.ecf-dev-resource jrrfs_ensf_forecast_master.ecf
  add_to_tmpfile "$ECF_DIR/scripts/ensf/forecast/jrrfs_ensf_forecast_master.ecf"
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

# Ursa retros read the staged GFS GRIB2 files for the deterministic boundaries; the netcdf files
# operations uses (hourly out to f102, four cycles a day) are far too large to stage.
if [[ "$(hostname -f)" == *"ufe"* ]]; then
  echo "Ursa: deterministic LBCs from GFS grib2, fewer forecast ranks per node..."
  sed -i "s|^export GFS_FILE_FMT_LBCS=.*|export GFS_FILE_FMT_LBCS='grib2'|" ./det/workflow.conf
  # An Ursa node has 360 GB for 192 cores, against 500 GB on WCOSS2, so 64 forecast ranks per node
  # leaves the write tasks short and they are OOM-killed. 48 per node restores ~7.5 GB per rank;
  # the rank count itself comes from the layout and does not change (see the ecf cards' --nodes).
  sed -i "s|^export PPN_FORECAST=.*|export PPN_FORECAST='48'|" ./det/workflow.conf
  # Even at 48 per node the production forecast's write ranks run out of memory as output builds up
  # (OOM near hour 12). Two write groups of 384 instead of three of 192 halve what each write rank
  # holds; the output is the same and the job still fits in 74 nodes (see the forecast cards).
  sed -i -E "s/^export (WRTCMP_write_groups(_18H|_LONG)?)=.*/export \1='2'/; s/^export (WRTCMP_write_tasks_per_group(_18H|_LONG)?)=.*/export \1='384'/" ./det/workflow.conf
  # No Great Lakes FVCOM (nosofs) data is staged on Ursa, and warm starts abort without it; the
  # Rocoto retros run without it too (PREP_FVCOM=FALSE)
  sed -i "s|^export USE_FVCOM=.*|export USE_FVCOM='FALSE'|; s|^export PREP_FVCOM=.*|export PREP_FVCOM='FALSE'|" ./det/workflow.conf
  # An EnKF member spreads the same domain over 704 ranks against 1856 for the deterministic
  # spinup, so each rank holds far more and needs 24 per node (see the member cards' --nodes).
  sed -i "s|^export PPN_FORECAST=.*|export PPN_FORECAST='24'|" ./enkf/workflow.conf
  # An ensf member is 3200 compute ranks over the same domain, so 48 per node as for det
  sed -i "s|^export PPN_FORECAST=.*|export PPN_FORECAST='48'|" ./ensf/workflow.conf
  grep -n "GFS_FILE_FMT\|PPN_FORECAST" ./det/workflow.conf
fi

# det prdgen files
cd $ECF_DIR/scripts/det/prdgen
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
    add_to_tmpfile "$ECF_DIR/scripts/det/prdgen/${output_file}"
  done
done
# Handle the two special cases for the standard files.
create_ecf_file "000_00_36" "jrrfs_det_prdgen_f000_00_36.ecf"
add_to_tmpfile "$ECF_DIR/scripts/det/prdgen/jrrfs_det_prdgen_f000_00_36.ecf"
create_ecf_file "018_00_00"    "jrrfs_det_prdgen_f018_00_00.ecf"
add_to_tmpfile "$ECF_DIR/scripts/det/prdgen/jrrfs_det_prdgen_f018_00_00.ecf"
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
    add_to_tmpfile "$ECF_DIR/scripts/det/prdgen/${output_file}"
  done
done
# NOTE: The original script had a bug here. It tried to rename a file that had already
# been moved and used an incorrect variable. The logic below corrects this by directly
# creating the intended special-case file.
create_ecf_file "000_00_36_long" "jrrfs_det_prdgen_f000_00_36_long.ecf"
add_to_tmpfile "$ECF_DIR/scripts/det/prdgen/jrrfs_det_prdgen_f000_00_36_long.ecf"
# Loop for hours 18-84 at hourly intervals for the "_long" files.
for fhr in $(seq 18 84); do
  fhr_padded=$(printf "%03d" "${fhr}")
  hour_combo="${fhr_padded}_00_00_long"
  # Note: The placeholder for these files is just the hour, not the hour_minute combo.
  output_file="jrrfs_det_prdgen_f${hour_combo}.ecf"
  create_ecf_file "${hour_combo}" "${output_file}"
  add_to_tmpfile "$ECF_DIR/scripts/det/prdgen/${output_file}"
done

# det gempak files
cd $ECF_DIR/scripts/det/prdgen
echo "Copy det gempak files ..."
rm -f jrrfs_det_gempak_f???.ecf
for fhrs in $(seq 0 60); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_det_gempak_master.ecf jrrfs_det_gempak_f${fhr_3d}.ecf
  sed -i -e "s|@gempak_ecf_fhr@|${fhr_3d}|g" jrrfs_det_gempak_f${fhr_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/det/prdgen/jrrfs_det_gempak_f${fhr_3d}.ecf"
done
for fhrs in $(seq 63 3 84); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_det_gempak_master.ecf jrrfs_det_gempak_f${fhr_3d}.ecf
  sed -i -e "s|@gempak_ecf_fhr@|${fhr_3d}|g" jrrfs_det_gempak_f${fhr_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/det/prdgen/jrrfs_det_gempak_f${fhr_3d}.ecf"
done

# ensf bufrsnd files
cd $ECF_DIR/scripts/ensf/prdgen
echo "Copy ensf bufrsnd files ..."
rm -f jrrfs_ensf_bufrsnd_mem???.ecf
for fhrs in $(seq 1 5); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_ensf_bufrsnd_master.ecf jrrfs_ensf_bufrsnd_mem${fhr_3d}.ecf
  sed -i -e "s|@ensf_bufrsnd_fhr@|${fhr_3d}|g" jrrfs_ensf_bufrsnd_mem${fhr_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/ensf/prdgen/jrrfs_ensf_bufrsnd_mem${fhr_3d}.ecf"
done

# ensf prdgen files
cd $ECF_DIR/scripts/ensf/prdgen
echo "Copy ensf prdgen files ..."
rm -f jrrfs_ensf_prdgen_mem???_f???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  for fhrs in $(seq 0 60); do
    fhr_3d=$( printf "%03d" "${fhrs}" )
    mem_hfr_combine=mem${mem_3d}_f${fhr_3d}
    cp jrrfs_ensf_prdgen_master.ecf jrrfs_ensf_prdgen_${mem_hfr_combine}.ecf
    sed -i -e "s|@ensf_prdgen_mem_fhr@|${mem_hfr_combine}|g" jrrfs_ensf_prdgen_${mem_hfr_combine}.ecf
    add_to_tmpfile "$ECF_DIR/scripts/ensf/prdgen/jrrfs_ensf_prdgen_${mem_hfr_combine}.ecf"
  done
done

# firewx prdgen files
cd $ECF_DIR/scripts/firewx/prdgen
echo "Copy firewx prdgen files ..."
rm -f jrrfs_firewx_prdgen_f???.ecf
for fhrs in $(seq 0 36); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_firewx_prdgen_master.ecf jrrfs_firewx_prdgen_f${fhr_3d}.ecf
  sed -i -e "s|@firewx_prdgen_fhr@|${fhr_3d}|g" jrrfs_firewx_prdgen_f${fhr_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/firewx/prdgen/jrrfs_firewx_prdgen_f${fhr_3d}.ecf"
done

# det post files
cd $ECF_DIR/scripts/det/post
echo "Copy det post files ..."
rm -f jrrfs_det_post_f*
MASTER_FILE_HOUR="jrrfs_det_post_master.ecf"
MASTER_FILE_SUBHOUR="jrrfs_det_post_subhour_master.ecf"
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
    if [[ ${min} == "00" ]]; then
      MASTER_FILE=${MASTER_FILE_HOUR}
    else
      MASTER_FILE=${MASTER_FILE_SUBHOUR}
    fi
    create_ecf_file "${hour_combo}" "${output_file}"
    add_to_tmpfile "$ECF_DIR/scripts/det/post/${output_file}"
  done
done
MASTER_FILE=${MASTER_FILE_HOUR}
# Handle the two special cases for the standard files.
create_ecf_file "000_00_36" "jrrfs_det_post_f000_00_36.ecf"
add_to_tmpfile "$ECF_DIR/scripts/det/post/jrrfs_det_post_f000_00_36.ecf"
create_ecf_file "018_00_00"    "jrrfs_det_post_f018_00_00.ecf"
add_to_tmpfile "$ECF_DIR/scripts/det/post/jrrfs_det_post_f018_00_00.ecf"
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
    if [[ ${min} == "00" ]]; then
      MASTER_FILE=${MASTER_FILE_HOUR}
    else
      MASTER_FILE=${MASTER_FILE_SUBHOUR}
    fi
    create_ecf_file "${hour_combo}" "${output_file}"
    add_to_tmpfile "$ECF_DIR/scripts/det/post/${output_file}"
  done
done
MASTER_FILE=${MASTER_FILE_HOUR}
# creating the intended special-case file.
create_ecf_file "000_00_36_long" "jrrfs_det_post_f000_00_36_long.ecf"
add_to_tmpfile "$ECF_DIR/scripts/det/post/jrrfs_det_post_f000_00_36_long.ecf"
# Loop for hours 18-84 at hourly intervals for the "_long" files.
for fhr in $(seq 18 84); do
  fhr_padded=$(printf "%03d" "${fhr}")
  hour_combo="${fhr_padded}_00_00_long"
  # Note: The placeholder for these files is just the hour, not the hour_minute combo.
  output_file="jrrfs_det_post_f${hour_combo}.ecf"
  create_ecf_file "${hour_combo}" "${output_file}"
  add_to_tmpfile "$ECF_DIR/scripts/det/post/${output_file}"
done 

# ensf post files
cd $ECF_DIR/scripts/ensf/post
echo "Copy ensf post files ..."
rm -f jrrfs_ensf_post_mem*
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  for fhrs in $(seq 0 60); do
    fhr_3d=$( printf "%03d" "${fhrs}" )
    mem_hfr_combine=mem${mem_3d}_f${fhr_3d}
    cp jrrfs_ensf_post_master.ecf jrrfs_ensf_post_${mem_hfr_combine}.ecf
    sed -i -e "s|@ensf_post_mem_fhr@|${mem_hfr_combine}|g" jrrfs_ensf_post_${mem_hfr_combine}.ecf
    add_to_tmpfile "$ECF_DIR/scripts/ensf/post/jrrfs_ensf_post_${mem_hfr_combine}.ecf"
  done
done

# firewx post files
cd $ECF_DIR/scripts/firewx/post
echo "Copy firewx post files ..."
rm -f jrrfs_firewx_post_f*
for fhrs in $(seq 0 36); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_firewx_post_master.ecf jrrfs_firewx_post_f${fhr_3d}.ecf
  sed -i -e "s|@firewx_post_fhr@|${fhr_3d}|g" jrrfs_firewx_post_f${fhr_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/firewx/post/jrrfs_firewx_post_f${fhr_3d}.ecf"
done

# det ics lbcs files
cd $ECF_DIR/scripts/det/ics
echo "Copy det ics lbcs files ..."
rm -f jrrfs_det_make_lbcs_??.ecf
for fhrs in $(seq 0 84); do
  fhr_2d=$( printf "%02d" "${fhrs}" )
  cp jrrfs_det_make_lbcs_master.ecf jrrfs_det_make_lbcs_${fhr_2d}.ecf
  sed -i -e "s|@det_make_lbcs_fhr@|${fhr_2d}|g" jrrfs_det_make_lbcs_${fhr_2d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/det/ics/jrrfs_det_make_lbcs_${fhr_2d}.ecf"
done

# firewx ics lbcs files
cd $ECF_DIR/scripts/firewx/ics
echo "Copy firewx ics lbcs files ..."
for fhrs in $(seq 0 35); do
  fhr_2d=$( printf "%02d" "${fhrs}" )
  rm -f jrrfs_firewx_make_lbcs_${fhr_2d}.ecf
  cp jrrfs_firewx_make_lbcs_master.ecf jrrfs_firewx_make_lbcs_${fhr_2d}.ecf
  sed -i -e "s|@firewx_make_lbcs_fhr@|${fhr_2d}|g" jrrfs_firewx_make_lbcs_${fhr_2d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/firewx/ics/jrrfs_firewx_make_lbcs_${fhr_2d}.ecf"
done

# enkf ics blend ics files
cd $ECF_DIR/scripts/enkf/ics
echo "Copy enkf ics blend ics files ..."
rm -f jrrfs_enkf_blend_ics_mem???.ecf
for fhrs in $(seq 1 30); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_enkf_blend_ics_master.ecf jrrfs_enkf_blend_ics_mem${fhr_3d}.ecf
  sed -i -e "s|@enkf_blend_ics_member@|${fhr_3d}|g" jrrfs_enkf_blend_ics_mem${fhr_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/ics/jrrfs_enkf_blend_ics_mem${fhr_3d}.ecf"
done

# enkf ics make ics files
cd $ECF_DIR/scripts/enkf/ics
echo "Copy enkf ics make ics files ..."
rm -f jrrfs_enkf_make_ics_mem???.ecf
for fhrs in $(seq 1 30); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_enkf_make_ics_master.ecf jrrfs_enkf_make_ics_mem${fhr_3d}.ecf
  sed -i -e "s|@enkf_make_ics_member@|${fhr_3d}|g" jrrfs_enkf_make_ics_mem${fhr_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/ics/jrrfs_enkf_make_ics_mem${fhr_3d}.ecf"
done

# enkf ics make lbcs files
cd $ECF_DIR/scripts/enkf/ics
echo "Copy enkf ics make lbcs files ..."
rm -f jrrfs_enkf_make_lbcs_??_mem???.ecf
for grp in $(seq 0 11); do
  grp_2d=$( printf "%02d" "${grp}" )
  for mem in $(seq 1 30); do
    mem_3d=$( printf "%03d" "${mem}" )
    mem_hfr_combine=${grp_2d}_mem${mem_3d}
    cp jrrfs_enkf_make_lbcs_master.ecf jrrfs_enkf_make_lbcs_${mem_hfr_combine}.ecf
    sed -i -e "s|@enkf_make_lbcs_grp_mem@|${mem_hfr_combine}|g" jrrfs_enkf_make_lbcs_${mem_hfr_combine}.ecf
    add_to_tmpfile "$ECF_DIR/scripts/enkf/ics/jrrfs_enkf_make_lbcs_${mem_hfr_combine}.ecf"
  done
done

# ensf ics make lbcs files
cd $ECF_DIR/scripts/ensf/ics
echo "Copy ensf ics make lbcs files ..."
rm -f jrrfs_ensf_make_lbcs_??_mem???.ecf
for grp in $(seq 0 9); do
  grp_2d=$( printf "%02d" "${grp}" )
  for mem in $(seq 1 5); do
    mem_3d=$( printf "%03d" "${mem}" )
    mem_hfr_combine=${grp_2d}_mem${mem_3d}
    cp jrrfs_ensf_make_lbcs_master.ecf jrrfs_ensf_make_lbcs_${mem_hfr_combine}.ecf
    sed -i -e "s|@ensf_make_lbcs_grp_mem@|${mem_hfr_combine}|g" jrrfs_ensf_make_lbcs_${mem_hfr_combine}.ecf
    add_to_tmpfile "$ECF_DIR/scripts/ensf/ics/jrrfs_ensf_make_lbcs_${mem_hfr_combine}.ecf"
  done
done

# enkf forecast enkf_forecast_mem??? files
cd $ECF_DIR/scripts/enkf/forecast
echo "Copy enkf forecast member files ..."
rm -f jrrfs_enkf_forecast_mem???.ecf
for fhrs in $(seq 1 30); do
  fhr_3d=$( printf "%03d" "${fhrs}" )
  cp jrrfs_enkf_forecast_master.ecf jrrfs_enkf_forecast_mem${fhr_3d}.ecf
  sed -i -e "s|@enkf_forecast_member@|${fhr_3d}|g" jrrfs_enkf_forecast_mem${fhr_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/forecast/jrrfs_enkf_forecast_mem${fhr_3d}.ecf"
done

# enkf ensinit fcst files
cd $ECF_DIR/scripts/enkf/forecast
echo "Copy enkf ensinit fcst files ..."
rm -f jrrfs_enkf_forecast_ensinit_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_forecast_ensinit_master.ecf jrrfs_enkf_forecast_ensinit_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_forecast_ensinit_member@|${mem_3d}|g" jrrfs_enkf_forecast_ensinit_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/forecast/jrrfs_enkf_forecast_ensinit_mem${mem_3d}.ecf"
done

# enkf forecast long files
cd $ECF_DIR/scripts/enkf/forecast
echo "Copy enkf forecast long files ..."
rm -f jrrfs_enkf_forecast_long_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_forecast_long_master.ecf jrrfs_enkf_forecast_long_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_forecast_long_member@|${mem_3d}|g" jrrfs_enkf_forecast_long_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/forecast/jrrfs_enkf_forecast_long_mem${mem_3d}.ecf"
done

# enkf forecast spinup files
cd $ECF_DIR/scripts/enkf/forecast
echo "Copy enkf forecast spinup files ..."
rm -f jrrfs_enkf_forecast_spinup_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_forecast_spinup_master.ecf jrrfs_enkf_forecast_spinup_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_forecast_spinup_member@|${mem_3d}|g" jrrfs_enkf_forecast_spinup_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/forecast/jrrfs_enkf_forecast_spinup_mem${mem_3d}.ecf"
done

# enkf save restart ensinit files
cd $ECF_DIR/scripts/enkf/forecast
echo "Copy enkf save restart ensinit files ..."
rm -f jrrfs_enkf_save_restart_ensinit_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_save_restart_ensinit_master.ecf jrrfs_enkf_save_restart_ensinit_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_save_restart_ensinit_member@|${mem_3d}|g" jrrfs_enkf_save_restart_ensinit_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/forecast/jrrfs_enkf_save_restart_ensinit_mem${mem_3d}.ecf"
done

# enkf save restart long files
cd $ECF_DIR/scripts/enkf/forecast
echo "Copy enkf save restart long files ..."
rm -f jrrfs_enkf_save_restart_long_mem???_f1.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  for fhr_2_save in $(seq 1 3); do
    cp jrrfs_enkf_save_restart_long_master.ecf jrrfs_enkf_save_restart_long_mem${mem_3d}_f${fhr_2_save}.ecf
    sed -i -e "s|@enkf_save_restart_long_member@|${mem_3d}|g" jrrfs_enkf_save_restart_long_mem${mem_3d}_f${fhr_2_save}.ecf
    sed -i -e "s|@enkf_save_restart_long_fhr@|${fhr_2_save}|g" jrrfs_enkf_save_restart_long_mem${mem_3d}_f${fhr_2_save}.ecf
    add_to_tmpfile "$ECF_DIR/scripts/enkf/forecast/jrrfs_enkf_save_restart_long_mem${mem_3d}_f${fhr_2_save}.ecf"
  done
done

# enkf save restart files
cd $ECF_DIR/scripts/enkf/forecast
echo "Copy enkf save restart files ..."
rm -f jrrfs_enkf_save_restart_mem???_f1.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  for fhr_2_save in $(seq 1 3); do
    cp jrrfs_enkf_save_restart_master.ecf jrrfs_enkf_save_restart_mem${mem_3d}_f${fhr_2_save}.ecf
    sed -i -e "s|@enkf_save_restart_member@|${mem_3d}|g" jrrfs_enkf_save_restart_mem${mem_3d}_f${fhr_2_save}.ecf
    sed -i -e "s|@enkf_save_restart_fhr@|${fhr_2_save}|g" jrrfs_enkf_save_restart_mem${mem_3d}_f${fhr_2_save}.ecf
    add_to_tmpfile "$ECF_DIR/scripts/enkf/forecast/jrrfs_enkf_save_restart_mem${mem_3d}_f${fhr_2_save}.ecf"
  done
done

# enkf save restart spinup files
cd $ECF_DIR/scripts/enkf/forecast
echo "Copy enkf save restart spinup files ..."
rm -f jrrfs_enkf_save_restart_spinup_mem???_f001.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_save_restart_spinup_master.ecf jrrfs_enkf_save_restart_spinup_mem${mem_3d}_f001.ecf
  sed -i -e "s|@enkf_save_restart_spinup_member@|${mem_3d}|g" jrrfs_enkf_save_restart_spinup_mem${mem_3d}_f001.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/forecast/jrrfs_enkf_save_restart_spinup_mem${mem_3d}_f001.ecf"
done

# ensf forecast files
cd $ECF_DIR/scripts/ensf/forecast
echo "Copy ensf forecast files ..."
rm -f jrrfs_ensf_forecast_mem???.ecf
# 94 node list
memlist="1 4"
for mem in ${memlist}; do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_ensf_forecast_master.ecf jrrfs_ensf_forecast_mem${mem_3d}.ecf
  sed -i -e "s|@ensf_forecast_member@|${mem_3d}|g" jrrfs_ensf_forecast_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/ensf/forecast/jrrfs_ensf_forecast_mem${mem_3d}.ecf"
done

# 103 node list
memlist="2 3 5"
for mem in ${memlist}; do
  mem_3d=$( printf "%03d" "${mem}" )
  if [ ${resource_config} == "NCO" ]; then
    cp jrrfs_ensf_forecast_master.ecf_103nodes jrrfs_ensf_forecast_mem${mem_3d}.ecf
  else
    cp jrrfs_ensf_forecast_master.ecf jrrfs_ensf_forecast_mem${mem_3d}.ecf
  fi
  sed -i -e "s|@ensf_forecast_member@|${mem_3d}|g" jrrfs_ensf_forecast_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/ensf/forecast/jrrfs_ensf_forecast_mem${mem_3d}.ecf"
done

# enkf analysis nonvarcld files
cd $ECF_DIR/scripts/enkf/analysis
echo "Copy enkf analysis nonvarcld files ..."
rm -f jrrfs_enkf_analysis_nonvarcld_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_analysis_nonvarcld_master.ecf jrrfs_enkf_analysis_nonvarcld_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_analysis_nonvarcld_member@|${mem_3d}|g" jrrfs_enkf_analysis_nonvarcld_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/analysis/jrrfs_enkf_analysis_nonvarcld_mem${mem_3d}.ecf"
done

# enkf analysis nonvarcld spinup files
cd $ECF_DIR/scripts/enkf/analysis
echo "Copy enkf analysis nonvarcld spinup files ..."
rm -f jrrfs_enkf_analysis_nonvarcld_spinup_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_analysis_nonvarcld_spinup_master.ecf jrrfs_enkf_analysis_nonvarcld_spinup_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_analysis_nonvarcld_spinup_member@|${mem_3d}|g" jrrfs_enkf_analysis_nonvarcld_spinup_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/analysis/jrrfs_enkf_analysis_nonvarcld_spinup_mem${mem_3d}.ecf"
done

# enkf save da output files
cd $ECF_DIR/scripts/enkf/analysis
echo "Copy enkf save da output files ..."
rm -f jrrfs_enkf_save_da_output_mem???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_save_da_output_master.ecf jrrfs_enkf_save_da_output_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_save_da_output_member@|${mem_3d}|g" jrrfs_enkf_save_da_output_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/analysis/jrrfs_enkf_save_da_output_mem${mem_3d}.ecf"
done

# ensf save da output files
cd $ECF_DIR/scripts/ensf/analysis
echo "Copy ensf save da output files ..."
rm -f jrrfs_ensf_save_da_output_mem???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_ensf_save_da_output_master.ecf jrrfs_ensf_save_da_output_mem${mem_3d}.ecf
  sed -i -e "s|@ensf_save_da_output_member@|${mem_3d}|g" jrrfs_ensf_save_da_output_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/ensf/analysis/jrrfs_ensf_save_da_output_mem${mem_3d}.ecf"
done

# enkf observer gsi files
cd $ECF_DIR/scripts/enkf/prep
echo "Copy enkf observer gsi files ..."
rm -f jrrfs_enkf_observer_gsi_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_observer_gsi_master.ecf jrrfs_enkf_observer_gsi_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_observer_gsi_member@|${mem_3d}|g" jrrfs_enkf_observer_gsi_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/prep/jrrfs_enkf_observer_gsi_mem${mem_3d}.ecf"
done

# enkf observer gsi spinup files
cd $ECF_DIR/scripts/enkf/prep
echo "Copy enkf observer gsi spinup files ..."
rm -f jrrfs_enkf_observer_gsi_spinup_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_observer_gsi_spinup_master.ecf jrrfs_enkf_observer_gsi_spinup_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_observer_gsi_spinup_member@|${mem_3d}|g" jrrfs_enkf_observer_gsi_spinup_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/prep/jrrfs_enkf_observer_gsi_spinup_mem${mem_3d}.ecf"
done

# enkf prep cyc files
cd $ECF_DIR/scripts/enkf/prep
echo "Copy enkf prep cyc files ..."
rm -f jrrfs_enkf_prep_cyc_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_prep_cyc_master.ecf jrrfs_enkf_prep_cyc_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_prep_cyc_member@|${mem_3d}|g" jrrfs_enkf_prep_cyc_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/prep/jrrfs_enkf_prep_cyc_mem${mem_3d}.ecf"
done

# enkf prep cyc spinup files
cd $ECF_DIR/scripts/enkf/prep
echo "Copy enkf prep cyc spinup files ..."
rm -f jrrfs_enkf_prep_cyc_spinup_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_prep_cyc_spinup_master.ecf jrrfs_enkf_prep_cyc_spinup_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_prep_cyc_spinup_member@|${mem_3d}|g" jrrfs_enkf_prep_cyc_spinup_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/prep/jrrfs_enkf_prep_cyc_spinup_mem${mem_3d}.ecf"
done

# enkf prep cyc spinup ensinit files
cd $ECF_DIR/scripts/enkf/prep
echo "Copy enkf prep cyc spinup ensinit files ..."
rm -f jrrfs_enkf_prep_cyc_spinup_ensinit_mem???.ecf
for mem in $(seq 1 30); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_enkf_prep_cyc_spinup_ensinit_master.ecf jrrfs_enkf_prep_cyc_spinup_ensinit_mem${mem_3d}.ecf
  sed -i -e "s|@enkf_prep_cyc_spinup_ensinit_member@|${mem_3d}|g" jrrfs_enkf_prep_cyc_spinup_ensinit_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/enkf/prep/jrrfs_enkf_prep_cyc_spinup_ensinit_mem${mem_3d}.ecf"
done

# ensf prep cyc files
cd $ECF_DIR/scripts/ensf/prep
echo "Copy ensf prep cyc files ..."
rm -f jrrfs_ensf_prep_cyc_mem???.ecf
for mem in $(seq 1 5); do
  mem_3d=$( printf "%03d" "${mem}" )
  cp jrrfs_ensf_prep_cyc_master.ecf jrrfs_ensf_prep_cyc_mem${mem_3d}.ecf
  sed -i -e "s|@ensf_prep_cyc_member@|${mem_3d}|g" jrrfs_ensf_prep_cyc_mem${mem_3d}.ecf
  add_to_tmpfile "$ECF_DIR/scripts/ensf/prep/jrrfs_ensf_prep_cyc_mem${mem_3d}.ecf"
done

# Create resource dependent files
if [ ${resource_config} == "NCO" ]; then
  cd $ECF_DIR/scripts/det/forecast
  for file in jrrfs_det_forecast jrrfs_det_forecast_long; do
    rm -f ${file}.ecf
    ln -s ${file}.ecf-prod-resource ${file}.ecf
    add_to_tmpfile "$ECF_DIR/scripts/det/forecast/${file}.ecf"
  done
else
  cd $ECF_DIR/scripts/det/forecast
  for file in jrrfs_det_forecast jrrfs_det_forecast_long; do
    rm -f ${file}.ecf
    ln -s ${file}.ecf-dev-resource ${file}.ecf
    add_to_tmpfile "$ECF_DIR/scripts/det/forecast/${file}.ecf"
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

# add created files/links to git info exclude
cd $ECF_DIR
exclude_path="${ECF_DIR}/../.git/info/exclude"
while read line; do
  tmpchkline=$(echo ${line} | sed "s|${ECF_DIR}|ecf|")
  # add line to git info exclude if not already present
  tmpchkcnt=$(grep "${tmpchkline}" ${exclude_path} | wc -l)
  if [[ $tmpchkcnt == 0 ]]; then
    echo "adding ${tmpchkline} to ${exclude_path}"
    echo ${tmpchkline} >> ${exclude_path}
  else
    echo "${tmpchkline} already in ${exclude_path}"
  fi
done < ${tmp_exclude}

echo "Removing temporary file: ${tmp_exclude}"
rm ${tmp_exclude}
