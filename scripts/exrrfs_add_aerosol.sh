#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHdir/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u -x; } > /dev/null 2>&1
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

This is the ex-script for the task that adds dust in GEFS aerosol data
to LBCs.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Set environment variables.
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a

case $MACHINE in
#
"WCOSS2")
  ncores=$(( NNODES_ADD_AEROSOL*PPN_ADD_AEROSOL ))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_ADD_AEROSOL}"
  ;;
#
"HERA")
  APRUN="srun --export=ALL"
  ;;
#
"JET")
  APRUN="srun --export=ALL"
  ;;
#
"ORION")
  APRUN="srun --export=ALL"
  ;;
#
"HERCULES")
  APRUN="srun --export=ALL"
  ;;
#
esac

CDATE_MOD=$( $DATE_UTIL --utc --date "${PDY} ${cyc} UTC - ${EXTRN_MDL_LBCS_OFFSET_HRS} hours" "+%Y%m%d%H" )
yyyymmdd=${CDATE_MOD:0:8}
mm="${CDATE_MOD:4:2}"
hh="${CDATE_MOD:8:2}"

gefs_file_cyc=$( printf "%02d" "${hh}" )
gefs_cyc_diff=$(( cyc - gefs_file_cyc ))
if [ "${gefs_cyc_diff}" -lt "0" ]; then
  tstepdiff=$( printf "%02d" $(( 24 + ${gefs_cyc_diff} )) )
else
  tstepdiff=$( printf "%02d" ${gefs_cyc_diff} )
fi

gefs_aerosol_mofile_fn="${GEFS_AEROSOL_FILE_PREFIX}.t${gefs_file_cyc}z.atmf"
gefs_aerosol_mofile_fp="${COMINgefs}/gefs.${yyyymmdd}/${gefs_file_cyc}/chem/sfcsig/${gefs_aerosol_mofile_fn}"

gefs_aerosol_fcst_hrs=()
for i_lbc in $(seq ${GEFS_AEROSOL_INTVL_HRS} ${GEFS_AEROSOL_INTVL_HRS} ${FCST_LEN_HRS} ); do
  gefs_aerosol_fcst_hrs+=("$i_lbc")
done
#
#-----------------------------------------------------------------------
#
# Check if GEFS aerosol files exist.
#
#-----------------------------------------------------------------------
#
for hr in 0 ${gefs_aerosol_fcst_hrs[@]}; do
  hr_mod=$(( hr + EXTRN_MDL_LBCS_OFFSET_HRS ))
  fhr=$( printf "%03d" "${hr_mod}" )
  gefs_aerosol_mofile_fhr_fp="${gefs_aerosol_mofile_fp}${fhr}.${GEFS_AEROSOL_FILE_FMT}"
  if [ -e "${gefs_aerosol_mofile_fhr_fp}" ]; then
    ls -nsf "${gefs_aerosol_mofile_fhr_fp}" .
    echo "File exists: ${gefs_aerosol_mofile_fhr_fp}"
  else
    message_warning="File was not found even after rechecks: ${gefs_aerosol_mofile_fhr_fp}"
    echo "${message_warning}"
    if [ ! -z "${MAILTO}" ] && [ "${MACHINE}" = "WCOSS2" ]; then
      echo "${message_warning}" | mail.py ${MAILTO}
    fi
  fi
done
#
#-----------------------------------------------------------------------
#
# Set up input namelist file.
#
#-----------------------------------------------------------------------
#
cat > gefs2lbc-nemsio.ini <<EOF
&control
 tstepdiff=${tstepdiff}
 dtstep=${GEFS_AEROSOL_INTVL_HRS}
 bndname='dust','coarsepm'
 mofile='${gefs_aerosol_mofile_fp}','.${GEFS_AEROSOL_FILE_FMT}'
 lbcfile='${COMIN}/gfs_bndy.tile7.','.nc'
 topofile='${OROG_DIR}/${CRES}_oro_data.tile7.halo4.nc'
 inblend=${HALO_BLEND}
&end

Species converting Factor
# Gocart ug/m3 to regional ug/m3
'dust1'    1  ## 0.2-2um diameter: assuming mean diameter is 0.3 um (volume= 0.01414x10^-18 m3) and density is 2.6x10^3 kg/m3 or 2.6x10^12 ug/m3.so 1 particle = 0.036x10^-6 ug
'dust'  1.0
'dust2'    2  ## 2-4um
'dust'  0.714  'coarsepm'  0.286
'dust3'    1  ## 4-6um
'coarsepm'  1.0
'dust4'    1   ## 6-12um
'coarsepm'  1.0
'dust5'    1     # kg/kg
'coarsepm'  1.0
EOF
#
#-----------------------------------------------------------------------
#
# Run gefs2lbc_para.
#
#-----------------------------------------------------------------------
#
export pgm="gefs2lbc_para"
. prep_step

${APRUN} ${EXECdir}/$pgm >>$pgmout 2>errfile
export err=$?; err_chk

cp -rp gfs_bndy.tile7.f*.nc ${INPUT_DATA}
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
ADD_AEROSOL completed successfully!!!

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
{ restore_shell_opts; } > /dev/null 2>&1

