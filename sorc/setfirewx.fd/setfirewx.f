       program setfirewx
!
!  This program creates the text file containing the center of the RRFS fire 
!  weather nest for each cycle. If no lat/lon is chosen, the default (DC) is
!  used.
!
       integer icyc(4)
       real xlat(4), ylat(4)
       data icyc /00,06,12,18/
!
! set default lat/lons (DC)
!
       do i = 1,4
         xlat(i) = 38.9
         ylat(i) = -77.0
       enddo
    
       iunit1=51

       open(unit=iunit1,file='rrfs_firewx_loc',status='unknown',form='formatted')

       do i = 1,4
         write(6,100) icyc(i)
         print *,"To keep default DC location, enter 0 for both"
         print *,"Otherwise format is xx.x -yyy.y (note longitude is always negative) for lat/lon"
100      format("ENTER LAT/LON FOR ",i2.2,"Z CYCLE")
         read (5,*) alat, alon
         if (alat .ne. 0.0) then
           xlat(i) = alat
           ylat(i) = alon
         endif
         write(iunit1,110) icyc(i),xlat(i),ylat(i)
110      format(i2.2,"z",1x,f4.1,1x,f6.1)
       enddo
       
       close(iunit1)
   
       end
