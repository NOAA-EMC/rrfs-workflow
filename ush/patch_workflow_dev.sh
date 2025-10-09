#! /bin/sh

# Updates namelist files for 52 node configuration
#


files="../parm/config/det/input.nml_18h ../parm/config/det/input.nml_restart_18h"

# 53,128 --> 43,64
#

for fl in $files
do
	cat $fl | sed s:53:43:g > ${fl}_new
	cat ${fl}_new | sed s:128:64:g > ${fl}
	rm -f ${fl}_new
done


files="../parm/config/det/input.nml_restart_long ../parm/config/det/input.nml_long"

# 71,128 --> 43,64
#
for fl in $files
do
	cat $fl | sed s:71:43:g > ${fl}_new
	cat ${fl}_new | sed s:128:64:g > ${fl}
	rm -f ${fl}_new
done

files="../parm/config/det/input.nml_restart_spinupcyc ../parm/config/det/input.nml_spinupcyc"
# 29,43 --> 43,64
#
for fl in $files
do
	cat $fl | sed s:29:43:g > ${fl}_new
	mv ${fl}_new ${fl}
done


files="../parm/config/ensf/input.nml_restart_stoch_ensphy?"
#
# 45,128 --> 50,64
#
for fl in $files
do
	cat $fl | sed s:45:50:g > ${fl}_new
	cat ${fl}_new | sed s:128:64:g > ${fl}
	rm -f ${fl}_new
done


# point at dev version of FIX workflow.config file
#

file="../scripts/exrrfs_forecast.sh"


cat ${file} | sed s:workflow.conf:workflow.conf_dev:g > ${file}_new
mv ${file}_new ${file}

