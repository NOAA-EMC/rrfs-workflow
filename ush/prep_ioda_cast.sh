#!/usr/bin/env bash
set -euo pipefail

module load nco

grp="MetaData"

usage() {
  cat <<EOF
Usage:
  $0 -i <input.nc> [-o <output.nc>]

Behavior:
  - Scans only variables declared in /${grp}
  - Skips variables named Location and dateTime
  - Skips variables already of type string, float, or double
  - Converts integer-like variables to float
  - Overwrites the input file by default unless -o is given

Examples:
  $0 -i ioda_adpsfc.nc
  $0 -i ioda_adpsfc.nc -o ioda_adpsfc_float.nc
EOF
}

in_nc=""
out_nc=""

while getopts ":i:o:h" opt; do
  case "$opt" in
    i) in_nc="$OPTARG" ;;
    o) out_nc="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "ERROR: invalid option -$OPTARG" >&2; usage; exit 2 ;;
    :)  echo "ERROR: option -$OPTARG requires an argument" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$in_nc" ]]; then
  usage
  exit 2
fi

# Default behavior: overwrite input file
if [[ -z "$out_nc" ]]; then
  out_nc="$in_nc"
fi

for exe in ncks ncap2 ncdump mktemp awk grep cp mv; do
  command -v "$exe" >/dev/null 2>&1 || {
    echo "ERROR: '$exe' not found in PATH" >&2
    exit 1
  }
done

[[ -f "$in_nc" ]] || {
  echo "ERROR: input file not found: $in_nc" >&2
  exit 1
}

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

out_stage="$tmpdir/out_stage.nc"
cp -f "$in_nc" "$out_stage"

# Confirm group exists without pipefail issues
hdr="$(ncdump -h "$in_nc")"
if ! grep -Fq "group: ${grp} {" <<< "$hdr"; then
  echo "ERROR: group '${grp}' not found in $in_nc" >&2
  exit 1
fi

# Return all variable names declared only inside /MetaData variables: block
get_metadata_vars() {
  local file="$1"
  local hdr
  hdr="$(ncdump -h "$file")"

  awk -v grp="$grp" '
    $0 ~ ("^group: " grp " \\{") {in_grp=1; in_vars=0; next}
    in_grp && $0 ~ /^  variables:/ {in_vars=1; next}
    in_grp && $0 ~ /^  } \/\/ group / {in_grp=0; in_vars=0; next}

    in_grp && in_vars {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ /^(byte|ubyte|char|string|short|ushort|int|uint|int64|uint64|float|double)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\(/) {
        split(line, a, /[[:space:](]+/)
        print a[2]
      }
    }
  ' <<< "$hdr"
}

# Return declared type for /MetaData/<var> only
get_declared_type() {
  local file="$1"
  local var="$2"
  local hdr
  hdr="$(ncdump -h "$file")"

  awk -v grp="$grp" -v var="$var" '
    $0 ~ ("^group: " grp " \\{") {in_grp=1; in_vars=0; next}
    in_grp && $0 ~ /^  variables:/ {in_vars=1; next}
    in_grp && $0 ~ /^  } \/\/ group / {in_grp=0; in_vars=0; next}

    in_grp && in_vars {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ ("^(byte|ubyte|char|string|short|ushort|int|uint|int64|uint64|float|double)[[:space:]]+" var "\\(")) {
        split(line, a, /[[:space:]]+/)
        print a[1]
        found=1
        exit
      }
    }

    END {
      if (!found) exit 1
    }
  ' <<< "$hdr"
}

# Quick existence test for /MetaData/<var>
var_exists() {
  local file="$1"
  local var="$2"
  ncks -m -g "$grp" -v "$var" "$file" >/dev/null 2>&1
}

mapfile -t vars < <(get_metadata_vars "$in_nc")

if [[ ${#vars[@]} -eq 0 ]]; then
  echo "ERROR: no variables found in /${grp}" >&2
  exit 1
fi

echo "Input : $in_nc"
echo "Output: $out_nc"
echo "Group : /$grp"
echo

for var in "${vars[@]}"; do
  echo "==> Processing /${grp}/${var}"

  # Explicit exclusions
  if [[ "$var" == "Location" || "$var" == "dateTime" ]]; then
    echo "  SKIP: excluded variable"
    echo
    continue
  fi

  if ! var_exists "$out_stage" "$var"; then
    echo "  SKIP: variable not found"
    echo
    continue
  fi

  declared_type="$(get_declared_type "$out_stage" "$var" || true)"

  if [[ -z "$declared_type" ]]; then
    echo "  SKIP: could not determine type"
    echo
    continue
  fi

  case "$declared_type" in
    string)
      echo "  SKIP: string variable"
      echo
      continue
      ;;
    float)
      echo "  SKIP: already float"
      echo
      continue
      ;;
    double)
      echo "  SKIP: already double"
      echo
      continue
      ;;
    int|short|byte|ubyte|ushort|uint|int64|uint64)
      echo "  INFO: converting $declared_type -> float"
      ;;
    *)
      echo "  SKIP: unsupported type '$declared_type'"
      echo
      continue
      ;;
  esac

  root_extract="$tmpdir/${var}_root.nc"
  root_float="$tmpdir/${var}_root_float.nc"

  # Extract /MetaData/<var> and flatten to root
  if ! ncks -O -G : -v "${grp}/${var}" "$out_stage" "$root_extract" >/dev/null 2>&1; then
    echo "  WARN: failed to extract variable, skipping"
    echo
    continue
  fi

  # Cast root variable to float
  if ! ncap2 -O -s "${var}=float(${var})" "$root_extract" "$root_float" >/dev/null 2>&1; then
    echo "  WARN: cast failed, leaving original unchanged"
    echo
    continue
  fi

  # Remove original grouped variable
  if ! ncks -O -C -x -v "${grp}/${var}" "$out_stage" "$out_stage" >/dev/null 2>&1; then
    echo "  WARN: failed to remove original variable, skipping"
    echo
    continue
  fi

  # Append float variable back into /MetaData
  if ! ncks -A -G "${grp}:1" -v "${var}" "$root_float" "$out_stage" >/dev/null 2>&1; then
    echo "  WARN: failed to append float variable back into group"
    echo
    continue
  fi

  # Verify
  new_type="$(get_declared_type "$out_stage" "$var" || true)"
  if [[ "$new_type" == "float" ]]; then
    echo "  DONE: converted to float"
  else
    echo "  WARN: replacement completed but could not verify float type"
  fi
  echo
done

mkdir -p "$(dirname "$out_nc")"
mv -f "$out_stage" "$out_nc"

echo "All done."
echo "Wrote: $out_nc"
