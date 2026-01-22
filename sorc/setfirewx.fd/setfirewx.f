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
           if (alat .ge. 52.0) then
             call nest_domain_check_location_ak(alat,alon,iret)
           else
             call nest_domain_check_location_conus(alat,alon,iret)
           endif
           if(iret<0)then
             read (5,*) alat, alon
             if (alat .ge. 52.0) then
               call nest_domain_check_location_ak(alat,alon,iret)
             else
               call nest_domain_check_location_conus(alat,alon,iret)
             endif
           endif
           xlat(i) = alat
           ylat(i) = alon
         endif
         write(iunit1,110) icyc(i),xlat(i),ylat(i)
110      format(i2.2,"z",1x,f4.1,1x,f6.1)
       enddo
       
       close(iunit1)
   
       end
         
!-----------------------------------------------------------------------
!#######################################################################
!-----------------------------------------------------------------------
!
       subroutine nest_domain_check_location_conus(alat,alon,iret)
!
!-----------------------------------------------------------------------
!***   Is the domain of the fire weather nest at the requested location
!***   entirely within the outer five rows of the CONUS nest?
!
!
       implicit none
!
!-----------------------------------------------------------------------
!
       integer,parameter :: double=selected_real_kind(p=13,r=200)
!
!------------------------
!***  Argument variables
!------------------------
!
       real,intent(in) :: alat,alon                                        !<-- Geographic lat/lon (degrees,positive north,east)
!                                                                          !    of fire weather nest center.
                                                                           !    of fire weather nest center.
       integer,intent(out) :: iret
!
!---------------------------
!***  Local variables, data
!---------------------------
!
       real(kind=double),save :: tph0d=54.0                             &  !<-- Central lat (degrees, positive north) of upper parent
                                ,tlm0d=-106.0                           &  !<-- Central lon (degrees, positive east) of upper parent
                                ,sbd_nam=-45.036                        &  !<-- Rotated latitude of upper parent south boundary
                                ,wbd_nam=-60.039                           !<-- Rotated longitude of upper parent west boundary
!
       real(kind=double),save :: im_nam=954.                            &  !<-- East-west dimension of uppermost parent
                                ,jm_nam=835.                               !<-- South-north dimension of uppermost parent
!
       real(kind=double),save :: nrows_buffer=5.                           !<-- Keep fw nest inside this many rows of CONUS edges
!
       real(kind=double),dimension(1:1),save :: im_nest=(/1827./)  &  !<-- East-west dimensions of the CONUS nests
                                               ,jm_nest=(/1467./)  &  !<-- South-north dimensions of the CONUS nests
                                               ,im_fw=(/333./)     &  !<-- East-west dimensions of the CONUS fw nests
                                               ,jm_fw=(/333./)        !<-- South-north dimensions of the CONUS fw nests
!
       real(kind=double),dimension(1:1),save :: i_sw_nest=(/295./) &  !<-- I of SW corner of nests on upper parent
                                               ,j_sw_nest=(/95./)     !<-- J of SW corner of nests on upper parent
!
       real(kind=double),dimension(1:1),save :: nam_nest_space_ratio=(/4./) &  !<-- Parent-to-nest ratios of grid increments
                                               ,nest_fw_space_ratio=(/2./)     !<-- Parent-to-fw ratios of grid increments
!
!------------------------------
!***  Local variables, general
!------------------------------
!
       integer :: i,i_sw,istart,iend,j,j_sw,jstart,jend,n
!
       integer,save :: kount_fail
!
       real(kind=double) :: cent_lat_fw,cent_lat_fw_new,cent_lat_fw_x   &
                           ,cent_lon_fw,cent_lon_fw_new,cent_lon_fw_x   &
                           ,deg2rad                                     &
                           ,dist_save,distance,dlmd_nam,dphd_nam        &
                           ,fw_extent_on_parent_ns                      &
                           ,fw_extent_on_parent_we                      &
                           ,half_inc_ns,half_inc_we                     &
                           ,lam_rot,phi_rot                             &
                           ,sbdx,nbdx                                   &
                           ,wbdx,ebdx                                   &
                           ,tlm0,tph0,x,y,z
!
       real(kind=double) :: half=0.5,one=1.,two=2.,four=4.,d180=180.
