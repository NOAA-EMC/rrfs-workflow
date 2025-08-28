#!/bin/bash

###################################################################
echo "--------------------------------------------------------------"
echo "convert RRFS NCEP GRIB files into GEMPAK Grids"
echo "--------------------------------------------------------------"
#####################################################################

# Exit on error, print commands and their arguments
set -xa

# --- Input Arguments ---
RUNTYPE=$1
GRIB=$2
fhr=$3

cd "$DATA/$RUNTYPE"

msg="Begin job for $job"
postmsg "$msg"

export PS4='GEMPAK_T$SECONDS + '

NAGRIB=nagrib2

# --- Copy GEMPAK Tables ---
cp "$GEMPAK_FIX/rrfs_g2varsncep1.tbl" g2varsncep1.tbl
cp "$GEMPAK_FIX/rrfs_g2varswmo2.tbl" g2varswmo2.tbl
cp "$GEMPAK_FIX/rrfs_g2vcrdncep1.tbl" g2vcrdncep1.tbl
cp "$GEMPAK_FIX/rrfs_g2vcrdwmo2.tbl" g2vcrdwmo2.tbl

# --- Set GEMPAK Parameters ---
cpyfil=gds
garea=dset
gbtbls=""
maxgrd=4999
kxky=""
grdarea=""
proj=""
output=T
pdsext=no
maxtries=720

