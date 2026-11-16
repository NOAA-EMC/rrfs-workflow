#!/bin/bash
set -x

if (( $# == 0 )); then
   L_MACHINE="${MACHINE}"
   cat << EOF_USAGE
Usage: source etc/lmod-setup.sh PLATFORM

OPTIONS:
   PLATFORM - name of machine you are building on
      (e.g. wcoss2 | hera | jet | orion | hercules )
EOF_USAGE
   exit 1
else
   L_MACHINE="$1"
fi

if [[ "${L_MACHINE}" != "wcoss2" ]]; then
  [[ ${SHELLOPTS} =~ nounset ]] && has_mu=true || has_mu=false
  [[ ${SHELLOPTS} =~ errexit ]] && has_me=true || has_me=false
  if [[ "${has_mu}" == "true" ]]; then
    set +u
  fi
  if [[ "${has_me}" == "true" ]]; then
    set +e
  fi
  source /etc/profile
  if [[ "${has_mu}" == "true" ]]; then
    set -u
  fi
  if [[ "${has_me}" == "true" ]]; then
    set -e
  fi
fi

if [[ "${L_MACHINE}" == "wcoss2" ]]; then
   module reset
else
   module purge
fi