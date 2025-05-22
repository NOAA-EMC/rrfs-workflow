#! /usr/bin/env bash
#
# Author: Larissa Reames CIWRO/NOAA/NSSL/FRDD

#set -eux

target=${1:-"NULL"}
compiler=${2:-"intel"}
debug=${3:-"false"}

# If target is not set
if [[ "$target" == "NULL" ]]; then
    source ./machine-setup.sh
fi

echo "target=$target, compiler=$compiler"

# Check for platform/compiler configuration file
if [[ ! -f modulefiles/build.$target && ! -f modulefiles/build.$target.$compiler.lua && ! -f modulefiles/build.$target.$compiler ]]; then
    echo "Platform ${target} configuration file not found in ./modulefiles, neither build.$target nor build.$target.$compiler.lua"
    exit 1
fi

if [[ "$target" == "vecna" || "$compiler" == "gnu" ]]; then
    echo "Use platform configuration file: build.$target.$compiler"
    source ./modulefiles/build.$target.$compiler > /dev/null
elif [[ "$target" == "linux.*" || "$target" == "macosx.*" ]]; then
    unset -f module
    echo "Use platform configuration file: build.$target"
    source ./modulefiles/build.$target > /dev/null
else
    echo "Use platform configuration file: build.$target.$compiler.lua"
    module use ./modulefiles
    module load build.$target.$compiler.lua
    module list
fi

CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=../ -DEMC_EXEC_DIR=ON -DBUILD_TESTING=OFF"
if [[ "$target" == "wcoss2" ]]; then
    CMAKE_FLAGS="${CMAKE_FLAGS} -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=CC -DCMAKE_Fortran_COMPILER=ftn"
elif [[ "$compiler" == "intel" ]]; then
    CMAKE_FLAGS="${CMAKE_FLAGS} -DCMAKE_C_COMPILER=icc -DCMAKE_CXX_COMPILER=icpc -DCMAKE_Fortran_COMPILER=ifort"
elif [[ "$compiler" == "gnu" ]]; then
    CMAKE_FLAGS="${CMAKE_FLAGS} -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_Fortran_COMPILER=gfortran"
fi
export debug=true
if [[ "${debug}" == "true" ]]; then
    CMAKE_FLAGS="${CMAKE_FLAGS} -DCMAKE_BUILD_TYPE=Debug"
else
    CMAKE_FLAGS="${CMAKE_FLAGS} -DCMAKE_BUILD_TYPE=Release"
fi

# for a clean build folder
rm -fr ./build
mkdir ./build && cd ./build || exit 0

# do the building
cmake .. ${CMAKE_FLAGS}

make -j 8 VERBOSE=1
make install

exit 0