# --- Format Forecast Hour (fhr) ---

 if [[ $((10#$fhr)) -ge 100 ]]; then
 fhr_padded=$(printf "%03d" "$((10#$fhr))")
 else
   fhr_padded=$(printf "%02d" "$((10#$fhr))")
 fi
(( fhcnt3 = 10#$fhr % 3 ))

fhr3=$(printf "%03d" "$((10#$fhr))")

(( fhr3m1 = 10#$fhr3 - 1 ))
fhr3m1=$(printf "%03d" "$fhr3m1")


# --- Define Input/Output Filenames based on RUNTYPE ---
case "$RUNTYPE" in
  rrfs_alaska)
    GRIBIN="$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.ak.grib2"
    GEMGRD="${RUNTYPE}_${PDY}${cyc}f${fhr3}"
    ;;
  rrfs_conus)
    GRIBIN="$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2"
    GEMGRD="${RUNTYPE}_${PDY}${cyc}f${fhr3}"
    ;;
  rrfs_conus_subh)
    GRIBIN="$COMIN/${model}.${cycle}.${GRIB}.3km.subh.f${fhr3}.conus.grib2"
    GEMGRDa="${RUNTYPE}_${PDY}${cyc}f${fhr3m1}15"
    (( timea = (10#$fhr3m1 * 60) + 15 ))
    GEMGRDb="${RUNTYPE}_${PDY}${cyc}f${fhr3m1}30"
    (( timeb = (10#$fhr3m1 * 60) + 30 ))
    GEMGRDc="${RUNTYPE}_${PDY}${cyc}f${fhr3m1}45"
    (( timec = (10#$fhr3m1 * 60) + 45 ))
    GEMGRDd="${RUNTYPE}_${PDY}${cyc}f${fhr3}00"
    (( timed = 10#$fhr ))
    ;;
  rrfs_conus_cam)
    GRIBIN="$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2"
    GEMGRD="${RUNTYPE}_${PDY}${cyc}f${fhr3}"
    ;;
  rrfs_hawaii)
    GRIBIN="$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr3}.hi.grib2"
    GEMGRD="${RUNTYPE}_${PDY}${cyc}f${fhr3}"
    ;;
  rrfs_prico)
    GRIBIN="$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr3}.pr.grib2"
    GEMGRD="${RUNTYPE}_${PDY}${cyc}f${fhr3}"
    ;;
esac

# --- Define the check-file (usually the .idx file) ---
if [[ "$RUNTYPE" == "rrfs_alaska" ]]; then
  GRIBIN_chk="$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.ak.grib2.idx"
elif [[ "$RUNTYPE" == "rrfs_conus" ]]; then
  GRIBIN_chk="$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2.idx"
elif [[ "$RUNTYPE" == "rrfs_conus_subh" ]]; then
  GRIBIN_chk="$COMIN/${model}.${cycle}.${GRIB}.3km.subh.f${fhr3}.conus.grib2.idx"
elif [[ "$RUNTYPE" == "rrfs_conus_cam" ]]; then
  GRIBIN_chk="$COMIN/${model}.${cycle}.${GRIB}.3km.f${fhr3}.conus.grib2.idx"
elif [[ "$RUNTYPE" == "rrfs_hawaii" ]]; then
  GRIBIN_chk="$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr3}.hi.grib2.idx"
elif [[ "$RUNTYPE" == "rrfs_prico" ]]; then
  GRIBIN_chk="$COMIN/${model}.${cycle}.${GRIB}.2p5km.f${fhr3}.pr.grib2.idx"
else
  GRIBIN_chk="$GRIBIN"
fi


# --- Wait for GRIB input file to become available ---
icnt=1
while [[ $icnt -lt 1000 ]]; do
  if [[ -r "$GRIBIN_chk" ]]; then
    sleep 5
    break
  else
    (( icnt++ ))
    sleep 20
  fi

  if [[ $icnt -ge $maxtries ]]; then
    msg="ABORTING after 2 hours of waiting for F$fhr to end."
    err_exit "$msg"
  fi
done

# --- Process GRIB files based on RUNTYPE ---
case "$RUNTYPE" in
  rrfs_alaska)
    "$WGRIB2" -s "$GRIBIN" | grep -f "$GEMPAK_FIX/rrfs.parmlist" | "$WGRIB2" -i -grib temp "$GRIBIN"
    mv temp "grib${fhr_padded}"
    ;;
  rrfs_conus)
    "$WGRIB2" "$GRIBIN" | grep "REFD:263 K" | grep max | "$WGRIB2" -i -grib tempref263k "$GRIBIN"
    "$WGRIB2" tempref263k -set_byte 4 11 198 -grib tempmaxref263k
    "$WGRIB2" -s "$GRIBIN" | grep -f "$GEMPAK_FIX/rrfs.parmlist" | "$WGRIB2" -i -grib temp "$GRIBIN"
    cat temp tempmaxref263k > "grib${fhr_padded}"
    ;;
  rrfs_conus_subh)
    cp "$GRIBIN" "grib${fhr_padded}"
    wgrib2 "${GRIBIN}" -match "$timea min" -grib "grib${fhr_padded}_${timea}"
    wgrib2 "${GRIBIN}" -match "$timeb min" -grib "grib${fhr_padded}_${timeb}"
    wgrib2 "${GRIBIN}" -match "$timec min" -grib "grib${fhr_padded}_${timec}"
    wgrib2 "${GRIBIN}" -match "$timed h"   -grib "grib${fhr_padded}_${timed}"
    ;;
  rrfs_conus_cam)
    "$WGRIB2" -s "$GRIBIN" | grep -f "$GEMPAK_FIX/rrfs.parmlist_mag" | "$WGRIB2" -i -grib temp "$GRIBIN"
    "$WGRIB2" "$GRIBIN" | grep "REFD:263 K" | grep max | "$WGRIB2" -i -grib tempref263k "$GRIBIN"
    "$WGRIB2" tempref263k -set_byte 4 11 198 -grib tempmaxref263k
    cat "$GRIBIN" tempmaxref263k > "grib${fhr_padded}"
    ;;
  rrfs_hawaii)
    "$WGRIB2" -s "$GRIBIN" | grep -f "$GEMPAK_FIX/rrfs.parmlist" | "$WGRIB2" -i -grib temp "$GRIBIN"
    mv temp "grib${fhr_padded}"
    ;;
  rrfs_prico)
    "$WGRIB2" -s "$GRIBIN" | grep -f "$GEMPAK_FIX/rrfs.parmlist" | "$WGRIB2" -i -grib temp "$GRIBIN"
    mv temp "grib${fhr_padded}"
    ;;
  *)
    cp "$GRIBIN" "grib${fhr_padded}"
    ;;
esac


# --- Run NAGRIB to convert GRIB to GEMPAK format ---
if [[ "$RUNTYPE" == "rrfs_conus_subh" ]]; then

  export pgm="nagrib2 F$fhr"
  startmsg

  "$NAGRIB" << EOF
   GBFILE   = grib${fhr_padded}_${timea}
   INDXFL   =
   GDOUTF   = $GEMGRDa
   PROJ     = $proj
   GRDAREA  = $grdarea
   KXKY     = $kxky
   MAXGRD   = $maxgrd
   CPYFIL   = $cpyfil
   GAREA    = $garea
   OUTPUT   = $output
   GBTBLS   = $gbtbls
   GBDIAG   =
   PDSEXT   = $pdsext
 l
 r
EOF

  "$NAGRIB" << EOF
   GBFILE   = grib${fhr_padded}_${timeb}
   INDXFL   =
   GDOUTF   = $GEMGRDb
 r
EOF

  "$NAGRIB" << EOF
   GBFILE   = grib${fhr_padded}_${timec}
   INDXFL   =
   GDOUTF   = $GEMGRDc
 r
EOF

  "$NAGRIB" << EOF
   GBFILE   = grib${fhr_padded}_${timed}
   INDXFL   =
   GDOUTF   = $GEMGRDd
 r
EOF
  export err=$?; err_chk

else

  export pgm="nagrib2 F$fhr"
  startmsg

  "$NAGRIB" << EOF
   GBFILE   = grib${fhr_padded}
   INDXFL   =
   GDOUTF   = $GEMGRD
   PROJ     = $proj
   GRDAREA  = $grdarea
   KXKY     = $kxky
   MAXGRD   = $maxgrd
   CPYFIL   = $cpyfil
   GAREA    = $garea
   OUTPUT   = $output
   GBTBLS   = $gbtbls
   GBDIAG   =
   PDSEXT   = $pdsext
 l
 r
EOF
  export err=$?; err_chk
fi

# #####################################################
# # GEMPAK DOES NOT ALWAYS HAVE A NON ZERO RETURN CODE
# # WHEN IT CAN NOT PRODUCE THE DESIRED GRID.  CHECK
# # FOR THIS CASE HERE.
# #####################################################
if [[ "$RUNTYPE" != "rrfs_conus_subh" ]]; then
  ls -l "$GEMGRD"
  export err=$?; export pgm="GEMPAK CHECK FILE"; err_chk
else
  ls -l "$GEMGRDa" "$GEMGRDb" "$GEMGRDc" "$GEMGRDd"
  export err=$?; export pgm="GEMPAK CHECK FILE"; err_chk
fi

if [[ "$NAGRIB" == "nagrib2" ]]; then
  gpend
fi


if [[ "$SENDCOM" == "YES" ]]; then
  if [[ "$RUNTYPE" != "rrfs_conus_subh" ]]; then
    cpreq "$GEMGRD" "$COMOUT/$GEMGRD"
  else
    cpreq "$GEMGRDa" "$COMOUT/$GEMGRDa"
    cpreq "$GEMGRDb" "$COMOUT/$GEMGRDb"
    cpreq "$GEMGRDc" "$COMOUT/$GEMGRDc"
    cpreq "$GEMGRDd" "$COMOUT/$GEMGRDd"
  fi

  if [[ "$SENDDBN" == "YES" ]]; then
    "$DBNROOT/bin/dbn_alert" MODEL "${DBN_ALERT_TYPE}" "$job" \
      "$COMOUT/$GEMGRD"
  else
    echo "##### DBN_ALERT_TYPE is: ${DBN_ALERT_TYPE} #####"
  fi
fi
