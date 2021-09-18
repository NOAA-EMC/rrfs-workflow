#!/bin/bash
set -eu

# Initialize and load modules
if [[ -d /dcom && -d /hwrf ]] ; then
    . /usrx/local/Modules/3.2.10/init/sh
    PLATFORM=wcoss
    . $MODULESHOME/init/sh
elif [[ -d /cm ]] ; then
    . $MODULESHOME/init/sh
    PLATFORM=wcoss_c
elif [[ -d /ioddev_dell ]]; then
    . $MODULESHOME/init/sh
    PLATFORM=wcoss_d
elif [[ -d /scratch1 ]] ; then
    . /apps/lmod/lmod/init/sh
    PLATFORM=hera
elif [[ -d /carddata ]] ; then
    . /opt/apps/lmod/3.1.9/init/sh
    PLATFORM=s4
elif [[ -d /jetmon ]] ; then
    . $MODULESHOME/init/sh
    PLATFORM=jet
elif [[ -d /glade ]] ; then
    . $MODULESHOME/init/sh
    PLATFORM=cheyenne
elif [[ -d /sw/gaea ]] ; then
    . /opt/cray/pe/modules/3.2.10.5/init/sh
    PLATFORM=gaea
elif [[ -d /work ]]; then
    . $MODULESHOME/init/sh
    PLATFORM=orion
else
    echo "unknown PLATFORM"
    exit 9
fi

#cd to location of script
MYDIR=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )" && pwd -P)

usage () {
  echo -e "\nExample Usage: "
  echo "  $0        (show this help)"
  echo "  $0 intel  (build GSI using Intel compiler)"
  echo "  $0 gnu    (build GSI using GNU compiler)"
  echo "  $0 kjet   (build GSI using Intel compiler and kjet specfici optimization)"
  echo "            ** kjet option should be used by real time deployment on Jet**   "
  echo "  $0 help   (show this help)"
  echo ""
  echo " The build script will automatically determine current HPC platform."
  echo " Don't use the 'kjet' optin if you will run GSI on other jet (such as xjet,etc) or you are not on Jet"
  echo ""
  echo "NOTE: This script is for internal developer use only;"
  echo "See User's Guide for detailed build instructions"
}

opt=${1:-""}
COMPILER="intel"
KJET=""
if [[ ! -z $opt ]]; then
  case $opt in
    kjet|kJet|KJET|Kjet|kJET)
      KJET="kjet"
       ;;
    --help|-h|help)
      usage
      exit 0
      ;;
    intel|gnu)
     COMPILER="${opt}"
      ;;
    *)
     echo -e "\n        unknown option: ${opt}"
     usage
     exit 0
      ;;
  esac
else
  usage
  exit 0
fi

ENV_FILE="env/build_${PLATFORM}_${COMPILER}.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: environment file ($ENV_FILE) does not exist for this platform/compiler combination"
  echo "PLATFORM=$PLATFORM"
  echo "COMPILER=$COMPILER"
  echo ""
  echo "See User's Guide for detailed build instructions"
  exit 64
fi

# If build directory already exists, offer a choice
BUILD_DIR=${MYDIR}/build

if [ -d "${BUILD_DIR}" ]; then
  while true; do
    echo "Build directory (${BUILD_DIR}) already exists! Please choose what to do:"
    echo ""
    echo "[R]emove the existing directory"
    echo "[C]ontinue building in the existing directory"
    echo "[Q]uit this build script"
    read -p "Choose an option (R/C/Q):" choice
    case $choice in
      [Rr]* ) rm -rf ${BUILD_DIR}; break;;
      [Cc]* ) break;;
      [Qq]* ) exit;;
      * ) echo "Invalid option selected.\n";;
    esac
  done
fi

# Source the README file for this platform/compiler combination, then build the code
. $ENV_FILE

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
cmake .. -DCMAKE_INSTALL_PREFIX=..
make -j ${BUILD_JOBS:-4}

cd ${MYDIR}/src/gsi
./ush/build.comgsi ${KJET}
cp ${MYDIR}/src/gsi/build/bin/gsi.x ${MYDIR}/bin/gsi.x

. ${MYDIR}/${ENV_FILE}_DA
cd ${MYDIR}/src/rrfs_utl
mkdir -p build
cd build
cmake ..
make -j ${BUILD_JOBS:-4}
mkdir -p ${MYDIR}/bin
cp ./bin/* ${MYDIR}/bin/.

exit 0
