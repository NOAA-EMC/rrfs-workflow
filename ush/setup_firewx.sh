#!/bin/sh

##########################################
echo "This script is run by the SDM to create the text file"
echo "with the central lat/lon of the RRFS fire weather nest."
echo "This text file, called "rrfs_firewx_loc" is copied to" 
echo "/lfs/h1/ops/prod/com/rrfs/v1.0/firewx_input and is read"
echo "by the RRFS jobs that process the fire weather nest."
##########################################

function setfirewx { 
     
# Set default center lat/lons (Washington DC)
   lat=38.9
   lon=-77.0
    
   echo
   echo
   echo "Enter center latitude and longitude points for ${cyc}Z cycle"
   echo "To keep default location as Washington DC, enter 0.0 for both"
   echo "Otherwise format is xx.x -yyy.y"
   read clat clon

   if [ $clat != "0.0" ] && [ $clon != "0.0" ]; then
    lat=$clat
    lon=$clon
   fi
  
   echo
   echo "Run Python script to check whether the center lat/lon are inside the RRFS domain"
   python $HOMErrfs/ush/rrfsfw_domain.py $lat $lon

}

##########################################
# Start of script
##########################################

envir=${envir:-prod}

# in ush
currentDir=`pwd`
HOMErrfs=$currentDir/..

. ${HOMErrfs}/versions/run.ver
COMOUT=/lfs/h1/ops/${envir}/com/rrfs/${rrfs_ver}/firewx_input

TMP=/lfs/h1/nco/ptmp
mkdir -p ${TMP}/`whoami`/firewx_setup
cd ${TMP}/`whoami`/firewx_setup
rm rrfs_firewx_loc

###
#main menu loop
###

###clear
endloop=""
until [ -n "$endloop" ]
do
 prcss_points="no"
 enter_dat="no"
 prcss="no"

 echo
 echo
 echo "Welcome to the firewx setup script..."
 echo
 echo "1. Enter firewx points"
 echo "2. Enter same firewx points as yesterday for all four cycles"
 echo "3. Check to see what points are currently entered in production"
 echo "4. Quit"
 echo 
 echo "Please select from the above (1-4):"
 read choice 
 
 case "$choice"
 in
  1) prcss_points="yes" 
     enter_dat="yes";;

  2) echo "Use same fire weather points as yesterday, which are:"
     echo
     echo "CYCLE     LAT      LON   "
     echo "-------------------------"
     for cyc in 00 06 12 18
     do
      lt=`grep ${cyc}z $COMOUT/rrfs_firewx_loc | awk '{print $2}'`
      lg=`grep ${cyc}z $COMOUT/rrfs_firewx_loc | awk '{print $3}'`
      echo "$cyc        $lt     $lg"
     done
     echo "exit script"
     exit 0 ;;
    
  3) clear
     echo "CURRENT SUBMITTED FIREWX POINTS/INFO IN PRODUCTION"
     echo 
     echo "CYCLE     LAT      LON   "
     echo "-------------------------"
     for cyc in 00 06 12 18 
     do
      lt=`grep ${cyc}z $COMOUT/rrfs_firewx_loc | awk '{print $2}'`
      lg=`grep ${cyc}z $COMOUT/rrfs_firewx_loc | awk '{print $3}'`
      echo "$cyc	$lt	$lg"
     done ;;
     
  4) endloop="yes";;

  *) echo "You entered $choice...Invalid Choice...try again"  ;;
 esac
 
 if [ "$prcss_points" = "yes" ]
  then
 if [ "$enter_dat" = "yes" ]
  then

  for cyc in 00 06 12 18
  do

# Call setfirewx function to set latitude and longitude
   check="incomplete"
   while [ ${check} = "incomplete" ] 
   do
    setfirewx
    if [ $? -ne 0 ]; then
     echo
     echo "WARNING: Problem with the requested fire weather grid"
     echo "Try again"
    else
     check="complete"
    fi
   done

   echo
   echo "For the ${cyc}Z cycle, the center latitude is ${lat} degrees and the center longitude is ${lon} degrees"
   echo "${cyc}z $lat $lon" >> rrfs_firewx_loc

  done

  clear
  echo "NEW FIREWX POINTS IN PRODUCTION"
  echo
  echo "CYCLE     LAT      LON   "
  echo "-------------------------"
  for cyc in 00 06 12 18
  do
   lt=`grep ${cyc}z rrfs_firewx_loc | awk '{print $2}'`
   lg=`grep ${cyc}z rrfs_firewx_loc | awk '{print $3}'`
   echo "$cyc        $lt     $lg"
  done

  cp -p $COMOUT/rrfs_firewx_loc $COMOUT/rrfs_firewx_loc_prev
  cp rrfs_firewx_loc $COMOUT/rrfs_firewx_loc

  fi #end prscc if statement

 fi  #end prcss_points if statement

done #end main until loop
