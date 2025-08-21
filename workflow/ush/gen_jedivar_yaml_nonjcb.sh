#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# shellcheck disable=SC1091
source init.sh

# --- Inputs and environment
DEFAULT_FILE="../exp.setup"
INPUT_FILE="${1:-$DEFAULT_FILE}"

# shellcheck disable=SC1090
source "$INPUT_FILE"

validated_yamls="${run_dir}/../../sorc/RDASApp/rrfs-test/validated_yamls"
cd "$validated_yamls" || exit 1

# --- Configurations
TEMPLATES_DIR="./templates"
BASIC_CONFIG="mpasjedi_hyb3denvar.yaml"
#BASIC_CONFIG="mpasjedi_3dvar.yaml"
OBTYPE_DIR="$TEMPLATES_DIR/obtype_config"
OUT="jedivar.yaml"
DISTRO="RoundRobin"
LENGTH=4

# --- Observation type configs
obtype_configs=(
    # Upper-air conventional
    "adpupa_airTemperature_120.yaml"
    "adpupa_airTemperature_132.yaml"
    "adpupa_specificHumidity_120.yaml"
    "adpupa_specificHumidity_132.yaml"
    "adpupa_stationPressure_120.yaml"
    "adpupa_winds_220.yaml"
    "adpupa_winds_232.yaml"

    "aircar_airTemperature_133.yaml"
    "aircar_specificHumidity_133.yaml"
    "aircar_winds_233.yaml"

    "aircft_airTemperature_130.yaml"
    "aircft_airTemperature_131.yaml"
    "aircft_airTemperature_134.yaml"
    "aircft_airTemperature_135.yaml"
    "aircft_specificHumidity_134.yaml"
    "aircft_winds_230.yaml"
    "aircft_winds_231.yaml"
    "aircft_winds_234.yaml"
    "aircft_winds_235.yaml"

    "proflr_winds_227.yaml"
    "vadwnd_winds_224.yaml"
    "rassda_airTemperature_126.yaml"

    # Surface conventional
    "adpsfc_airTemperature_181.yaml"
    "adpsfc_airTemperature_183.yaml"
    "adpsfc_airTemperature_187.yaml"
    "adpsfc_specificHumidity_181.yaml"
    "adpsfc_specificHumidity_183.yaml"
    "adpsfc_specificHumidity_187.yaml"
    "adpsfc_stationPressure_181.yaml"
    "adpsfc_stationPressure_187.yaml"
    "adpsfc_winds_281.yaml"
    "adpsfc_winds_284.yaml"
    "adpsfc_winds_287.yaml"

    "msonet_airTemperature_188.yaml"
    "msonet_specificHumidity_188.yaml"
    "msonet_stationPressure_188.yaml"
    "msonet_winds_288.yaml"

    "sfcshp_airTemperature_180.yaml"
    "sfcshp_airTemperature_182.yaml"
    "sfcshp_airTemperature_183.yaml"
    "sfcshp_specificHumidity_180.yaml"
    "sfcshp_specificHumidity_182.yaml"
    "sfcshp_specificHumidity_183.yaml"
    "sfcshp_stationPressure_180.yaml"
    "sfcshp_stationPressure_182.yaml"
    "sfcshp_winds_280.yaml"
    "sfcshp_winds_282.yaml"
    "sfcshp_winds_284.yaml"
)

# --- Temp files (auto-removed)
TMP_COMBINED=$(mktemp)
trap 'rm -f "$TMP_COMBINED" "$TMP_COMBINED.out"' EXIT
: > "$TMP_COMBINED"

echo "Building combined obtype yaml into $TMP_COMBINED..."
for ob in "${obtype_configs[@]}"; do
  src="$OBTYPE_DIR/$ob"
  if [[ -f "$src" ]]; then
    echo "  appending $ob"
    cat "$src" >> "$TMP_COMBINED"
  else
    echo "  WARNING: missing $src"
  fi
done

cp "$TMP_COMBINED" "${TMP_COMBINED}.out"

# --- Build super-YAML
cp "$TEMPLATES_DIR/basic_config/$BASIC_CONFIG" "$OUT"
#cp "/scratch4/NCEPDEV/fv3-cam/Donald.E.Lippi/RRFSv2/basic_config/$BASIC_CONFIG" "$OUT"

# Replace @OBSERVATIONS@ with obtype block
sed -i '/@OBSERVATIONS@/{
  r '"${TMP_COMBINED}.out"'
  d
}' "$OUT"

# --- Placeholder substitutions
date_pattern='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'

sed -i -E \
  -e "s/date: \&analysisDate '${date_pattern}'/date: \&analysisDate '@analysisDate@'/" \
  -e "s/begin: '${date_pattern}'/begin: '@beginDate@'/" \
  -e "s/seed_time: \"${date_pattern}\"/seed_time: '@analysisDate@'/" \
  -e "s/length: PT[0-9]H/length: 'PT${LENGTH}H'/" \
  -e "0,/filename: mpasin.nc/s/filename: mpasin.nc/filename: '@analysisFile@'/" \
  -e "0,/filename: mpasin.nc/s/filename: mpasin.nc/filename: '@backgroundFile@'/" \
  -e "s/name: accept/name: @analysisUse@/" \
  -e "s/@DISTRIBUTION@/${DISTRO}/" \
  "$OUT"

if [[ ${BASIC_CONFIG} == "mpasjedi_hyb3denvar.yaml" ]]; then
  # --- Hybrid weights
  if [[ "${HYB_WGT_ENS}" == "0" || "${HYB_WGT_ENS}" == "0.0" ]]; then
    sed -i '/covariance model: ensemble/,/weight:/d' "$OUT"
    sed -i '/- covariance:/ {N; /value: "@HYB_WGT_ENS@"/d;}' "$OUT"
  elif [[ "${HYB_WGT_STATIC}" == "0" || "${HYB_WGT_STATIC}" == "0.0" ]]; then
    sed -i '/covariance model: SABER/,/weight:/d' "$OUT"
    sed -i '/- covariance:/ {N; /value: "@HYB_WGT_STATIC@"/d;}' "$OUT"
  fi

  sed -i \
    -e "s/@HYB_WGT_STATIC@/${HYB_WGT_STATIC}/" \
    -e "s/@HYB_WGT_ENS@/${HYB_WGT_ENS}/" \
    "$OUT"
fi

# --- Copy to destinations
echo "Super YAML created in $OUT"
cp -p "$OUT" "${run_dir}/jedivar.yaml"

mkdir -p "${run_dir}/../../parm/baseline_jedi_yamls"
cp -p "$OUT" "${run_dir}/../../parm/baseline_jedi_yamls/jedivar.yaml"

echo "Generated jedivar.yaml to:"
echo "   ${run_dir}/../../parm/baseline_jedi_yamls/jedivar.yaml"

