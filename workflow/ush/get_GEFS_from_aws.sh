#!/bin/ksh
# For Hera, Jet, Orio
#SBATCH --time=23:30:00
#SBATCH --qos=batch
#SBATCH --partition=service
#SBATCH --ntasks=1
#SBATCH --account=nrtrr
#SBATCH --job-name=aws_GEFS
#SBATCH --output=./log.aws_GEFS.1
# https://noaa-gefs-pds.s3.amazonaws.com/gefs.20220429/00/atmos/pgrb2ap5/gep01.t00z.pgrb2a.0p50.f114
# https://noaa-gefs-pds.s3.amazonaws.com/gefs.20220429/00/atmos/pgrb2bp5/gep01.t00z.pgrb2b.0p50.f114
# shellcheck disable=SC2181

datadir=/scratch2/BMC/rtrr/RRFS2_RETRO_DATA/sandbox/GEFS  #set you own datadir (absolute path)

set -x
waittime=30
maxtries=10
#cdate=2024052512  
#fhr_bgn=033 #has to be three digits
#fhr_end=060 #has to be three digits
cdate=$1
fhr_bgn=$2 #has to be three digits
fhr_end=$3  #has to be three digits
if [[ -z "${cdate}" ]] || [[ -z "${fhr_bgn}" ]] || [[ -z "${fhr_end}"  ]]; then
  echo "Usage: $0 cdate fhr_bgn fhr_end # fhr has to be three digits"
  exit
fi
if (( ${#fhr_bgn} <=2 )) || (( ${#fhr_end} <=2  )); then
  echo "fhr has to be three digits"
  exit 1
fi

interval=3 #every $interval hours

for imem in $(seq -w 1 30); do
  for fhr in $(seq -w "${fhr_bgn}" "${interval}" "${fhr_end}"); do
    for grbtype in pgrb2a pgrb2b; do
      grbdir="${datadir}/gefs.${cdate:0:8}/${cdate:8:2}/${grbtype}p5"
      mkdir -p "${grbdir}"
      cd "${grbdir}" || exit 1
      grbfile=${grbdir}/gep${imem}.t${cdate:8:2}z.${grbtype}.0p50.f${fhr}
      tries=0
      while [[ $tries -le $maxtries ]] && [[ -z  "$( find "${grbfile}"  -size +8M 2>/dev/null )" ]]; do
        awsfile="https://noaa-gefs-pds.s3.amazonaws.com/gefs.${cdate:0:8}/${cdate:8:2}/atmos/${grbtype}p5/gep${imem}.t${cdate:8:2}z.${grbtype}.0p50.f${fhr}"
        timeout  --foreground  "${waittime}"  wget "${awsfile}"
        if [ $? -ne 0 ] ; then
          echo "Failed to download ${awsfile} ... trying again ..."
          rm -f "${grbfile}"
          tries=$((tries+1))
        fi
      done
    done
  done
done

