#!/bin/bash
set -x

source ${FIXrrfs}/workflow/${WGF}/workflow.conf

export FIX_UPP="${FIXrrfs}/upp"

#
#-----------------------------------------------------------------------
#
# Source the bash utility functions.
#
#-----------------------------------------------------------------------
#
. $USHrrfs/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that runs the post-processor (UPP) on
the output files corresponding to a specified forecast hour.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set environment
#
#-----------------------------------------------------------------------
#
ulimit -a

case $MACHINE in

  "WCOSS2")
    export OMP_NUM_THREADS=1
    ncores=$(( NNODES_PRDGEN*PPN_PRDGEN))
    APRUN="mpiexec -n ${ncores} -ppn ${PPN_PRDGEN}"
    ;;

  "HERA")
    APRUN="srun --export=ALL"
    ;;

  "ORION")
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=1024M
    APRUN="srun"
    ;;

  "HERCULES")
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=1024M
    APRUN="srun"
    ;;

  "JET")
    APRUN="srun"
    ;;

  *)
    err_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN = \"$APRUN\""
    ;;

esac
#
#-----------------------------------------------------------------------
#
# Get the cycle date and hour (in formats of yyyymmdd and hh, respectively)
# from CDATE.
#
#-----------------------------------------------------------------------
#
yyyymmdd=${CDATE:0:8}
hh=${CDATE:8:2}
cyc=$hh
fhr=${FHR:-}
#
#-----------------------------------------------------------------------
#
# A separate ${post_fhr} forecast hour variable is required for the post
# files, since they may or may not be three digits long, depending on the
# length of the forecast.
#
#-----------------------------------------------------------------------
#
len_fhr=${#fhr}
if [ ${len_fhr} -eq 9 ]; then
  post_min=${fhr:4:2}
  if [ ${post_min} -lt 15 ]; then
    post_min=00
  fi
else
  post_min=00
fi

subh_fhr=${fhr}
if [ ${len_fhr} -eq 2 ]; then
  post_fhr=${fhr}00
elif [ ${len_fhr} -eq 3 ]; then
  if [ "${fhr:0:1}" = "0" ]; then
    post_fhr="${fhr:1}00"
  else
    post_fhr=${fhr}00
  fi
elif [ ${len_fhr} -eq 9 ]; then
  if [ "${fhr:0:1}" = "0" ]; then
    if [ ${post_min} -eq 00 ]; then
      post_fhr="${fhr:1:2}00"
      subh_fhr="${fhr:0:3}"
    else
      post_fhr="${fhr:1:2}${fhr:4:2}"
    fi
  else
    if [ ${post_min} -eq 00 ]; then
      post_fhr="${fhr:0:3}00"
      subh_fhr="${fhr:0:3}"
    else
      post_fhr="${fhr:0:3}${fhr:4:2}"
    fi
  fi
else
  err_exit "\
The \${fhr} variable contains too few or too many characters:
  fhr = \"$fhr\""
fi

# replace fhr with subh_fhr
echo "fhr=${fhr} and subh_fhr=${subh_fhr}"
fhr=${subh_fhr}
#
gridname=""
gridspacing=""
if [ "${PREDEF_GRID_NAME}" = "RRFS_FIREWX_1.5km" ]; then
  gridname="firewx"
  gridspacing="1p5km"
elif [ "${PREDEF_GRID_NAME}" = "RRFS_NA_3km" ]; then
  gridname="na"
  gridspacing="3km"
fi
#
net4=$(echo ${NET:0:4} | tr '[:upper:]' '[:lower:]')
#
# Include member number with ensemble forecast output
if [ ${DO_ENSFCST} = "TRUE" ]; then
  prslev=${net4}.t${cyc}z.${mem_num}.prslev.${gridspacing}.f${fhr}.${gridname}.grib2
  natlev=${net4}.t${cyc}z.${mem_num}.natlev.${gridspacing}.f${fhr}.${gridname}.grib2
  fld2d=${net4}.t${cyc}z.${mem_num}.2dfld.${gridspacing}.f${fhr}.${gridname}.grib2
  subset=${net4}.t${cyc}z.${mem_num}.subset.${gridspacing}.f${fhr}.${gridname}.grib2
else
  prslev=${net4}.t${cyc}z.prslev.${gridspacing}.f${fhr}.${gridname}.grib2
  natlev=${net4}.t${cyc}z.natlev.${gridspacing}.f${fhr}.${gridname}.grib2
  fld2d=${net4}.t${cyc}z.2dfld.${gridspacing}.f${fhr}.${gridname}.grib2
  subset=${net4}.t${cyc}z.subset.${gridspacing}.f${fhr}.${gridname}.grib2
  fld2d_subh=${net4}.t${cyc}z.2dfld.${gridspacing}.subh.f${fhr}.${gridname}.grib2
fi

# extract the output fields for the subset files
if [ "${PREDEF_GRID_NAME}" != "RRFS_FIREWX_1.5km" ]; then
  wgrib2 ${COMOUT}/${fld2d} | grep -F -f ${FIX_UPP}/subset_fields_2dfld.txt | wgrib2 -i -grib ${DATA}/${subset} ${COMOUT}/${fld2d}
  wgrib2 ${COMOUT}/${prslev} | grep -F -f ${FIX_UPP}/subset_fields_prslev.txt | wgrib2 -i -append -grib ${DATA}/${subset} ${COMOUT}/${prslev}

  if [ ${DO_ENSFCST} != "TRUE" ]; then
    wgrib2 ${COMOUT}/${natlev} | grep -F -f ${FIX_UPP}/subset_fields_natlev.txt | wgrib2 -i -append -grib ${DATA}/${subset} ${COMOUT}/${natlev}
    export err=$?; err_chk
  fi

  cpreq ${DATA}/${subset}  ${COMOUT}/${subset}
fi

# create index files
if [ -s ${COMOUT}/${prslev} ]; then
  wgrib2 ${COMOUT}/${prslev} -s > ${COMOUT}/${prslev}.idx
fi
if [ -s ${COMOUT}/${natlev} ]; then
  wgrib2 ${COMOUT}/${natlev} -s > ${COMOUT}/${natlev}.idx
fi
if [ -s ${COMOUT}/${fld2d} ]; then
  wgrib2 ${COMOUT}/${fld2d} -s > ${COMOUT}/${fld2d}.idx
fi
if [ -s ${COMOUT}/${subset} ]; then
  wgrib2 ${COMOUT}/${subset} -s > ${COMOUT}/${subset}.idx
fi

if [ "${DO_ENSFCST}" != "TRUE" ] && [ ${fhr} != '000' ] && [ -e $COMOUT/${fld2d_subh} ]; then
  wgrib2 ${COMOUT}/${fld2d_subh} -s > ${COMOUT}/${fld2d_subh}.idx
fi

#  Generate products
if [ ${WGF} = "det" ] || [ ${WGF} = "ensf" ]; then
  #
  # Processing for the RRFS deterministic and ensemble forecasts
  #
  DATAprdgen=$DATA/prdgen_${fhr}
  mkdir -p $DATAprdgen

  wgrib2 ${COMOUT}/${prslev} >& $DATAprdgen/prslevf${fhr}.txt
  wgrib2 ${COMOUT}/${fld2d} >& $DATAprdgen/2dfldf${fhr}.txt

  # Create parm files for subsetting on the fly - do it for each forecast hour
  # 3 prslev subpieces for CONUS and Alaska grids
  sed -n -e '1,225p' $DATAprdgen/prslevf${fhr}.txt >& $DATAprdgen/conus_ak_1.txt
  sed -n -e '226,450p' $DATAprdgen/prslevf${fhr}.txt >& $DATAprdgen/conus_ak_2.txt
  sed -n -e '451,$p' $DATAprdgen/prslevf${fhr}.txt >& $DATAprdgen/conus_ak_3.txt
  # 1 prslev subpiece for Hawaii and Puerto Rico grids
  sed -n -e '1,$p' $DATAprdgen/prslevf${fhr}.txt >& $DATAprdgen/hi_pr_1.txt
  # 1 2dfld subpiece for all grids
  sed -n -e '1,$p' $DATAprdgen/2dfldf${fhr}.txt >& $DATAprdgen/conus_ak_4.txt
  sed -n -e '1,$p' $DATAprdgen/2dfldf${fhr}.txt >& $DATAprdgen/hi_pr_2.txt

  # Create script to execute production generation tasks in parallel using CFP
  tasks=(3 3 1 1)
  domains=(conus ak hi pr)
  count=0
  for domain in ${domains[@]}
  do
    for task in $(seq ${tasks[count]})
    do
      mkdir -p $DATAprdgen/prdgen_${domain}_${task}
      echo "$USHrrfs/prdgen/rrfs_prdgen_subpiece.sh $fhr $cyc $task $domain $prslev ${DATAprdgen} ${COMOUT}" >> $DATAprdgen/poescript_${fhr}
    done
    count=$count+1
  done
# Add 2dfld tasks to the parallel script
  mkdir -p $DATAprdgen/prdgen_conus_4
  echo "$USHrrfs/prdgen/rrfs_prdgen_subpiece.sh $fhr $cyc 4 conus $fld2d ${DATAprdgen} ${COMOUT}" >> $DATAprdgen/poescript_${fhr}
  mkdir -p $DATAprdgen/prdgen_ak_4
  echo "$USHrrfs/prdgen/rrfs_prdgen_subpiece.sh $fhr $cyc 4 ak $fld2d ${DATAprdgen} ${COMOUT}" >> $DATAprdgen/poescript_${fhr}
  mkdir -p $DATAprdgen/prdgen_hi_2
  echo "$USHrrfs/prdgen/rrfs_prdgen_subpiece.sh $fhr $cyc 2 hi $fld2d ${DATAprdgen} ${COMOUT}" >> $DATAprdgen/poescript_${fhr}
  mkdir -p $DATAprdgen/prdgen_pr_2
  echo "$USHrrfs/prdgen/rrfs_prdgen_subpiece.sh $fhr $cyc 2 pr $fld2d ${DATAprdgen} ${COMOUT}" >> $DATAprdgen/poescript_${fhr}

  chmod 775 $DATAprdgen/poescript_${fhr}

  # Execute the script
  export CMDFILE=$DATAprdgen/poescript_${fhr} 
  mpiexec -np 12 --cpu-bind core cfp $CMDFILE >>$pgmout 2>errfile
  export err=$?; err_chk

  # reassemble the CONUS and Alaska prslev output grids and send to COM
  tasks=(3 3)
  domains=(conus ak)
  count=0
  for domain in ${domains[@]}
  do

    DBNDOM="${domain^^}"
    outspacing=${gridspacing}
    if [ ${DO_ENSFCST} = "TRUE" ]; then
      for task in $(seq ${tasks[count]})
      do
        cat $DATAprdgen/prdgen_${domain}_${task}/${domain}_${task}.grib2 >> ${DATAprdgen}/rrfs.t${cyc}z.${mem_num}.prslev.${outspacing}.f${fhr}.${domain}.grib2
      done
      if [[ $SENDCOM = 'YES' ]]; then
        cpreq ${DATAprdgen}/rrfs.t${cyc}z.${mem_num}.prslev.${outspacing}.f${fhr}.${domain}.grib2 ${COMOUT}
        wgrib2 ${COMOUT}/rrfs.t${cyc}z.${mem_num}.prslev.${outspacing}.f${fhr}.${domain}.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.${mem_num}.prslev.${outspacing}.f${fhr}.${domain}.grib2.idx
      fi
    else
      for task in $(seq ${tasks[count]})
      do
        cat $DATAprdgen/prdgen_${domain}_${task}/${domain}_${task}.grib2 >> ${DATAprdgen}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2
      done
      if [[ $SENDCOM = 'YES' ]]; then
        cpreq ${DATAprdgen}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2 ${COMOUT}
        wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2.idx
      fi

      if [[ ${SENDDBN} = "YES" ]] ; then
        if (( 10#$cyc % 3 == 0 )); then
            $DBNROOT/bin/dbn_alert MODEL RRFS_DET_${DBNDOM} $job \
                ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2
	    $DBNROOT/bin/dbn_alert MODEL RRFS_DET_${DBNDOM}_IDX $job \
                ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2.idx
        fi
      fi  #SENDDBN
    fi
    count=$count+1
  done

  # Send Hawaii/Puerto Rico prslev output to COM
  domains=(hi pr)
  for domain in ${domains[@]}
  do
    DBNDOM="${domain^^}"
    outspacing="2p5km"
    if [ ${DO_ENSFCST} = "TRUE" ]; then
      if [[ $SENDCOM = 'YES' ]]; then
        cpreq ${DATAprdgen}/prdgen_${domain}_1/${domain}_1.grib2 ${COMOUT}/rrfs.t${cyc}z.${mem_num}.prslev.${outspacing}.f${fhr}.${domain}.grib2
        wgrib2 ${COMOUT}/rrfs.t${cyc}z.${mem_num}.prslev.${outspacing}.f${fhr}.${domain}.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.${mem_num}.prslev.${outspacing}.f${fhr}.${domain}.grib2.idx
      fi
    else
      if [[ $SENDCOM = 'YES' ]]; then
        cpreq ${DATAprdgen}/prdgen_${domain}_1/${domain}_1.grib2 ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2
        wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2.idx
      fi
      if [[ ${SENDDBN} = "YES" ]] ; then
        if (( 10#$cyc % 3 == 0 )); then
            $DBNROOT/bin/dbn_alert MODEL RRFS_DET_${DBNDOM} $job \
                ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2
            $DBNROOT/bin/dbn_alert MODEL RRFS_DET_${DBNDOM}_IDX $job \
                ${COMOUT}/rrfs.t${cyc}z.prslev.${outspacing}.f${fhr}.${domain}.grib2.idx
        fi
      fi  #SENDDBN
    fi
  done

  # Send 2dfld output (all domains) to COM
  domains=(conus ak hi pr)
  for domain in ${domains[@]}
  do
    DBNDOM="${domain^^}"
    if [[ $domain = "conus" || $domain = "ak" ]]; then
      outspacing="3km"
      task="4"
    elif [[ $domain = "hi" || $domain = "pr" ]]; then
      outspacing="2p5km"
      task="2"
    fi

    if [ ${DO_ENSFCST} = "TRUE" ]; then
      if [[ $SENDCOM = 'YES' ]]; then
        cpreq ${DATAprdgen}/prdgen_${domain}_${task}/${domain}_${task}.grib2 ${COMOUT}/rrfs.t${cyc}z.${mem_num}.2dfld.${outspacing}.f${fhr}.${domain}.grib2
        wgrib2 ${COMOUT}/rrfs.t${cyc}z.${mem_num}.2dfld.${outspacing}.f${fhr}.${domain}.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.${mem_num}.2dfld.${outspacing}.f${fhr}.${domain}.grib2.idx
      fi
    else
      if [[ $SENDCOM = 'YES' ]]; then
        cpreq ${DATAprdgen}/prdgen_${domain}_${task}/${domain}_${task}.grib2 ${COMOUT}/rrfs.t${cyc}z.2dfld.${outspacing}.f${fhr}.${domain}.grib2
        wgrib2 ${COMOUT}/rrfs.t${cyc}z.2dfld.${outspacing}.f${fhr}.${domain}.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.2dfld.${outspacing}.f${fhr}.${domain}.grib2.idx
      fi
      if [[ ${SENDDBN} = "YES" ]] ; then
        if (( 10#$cyc % 3 == 0 )); then
            $DBNROOT/bin/dbn_alert MODEL RRFS_DET_2DFLD_${DBNDOM} $job \
                ${COMOUT}/rrfs.t${cyc}z.2dfld.${outspacing}.f${fhr}.${domain}.grib2
            $DBNROOT/bin/dbn_alert MODEL RRFS_DET_2DFLD_${DBNDOM}_IDX $job \
                ${COMOUT}/rrfs.t${cyc}z.2dfld.${outspacing}.f${fhr}.${domain}.grib2.idx
        fi
      fi  #SENDDBN
    fi
  done

  # create subhourly files for CONUS, Alaska, Hawaii, Puerto Rico grids
  if [ "${DO_ENSFCST}" != "TRUE" ] && [ ${fhr} != '000' ] && [ -e $COMOUT/${fld2d_subh} ]; then
    for domain in ${domains[@]}
    do

    DBNDOM="${domain^^}"
    outspacing=${gridspacing}
    if [[ $domain = "hi" || $domain = "pr" ]]
     then
      outspacing="2p5km"
    fi
      fld2d_subh_dom=${net4}.t${cyc}z.2dfld.${outspacing}.subh.f${fhr}.${domain}.grib2
      if [ $domain == "conus" ]; then
        # 3-km Lambert Conformal CONUS domain
        gridspecs="lambert:262.5:38.5:38.5 237.280472:1799:3000 21.138123:1059:3000"
      elif [ $domain == "ak" ]; then
        # 3-km NPS Alaska domain
        gridspecs="nps:210.0:60.0 181.429:1649:2976.0 40.530:1105:2976.0"
      elif [ $domain == "hi" ]; then
        # 2.5 km Mercator Hawaii domain
        gridspecs="mercator:20.00 198.474999:321:2500.0:206.13099 18.072699:225:2500.0:23.087799"
      elif [ $domain == "pr" ]; then
        # 2.5 km Mercator Puerto Rico domain
        gridspecs="mercator:20 284.5:544:2500:297.491 15.0:310:2500:22.005"
      fi

      if [[ $SENDCOM = 'YES' ]]; then
        
        wgrib2 ${COMOUT}/${fld2d_subh} -new_grid_vectors "UGRD:VGRD:USTM:VSTM" -submsg_uv inputs.grib${domain}.uv
        wgrib2 inputs.grib${domain}.uv -set_bitmap 1 -set_grib_type c3 \
          -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
          -new_grid_interpolation neighbor \
          -if ":(WEASD|APCP|NCPCP|ACPCP|SNOD):" -new_grid_interpolation budget -fi \
          -new_grid ${gridspecs} ${COMOUT}/${fld2d_subh_dom}
        wgrib2 ${COMOUT}/${fld2d_subh_dom} -s > ${COMOUT}/${fld2d_subh_dom}.idx

	if [[ $SENDDBN = 'YES' ]]; then
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_SUBH_${DBNDOM} $job \
                  ${COMOUT}/rrfs.t${cyc}z.2dfld.${outspacing}.subh.f${fhr}.${domain}.grib2
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_SUBH_${DBNDOM}_IDX $job \
                  ${COMOUT}/rrfs.t${cyc}z.2dfld.${outspacing}.subh.f${fhr}.${domain}.grib2.idx
	fi
      fi
    done
  fi

  # create subset files on 3-km CONUS grid
  if [ ${DO_ENSFCST} = "TRUE" ]; then
    subset_conus=${net4}.t${cyc}z.${mem_num}.subset.${gridspacing}.f${fhr}.conus.grib2
  else
    subset_conus=${net4}.t${cyc}z.subset.${gridspacing}.f${fhr}.conus.grib2
  fi

  if [[ $SENDCOM = 'YES' ]]; then
    export gridspecs="lambert:262.5:38.5:38.5 237.280472:1799:3000 21.138123:1059:3000"
    wgrib2 ${DATA}/${subset} -new_grid_vectors "UGRD:VGRD:USTM:VSTM" -submsg_uv inputs.gribsubset.uv
    wgrib2 inputs.gribsubset.uv -set_bitmap 1 -set_grib_type c3 \
      -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
      -new_grid_interpolation neighbor \
      -if ":(WEASD|APCP|NCPCP|ACPCP|SNOD):" -new_grid_interpolation budget -fi \
      -new_grid ${gridspecs} ${COMOUT}/${subset_conus}
    wgrib2 ${COMOUT}/${subset_conus} -s > ${COMOUT}/${subset_conus}.idx

    if [ "${SENDDBN}" = "YES" ] ; then
      if [ "${DO_ENSFCST}" = "TRUE" ]; then
             $DBNROOT/bin/dbn_alert MODEL RRFS_ENS_SUBSET_CONUS $job \
                  ${COMOUT}/rrfs.t${cyc}z.${mem_num}.subset.${gridspacing}.f${fhr}.conus.grib2
             $DBNROOT/bin/dbn_alert MODEL RRFS_ENS_SUBSET_CONUS_IDX $job \
                  ${COMOUT}/rrfs.t${cyc}z.${mem_num}.subset.${gridspacing}.f${fhr}.conus.grib2.idx
      else
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_SUBSET_CONUS $job \
                  ${COMOUT}/rrfs.t${cyc}z.subset.${gridspacing}.f${fhr}.conus.grib2
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_SUBSET_CONUS_IDX $job \
                  ${COMOUT}/rrfs.t${cyc}z.subset.${gridspacing}.f${fhr}.conus.grib2.idx
      fi 
    fi

  fi

  # create prslev and 2dfld files on 32-km North America grid
  # Deterministic cycles only for now
  if [ ${DO_ENSFCST} = "FALSE" ]; then
    prslev_na_32km=${net4}.t${cyc}z.prslev.32km.f${fhr}.na.grib2
    fld2d_na_32km=${net4}.t${cyc}z.2dfld.32km.f${fhr}.na.grib2

    if [[ $SENDCOM = 'YES' ]]; then
      export gridspecs="lambert:253:50.000000 214.500000:349:32463.000000 1.000000:277:32463.000000"
      wgrib2 ${COMOUT}/${prslev} -new_grid_vectors "UGRD:VGRD:USTM:VSTM" -submsg_uv inputs.gribprslev32km.uv
      wgrib2 inputs.gribprslev32km.uv -set_bitmap 1 -set_grib_type c3 \
        -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
        -new_grid_interpolation neighbor \
        -if ":(WEASD|APCP|NCPCP|ACPCP|SNOD):" -new_grid_interpolation budget -fi \
        -new_grid ${gridspecs} ${COMOUT}/${prslev_na_32km}
      wgrib2 ${COMOUT}/${prslev_na_32km} -s > ${COMOUT}/${prslev_na_32km}.idx

      wgrib2 ${COMOUT}/${fld2d} -new_grid_vectors "UGRD:VGRD:USTM:VSTM" -submsg_uv inputs.grib2dfld32km.uv
      wgrib2 inputs.grib2dfld32km.uv -set_bitmap 1 -set_grib_type c3 \
        -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
        -new_grid_interpolation neighbor \
        -if ":(WEASD|APCP|NCPCP|ACPCP|SNOD):" -new_grid_interpolation budget -fi \
        -new_grid ${gridspecs} ${COMOUT}/${fld2d_na_32km}
      wgrib2 ${COMOUT}/${fld2d_na_32km} -s > ${COMOUT}/${fld2d_na_32km}.idx

      if [[ ${SENDDBN} = "YES" ]] ; then
      if [ $cyc -eq 00 ] || [ $cyc -eq 06 ] || [ $cyc -eq 12 ] || [ $cyc -eq 18 ]; then
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_NA $job \
                  ${COMOUT}/rrfs.t${cyc}z.prslev.32km.f${fhr}.na.grib2
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_NA_IDX $job \
                  ${COMOUT}/rrfs.t${cyc}z.prslev.32km.f${fhr}.na.grib2.idx
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_2DFLD_NA $job \
                  ${COMOUT}/rrfs.t${cyc}z.2dfld.32km.f${fhr}.na.grib2
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_2DFLD_NA_IDX $job \
                  ${COMOUT}/rrfs.t${cyc}z.2dfld.32km.f${fhr}.na.grib2.idx
      fi
      fi

    fi
  fi

  #-- Generate AWIPS/wmo products for RRFS
  #-- 00/06/12/18Z deterministic cycles only
  #-- AWIPS/wmo products are not generated for ensemble member forecasts
  if [ ${DO_ENSFCST} = "FALSE" ]; then
    if [ $cyc -eq 00 ] || [ $cyc -eq 06 ] || [ $cyc -eq 12 ] || [ $cyc -eq 18 ]; then
      ${USHrrfs}/prdgen/rrfs_mkawp.sh ${fhr}
    fi
  fi

  #-- Generate RAP smoke and HYSPLIT dust products for RRFS
  #-- 06Z and 12Z deterministic cycles only
  #-- Smoke/dust products are not generated for ensemble member forecasts
  if [ ${DO_ENSFCST} = "FALSE" ]; then
    if [ $cyc -eq 06 ] || [ $cyc -eq 12 ]; then
      if (( 10#$fhr <= 72 )); then
        $USHrrfs/prdgen/rrfs_smokedust.sh $fhr 227
        $USHrrfs/prdgen/rrfs_smokedust.sh $fhr 198
        $USHrrfs/prdgen/rrfs_smokedust.sh $fhr 196
      fi
  #-- Files from forecast hours 0-72 are combined into one file
      if (( 10#$fhr == 72 )); then
        $USHrrfs/prdgen/rrfs_smokedust_combine.sh
      fi
    fi
  fi


elif [ ${PREDEF_GRID_NAME} = "RRFS_FIREWX_1.5km" ]; then
  #
  # Processing for the RRFS fire weather grid
  #


. prep_step

  # set GTYPE=2 for GRIB2
  GTYPE=2

  cat > itagfw <<EOF
CONUS
$GTYPE
EOF

  # Read in corner lat lons from UPP text file
  export FORT11=${COMOUT}/latlons_corners.txt.f${fhr}
  export FORT45=itagfw

  # Calculate the wgrib2 gridspecs for the fire weather grid
  $APRUN $EXECrrfs/rrfs_util_firewx_gridspecs.exe >> $pgmout 2>errfile
  export err=$?; err_chk

  grid_specs_firewx=`head $DATA/copygb_gridnavfw.txt`

  eval infile=${COMOUT}/${net4}.t${cyc}z.prslev.${gridspacing}.f${fhr}.firewx.grib2

# process firewx prslev file

  wgrib2 ${infile} -set_bitmap 1 -set_grib_type c3 -new_grid_winds grid \
   -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH" \
   -new_grid_interpolation neighbor \
   -if ":(WEASD|APCP|NCPCP|ACPCP|SNOD):" -new_grid_interpolation budget -fi \
   -new_grid ${grid_specs_firewx} ${COMOUT}/rrfs.t${cyc}z.prslev.${gridspacing}.f${fhr}.firewx_lcc.grib2

  wgrib2 ${COMOUT}/rrfs.t${cyc}z.prslev.${gridspacing}.f${fhr}.firewx_lcc.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.prslev.${gridspacing}.f${fhr}.firewx_lcc.grib2.idx

# process firewx 2dfld file

  eval infile2d=${COMOUT}/${net4}.t${cyc}z.2dfld.${gridspacing}.f${fhr}.firewx.grib2

  wgrib2 ${infile2d} -set_bitmap 1 -set_grib_type c3 -new_grid_winds grid \
   -new_grid_vectors "UGRD:VGRD:USTM:VSTM:VUCSH:VVCSH" \
   -new_grid_interpolation neighbor \
   -if ":(WEASD|APCP|NCPCP|ACPCP|SNOD):" -new_grid_interpolation budget -fi \
   -new_grid ${grid_specs_firewx} ${COMOUT}/rrfs.t${cyc}z.2dfld.${gridspacing}.f${fhr}.firewx_lcc.grib2

  wgrib2 ${COMOUT}/rrfs.t${cyc}z.2dfld.${gridspacing}.f${fhr}.firewx_lcc.grib2 -s > ${COMOUT}/rrfs.t${cyc}z.2dfld.${gridspacing}.f${fhr}.firewx_lcc.grib2.idx


  if [[ ${SENDDBN} = "YES" ]] ; then
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_FIREWX $job \
                  ${COMOUT}/rrfs.t${cyc}z.prslev.${gridspacing}.f${fhr}.firewx_lcc.grib2
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_FIREWX_IDX $job \
                  ${COMOUT}/rrfs.t${cyc}z.prslev.${gridspacing}.f${fhr}.firewx_lcc.grib2.idx
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_2DFLD_FIREWX $job \
                  ${COMOUT}/rrfs.t${cyc}z.2dfld.${gridspacing}.f${fhr}.firewx_lcc.grib2
             $DBNROOT/bin/dbn_alert MODEL RRFS_DET_2DFLD_FIREWX_IDX $job \
                  ${COMOUT}/rrfs.t${cyc}z.2dfld.${gridspacing}.f${fhr}.firewx_lcc.grib2.idx
  fi


fi
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Product generation for forecast hour $fhr completed successfully.

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/function.
#
#-----------------------------------------------------------------------
#
#tmp { restore_shell_opts; } > /dev/null 2>&1