!
       real(kind=double),dimension(1:1) :: dlmd_fw,dphd_fw              &
                                          ,dlmd_nest,dphd_nest          &
                                          ,sbd_nest,nbd_nest            &
                                          ,wbd_nest,ebd_nest            &
                                          ,sbd_fw,nbd_fw                &
                                          ,wbd_fw,ebd_fw
!
       logical,dimension(1:1) :: inside
!
!-----------------------------------------------------------------------
!***********************************************************************
!-----------------------------------------------------------------------
!
      deg2rad=dacos(-one)/d180
!
      cent_lat_fw=alat
      cent_lon_fw=alon
!
      dphd_nam=-two*sbd_nam/(jm_nam-one)
      dlmd_nam=-two*wbd_nam/(im_nam-one)
!
      tph0=tph0d*deg2rad
      tlm0=tlm0d*deg2rad
!
!-----------------------------------------------------------------------
!***  Find the rotated lat/lon of the sides of the CONUS nests.
!-----------------------------------------------------------------------
!
      do n=1,1
        dphd_nest(n)=dphd_nam/nam_nest_space_ratio(n)
        dlmd_nest(n)=dlmd_nam/nam_nest_space_ratio(n)
!
        sbd_nest(n)=sbd_nam+(j_sw_nest(n)-one)*dphd_nam                    !<-- Rotated latitude of CONUS south edges
        nbd_nest(n)=sbd_nest(n)+(jm_nest(n)-one)*dphd_nest(n)              !<-- Rotated latitude of CONUS north edges
!
        wbd_nest(n)=wbd_nam+(i_sw_nest(n)-one)*dlmd_nam                    !<-- Rotated longitude of CONUS west edges
        ebd_nest(n)=wbd_nest(n)+(im_nest(n)-one)*dlmd_nest(n)              !<-- Rotated longitude of CONUS east edges
      enddo
!
!-----------------------------------------------------------------------
!***  Modify those nest boundary locations to be the rotated lat/lon
!***  of the 5th row inside the domains.  We do not want the fw nests
!***  to get within nrows_buffer rows of their parents' domain boundaries.
!-----------------------------------------------------------------------
!
      do n=1,1
        sbd_nest(n)=sbd_nest(n)+(nrows_buffer-one)*dphd_nest(n)
        nbd_nest(n)=nbd_nest(n)-(nrows_buffer-one)*dphd_nest(n)
        wbd_nest(n)=wbd_nest(n)+(nrows_buffer-one)*dlmd_nest(n)
        ebd_nest(n)=ebd_nest(n)-(nrows_buffer-one)*dlmd_nest(n)
      enddo
!
!-----------------------------------------------------------------------
!***  The user provided his desired geographic lat/lon for the center
!***  of the fw nest.  The SW corner of the fw nest must lie on an
!***  H point of the CONUS nest.  So now loop through
!***  the parents' gridpoints.  Find the distance between all the 
!***  CONUS H points that can potentially serve as a SW corner
!***  for the fw nest grid.  Select the CONUS/Alaska point that 
!***  provides a central nest point nearest to the requested lat/lon
!***  that was this subroutine's input.  The lat/lon of the fw nest's
!***  central location for its grid anchored at that SW point is then 
!***  known.
!***  However first we determine if the sides of a fw nest at the 
!***  requested location are no more than half a parent grid increment
!***  outside the outer perimeter we are using which is nrows_buffer
!***  inside the CONUS domains.  If that is not the case then 
!***  we stop.
!-----------------------------------------------------------------------
!
      loop_1 : do n=1,1                                                   !<-- Loop through CONUS domain
!
!-----------------------------------------------------------------------
!***  What are the rotated lat/lon of the requested center location?
!-----------------------------------------------------------------------
!
        inside(n)=.false.
!
        x=dcos(tph0)                                                    &
         *dcos(cent_lat_fw*deg2rad)                                     &
         *dcos(cent_lon_fw*deg2rad-tlm0)                                &
         +dsin(tph0)                                                    &
         *dsin(cent_lat_fw*deg2rad)
!
        y=dcos(cent_lat_fw*deg2rad)                                     &
         *dsin(cent_lon_fw*deg2rad-tlm0)
!
        z=-dsin(tph0)                                                   &
          *dcos(cent_lat_fw*deg2rad)                                    &
          *dcos(cent_lon_fw*deg2rad-tlm0)                               &
          +dcos(tph0)                                                   &
          *dsin(cent_lat_fw*deg2rad)
