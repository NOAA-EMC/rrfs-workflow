#!/bin/bash
#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh

function ncvarlst_noaxis_time { ncks --trd -m ${1} | grep -E ': type' | cut -f 1 -d ' ' | sed 's/://' | sort |grep -v -i -E "axis|time" ;  }
function ncvarlst_noaxis_time_new { ncks -m  ${1} | grep -E 'float' | cut -d "(" -f 1 | cut -c 10- ;  }
export  HDF5_USE_FILE_LOCKING=FALSE #clt to avoild recenter's error "NetCDF: HDF error"
export MPICH_COLL_OPT_OFF=1  # to fix non-physical EnKF analysis increments
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

This is the ex-script for the task that runs EnKF analysis with FV3 for the
specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( "cycle_dir" "cycle_type" "enkfworkdir" "NWGES_DIR" "ob_type" )
process_args valid_args "$@"

cycle_type=${cycle_type:-prod}

case $MACHINE in
#
"WCOSS2")
#
  module list
  ulimit -s unlimited
  ulimit -a
  export FI_OFI_RXM_SAR_LIMIT=3145728
  export OMP_STACKSIZE=1G
  export OMP_NUM_THREADS=1
  ncores=$(( NNODES_RUN_ENKF*PPN_RUN_ENKF ))
  APRUN="mpiexec -n ${ncores} -ppn ${PPN_RUN_ENKF} --cpu-bind core --depth ${OMP_NUM_THREADS}"
  ;;
#
"THEIA")
#
  ulimit -s unlimited
  ulimit -a
  np=${SLURM_NTASKS}
  APRUN="mpirun -np ${np}"
  ;;
#
"HERA")
  module load nco/4.9.3
  ulimit -s unlimited
  ulimit -v unlimited
  ulimit -a
  export OMP_NUM_THREADS=1
#  export OMP_STACKSIZE=300M
  APRUN="srun"
  ;;
#
"ORION")
  ulimit -s unlimited
  ulimit -a
  export OMP_NUM_THREADS=1
  export OMP_STACKSIZE=1024M
  APRUN="srun"
  ;;
#
"JET")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun --mem=0"
  ;;
#
"ODIN")
#
  module list

  ulimit -s unlimited
  ulimit -a
  APRUN="srun -n ${PE_MEMBER01}"
  ;;
