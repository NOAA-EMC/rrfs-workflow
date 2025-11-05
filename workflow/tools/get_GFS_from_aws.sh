#!/bin/ksh
#SBATCH --time=23:30:00
#SBATCH --qos=batch
#SBATCH --partition=service
#SBATCH --ntasks=1
#SBATCH --account=nrtrr
#SBATCH --job-name=aws_GFS
#SBATCH --output=./log.aws_GFS
# https://noaa-gfs-bdp-pds.s3.amazonaws.com/gfs.20240526/18/atmos/gfs.t18z.pgrb2.0p25.f022
# https://noaa-gfs-bdp-pds.s3.amazonaws.com/gfs.20240526/18/atmos/gfs.t18z.pgrb2b.0p25.f022
# shellcheck disable=SC2181

datadir=/scratch2/BMC/rtrr/RRFS2_RETRO_DATA/sandbox/GFS  #set you own datadir, absolute path

set -x
waittime=30
maxtries=10
#cdate=2024052512  
#fhr_bgn=000 #has to be three digits
#fhr_end=060 #has to be three digits
cdate=$1
fhr_bgn=$2 #has to be three digits
fhr_end=$3  #has to be three digits
if [[ -z "${cdate}" ]] || [[ -z "${fhr_bgn}" ]] || [[ -z "${fhr_end}"  ]]; then
  echo "Usage: $0 cdate fhr_bgn fhr_end # fhr has to be three digits"
  exit 1
fi
if (( ${#fhr_bgn} <=2 )) || (( ${#fhr_end} <=2  )); then
  echo "fhr has to be three digits"
  exit 1
fi

interval=1 # every $interval hours

grbdir="${datadir}/gfs.${cdate:0:8}/${cdate:8:2}"
mkdir -p "${grbdir}"
for fhr in $(seq -w "${fhr_bgn}" "${interval}" "${fhr_end}"); do
  for grbtype in pgrb2 pgrb2b; do
    cd "${grbdir}" || exit 1
    grbfile=${grbdir}/gfs.t${cdate:8:2}z.${grbtype}.0p25.f${fhr}
    awsfile="https://noaa-gfs-bdp-pds.s3.amazonaws.com/gfs.${cdate:0:8}/${cdate:8:2}/atmos/gfs.t${cdate:8:2}z.${grbtype}.0p25.f${fhr}"
    tries=0
    while [[ $tries -le $maxtries ]] && [[ -z  "$( find "${grbfile}"  -size +90M 2>/dev/null)" ]]; do
    #while [[ ! -s ${grbfile} && $tries -le $maxtries ]] && [[ -z  "$( find ${grbfile}  -size +90M 2>/dev/null)" ]]; do
      timeout  --foreground  "${waittime}"  wget "${awsfile}"
      if [ $? -ne 0 ] ; then
        echo "Failed to download ${awsfile} ... trying again ..."
        rm -f "${grbfile}"
        tries=$((tries+1))
      fi
    done
  done
done