!
        phi_rot=datan(z/dsqrt(x*x+y*y))/deg2rad                            !<-- Rotated latitude (deg,N) of requested center location
        lam_rot=datan(y/x)/deg2rad                                         !<-- Rotated longitude (deg,E) of requested center location
        if(x<0.)lam_rot=lam_rot+d180
!
!-----------------------------------------------------------------------
!***  What are the rotated lat/lon of the four sides?
!-----------------------------------------------------------------------
!
        dphd_fw(n)=dphd_nest(n)/nest_fw_space_ratio(n)                     !<-- The N/S grid increment of the fw nest
        dlmd_fw(n)=dlmd_nest(n)/nest_fw_space_ratio(n)                     !<-- The W/E grid increment of the fw nest
!
        sbdx=phi_rot-half*(jm_fw(n)-one)*dphd_fw(n)
        nbdx=phi_rot+half*(jm_fw(n)-one)*dphd_fw(n)
        wbdx=lam_rot-half*(im_fw(n)-one)*dlmd_fw(n)
        ebdx=lam_rot+half*(im_fw(n)-one)*dlmd_fw(n)
!
        half_inc_ns=half*dphd_nest(n)
        half_inc_we=half*dlmd_nest(n)
!
        if(sbd_nest(n)-sbdx<half_inc_ns                                 &
                     .and.                                              &
           nbd_nest(n)-nbdx>-half_inc_ns                                &       
                     .and.                                              &
           wbd_nest(n)-wbdx<half_inc_we                                 &
                     .and.                                              &
           ebd_nest(n)-ebdx>-half_inc_we )then
!
          inside(n)=.true.

        endif
!
      enddo loop_1
!
!-----------------------------------------------------------------------
!
      iret=0
!
      if(inside(1))then
        kount_fail=0
      else
        write(0,*)' Requested fire weather nest location lies'        &
                  ,' outside the CONUS nest domain!!!'
        kount_fail=kount_fail+1
        if(kount_fail<2)then
          write(0,*)' TRY AGAIN TO SPECIFY THE LOCATION.'
          iret=-1
          RETURN
        elseif(kount_fail==2)then
          STOP ' AFTER TWO BAD LOCATIONS THE PROGRAM WILL STOP.'
        endif
      endif
!
!-----------------------------------------------------------------------
!
      loop_2 : do n=1,1
!
!-----------------------------------------------------------------------
!
        dist_save=1000000000.
!
        fw_extent_on_parent_ns=(jm_fw(n)-one)/nest_fw_space_ratio(n)       !<-- N/S extent of fw nest measured in its parent gridpoints
        fw_extent_on_parent_we=(im_fw(n)-one)/nest_fw_space_ratio(n)       !<-- W/E extent of fw nest measured in its parent gridpoints
!
        istart=nrows_buffer
        iend  =im_nest(n)-(nrows_buffer-one)
        jstart=nrows_buffer
        jend  =jm_nest(n)-(nrows_buffer-one)
!
        do j=jstart,jend
        do i=istart,iend
!
          if(i+fw_extent_on_parent_we<=im_nest(n)-4                     &  !<-- If true, fw nest is inside outer 5 rows of
                          .and.                                         &  !    CONUS/Alaska nest for SW corner of fw nest 
             j+fw_extent_on_parent_ns<=jm_nest(n)-4)then                   !    at this I,J of its parent.
!
            call center_of_nest_conus(i,j,cent_lat_fw_x,cent_lon_fw_x)           !<-- What is the fw nest's center for this location?
!
            call distance_on_sphere(cent_lat_fw,cent_lon_fw             &  !<-- Compute the distance between this center location
                                   ,cent_lat_fw_x,cent_lon_fw_x         &  !    and the user's requested center.
                                   ,distance)                              !
!
            if(distance<dist_save)then
              dist_save=distance
              i_sw=i
              j_sw=j
              cent_lat_fw_new=cent_lat_fw_x
              cent_lon_fw_new=cent_lon_fw_x
            endif
!
          endif
!
        enddo
        enddo
