#!/bin/bash

source ush/init.sh
source ush/detect_machine.sh
source exp.setup

validated_yamls="${run_dir}/../../sorc/RDASApp/rrfs-test/validated_yamls"
cd $validated_yamls

# Define the basic configuration YAML
basic_config="mpasjedi_hyb3denvar.yaml"

# Which observation distribution to use? Halo or RoundRobin
distribution="RoundRobin"

# Define all observation type configurations
obtype_configs=(
    #"adpsfc_airTemperature_187.yaml"
    #"adpsfc_specificHumidity_187.yaml"
    #"adpsfc_stationPressure_187.yaml"
    #"adpsfc_winds_287.yaml"
    "adpupa_airTemperature_120.yaml"
    #"adpupa_winds_220.yaml"
    #"adpupa_specificHumidity_120.yaml"
    #"aircar_airTemperature_133.yaml"
    #"aircar_winds_233.yaml"
    #"aircar_specificHumidity_133.yaml"
    #"aircft_airTemperature_130.yaml"
    #"aircft_airTemperature_131.yaml"
    #"aircft_airTemperature_134.yaml"
    #"aircft_airTemperature_135.yaml"
    #"aircft_specificHumidity_134.yaml"
    #"aircft_winds_230.yaml"
    #"aircft_winds_231.yaml"
    #"aircft_winds_234.yaml"
    #"aircft_winds_235.yaml"
    #"msonet_airTemperature_188.yaml"
    #"msonet_specificHumidity_188.yaml"
    #"msonet_stationPressure_188.yaml"
    #"msonet_winds_288.yaml"
    #"proflr_winds_227.yaml"
    #"rassda_airTemperature_126.yaml"
    #"vadwnd_winds_224.yaml"
)

rm -f jedivar.yaml  # Remove any existing file
rm -f temp.yaml  # Remove any existing file

# Process each YAML file
declare -A processed_groups

for config in "${obtype_configs[@]}"; do
    # Extract the 6-letter identifier (e.g., "msonet" from "msonet_airTemperature_188.yaml")
    obtype_group="${config:0:6}"

    # Derive the observation file path
    obs_filename="data/obs/ioda_${obtype_group}.nc"

    # Ensure we append only once per obtype group
    if [[ -z "${processed_groups[$obtype_group]}" ]]; then
        echo "Appending YAMLs for $obtype_group -> $obs_filename"
        processed_groups[$obtype_group]=1
    fi

    # Append YAML content
    cat "./templates/obtype_config/$config" >> temp.yaml

    # Replace OBSFILE local placeholder in loop
    sed -i "s#@OBSFILE@#$obs_filename#" temp.yaml
done

# Copy the basic configuration yaml into the super yaml
cp -p templates/basic_config/$basic_config ./jedivar.yaml

# Replace @OBSERVATIONS@ placeholder with the contents of the combined yaml
sed -i '/@OBSERVATIONS@/{
    r ./'"temp.yaml"'
    d
}' ./jedivar.yaml
rm -f temp.yaml # Clean up temporary yaml

# Temporary solution, replace actual date strings with placeholders
date_pattern="[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"
sed -i -E \
    -e "s/date: &analysisDate '$date_pattern'/date: &analysisDate '@analysisDate@'/" \
    -e "s/begin: '$date_pattern'/begin: '@beginDate@'/" \
    -e "s/seed_time: \"$date_pattern\"/seed_time: '@analysisDate@'/" \
    -e "s/length: PT[0-9]H/length: 'PT@length@H'/" \
    ./jedivar.yaml

echo "Super YAML created in jedivar.yaml"

cp -p jedivar.yaml ${run_dir}/../../parm/.
#cp jedivar.yaml $EXPDIR/.
ln -sf ${run_dir}/../../parm/jedivar.yaml $EXPDIR/.