#
esac
#
#-----------------------------------------------------------------------
#
# Extract from CDATE the starting year, month, day, and hour of the
# forecast.  These are needed below for various operations.
#
#-----------------------------------------------------------------------
#
START_DATE=$(echo "${CDATE}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/')

YYYYMMDDHH=$(date +%Y%m%d%H -d "${START_DATE}")

vlddate=$CDATE
l_fv3reg_filecombined=.false.
#
#-----------------------------------------------------------------------
#
# Go to working directory.
# Define fix path
#
#-----------------------------------------------------------------------
#

cd_vrfy $enkfworkdir
fixgriddir=$FIX_GSI/${PREDEF_GRID_NAME}

if [ ${cycle_type} == "spinup" ]; then
   enkfanal_nwges_dir="${NWGES_DIR}/anal_enkf_spinup"
else
   enkfanal_nwges_dir="${NWGES_DIR}/anal_enkf"
fi
mkdir_vrfy -p ${enkfanal_nwges_dir}
#
#-----------------------------------------------------------------------
#
 cp_vrfy ${fixgriddir}/fv3_coupler.res    coupler.res
 cp_vrfy ${fixgriddir}/fv3_akbk           fv3sar_tile1_akbk.nc
 cp_vrfy ${fixgriddir}/fv3_grid_spec      fv3sar_tile1_grid_spec.nc

#
#-----------------------------------------------------------------------
#
# Loop through the members, link the background and copy over
#  observer output (diag*ges*) files to the running directory
#
#-----------------------------------------------------------------------
#
 for imem in  $(seq 1 $nens) ensmean; do

     if [ ${imem} == "ensmean" ]; then
        memchar="ensmean"
        memcharv0="ensmean"
     else
        memchar="mem"$(printf %04i $imem)
        memcharv0="mem"$(printf %03i $imem)
     fi
     slash_ensmem_subdir=$memchar
     if [ ${cycle_type} == "spinup" ]; then
        bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam_spinup/INPUT
        observer_nwges_dir="${NWGES_DIR}/${slash_ensmem_subdir}/observer_gsi_spinup"
     else
        bkpath=${cycle_dir}/${slash_ensmem_subdir}/fcst_fv3lam/INPUT
        observer_nwges_dir="${NWGES_DIR}/${slash_ensmem_subdir}/observer_gsi"
     fi

     ln_vrfy  -snf  ${bkpath}/fv_core.res.tile1.nc         fv3sar_tile1_${memcharv0}_dynvars
     ln_vrfy  -snf  ${bkpath}/fv_tracer.res.tile1.nc       fv3sar_tile1_${memcharv0}_tracer
     ln_vrfy  -snf  ${bkpath}/sfc_data.nc                  fv3sar_tile1_${memcharv0}_sfcdata
     ln_vrfy  -snf  ${bkpath}/phy_data.nc                  fv3sar_tile1_${memcharv0}_phyvar

#
#-----------------------------------------------------------------------
#
# Copy observer outputs (diag*ges*) to the working directory
#
#-----------------------------------------------------------------------
#

  if [ ${netcdf_diag} == ".true." ] ; then

    # Note, listall_rad is copied from exregional_run_analysis.sh
    listall_rad="hirs2_n14 msu_n14 sndr_g08 sndr_g11 sndr_g11 sndr_g12 sndr_g13 sndr_g08_prep sndr_g11_prep sndr_g12_prep sndr_g13_prep sndrd1_g11 sndrd2_g11 sndrd3_g11 sndrd4_g11 sndrd1_g15 sndrd2_g15 sndrd3_g15 sndrd4_g15 sndrd1_g13 sndrd2_g13 sndrd3_g13 sndrd4_g13 hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 amsua_n18 amsua_n19 amsua_metop-a amsua_metop-b amsua_metop-c amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua imgr_g08 imgr_g11 imgr_g12 pcp_ssmi_dmsp pcp_tmi_trmm conv sbuv2_n16 sbuv2_n17 sbuv2_n18 omi_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 hirs4_metop-a mhs_n18 mhs_n19 mhs_metop-a mhs_metop-b mhs_metop-c amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 iasi_metop-a iasi_metop-b iasi_metop-c seviri_m08 seviri_m09 seviri_m10 seviri_m11 cris_npp atms_npp ssmis_f17 cris-fsr_npp cris-fsr_n20 atms_n20 abi_g16"
    
    if [ ${ob_type} == "conv" ]; then
      list_ob_type="conv_ps conv_q conv_t conv_uv conv_pw conv_rw conv_sst"	

      if [ ${DO_ENS_RADDA} == "TRUE" ]; then
        list_ob_type="$list_ob_type $listall_rad"
      fi	
      
    fi
	
    if [ ${ob_type} == "radardbz" ]; then
      list_ob_type="conv_dbz"
    fi
    for sub_ob_type in ${list_ob_type} ; do
      diagfile0=${observer_nwges_dir}/diag_${sub_ob_type}_ges.${YYYYMMDDHH}.nc4
      if [ -s $diagfile0 ]; then
        diagfile=$(basename  $diagfile0)
        cp_vrfy  $diagfile0  $diagfile
        ncfile=$(basename -s .nc4 $diagfile)
        mv_vrfy $ncfile.nc4 ${ncfile}_${memcharv0}.nc4
      fi
    done
  else
    for diagfile0 in $(ls  ${observer_nwges_dir}/diag*${ob_type}*ges* ) ; do
      if [ -s $diagfile0 ]; then
         diagfile=$(basename  $diagfile0)
         cp_vrfy  $diagfile0   diag_conv_ges.$memcharv0
      fi
    done
  fi

done

#
#-----------------------------------------------------------------------
#
# Set GSI fix files
#
#----------------------------------------------------------------------
#
found_ob_type=0

CONVINFO=${FIX_GSI}/convinfo.rrfs

if [ ${ob_type} == "conv" ]; then
  ANAVINFO=${FIX_GSI}/${ENKF_ANAVINFO_FN}
  found_ob_type=1
fi
if [ ${ob_type} == "radardbz" ]; then
  ANAVINFO=${FIX_GSI}/${ENKF_ANAVINFO_DBZ_FN}
  CORRLENGTH=${CORRLENGTH_radardbz}
  LNSIGCUTOFF=${LNSIGCUTOFF_radardbz}
  found_ob_type=1
fi
if [ ${found_ob_type} == 0 ]; then
  print_err_msg_exit "Error: unknown observation type: ${ob_type}"
fi
stdout_name=stdout.${ob_type}
stderr_name=stderr.${ob_type}

SATINFO=${FIX_GSI}/global_satinfo.txt
OZINFO=${FIX_GSI}/global_ozinfo.txt

cp_vrfy ${ANAVINFO} anavinfo
cp_vrfy $SATINFO    satinfo
cp_vrfy $CONVINFO   convinfo
cp_vrfy $OZINFO     ozinfo


if [ ${DO_ENS_RADDA} == "TRUE" ]; then

  # This follows the procedure of DO_RADDA=TRUE in exregional_run_analysis.sh, with differences below
  #   - The check for "spinup" or "prod" is not performed, as there is only one spinup cycle.
  #   - The file check is back in time for up to 72 hours only.  EnVar checks up to 240 hours back.
  #   - No $satbias_dir is defined in EnKF.  Thus, it is defined as below.
  #   - No use of radstat file in EnKF

  satbias_dir=$NWGES_DIR/../satbias_ensmean
  
  # Searching the satbias files from ${satbias_dir}
  satcounter=1
  maxcounter=72
  while [ $satcounter -lt $maxcounter ]; do
    SAT_TIME=`date +"%Y%m%d%H" -d "${START_DATE}  ${satcounter} hours ago"`
    echo $SAT_TIME
  
    if [ -r ${satbias_dir}/rrfs.prod.${SAT_TIME}_satbias ]; then
      echo " using satellite bias files from ${SAT_TIME}"
      
      cp_vrfy ${satbias_dir}/rrfs.prod.${SAT_TIME}_satbias ./satbias_in
      cp_vrfy ${satbias_dir}/rrfs.prod.${SAT_TIME}_satbias_pc ./satbias_pc
    
      break
    fi
    satcounter=` expr $satcounter + 1 `
  done

  # if satbias files are not available from ${satbias_dir}, use satbias files from the ${FIX_GSI} 
  if [ $satcounter -eq $maxcounter ]; then
	
    if [ -r ${FIX_GSI}/rrfs.starting_satbias ]; then
      echo "using satllite satbias_in files from ${FIX_GSI}"     
      cp_vrfy ${FIX_GSI}/rrfs.starting_satbias ./satbias_in
    fi
    if [ -r ${FIX_GSI}/rrfs.starting_satbias_pc ]; then
      echo "using satllite satbias_pc files from ${FIX_GSI}"     
      cp_vrfy ${FIX_GSI}/rrfs.starting_satbias_pc ./satbias_pc
    fi

  fi
  
fi	

#
#-----------------------------------------------------------------------
#
# Get nlons (NX_RES), nlats (NY_RES) and nlevs
#
#-----------------------------------------------------------------------
#
NX_RES=$(ncdump -h fv3sar_tile1_grid_spec.nc | grep "grid_xt =" | cut -f3 -d" " )
NY_RES=$(ncdump -h fv3sar_tile1_grid_spec.nc | grep "grid_yt =" | cut -f3 -d" " )
nlevs=$(ncdump -h fv3sar_tile1_mem001_tracer | grep "zaxis_1 =" | cut -f3 -d" " )
#
#----------------------------------------------------------------------
#
# Set namelist parameters for EnKF
#
#----------------------------------------------------------------------
#

EnKFTracerVars=${EnKFTracerVar:-"sphum,o3mr"}
ldo_enscalc_option=${ldo_enscalc_option:-0}

# We expect 81 total files to be present (80 enkf + 1 mean)
nens=${nens:-81}
USEGFSO3=.false.
# Not using FGAT or 4DEnVar, so hardwire nhr_assimilation to 3
nhr_assimilation=3.
vs=1.
fstat=.false.
i_gsdcldanal_type=0
use_gfs_nemsio=.true.,

#
#----------------------------------------------------------------------
#
# Make enkf namelist
#
#----------------------------------------------------------------------
#
	cat > enkf.nml << EOFnml
	&nam_enkf
	datestring="$vlddate",datapath="$enkfworkdir/",
	analpertwtnh=1.10,analpertwtsh=1.10,analpertwttr=1.10,
	covinflatemax=1.e2,covinflatemin=1,pseudo_rh=.true.,iassim_order=0,
        corrlengthnh=$CORRLENGTH,corrlengthsh=$CORRLENGTH,corrlengthtr=$CORRLENGTH,
        lnsigcutoffnh=$LNSIGCUTOFF,lnsigcutoffsh=$LNSIGCUTOFF,lnsigcutofftr=$LNSIGCUTOFF,
        lnsigcutoffpsnh=$LNSIGCUTOFF,lnsigcutoffpssh=$LNSIGCUTOFF,lnsigcutoffpstr=$LNSIGCUTOFF,
        lnsigcutoffsatnh=$LNSIGCUTOFF,lnsigcutoffsatsh=$LNSIGCUTOFF,lnsigcutoffsattr=$LNSIGCUTOFF,
	obtimelnh=1.e30,obtimelsh=1.e30,obtimeltr=1.e30,
	saterrfact=1.0,numiter=1,
	sprd_tol=1.e30,paoverpb_thresh=0.98,
	nlons=${NX_RES:-396},nlats= ${NY_RES:-232}, nlevs= ${nlevs:-65},nanals=$nens,
	deterministic=.true.,sortinc=.true.,lupd_satbiasc=.false.,
	reducedgrid=.true.,readin_localization=.false.,
	use_gfs_nemsio=.true.,imp_physics=99,lupp=.false.,
	univaroz=.false.,adp_anglebc=.true.,angord=4,use_edges=.false.,emiss_bc=.true.,
	lobsdiag_forenkf=.false.,
	write_spread_diag=.false.,
	netcdf_diag=${netcdf_diag:-.false.},
        fv3_native=.true.,
	/
	&satobs_enkf
	sattypes_rad(1) = 'amsua_n15',     dsis(1) = 'amsua_n15',
	sattypes_rad(2) = 'amsua_n18',     dsis(2) = 'amsua_n18',
	sattypes_rad(3) = 'amsua_n19',     dsis(3) = 'amsua_n19',
	sattypes_rad(4) = 'amsub_n16',     dsis(4) = 'amsub_n16',
	sattypes_rad(5) = 'amsub_n17',     dsis(5) = 'amsub_n17',
	sattypes_rad(6) = 'amsua_aqua',    dsis(6) = 'amsua_aqua',
	sattypes_rad(7) = 'amsua_metop-a', dsis(7) = 'amsua_metop-a',
	sattypes_rad(8) = 'airs_aqua',     dsis(8) = 'airs_aqua',
	sattypes_rad(9) = 'hirs3_n17',     dsis(9) = 'hirs3_n17',
	sattypes_rad(10)= 'hirs4_n19',     dsis(10)= 'hirs4_n19',
	sattypes_rad(11)= 'hirs4_metop-a', dsis(11)= 'hirs4_metop-a',
	sattypes_rad(12)= 'mhs_n18',       dsis(12)= 'mhs_n18',
	sattypes_rad(13)= 'mhs_n19',       dsis(13)= 'mhs_n19',
	sattypes_rad(14)= 'mhs_metop-a',   dsis(14)= 'mhs_metop-a',
	sattypes_rad(15)= 'goes_img_g11',  dsis(15)= 'imgr_g11',
	sattypes_rad(16)= 'goes_img_g12',  dsis(16)= 'imgr_g12',
	sattypes_rad(17)= 'goes_img_g13',  dsis(17)= 'imgr_g13',
	sattypes_rad(18)= 'goes_img_g14',  dsis(18)= 'imgr_g14',
	sattypes_rad(19)= 'goes_img_g15',  dsis(19)= 'imgr_g15',
	sattypes_rad(20)= 'avhrr_n18',     dsis(20)= 'avhrr3_n18',
	sattypes_rad(21)= 'avhrr_metop-a', dsis(21)= 'avhrr3_metop-a',
	sattypes_rad(22)= 'avhrr_n19',     dsis(22)= 'avhrr3_n19',
	sattypes_rad(23)= 'amsre_aqua',    dsis(23)= 'amsre_aqua',
	sattypes_rad(24)= 'ssmis_f16',     dsis(24)= 'ssmis_f16',
	sattypes_rad(25)= 'ssmis_f17',     dsis(25)= 'ssmis_f17',
	sattypes_rad(26)= 'ssmis_f18',     dsis(26)= 'ssmis_f18',
	sattypes_rad(27)= 'ssmis_f19',     dsis(27)= 'ssmis_f19',
	sattypes_rad(28)= 'ssmis_f20',     dsis(28)= 'ssmis_f20',
	sattypes_rad(29)= 'sndrd1_g11',    dsis(29)= 'sndrD1_g11',
	sattypes_rad(30)= 'sndrd2_g11',    dsis(30)= 'sndrD2_g11',
	sattypes_rad(31)= 'sndrd3_g11',    dsis(31)= 'sndrD3_g11',
	sattypes_rad(32)= 'sndrd4_g11',    dsis(32)= 'sndrD4_g11',
	sattypes_rad(33)= 'sndrd1_g12',    dsis(33)= 'sndrD1_g12',
	sattypes_rad(34)= 'sndrd2_g12',    dsis(34)= 'sndrD2_g12',
	sattypes_rad(35)= 'sndrd3_g12',    dsis(35)= 'sndrD3_g12',
	sattypes_rad(36)= 'sndrd4_g12',    dsis(36)= 'sndrD4_g12',
	sattypes_rad(37)= 'sndrd1_g13',    dsis(37)= 'sndrD1_g13',
	sattypes_rad(38)= 'sndrd2_g13',    dsis(38)= 'sndrD2_g13',
	sattypes_rad(39)= 'sndrd3_g13',    dsis(39)= 'sndrD3_g13',
	sattypes_rad(40)= 'sndrd4_g13',    dsis(40)= 'sndrD4_g13',
	sattypes_rad(41)= 'sndrd1_g14',    dsis(41)= 'sndrD1_g14',
	sattypes_rad(42)= 'sndrd2_g14',    dsis(42)= 'sndrD2_g14',
	sattypes_rad(43)= 'sndrd3_g14',    dsis(43)= 'sndrD3_g14',
	sattypes_rad(44)= 'sndrd4_g14',    dsis(44)= 'sndrD4_g14',
	sattypes_rad(45)= 'sndrd1_g15',    dsis(45)= 'sndrD1_g15',
	sattypes_rad(46)= 'sndrd2_g15',    dsis(46)= 'sndrD2_g15',
	sattypes_rad(47)= 'sndrd3_g15',    dsis(47)= 'sndrD3_g15',
	sattypes_rad(48)= 'sndrd4_g15',    dsis(48)= 'sndrD4_g15',
	sattypes_rad(49)= 'iasi_metop-a',  dsis(49)= 'iasi_metop-a',
	sattypes_rad(50)= 'seviri_m08',    dsis(50)= 'seviri_m08',
	sattypes_rad(51)= 'seviri_m09',    dsis(51)= 'seviri_m09',
	sattypes_rad(52)= 'seviri_m10',    dsis(52)= 'seviri_m10',
	sattypes_rad(53)= 'amsua_metop-b', dsis(53)= 'amsua_metop-b',
	sattypes_rad(54)= 'hirs4_metop-b', dsis(54)= 'hirs4_metop-b',
	sattypes_rad(55)= 'mhs_metop-b',   dsis(55)= 'mhs_metop-b',
	sattypes_rad(56)= 'iasi_metop-b',  dsis(56)= 'iasi_metop-b',
	sattypes_rad(57)= 'avhrr_metop-b', dsis(57)= 'avhrr3_metop-b',
	sattypes_rad(58)= 'atms_npp',      dsis(58)= 'atms_npp',
	sattypes_rad(59)= 'atms_n20',      dsis(59)= 'atms_n20',
	sattypes_rad(60)= 'cris_npp',      dsis(60)= 'cris_npp',
	sattypes_rad(61)= 'cris-fsr_npp',  dsis(61)= 'cris-fsr_npp',
	sattypes_rad(62)= 'cris-fsr_n20',  dsis(62)= 'cris-fsr_n20',
	sattypes_rad(63)= 'gmi_gpm',       dsis(63)= 'gmi_gpm',
	sattypes_rad(64)= 'saphir_meghat', dsis(64)= 'saphir_meghat',
	/
	&ozobs_enkf
	sattypes_oz(1) = 'sbuv2_n16',
	sattypes_oz(2) = 'sbuv2_n17',
	sattypes_oz(3) = 'sbuv2_n18',
	sattypes_oz(4) = 'sbuv2_n19',
	sattypes_oz(5) = 'omi_aura',
	sattypes_oz(6) = 'gome_metop-a',
	sattypes_oz(7) = 'gome_metop-b',
	sattypes_oz(8) = 'mls30_aura',
	/
	&nam_fv3
	fv3fixpath="XXX",nx_res=${NX_RES:-396},ny_res=${NY_RES-232},ntiles=1,
        l_fv3reg_filecombined=${l_fv3reg_filecombined},
	/
EOFnml

#
#-----------------------------------------------------------------------
#
# Copy the EnKF executable to the run directory.
#
#-----------------------------------------------------------------------
#

echo pwd is `pwd`
ENKFEXEC=${EXECDIR}/enkf.x

if [ -f ${ENKFEXEC} ]; then
  print_info_msg "$VERBOSE" "
Copying the EnKF executable to the run directory..."
  cp_vrfy ${ENKFEXEC} ${enkfworkdir}/enkf.x
else
  print_err_msg_exit "\
The EnKF executable specified in ENKFEXEC does not exist:
  EnKF_EXEC = \"${ENKFEXEC}\"
Build EnKF and rerun."
fi

#
#-----------------------------------------------------------------------
#
# Run the EnKF
#
#-----------------------------------------------------------------------
#
countdiag=$(ls diag*conv* | wc -l)
if [ $countdiag -gt $nens ]; then

${APRUN}  $enkfworkdir/enkf.x < enkf.nml 1>${stdout_name} 2>${stderr_name} || print_err_msg_exit "\
Call to executable to run EnKF returned with nonzero exit code."


cp_vrfy ${stdout_name} ${enkfanal_nwges_dir}/.
cp_vrfy ${stderr_name} ${enkfanal_nwges_dir}/.
if [ ! -d ${NWGES_DIR}/../enkf_diag ]; then
  mkdir -p ${NWGES_DIR}/../enkf_diag
fi
cp_vrfy ${stdout_name} ${NWGES_DIR}/../enkf_diag/${stdout_name}.$vlddate
cp_vrfy ${stderr_name} ${NWGES_DIR}/../enkf_diag/${stderr_name}.$vlddate

else
  echo "Warning: EnKF not running due to lack of ${ob_type} obs for cycle $vlddate !!!"
fi

print_info_msg "
========================================================================
EnKF PROCESS completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1