!
!-----------------------------------------------------------------------
!***  What are the fw nest's grid increments and boundary locations
!***  at this adjusted location?
!-----------------------------------------------------------------------
!
        sbd_fw(n)=sbd_nest(n)+(j_sw-one)*dphd_nest(n)                      !<-- Rotated lat of fw nest south boundary
        nbd_fw(n)=sbd_fw(n)+(jm_fw(n)-one)*dphd_fw(n)                      !<-- Rotated lat of fw nest north boundary
        wbd_fw(n)=wbd_nest(n)+(i_sw-one)*dlmd_nest(n)                      !<-- Rotated lon of fw nest west boundary
        ebd_fw(n)=wbd_fw(n)+(im_fw(n)-one)*dlmd_fw(n)                      !<-- Rotated lon of fw nest east boundary
!
!-----------------------------------------------------------------------
!***  Does the fw nest at this adjusted location lie within the
!***  outer nrows_buffer rows of the CONUS nest?
!-----------------------------------------------------------------------
!
        if(sbd_fw(n)>=sbd_nest(n).and.nbd_fw(n)<=nbd_nest(n)            &
                                 .and.                                  &
           wbd_fw(n)>=wbd_nest(n).and.ebd_fw(n)<=ebd_nest(n))then
!
          inside(n)=.true.
!
        endif
!
!-----------------------------------------------------------------------
!
      enddo  loop_2
!
!-----------------------------------------------------------------------
!
      contains
!
!-----------------------------------------------------------------------
!
      subroutine center_of_nest_conus(i_parent_sw,j_parent_sw                 &
                               ,phi_c,lam_c)
!
!-----------------------------------------------------------------------
!
!------------------------
!***  Argument Variables
!------------------------
!
      integer,intent(in) :: i_parent_sw                                 &  !<-- Parent I of contingent SW corner of nest
                           ,j_parent_sw                                    !<-- Parent J of contingent SW corner of nest
!
      real(kind=double),intent(out) :: lam_c,phi_c                         !<-- Lon/lat of nest center with the given SW corner
!
!---------------------
!***  Local Variables
!---------------------
!
      real(kind=double) :: arg,cent_i_fw,cent_j_fw                      &
                          ,factor,lam_t,phi_t
!
!-----------------------------------------------------------------------
!***********************************************************************
!-----------------------------------------------------------------------
!
!-----------------------------------------------------------------------
!***  What are the fw nest's central I,J relative to the parent?
!-----------------------------------------------------------------------
!
      cent_i_fw=i_parent_sw+half*(im_fw(n)-1)/nest_fw_space_ratio(n)
      cent_j_fw=j_parent_sw+half*(jm_fw(n)-1)/nest_fw_space_ratio(n)
!
!-----------------------------------------------------------------------
!***  Convert to earth lat/lon.
!-----------------------------------------------------------------------
!
      phi_t=(sbd_nest(n)+(cent_j_fw-one)*dphd_nest(n))*deg2rad             !<-- Parent's transformed latitude of fw domain's center
      lam_t=(wbd_nest(n)+(cent_i_fw-one)*dlmd_nest(n))*deg2rad             !<-- Parent's transformed longitude of fw domain's center
!
!-----------------------------------------------------------------------
!
      arg=dsin(phi_t)*dcos(tph0d*deg2rad)                               &
         +dcos(phi_t)*dsin(tph0d*deg2rad)*dcos(lam_t)
!
      phi_c=dasin(arg)                                                     !<-- Geographic latitude of nest domain's center (radians)
!
      arg=dcos(phi_t)*dcos(lam_t)                                       &
            /(dcos(phi_c)*dcos(tph0d*deg2rad))                          &
             -dtan(phi_c)*dtan(tph0d*deg2rad)
!
      factor=one
      if(lam_t<0.)factor=-one
!
      lam_c=tlm0d+factor*dacos(arg)/deg2rad                                !<-- Geographic longitude of nest domain's center (degrees)
      phi_c=phi_c/deg2rad                                                  !<-- Geographic latitude of nest domain's center (degrees)
!
!-----------------------------------------------------------------------
!
      end subroutine center_of_nest_conus
!
!-----------------------------------------------------------------------
!
      end subroutine nest_domain_check_location_conus
!
!-----------------------------------------------------------------------
!#######################################################################
!-----------------------------------------------------------------------
!
       subroutine nest_domain_check_location_ak(alat,alon,iret)
!
!-----------------------------------------------------------------------
!***   Is the domain of the fire weather nest at the requested location
!***   entirely within the outer five rows of the Alaska nest?
!
!-----------------------------------------------------------------------
!
       implicit none
