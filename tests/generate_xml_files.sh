#!/usr/bin/env bash
# shellcheck disable=SC2016
rundir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
wflow="${rundir}/../workflow"
cd "${wflow}" || exit 1
mkdir -p "${rundir}/xml"

# ----------------------------------------------------------------------------------------------------
# conus12km
echo -e "\n----------conus12km org----------"
myexp=conus12km
myfile=${wflow}/exp/exp.${myexp}
sed 's|^export OPSROOT=/scratch3/BMC/wrfruc/gge/OPSROOT/${EXP_NAME}|export OPSROOT=./OPSROOT/${EXP_NAME}|' "${myfile}" > "exp.test"
./setup_rocoto.py "exp.test"
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_retro.xml"

# -- realtime --
echo -e "\n----------conus12km realtime----------"
{ cat "exp.test"; echo -e 'export REALTIME=true'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_rt.xml"

# -- USE_THE_LATEST_SATBIAS --
echo -e "\n----------conus12km USE_THE_LATEST_SATBIAS----------"
{ cat "exp.test"; echo -e 'export USE_THE_LATEST_SATBIAS=true'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_satbias.xml"

# -- SFC_UPDATE_CYCS --
echo -e "\n----------conus12km SFC_UPDATE_CYCS----------"
{ cat "exp.test"; echo -e 'export SFC_UPDATE_CYCS="03 15"'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_sfcupdate.xml"

# -- coldstart-only --
echo -e "\n----------conus12km coldstart-only----------"
{ cat "exp.test"; echo -e 'export DO_CYC=false\nexport DO_JEDI=false'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_coldstart-only.xml"

# -- DO_BLENDING --
echo -e "\n----------conus12km DO_BLENDING----------"
{ cat "exp.test"; echo -e 'export DO_BLENDING=true'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_blending.xml"

# -- COLDSTART_CYCS_DO_DA --
echo -e "\n----------conus12km COLDSTART_CYCS_DO_DA----------"
{ cat "exp.test"; echo -e 'export COLDSTART_CYCS_DO_DA=true'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_coldstartDA.xml"

# -- HYB_WGT_ENS="0.5" HYB_ENS_TYPE="1" --
echo -e "\n----------conus12km HYB_WGT_ENS=0.5 HYB_ENS_TYPE=1----------"
{ cat "exp.test"; echo -e 'export HYB_WGT_ENS="0.5"\nexport HYB_ENS_TYPE="1"'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_refs.xml"

# -- HYB_WGT_ENS="0.5" HYB_ENS_TYPE="2" --
echo -e "\n----------conus12km HYB_WGT_ENS=0.5 HYB_ENS_TYPE=2----------"
{ cat "exp.test"; echo -e 'export HYB_WGT_ENS="0.5"\nexport HYB_ENS_TYPE="2"'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_gefs.xml"

# -- DO_RECENTER --
# -- global --
# -- chemistry --
# -- rtma --

# ens_conus12km
echo -e "\n----------ens_conus12km org----------"
myexp=ens_conus12km
myfile=${wflow}/exp/exp.${myexp}
sed 's|^export OPSROOT=/scratch3/BMC/wrfruc/gge/OPSROOT/${EXP_NAME}|export OPSROOT=./OPSROOT/${EXP_NAME}|' "${myfile}" > "exp.test"
./setup_rocoto.py "exp.test"
mv "OPSROOT/hrly_12km/exp/rrfsenkf/rrfs.xml" "${rundir}/xml/${myexp}_retro.xml"

echo -e "\n----------ens_conus12km realtime----------"
{ cat "exp.test"; echo -e 'export REALTIME=true'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/hrly_12km/exp/rrfsenkf/rrfs.xml" "${rundir}/xml/${myexp}_rt.xml"

# ----------------------------------------------------------------------------------------------------
# conus3km
echo -e "\n----------conus3km org----------"
myexp=conus3km
myfile=${wflow}/exp/exp.${myexp}
sed 's|^export OPSROOT=/scratch3/BMC/wrfruc/gge/OPSROOT/${EXP_NAME}|export OPSROOT=./OPSROOT/${EXP_NAME}|' "${myfile}" > "exp.test"
./setup_rocoto.py "exp.test"
mv "OPSROOT/conus3km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_retro.xml"

echo -e "\n----------conus3km realtime----------"
{ cat "exp.test"; echo -e 'export REALTIME=true'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/conus3km/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}_rt.xml"

# ens_conus3km
echo -e "\n----------ens_conus3km org----------"
myexp=ens_conus3km
myfile=${wflow}/exp/exp.${myexp}
sed 's|^export OPSROOT=/scratch3/BMC/wrfruc/gge/OPSROOT/${EXP_NAME}|export OPSROOT=./OPSROOT/${EXP_NAME}|' "${myfile}" > "exp.test"
./setup_rocoto.py "exp.test"
mv "OPSROOT/conus3km/exp/rrfsenkf/rrfs.xml" "${rundir}/xml/${myexp}_retro.xml"

echo -e "\n----------ens_conus3km realtime----------"
{ cat "exp.test"; echo -e 'export REALTIME=true'; } > exp.tmp
./setup_rocoto.py exp.tmp
mv "OPSROOT/conus3km/exp/rrfsenkf/rrfs.xml" "${rundir}/xml/${myexp}_rt.xml"


# ----------------------------------------------------------------------------------------------------
# na12km
# ens_na12km

# ----------------------------------------------------------------------------------------------------
# rt_ursa
echo -e "\n----------rrfsv2x----------"
myexp=rrfsv2x
myfile=${wflow}/exp/rt_ursa/exp.${myexp}
sed 's|^export OPSROOT=/scratch3/BMC/rtwrfruc/RRFSv2X/NCO_dirs/${EXP_NAME}|export OPSROOT=./OPSROOT/${EXP_NAME}|' "${myfile}" > "exp.test"
./setup_rocoto.py "exp.test"
mv "OPSROOT/RRFSv2X/exp/rrfsdet/rrfs.xml" "${rundir}/xml/${myexp}.xml"

echo -e "\n----------rrfsv2x_ens----------"
myexp=rrfsv2x_ens
myfile=${wflow}/exp/rt_ursa/exp.${myexp}
sed 's|^export OPSROOT=/scratch3/BMC/rtwrfruc/RRFSv2X/NCO_dirs/${EXP_NAME}|export OPSROOT=./OPSROOT/${EXP_NAME}|' "${myfile}" > "exp.test"
./setup_rocoto.py "exp.test"
mv "OPSROOT/RRFSv2X/exp/rrfsenkf/rrfs.xml" "${rundir}/xml/${myexp}.xml"

echo "OPSROOT: ${wflow}/OPSROOT"
