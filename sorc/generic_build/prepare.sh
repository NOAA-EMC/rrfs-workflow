#!/usr/bin/env bash
#
# shellcheck disable=SC1091
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
HOMErrfs="${run_dir}/../.."

### use generic module files
declare -A mappings
mappings["rrfs"]="${HOMErrfs}/modulefiles/rrfs"
mappings["rdas"]="${HOMErrfs}/sorc/RDASApp/modulefiles/RDAS"
mappings["mpassit"]="${HOMErrfs}/sorc/MPASSIT/modulefiles"
mappings["upp"]="${HOMErrfs}/sorc/UPP/modulefiles"
mappings["util"]="${HOMErrfs}/sorc/RRFS_UTILS/modulefiles"
mappings["blend"]="${HOMErrfs}/sorc/MPASBlend/modulefiles"

cd "${run_dir}/modulefiles" || exit 1
echo "copy hostgeneric module files to the corresponding locations ..."
for file in *.lua; do
  key="${file%%-*}"
  lua="${file#*-}"
  cp "${file}" "${mappings[${key}]}/${lua}"
done

### tweak RDASApp to avoid spending long time on downloading JCSDA test data not needed by rrfs-workflow
echo "tweak RDASApp ..."
cd "${HOMErrfs}/sorc/RDASApp/fix/crtm" || exit 1
rm -rf  2.4.1_skylab_4.0 fix_REL-3.1.1.2
mkdir -p 2.4.1_skylab_4.0 fix_REL-3.1.1.2/fix
cd "${HOMErrfs}/sorc/RDASApp/fix/jcsda" || exit 1
rm -rf ioda-data  ufo-data
mkdir -p ioda-data/testinput_tier_1  ufo-data/testinput_tier_1

### print out information
echo "Done!"
cat << 'EOF'
# set the following variables accordingly and then run "build.all" or "build.all noda"

export MACHINE=hostgeneric
export MACHINE_ID=hostgeneric  # for UPP
export mpas_compiler_str="ifort_icx"
export compiler=intel
export COMPILER=intel
EOF