!
!-----------------------------------------------------------------------
!
       integer,parameter :: double=selected_real_kind(p=13,r=200)
!
!------------------------
!***  Argument variables
!------------------------
!
       real,intent(in) :: alat,alon                                        !<-- Geographic lat/lon (degrees,positive north,east)
!                                                                          !    of fire weather nest center.
                                                                           !    of fire weather nest center.
       integer,intent(out) :: iret
!
!---------------------------
!***  Local variables, data
!---------------------------
!
       real(kind=double),save :: tph0d=54.0                             &  !<-- Central lat (degrees, positive north) of upper parent
                                ,tlm0d=-106.0                           &  !<-- Central lon (degrees, positive east) of upper parent
                                ,sbd_nam=-45.036                        &  !<-- Rotated latitude of upper parent south boundary
                                ,wbd_nam=-60.039                           !<-- Rotated longitude of upper parent west boundary
!
       real(kind=double),save :: im_nam=954.                            &  !<-- East-west dimension of uppermost parent
                                ,jm_nam=835.                               !<-- South-north dimension of uppermost parent
!
       real(kind=double),save :: nrows_buffer=5.                           !<-- Keep fw nest inside this many rows of Alaska edges
!
       real(kind=double),dimension(1:1),save :: im_nest=(/1189./)  &  !<-- East-west dimensions of the Alaska nests
                                               ,jm_nest=(/1249./)  &  !<-- South-north dimensions of the Alaska nests
                                               ,im_fw=(/333./)     &  !<-- East-west dimensions of the Alaska fw nests
                                               ,jm_fw=(/333./)        !<-- South-north dimensions of the Alaska fw nests
!
       real(kind=double),dimension(1:1),save :: i_sw_nest=(/139./) &  !<-- I of SW corner of nests on upper parent
                                               ,j_sw_nest=(/398./)     !<-- J of SW corner of nests on upper parent
!
       real(kind=double),dimension(1:1),save :: nam_nest_space_ratio=(/4./) &  !<-- Parent-to-nest ratios of grid increments
                                               ,nest_fw_space_ratio=(/2./)     !<-- Parent-to-fw ratios of grid increments
!
!------------------------------
!***  Local variables, general
!------------------------------
!
       integer :: i,i_sw,istart,iend,j,j_sw,jstart,jend,n
!
       integer,save :: kount_fail
!
       real(kind=double) :: cent_lat_fw,cent_lat_fw_new,cent_lat_fw_x   &
                           ,cent_lon_fw,cent_lon_fw_new,cent_lon_fw_x   &
                           ,deg2rad                                     &
                           ,dist_save,distance,dlmd_nam,dphd_nam        &
                           ,fw_extent_on_parent_ns                      &
                           ,fw_extent_on_parent_we                      &
                           ,half_inc_ns,half_inc_we                     &
                           ,lam_rot,phi_rot                             &
                           ,sbdx,nbdx                                   &
                           ,wbdx,ebdx                                   &
                           ,tlm0,tph0,x,y,z
!
       real(kind=double) :: half=0.5,one=1.,two=2.,four=4.,d180=180.
!
       real(kind=double),dimension(1:1) :: dlmd_fw,dphd_fw              &
                                          ,dlmd_nest,dphd_nest          &
                                          ,sbd_nest,nbd_nest            &
                                          ,wbd_nest,ebd_nest            &
                                          ,sbd_fw,nbd_fw                &
                                          ,wbd_fw,ebd_fw
!
       logical,dimension(1:1) :: inside
!
!-----------------------------------------------------------------------
!***********************************************************************
!-----------------------------------------------------------------------
!
      deg2rad=dacos(-one)/d180
!
      cent_lat_fw=alat
      cent_lon_fw=alon
!
      dphd_nam=-two*sbd_nam/(jm_nam-one)
      dlmd_nam=-two*wbd_nam/(im_nam-one)
!
      tph0=tph0d*deg2rad
      tlm0=tlm0d*deg2rad
!
!-----------------------------------------------------------------------
!***  Find the rotated lat/lon of the sides of the CONUS/Alaska nests.
!-----------------------------------------------------------------------
!
      do n=1,1
        dphd_nest(n)=dphd_nam/nam_nest_space_ratio(n)
        dlmd_nest(n)=dlmd_nam/nam_nest_space_ratio(n)
