################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         rrfs_smokedust.sh
# Script description:  To generate the RAP and HYSPLIT look-alike smoke and dust 
#                      products for the Rapid Refresh Forecast System
#
# Author:      M Hu, G Manikin /  GSL, EMC         Date: 2021-12-06
#
# Script history log:
# 2021-12-06  M Hu, G Manikin  -- new script
# 2022-06-17  B Blake          -- separate smoke records into sfc and pbl files
# 2026-03-24  B Blake          -- adapted script for RRFS

set -xa

fhr=$1
grid=$2

mkdir -p ${DATA}/smoke_dust/${grid}
cd ${DATA}/smoke_dust/${grid}

# smoke/dust grids
# CONUS
if [ ${grid} = "227" ]; then
  export grid_specs="lambert:265:25:25 226.541:1473:5079 12.190:1025:5079"
  export rrfs_dust='YES'
# Alaska
elif [ ${grid} = "198" ]; then
  export grid_specs="nps:210:60 181.429:825:5953 40.53:553:5953"
  export rrfs_dust='NO'
# Hawaii
elif [ ${grid} = "196" ]; then
  export grid_specs="mercator:20.000000 198.475000:321:2500:206.131000 18.073000:225:2500:23.088000"
  export rrfs_dust='NO'
fi

export INPUTfile=${COMOUT}/rrfs.t${cyc}z.2dfld.3km.f${fhr}.na.grib2

# Create subset of fields to be posted
for aerosol in smoke dust
do
    for type in sfc pbl
    do
        export OUTPUTfile=rrfs.t${cyc}z.${aerosol}.${type}.f${fhr}.${grid}.grib2
        if [ ${aerosol} = "smoke" ] && [ ${type} = "sfc" ]; then
            wgrib2 ${INPUTfile} -match "MASSDEN:8 m above ground:.*aerosol=Particulate organic matter dry" -new_grid_winds grid -set_grib_type same -new_grid ${grid_specs} ${OUTPUTfile}
        elif [ ${aerosol} = "smoke" ] && [ ${type} = "pbl" ]; then
            wgrib2 ${INPUTfile} -match "COLMD:.*aerosol=Particulate organic matter dry" -new_grid_winds grid -set_grib_type same -new_grid ${grid_specs} ${OUTPUTfile}
        elif [ ${rrfs_dust} = "YES" ] && [ ${aerosol} = "dust" ] && [ ${type} = "sfc" ] && [ ${fhr} != "000" ]; then
            wgrib2 ${INPUTfile} -match "MASSDEN:8 m above ground:.*ave fcst:aerosol=Total aerosol:aerosol_size <1e-05" -new_grid_winds grid -set_grib_type same -new_grid ${grid_specs} ${OUTPUTfile}
        elif [ ${rrfs_dust} = "YES" ] && [ ${aerosol} = "dust" ] && [ ${type} = "pbl" ]; then
            wgrib2 ${INPUTfile} -match "COLMD:.*aerosol=Dust dry:aerosol_size <1e-05" -new_grid_winds grid -set_grib_type same -new_grid ${grid_specs} ${OUTPUTfile}
        fi

# Copy output file to umbrella directory for post processing.  These individual files will then be combined into one file at forecast hour 72.
        if [ -f ${OUTPUTfile} ]; then
            cpreq -p ${OUTPUTfile} ${umbrella_post_data}
            echo "${OUTPUTfile} copied to umbrella data directory"
        fi
    done
done
