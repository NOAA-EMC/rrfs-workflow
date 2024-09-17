#!/usr/bin/env bash
# First detect w/ hostname
export MACHINE
case $(hostname -f) in

  adecflow0[12].acorn.wcoss2.ncep.noaa.gov)  MACHINE=acorn ;; ### acorn
  alogin0[12].acorn.wcoss2.ncep.noaa.gov)    MACHINE=acorn ;; ### acorn
  clogin0[1-9].cactus.wcoss2.ncep.noaa.gov)  MACHINE=wcoss2 ;; ### cactus01-9
  clogin10.cactus.wcoss2.ncep.noaa.gov)      MACHINE=wcoss2 ;; ### cactus10
  dlogin0[1-9].dogwood.wcoss2.ncep.noaa.gov) MACHINE=wcoss2 ;; ### dogwood01-9
  dlogin10.dogwood.wcoss2.ncep.noaa.gov)     MACHINE=wcoss2 ;; ### dogwood10

  gaea9)               MACHINE=gaea ;; ### gaea9
  gaea1[0-6])          MACHINE=gaea ;; ### gaea10-16
  gaea9.ncrc.gov)      MACHINE=gaea ;; ### gaea9
  gaea1[0-6].ncrc.gov) MACHINE=gaea ;; ### gaea10-16

  hfe0[1-9]) MACHINE=hera ;; ### hera01-09
  hfe1[0-2]) MACHINE=hera ;; ### hera10-12
  hecflow01) MACHINE=hera ;; ### heraecflow01

  s4-submit.ssec.wisc.edu) MACHINE=s4 ;; ### s4

  fe[1-8]) MACHINE=jet ;; ### jet01-8
  tfe[12]) MACHINE=jet ;; ### tjet1-2

  Orion-login-[1-4].HPC.MsState.Edu) MACHINE=orion ;; ### orion1-4

  [Hh]ercules-login-[1-4].[Hh][Pp][Cc].[Mm]s[Ss]tate.[Ee]du) MACHINE=hercules ;; ### hercules1-4

  login[1-4].stampede2.tacc.utexas.edu) MACHINE=stampede ;; ### stampede1-4

  login0[1-2].expanse.sdsc.edu) MACHINE=expanse ;; ### expanse1-2

  discover3[1-5].prv.cube) MACHINE=discover ;; ### discover31-35
  *) MACHINE=UNKNOWN ;;  # Unknown platform
esac

if [[ ${MACHINE} == "UNKNOWN" ]]; then 
   case ${PW_CSP:-} in
      "aws" | "google" | "azure") MACHINE=noaacloud ;;
      *) PW_CSP="UNKNOWN"
   esac
fi

# If MACHINE is still UNKNOWN,
# Try searching based on paths since hostname may not match on compute nodes
if [[ "${MACHINE}" == "UNKNOWN" ]]; then
  if [[ -d /lfs/h3 ]]; then
    # We are on NOAA Cactus or Dogwood
    MACHINE=wcoss2
  elif [[ -d /lfs/h1 && ! -d /lfs/h3 ]]; then
    # We are on NOAA TDS Acorn
    MACHINE=acorn
  elif [[ -d /mnt/lfs5 ]]; then
    # We are on NOAA Jet
    MACHINE=jet
  elif [[ -d /scratch1 ]]; then
    # We are on NOAA Hera
    MACHINE=hera
  elif [[ -d /work ]]; then
    # We are on MSU Orion or Hercules
    if [[ -d /apps/other ]]; then
      # We are on Hercules
      MACHINE=hercules
    else
      MACHINE=orion
    fi
  elif [[ -d /gpfs && -d /ncrc ]]; then
    # We are on GAEA.
    MACHINE=gaea
  elif [[ -d /data/prod ]]; then
    # We are on SSEC's S4
    MACHINE=s4
  else
    echo WARNING: UNKNOWN PLATFORM 1>&2
  fi
fi