!
        sbd_nest(n)=sbd_nam+(j_sw_nest(n)-one)*dphd_nam                    !<-- Rotated latitude of Alaska south edges
        nbd_nest(n)=sbd_nest(n)+(jm_nest(n)-one)*dphd_nest(n)              !<-- Rotated latitude of Alaska north edges
!
        wbd_nest(n)=wbd_nam+(i_sw_nest(n)-one)*dlmd_nam                    !<-- Rotated longitude of Alaska west edges
        ebd_nest(n)=wbd_nest(n)+(im_nest(n)-one)*dlmd_nest(n)              !<-- Rotated longitude of Alaska east edges
      enddo
!
!-----------------------------------------------------------------------
!***  Modify those nest boundary locations to be the rotated lat/lon
!***  of the 5th row inside the domains.  We do not want the fw nests
!***  to get within nrows_buffer rows of their parents' domain boundaries.
!-----------------------------------------------------------------------
!
      do n=1,1
        sbd_nest(n)=sbd_nest(n)+(nrows_buffer-one)*dphd_nest(n)
        nbd_nest(n)=nbd_nest(n)-(nrows_buffer-one)*dphd_nest(n)
        wbd_nest(n)=wbd_nest(n)+(nrows_buffer-one)*dlmd_nest(n)
        ebd_nest(n)=ebd_nest(n)-(nrows_buffer-one)*dlmd_nest(n)
      enddo
!
!-----------------------------------------------------------------------
!***  The user provided his desired geographic lat/lon for the center
!***  of the fw nest.  The SW corner of the fw nest must lie on an
!***  H point of the Alaska nest.  So now loop through
!***  the parents' gridpoints.  Find the distance between all the 
!***  Alaska H points that can potentially serve as a SW corner
!***  for the fw nest grid.  Select the Alaska point that 
!***  provides a central nest point nearest to the requested lat/lon
!***  that was this subroutine's input.  The lat/lon of the fw nest's
!***  central location for its grid anchored at that SW point is then 
!***  known.
!***  However first we determine if the sides of a fw nest at the 
!***  requested location are no more than half a parent grid increment
!***  outside the outer perimeter we are using which is nrows_buffer
!***  inside the CONUS domains.  If that is not the case then 
!***  we stop.
!-----------------------------------------------------------------------
!
      loop_1 : do n=1,1                                                   !<-- Loop through Alaska domain
!
!-----------------------------------------------------------------------
!***  What are the rotated lat/lon of the requested center location?
!-----------------------------------------------------------------------
!
        inside(n)=.false.
!
        x=dcos(tph0)                                                    &
         *dcos(cent_lat_fw*deg2rad)                                     &
         *dcos(cent_lon_fw*deg2rad-tlm0)                                &
         +dsin(tph0)                                                    &
         *dsin(cent_lat_fw*deg2rad)
!
        y=dcos(cent_lat_fw*deg2rad)                                     &
         *dsin(cent_lon_fw*deg2rad-tlm0)
!
        z=-dsin(tph0)                                                   &
          *dcos(cent_lat_fw*deg2rad)                                    &
          *dcos(cent_lon_fw*deg2rad-tlm0)                               &
          +dcos(tph0)                                                   &
          *dsin(cent_lat_fw*deg2rad)
!
        phi_rot=datan(z/dsqrt(x*x+y*y))/deg2rad                            !<-- Rotated latitude (deg,N) of requested center location
        lam_rot=datan(y/x)/deg2rad                                         !<-- Rotated longitude (deg,E) of requested center location
        if(x<0.)lam_rot=lam_rot+d180
!
!-----------------------------------------------------------------------
!***  What are the rotated lat/lon of the four sides?
!-----------------------------------------------------------------------
!
        dphd_fw(n)=dphd_nest(n)/nest_fw_space_ratio(n)                     !<-- The N/S grid increment of the fw nest
        dlmd_fw(n)=dlmd_nest(n)/nest_fw_space_ratio(n)                     !<-- The W/E grid increment of the fw nest
!
        sbdx=phi_rot-half*(jm_fw(n)-one)*dphd_fw(n)
        nbdx=phi_rot+half*(jm_fw(n)-one)*dphd_fw(n)
        wbdx=lam_rot-half*(im_fw(n)-one)*dlmd_fw(n)
        ebdx=lam_rot+half*(im_fw(n)-one)*dlmd_fw(n)
