#!/bin/csh

if ( $# == 0 ) then
   cat << EOF_USAGE
Usage: source etc/lmod-setup.csh PLATFORM

OPTIONS:
   PLATFORM - name of machine you are building on
      (e.g. wcoss2 | hera | jet | orion | hercules )
EOF_USAGE
   exit 1
else
   set L_MACHINE=$1
endif

if ( "$L_MACHINE" != wcoss2 ) then
  source /etc/csh.login
endif
   
if ( "$L_MACHINE" = wcoss2 ) then
   module reset

else
   module purge
endif

