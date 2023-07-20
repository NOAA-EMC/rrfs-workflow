#!/bin/bash

if [[ $# -lt 2 ]] || [[ "$@" == "--help" ]] || [[ "$@" == "-h" ]]; then
    echo "Usage: $0 s_suffix t_suffix"
    echo " Example: $0 DIR dir"
    exit 0
fi

# directories to look for model variables to rename
mdirs=( "doc" "jobs" "parm" "scripts" "tests" "ush" )

# model variables to rename
mvars=( "USH" "SCRIPTS" "JOBS" "SORC" "PARM" "EXEC" )

function replace() {
    for i in ${mdirs[@]}; do
        echo "Replacing ${1^^}$2 by ${1^^}$3 in directory $i/"
        find $i/ -type f -exec sed -i "s/${1^^}${2}/${1^^}${3}/g" {} \;
        find $i/ -type f -exec sed -i "s/${1}${2}/${1}${3}/g" {} \;
    done
}
for i in ${mvars[@]}; do
   replace $i $1 $2
done