!
        half_inc_ns=half*dphd_nest(n)
        half_inc_we=half*dlmd_nest(n)
!
        if(sbd_nest(n)-sbdx<half_inc_ns                                 &
                     .and.                                              &
           nbd_nest(n)-nbdx>-half_inc_ns                                &       
                     .and.                                              &
           wbd_nest(n)-wbdx<half_inc_we                                 &
                     .and.                                              &
           ebd_nest(n)-ebdx>-half_inc_we )then
!
          inside(n)=.true.

        endif
!
      enddo loop_1
!
!-----------------------------------------------------------------------
!
      iret=0
!
      if(inside(1))then
        kount_fail=0
      else
        write(0,*)' Requested fire weather nest location lies'        &
                    ,' outside the Alaska nest domain!!!'
        kount_fail=kount_fail+1
        if(kount_fail<2)then
          write(0,*)' TRY AGAIN TO SPECIFY THE LOCATION.'
          iret=-1
          RETURN
        elseif(kount_fail==2)then
          STOP ' AFTER TWO BAD LOCATIONS THE PROGRAM WILL STOP.'
        endif
      endif
!
!-----------------------------------------------------------------------
!
      loop_2 : do n=1,1
!
!-----------------------------------------------------------------------
!
        dist_save=1000000000.
!
        fw_extent_on_parent_ns=(jm_fw(n)-one)/nest_fw_space_ratio(n)       !<-- N/S extent of fw nest measured in its parent gridpoints
        fw_extent_on_parent_we=(im_fw(n)-one)/nest_fw_space_ratio(n)       !<-- W/E extent of fw nest measured in its parent gridpoints
!
        istart=nrows_buffer
        iend  =im_nest(n)-(nrows_buffer-one)
        jstart=nrows_buffer
        jend  =jm_nest(n)-(nrows_buffer-one)
!
        do j=jstart,jend
        do i=istart,iend
!
          if(i+fw_extent_on_parent_we<=im_nest(n)-4                     &  !<-- If true, fw nest is inside outer 5 rows of
                          .and.                                         &  !    CONUS/Alaska nest for SW corner of fw nest 
             j+fw_extent_on_parent_ns<=jm_nest(n)-4)then                   !    at this I,J of its parent.
!
            call center_of_nest_ak(i,j,cent_lat_fw_x,cent_lon_fw_x)           !<-- What is the fw nest's center for this location?
!
            call distance_on_sphere(cent_lat_fw,cent_lon_fw             &  !<-- Compute the distance between this center location
                                   ,cent_lat_fw_x,cent_lon_fw_x         &  !    and the user's requested center.
                                   ,distance)                              !
!
            if(distance<dist_save)then
              dist_save=distance
              i_sw=i
              j_sw=j
              cent_lat_fw_new=cent_lat_fw_x
              cent_lon_fw_new=cent_lon_fw_x
            endif
!
          endif
!
        enddo
        enddo
!
!-----------------------------------------------------------------------
!***  What are the fw nest's grid increments and boundary locations
!***  at this adjusted location?
!-----------------------------------------------------------------------
!
        sbd_fw(n)=sbd_nest(n)+(j_sw-one)*dphd_nest(n)                      !<-- Rotated lat of fw nest south boundary
        nbd_fw(n)=sbd_fw(n)+(jm_fw(n)-one)*dphd_fw(n)                      !<-- Rotated lat of fw nest north boundary
        wbd_fw(n)=wbd_nest(n)+(i_sw-one)*dlmd_nest(n)                      !<-- Rotated lon of fw nest west boundary
        ebd_fw(n)=wbd_fw(n)+(im_fw(n)-one)*dlmd_fw(n)                      !<-- Rotated lon of fw nest east boundary
!
!-----------------------------------------------------------------------
!***  Does the fw nest at this adjusted location lie within the
!***  outer nrows_buffer rows of the Alaska nest?
!-----------------------------------------------------------------------
!
        if(sbd_fw(n)>=sbd_nest(n).and.nbd_fw(n)<=nbd_nest(n)            &
                                 .and.                                  &
           wbd_fw(n)>=wbd_nest(n).and.ebd_fw(n)<=ebd_nest(n))then
!
          inside(n)=.true.
!
        endif
!
!-----------------------------------------------------------------------
!
      enddo  loop_2
!
!-----------------------------------------------------------------------
!
      contains
