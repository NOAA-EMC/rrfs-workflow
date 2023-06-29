#!/bin/ksh --login

. ${GLOBAL_VAR_DEFNS_FP}

DATAROOT=${EXPTDIR}
DATAHOME=${COMOUT_BASEDIR}/${RUN}.${START_TIME:0:8}/${START_TIME:8:2}
POST_PREFIX=${NET}

if [ "${PBS_NODEFILE:-unset}" != "unset" ]; then
        THREADS=$(cat $PBS_NODEFILE | wc -l)
else
        THREADS=16
fi
echo "Using $THREADS thread(s) for procesing."

# Variables sent from xml
# DATAROOT
# DATAHOME
# START_TIME
# FCST_TIME

FCST_TIME_3=$(printf "%03d" $(( 10#$FCST_TIME )))
FCST_TIME=$(printf "%02d" $(( 10#$FCST_TIME )))

# Load modules
module purge
module load intel
module load szip hdf5 netcdf
module load imagemagick
module load ncl

# Make sure we are using GMT time zone for time computations
export TZ="GMT"
export UDUNITS2_XML_PATH=${NCARG_ROOT}/lib/ncarg/udunits/udunits2.xml
export NCL_HOME=${NCL_HOME}
export MODEL=${MODEL}
export NCL_EXE_ROOT=${NCL_HOME}/scripts
export NCL_CONFIG=${NCL_HOME}/config
export SUBDOMAINS=${NCL_CONFIG}/${NCL_REGION}_subdomains.ncl

# Set up paths to shell commands
LS=/bin/ls
LN=/bin/ln
RM=/bin/rm
MKDIR=/bin/mkdir
CP=/bin/cp
MV=/bin/mv
ECHO=/bin/echo
CAT=/bin/cat
GREP=/bin/grep
CUT=/bin/cut
AWK="/bin/gawk --posix"
SED=/bin/sed
DATE=/bin/date
BC=/usr/bin/bc
XARGS=${XARGS:-/usr/bin/xargs}
BASH=${BASH:-/bin/bash}
NCL=`which ncl`
CTRANS=`which ctrans`
PS2PDF=/usr/bin/ps2pdf
CONVERT=`which convert`
PATH=${NCARG_ROOT}/bin:${PATH}

typeset -Z6 j
typeset -Z6 k
ulimit -s 1024000

# Print run parameters
${ECHO}
${ECHO} "ncl.ksh started at `${DATE}`"
${ECHO}
${ECHO} "NCL = ${NCL}"
${ECHO} "CTRANS = ${CTRANS}"
${ECHO} "CONVERT = ${CONVERT}"
${ECHO} "DATAROOT = ${DATAROOT}"
${ECHO} "DATAHOME = ${DATAHOME}"
${ECHO} "NCL_EXE_ROOT = ${NCL_EXE_ROOT}"

# Check to make sure the EXE_ROOT var was specified
if [ ! -d ${NCL_EXE_ROOT} ]; then
  ${ECHO} "ERROR: NCL_EXE_ROOT, '${NCL_EXE_ROOT}', does not exist"
  exit 1
fi

# Check to make sure that the DATAHOME exists
if [ ! -d ${DATAHOME} ]; then
  ${ECHO} "ERROR: DATAHOME, '${DATAHOME}', does not exist"
  exit 1
fi
# If START_TIME is not defined, use the current time
if [ ! "${START_TIME}" ]; then
  ${ECHO} "START_TIME not defined - get from date"
  START_TIME=$( date +"%Y%m%d %H" )
  INIT_HOUR=$( date +"%H" -d "${START_TIME}" )
  START_TIME=$( date +"%Y%m%d%H" -d "${START_TIME}" )
else
  ${ECHO} "START_TIME defined and is ${START_TIME}"
  START_TIME=$( date +"%Y%m%d %H" -d "${START_TIME%??} ${START_TIME#????????}" )
  INIT_HOUR=$( date +"%H" -d "${START_TIME}" )
  START_TIME=$( date +"%Y%m%d%H" -d "${START_TIME}" )
fi

# Print out times
# ${ECHO} "   START TIME = "`${DATE} +%Y%m%d%H -d "${START_TIME}"`
${ECHO} "   START_TIME = ${START_TIME}"
${ECHO} "   FCST_TIME = ${FCST_TIME}"

# Set up the work directory and cd into it
workdir=${DATAHOME}/nclprd/${START_TIME}${FCST_TIME}
${RM} -rf ${workdir}
${MKDIR} -p ${workdir}
cd ${workdir}
pwd

# Check that the input file exists
input_file=${DATAHOME}/${POST_PREFIX}.t${INIT_HOUR}z.bgdawpf${FCST_TIME_3}.tm00.grib2

if [ -e $input_file ] ; then
  # Link to input file
  ${LN} -sf ${input_file} rrfsfile.grb
else
  echo "Cannot find input file: ${input_file}!"
  exit 1
fi

${ECHO} "rrfsfile.grb" > rrfs_file.txt

ls -al rrfsfile.grb

# set the plot types you want to generate here
set -A ncgms  sfc_temp   \
              2m_temp    \
              2m_rh      \
              2m_dewp    \
              2ds_temp   \
              10m_wind   \
              80m_wind   \
              850_wind   \
              250_wind   \
              sfc_pwtr   \
              sfc_cref   \
              sfc_ptyp   \
              sfc_cape   \
              sfc_cin    \
              sfc_acp    \
              sfc_weasd  \
              sfc_1hsnw  \
              sfc_totp   \
              sfc_sfcp   \
              ua_rh      \
              850_rh     \
              700_vvel   \
              sfc_vis    \
              ua_ceil    \
              ua_ctop    \
              10m_gust   \
              sfc_hlcy  \
              in25_hlcy \
              mx03_hlcy \
              mx03_hlcytot \
              mx25_hlcytot \
              sfc_lcl   \
              sfc_tcc   \
              sfc_lcc   \
              sfc_mcc   \
              sfc_hcc   \
              sfc_mucp  \
              sfc_mulcp \
              sfc_mxcp  \
              sfc_1hsm  \
              sfc_3hsm  \
              sfc_s1shr \
              sfc_6kshr \
              500_temp  \
              700_temp  \
              850_temp  \
              925_temp  \
              sfc_1ref  \
              sfc_bli   \
              nta_ulwrf \
              sfc_ulwrf \
              sfc_uswrf \
              sfc_lhtfl \
              sfc_shtfl \
              sfc_flru  \
              sfc_solar \
              sfc_rvil

# this is the set of all possible tiles
# to set the tiles you actually want to generate, modify the loop in <region>_subdomains.ncl
set -A tiles full t1 t2 t3 t4 t5 t6 t7 t8 z0 z1 z2 z3 z4 z5 z6 z7 z8 z9

i=0
p=0
while [ ${i} -lt ${#ncgms[@]} ]; do
  j=000000
  k=000000
  numtiles=${#tiles[@]}
  (( numtiles=numtiles - 1 )) 
  while [ ${j} -le ${numtiles} ]; do
    (( k=j + 1 )) 
    pngs[${p}]=${ncgms[${i}]}.${k}.png
    webpfx=`echo ${ncgms[${i}]} | cut -d '_' -f2`
    websfx=`echo ${ncgms[${i}]} | cut -d '_' -f1`
    if [ ${j} -eq 000000 ]; then 
      if [ "${websfx}" = "ua" ]; then 
        webnames[${p}]=${webpfx}
      else 
        webnames[${p}]=${webpfx}_${websfx}
      fi   
    else 
      if [ "${websfx}" = "ua" ]; then 
        webnames[${p}]=${webpfx}_${tiles[${j}]}
      else 
        webnames[${p}]=${webpfx}_${tiles[${j}]}${websfx}
      fi   
    fi   
    (( j=j + 1 )) 
# p is total number of images (image index)
    (( p=p + 1 )) 
  done 
  (( i=i + 1 )) 
done

ncl_error=0

# Run the NCL scripts for each plot
cp ${NCL_CONFIG}/Airpor* .
cp ${NCL_CONFIG}/fv3_names_grib2.txt names_grib2.txt
i=0
echo "FIRST While, ${#ncgms[@]} items"
CMDFN=/tmp/cmd.rrfsx.$$
${RM} -f $CMDFN

while [ ${i} -lt ${#ncgms[@]} ]; do
  plot=${ncgms[${i}]}
  ${ECHO} "Starting rr_${plot}.ncl at `${DATE}`"
  echo ${NCL} ${NCL_EXE_ROOT}/rr_${plot}.ncl >> $CMDFN
  (( i=i + 1 ))
done

${CAT} $CMDFN | ${XARGS} -P $THREADS -I {} ${BASH} -c "{}" 
ncl_error=$?
${RM} -f $CMDFN

# Copy png files to their proper names
i=0
while [ ${i} -lt ${#pngs[@]} ]; do
  j=0
  while [ ${j} -lt ${#tiles[@]} ]; do
    pngfile=${pngs[${i}]}
    if [[ -e ${pngfile} ]];then
      plotdir=${DATAHOME}/nclprd/${tiles[${j}]}
      webfile=${plotdir}/${webnames[${i}]}_f${FCST_TIME}.png
      echo "Converting ${pngfile} to ${webfile}"
      ${CONVERT} -colors 255 -trim ${pngfile} ${pngfile}
      ${MKDIR} -p ${plotdir}
      ${MV} ${pngfile} ${webfile}
    fi
    (( i=i + 1 ))
    (( j=j + 1 ))
  done
done

# Remove the workdir
${RM} -rf ${workdir}

${ECHO} "ncl.ksh completed at `${DATE}`"

exit ${ncl_error}