!
!-----------------------------------------------------------------------
!
      subroutine center_of_nest_ak(i_parent_sw,j_parent_sw                 &
                               ,phi_c,lam_c)
!
!-----------------------------------------------------------------------
!
!------------------------
!***  Argument Variables
!------------------------
!
      integer,intent(in) :: i_parent_sw                                 &  !<-- Parent I of contingent SW corner of nest
                           ,j_parent_sw                                    !<-- Parent J of contingent SW corner of nest
!
      real(kind=double),intent(out) :: lam_c,phi_c                         !<-- Lon/lat of nest center with the given SW corner
!
!---------------------
!***  Local Variables
!---------------------
!
      real(kind=double) :: arg,cent_i_fw,cent_j_fw                      &
                          ,factor,lam_t,phi_t
!
!-----------------------------------------------------------------------
!***********************************************************************
!-----------------------------------------------------------------------
!
!-----------------------------------------------------------------------
!***  What are the fw nest's central I,J relative to the parent?
!-----------------------------------------------------------------------
!
      cent_i_fw=i_parent_sw+half*(im_fw(n)-1)/nest_fw_space_ratio(n)
      cent_j_fw=j_parent_sw+half*(jm_fw(n)-1)/nest_fw_space_ratio(n)
!
!-----------------------------------------------------------------------
!***  Convert to earth lat/lon.
!-----------------------------------------------------------------------
!
      phi_t=(sbd_nest(n)+(cent_j_fw-one)*dphd_nest(n))*deg2rad             !<-- Parent's transformed latitude of fw domain's center
      lam_t=(wbd_nest(n)+(cent_i_fw-one)*dlmd_nest(n))*deg2rad             !<-- Parent's transformed longitude of fw domain's center
!
!-----------------------------------------------------------------------
!
      arg=dsin(phi_t)*dcos(tph0d*deg2rad)                               &
         +dcos(phi_t)*dsin(tph0d*deg2rad)*dcos(lam_t)
!
      phi_c=dasin(arg)                                                     !<-- Geographic latitude of nest domain's center (radians)
!
      arg=dcos(phi_t)*dcos(lam_t)                                       &
            /(dcos(phi_c)*dcos(tph0d*deg2rad))                          &
             -dtan(phi_c)*dtan(tph0d*deg2rad)
!
      factor=one
      if(lam_t<0.)factor=-one
!
      lam_c=tlm0d+factor*dacos(arg)/deg2rad                                !<-- Geographic longitude of nest domain's center (degrees)
      phi_c=phi_c/deg2rad                                                  !<-- Geographic latitude of nest domain's center (degrees)
!
!-----------------------------------------------------------------------
!
      end subroutine center_of_nest_ak
!
!-----------------------------------------------------------------------
!
      end subroutine nest_domain_check_location_ak
!
!
!-----------------------------------------------------------------------
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!-----------------------------------------------------------------------
!
      subroutine distance_on_sphere(lat1,lon1,lat2,lon2                 &
                                   ,distance)
!
!-----------------------------------------------------------------------
      implicit none
!-----------------------------------------------------------------------
!
      integer,parameter :: double=selected_real_kind(p=13,r=200)
!
      real(kind=double),parameter :: radius=6376000.
!
!-----------------------------------------------------------------------
!
      real(kind=double),intent(in) :: lat1,lon1,lat2,lon2
!
      real(kind=double),intent(out) :: distance
!
      real(kind=double) :: alpha,arg,beta,cross,dlon,dtr             &
                          ,phi1,phi2,pi,pi_h
!
!--------------------------------------------------------------------
!********************************************************************
!--------------------------------------------------------------------
!
      pi_h=acos(0.)
      pi=2.*pi_h
      dtr=pi/180.
!
!--------------------------------------------------------------------
!
      phi1=lat1*dtr
      phi2=lat2*dtr
      dlon=(lon2-lon1)*dtr
!
      cross=acos(cos(dlon)*cos(phi2))
      arg=tan(phi2)/sin(dlon)
      alpha=atan(arg)
      if(dlon<0.)alpha=-alpha
      beta=pi_h-alpha
!
      distance=acos(cos(phi1)*cos(phi2)*cos(dlon)+sin(phi1)*sin(cross)*cos(beta))
!
      distance=distance*radius
!
!--------------------------------------------------------------------
!
      end subroutine distance_on_sphere
!
!--------------------------------------------------------------------
