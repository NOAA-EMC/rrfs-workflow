module grb2nemsio_module


  !=======================================================================

  ! Define associated modules and subroutines

  !-----------------------------------------------------------------------
  use netcdf
  use constants
  use kinds
  use nemsio_module   

  type,public :: nemsio_meta

     character(nemsio_charkind),   dimension(:),       allocatable :: recname	     
     character(nemsio_charkind),   dimension(:),       allocatable :: reclevtyp      
     character(16),                dimension(:),       allocatable :: variname	     
     character(16),                dimension(:),       allocatable :: varr8name      
     character(16),                dimension(:),       allocatable :: aryiname	      
     character(nemsio_charkind8)                                   :: gdatatype      
     character(nemsio_charkind8)                                   :: modelname 
     character(nemsio_charkind8)								   :: modelfiletype     
     real(nemsio_realkind)                                         :: rlon_min	     
     real(nemsio_realkind)                                         :: rlon_max	     
     real(nemsio_realkind)                                         :: rlat_min	     
     real(nemsio_realkind)                                         :: rlat_max     
     real(nemsio_realkind),        dimension(:),       allocatable :: lon     
     real(nemsio_realkind),        dimension(:),       allocatable :: lat
     real(nemsio_realkind),        dimension(:),       allocatable :: ri
     real(nemsio_realkind),        dimension(:),       allocatable :: cpi
     real(nemsio_realkind),		   dimension(:,:,:),   allocatable :: vcoord
     integer(nemsio_intkind),      dimension(:,:),     allocatable :: aryival	     
     integer(nemsio_intkind),      dimension(:),       allocatable :: reclev	     
     integer(nemsio_intkind),      dimension(:),       allocatable :: varival	     
     integer(nemsio_intkind),      dimension(:),       allocatable :: aryilen	     	     
     integer(nemsio_intkind)                                       :: idate(7)	     
     integer(nemsio_intkind)                                       :: version	     
     integer(nemsio_intkind)                                       :: nreo_vc	     
     integer(nemsio_intkind)                                       :: nrec	     
     integer(nemsio_intkind)                                       :: nmeta	     
     integer(nemsio_intkind)                                       :: nmetavari      
     integer(nemsio_intkind)                                       :: nmetaaryi
     integer(nemsio_intkind)									   :: nmetaaryr     
     integer(nemsio_intkind)                                       :: nfhour	     
     integer(nemsio_intkind)                                       :: nfminute	     
     integer(nemsio_intkind)                                       :: nfsecondn      
     integer(nemsio_intkind)                                       :: nfsecondd      
     integer(nemsio_intkind)                                       :: dimx     
     integer(nemsio_intkind)                                       :: dimy     
     integer(nemsio_intkind)                                       :: dimz     
     integer(nemsio_intkind)                                       :: nframe     
     integer(nemsio_intkind)                                       :: nsoil     
     integer(nemsio_intkind)                                       :: ntrac    
     integer(nemsio_intkind)                                       :: ncldt     
     integer(nemsio_intkind)                                       :: idvc     
     integer(nemsio_intkind)                                       :: idsl     
     integer(nemsio_intkind)                                       :: idvm     
     integer(nemsio_intkind)                                       :: idrt     
     integer(nemsio_intkind)                                       :: fhour 
     integer(nemsio_intkind)									   :: jcap
     integer(nemsio_intkind)									   :: kgds(200)
     

  end type nemsio_meta ! type nemsio_meta
  contains

!-----------------------------------------------------------------------
 SUBROUTINE P2HYO(PI,MLON,NLAT,KLEVI,XI,PSFC &
                      ,P0,HYAO,HYBO,KLEVO,XO,XMSG &
                      ,KFLAG,IER) 
      IMPLICIT NONE
      
!      this routine interploates constant pres levels to hybrid
!     the formula for the pressure of a hybrid surface is;
!          phy(k) = pOut(k) = hya(k)*p0 + hyb(k)*psfc
!
!     input  ["i" input ... "o" output]
!          pi     - pressure level                     [input]
!          psfc   - is the surface pressure Pa         [input]
!          mlon   - longitude dimension
!          nlat   - latitude  dimension
!          klevi  - number of input  levels
!          hyao   - is the "a" or pressure hybrid coef
!          hybo   - is the "b" or sigma coeficient
!          klevo  - number of output levels
!          kflag  - specify how values outside the "pi" will be handled
!                   By "outside" I mean [pOut < pi(1)] or [pOut > pi(klevi)]
!                   Extrapolation is via log-linear extrapolation.
!                   =0   no extrapolation. Values set to _FillValue
!                   =1   values set to nearest valid value
!                   =2   values at pOut less    than pi(1) set to nearest value
!                        values at pOut greater than pi(klevi) are extrapolated 
!                   =3   values at pOut less    than pi(1) are extrapolated
!                        values at pOut greater than pi(klevi) set to nearest value 
!                   =4   values at pOut less    than pi(1) are extrapolated
!                        values at pOut greater than pi(klevi) are extrapolated
!               
!          ier    - error code  [=0 no error detected]
!                               [.ne.0 error detected: one or both
!                                      pressure arrays not top->bot order]
!     output
!          iflag  - indicates whether missing values in output
!          xo     - pressure at hybrid levels [Pa]
      
      INTEGER 				:: MLON,NLAT,KLEVI,KLEVO,KFLAG
      INTEGER				:: IFLAG, IER
      REAL					:: P0,PI(KLEVI),PSFC(MLON,NLAT),XI(MLON,NLAT,KLEVI)
      REAL                	:: HYAO(KLEVO),HYBO(KLEVO),XMSG
      REAL					:: XO(MLON,NLAT,KLEVO)
      REAL					:: PO(KLEVO)

      
      
      IFLAG = 0
!                                                 ! ? input asending order     
      IER   = 0
      
      !print *, HYAO(KLEVO), ' ', HYBO(KLEVO), ' ', PSFC(1,1), ' ', P0
      !	print *, PI
      
      IF (PI(1).GT.PI(KLEVI)) THEN
          IER = 1
      END IF

      PO(1)     = HYAO(1)*P0     + HYBO(1)*PSFC(1,1)
      
      PO(KLEVO) = HYAO(KLEVO)*P0 + HYBO(KLEVO)*PSFC(1,1)
!                                                 ! ? output ascending order     
      IF (PO(1).GT.PO(KLEVO)) THEN
          IER = 20 + IER
      END IF

      IF (IER.NE.0) RETURN

      CALL P2HYB(PI,MLON,NLAT,KLEVI,XI,PSFC,P0,HYAO,HYBO,KLEVO,XO,PO 	&
               ,IFLAG, KFLAG, XMSG)
      RETURN
END subroutine p2hyo

SUBROUTINE P2HYB(PI,MLON,NLAT,KLEVI,XI,PSFC,P0,HYAO,HYBO,KLEVO 			&
                     ,XO,PO,IFLAG, KFLAG, XMSG)
      IMPLICIT NONE
!                                                 ! input
      INTEGER 			:: MLON,NLAT,KLEVI,KLEVO,IFLAG, KFLAG
      REAL 				:: P0,HYAI(KLEVI),HYBI(KLEVI),HYAO(KLEVO),		&
                      HYBO(KLEVO),PSFC(MLON,NLAT),XI(MLON,NLAT,KLEVI),	&
                      PI(KLEVI),PO(KLEVO),XMSG
      REAL 				:: XO(MLON,NLAT,KLEVO)
      INTEGER			:: NL,ML,KI,KO
      REAL				:: PIMIN, PIMAX, POMIN, POMAX, DXDP

      
      
      PIMIN = PI(1)   
      PIMAX = PI(KLEVI)

      DO NL = 1,NLAT
        DO ML = 1,MLON

          DO KO = 1,KLEVO
             PO(KO) = HYAO(KO)*P0 + HYBO(KO)*PSFC(ML,NL)     
             
          END DO

          POMIN = PO(1)
          POMAX = PO(KLEVO)
          

          DO KO = 1,KLEVO
             XO(ML,NL,KO) = XMSG
          
            DO KI = 1,KLEVI-1
               IF (PO(KO).GE.PIMIN .AND. PO(KO).LE.PIMAX ) THEN     
                   IF (PO(KO).GE.PI(KI) .AND. PO(KO).LT.PI(KI+1)) THEN
                   	
                       XO(ML,NL,KO) = XI(ML,NL,KI) 						&
                                   +(XI(ML,NL,KI+1)-XI(ML,NL,KI))*		&
                                    (LOG(PO(KO))  -LOG(PI(KI)))/		&
                                    (LOG(PI(KI+1))-LOG(PI(KI)))	
                   ! if (NL .eq. 50 .and. ML .eq. 50) then
          		!	endif	
          			
                   END IF
                   
               ELSE
                   IF (KFLAG.EQ.0) THEN
                       IFLAG = 1
                       
                   END IF

                   IF (KFLAG.EQ.1) THEN
                       IF (PO(KO).LT.PIMIN) THEN
                           XO(ML,NL,KO) = XI(ML,NL,1)
                       END IF
                       IF (PO(KO).GT.PIMAX) THEN
                           XO(ML,NL,KO) = XI(ML,NL,KLEVI)
                       END IF
                       
                   END IF

                   IF (KFLAG.EQ.2) THEN
                       IF (PO(KO).LT.PIMIN) THEN
                           XO(ML,NL,KO) = XI(ML,NL,1)   
                       END IF
                       IF (PO(KO).GT.PIMAX) THEN
                           DXDP = (XI(ML,NL,KLEVI)-XI(ML,NL,KLEVI-1))* 	&
                                 (LOG(PI(KLEVI))-LOG(PI(KLEVI-1)))
                           XO(ML,NL,KO) = XI(ML,NL,KLEVI)				&
                                 + (LOG(PO(KO))-LOG(PI(KLEVI)))*DXDP   
                       END IF
                       
                   END IF

                   IF (KFLAG.EQ.3) THEN
                       IF (PO(KO).LT.PIMIN) THEN
                           DXDP = (XI(ML,NL,2)-XI(ML,NL,1))* 			&
                                 (LOG(PI(2))-LOG(PI(1)))
                           XO(ML,NL,KO) = XI(ML,NL,1)					&
                                 + (LOG(PO(KO))-LOG(PI(1)))*DXDP   
                       END IF
                       IF (PO(KO).GT.PIMAX) THEN
                           XO(ML,NL,KO) = XI(ML,NL,KLEVI)   
                       END IF
                       
                   END IF

                   IF (KFLAG.EQ.4) THEN
                       IF (PO(KO).LT.PIMIN) THEN
                           DXDP = (XI(ML,NL,2)-XI(ML,NL,1))* 			&
                                 (LOG(PI(2))-LOG(PI(1)))
                           XO(ML,NL,KO) = XI(ML,NL,1)					&
                                 + (LOG(PO(KO))-LOG(PI(1)))*DXDP   
                       END IF
                       IF (PO(KO).GT.PIMAX) THEN
                           DXDP = (XI(ML,NL,KLEVI)-XI(ML,NL,KLEVI-1))* 	&
                                 (LOG(PI(KLEVI))-LOG(PI(KLEVI-1)))
                           XO(ML,NL,KO) = XI(ML,NL,KLEVI)				&
                                 + (LOG(PO(KO))-LOG(PI(KLEVI)))*DXDP   
                       END IF

                   END IF
                   	
               END IF
               
             END DO
             
          END DO
        END DO
      END DO

      RETURN
 END subroutine p2hyb
!-----------------------------------------------------------------------
  subroutine gen_fhours_array(fstart,fend,fspan,nhours,fhours)
  
  	implicit none
  	integer :: fstart,fend,fspan,nhours, i
  	integer :: fhours(nhours) 
  	
  	 do i=1,nhours
  	 	fhours(i) = fstart + (i-1)*fspan
  	 enddo

  end subroutine gen_fhours_array
!-----------------------------------------------------------------------
  subroutine fv3_comp_sphum(T,RH,P,sphum)
    
    implicit none
	integer,parameter			 :: alpha=-9.477E-4 !K^-1
	integer,parameter			 :: Tnot=273.15 !K
	integer,parameter			 :: Lnot=2.5008E6 !JKg^-1
	integer,parameter			 :: Rv=461.51 !JKg^-1K^-1
	integer,parameter			 :: esnot=611.21 !Pa
    real                         :: T,RH,P,sphum,es,e
    
	!print *, 'T = ', T, ' RH = ', RH, ' P = ', P
	es = esnot * EXP( Lnot/Rv * ((T-Tnot)/(T*tnot) + alpha * LOG(T/Tnot) - alpha * (T-Tnot)/ T))
	!print *, 'es = ', es
	e = RH * es / 100.0
	!print *, 'e = ', e
	sphum = 0.622 * e / P 
	!print *, 'q = ', sphum
	
	!if (P .eq. 100000.0) THEN
	!	print *, 'T = ', T, ' RH = ', RH, ' P = ', P, ' es = ', es, ' e = ', e, ' q = ', sphum
	!end if


end subroutine    fv3_comp_sphum
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
  subroutine fv3_netcdf_read_1d(ncid1d,meta_nemsio,varname,data1d)
    
    implicit none
    type(nemsio_meta)               :: meta_nemsio
    integer                         :: ncid1d
    integer                         :: varid,stat
    real                            :: data1d(meta_nemsio%dimz)
    character(len=25)      :: varname

  ! loop through 2d data
    stat = nf90_inq_varid(ncid1d,trim(varname),varid)
    !print*,stat,varid,trim(varname)
    stat = nf90_get_var(ncid1d,varid,data1d,start=(/1/),count=(/meta_nemsio%dimz/))
    IF (stat .NE. 0 ) THEN
       print*,'error reading ',varname
       STOP
    ENDIF

end subroutine    fv3_netcdf_read_1d
!-----------------------------------------------------------------------
  subroutine fv3_netcdf_read_2d(ncid2d,ifhr,meta_nemsio,varname,data2d)
    
    implicit none
    type(nemsio_meta)               :: meta_nemsio
    integer                         :: ncid2d
    integer                         :: ifhr,varid,stat
    real                            :: data2d(meta_nemsio%dimx,meta_nemsio%dimy)
    character(len=25)      :: varname

  ! loop through 2d data

    stat = nf90_inq_varid(ncid2d,trim(varname),varid)
    !print*,stat,varid,trim(varname)

    stat = nf90_get_var(ncid2d,varid,data2d,start=(/1,1,ifhr/),count=(/meta_nemsio%dimx,meta_nemsio%dimy,1/))

    IF (stat .NE. 0 ) THEN
       print*,'error reading ',varname
       STOP
    ENDIF

end subroutine    fv3_netcdf_read_2d
!-----------------------------------------------------------------------

  subroutine fv3_netcdf_read_3d(ncid3d,ifhr,meta_nemsio,varname,k,nlevs,data3d)
    
    implicit none
    
    type(nemsio_meta)               :: meta_nemsio
    integer                         :: ncid3d
    integer                         :: k
    integer                         :: ifhr,varid,stat,nlevs
    character(len=25)      :: varname
    real                            :: data3d(meta_nemsio%dimx,meta_nemsio%dimy,nlevs)
    !real                            :: data2d(meta_nemsio%dimx,meta_nemsio%dimy)


    stat = nf90_inq_varid(ncid3d,trim(varname),varid)
    stat = nf90_get_var(ncid3d,varid,data3d,start=(/1,1,k,ifhr/),count=(/meta_nemsio%dimx,meta_nemsio%dimy,nlevs,1/))
    !stat = nf90_get_var(ncid3d,varid,data2d,start=(/1,1,k,ifhr/),count=(/meta_nemsio%dimx,meta_nemsio%dimy,1,1/))
    
    IF (stat .NE. 0 ) THEN
       print*,'error reading ',varname
       STOP
    ENDIF
   
end subroutine    fv3_netcdf_read_3d
!-----------------------------------------------------------------------

  subroutine define_nemsio_meta(meta_nemsio,nlons,nlats,nlevs,nvar2d,nvar3d,names2d,levs2d,lons,lats,mname)
    implicit none
    type(nemsio_meta)               :: meta_nemsio
    integer                         :: nlons,nlats,nlevs,i,j,k,nvar2d,nvar3d
    integer*8                       :: ct
    real                			:: lons(nlons),lats(nlats)
    character(len=25), dimension(nvar2d) :: names2d, levs2d 
    character(len=15)				:: mname
    integer, parameter				:: one=1
! local

    meta_nemsio%idate(1:6) = 0
    meta_nemsio%idate(7)   = 1
    
    meta_nemsio%version    = 198410
    meta_nemsio%nrec       = nvar2d + nlevs*nvar3d 
    meta_nemsio%nmeta      = 8
    meta_nemsio%nmetavari  = 8
    meta_nemsio%nmetaaryi  = 1
    
    meta_nemsio%dimx       = nlons
    meta_nemsio%dimy       = nlats
    meta_nemsio%dimz		= nlevs
    meta_nemsio%rlon_min   = minval(lons)
	meta_nemsio%rlon_max   = maxval(lons)
	meta_nemsio%rlat_min   = minval(lats)
	meta_nemsio%rlat_max   = maxval(lats)
	
    if (mname=='gfs4' .or. mname=='gfs3') then
		meta_nemsio%modelname  	= 'GFS'
		meta_nemsio%jcap		= 1534
		meta_nemsio%ncldt      	= 1
		meta_nemsio%ntrac		= 3
	else if (mname == 'ruc13_native') then
		meta_nemsio%modelname  	= 'RAP'
		meta_nemsio%ncldt      	= 5
		meta_nemsio%ntrac		= 7
	elseif(mname == 'nam') then
	 	meta_nemsio%modelname  	= 'NAM'
		meta_nemsio%ncldt      	= 1
		meta_nemsio%ntrac		= 3
	endif
	
    meta_nemsio%nsoil      = 4
    meta_nemsio%nframe     = 0
    meta_nemsio%nfminute   = 0
    meta_nemsio%nfsecondn  = 0
    meta_nemsio%nfsecondd  = 1
    meta_nemsio%idrt       = 0  
    meta_nemsio%idsl	    = 1
    meta_nemsio%idvm		= 2 
    
    meta_nemsio%idvc       = 1
   



   allocate(meta_nemsio%recname(meta_nemsio%nrec))
   allocate(meta_nemsio%reclevtyp(meta_nemsio%nrec))
   allocate(meta_nemsio%reclev(meta_nemsio%nrec))
   allocate(meta_nemsio%variname(meta_nemsio%nmetavari))
   allocate(meta_nemsio%varival(meta_nemsio%nmetavari))
   allocate(meta_nemsio%aryiname(meta_nemsio%nmetaaryi))
   allocate(meta_nemsio%aryilen(meta_nemsio%nmetaaryi))
   allocate(meta_nemsio%lon(nlons*nlats))
   allocate(meta_nemsio%lat(nlons*nlats))
   allocate(meta_nemsio%ri(meta_nemsio%ntrac))
   allocate(meta_nemsio%cpi(meta_nemsio%ntrac))
   allocate(meta_nemsio%vcoord(meta_nemsio%dimz+1,3,2))
  


   meta_nemsio%variname(1)='cu_physics'
   meta_nemsio%varival(1)=4
   meta_nemsio%variname(2)='mp_physics'
   meta_nemsio%varival(2)=1000 
   meta_nemsio%variname(3)='IVEGSRC'
   if (mname=='gfs4' .or. mname=='gfs3' .or. mname =='nam') then
   	meta_nemsio%varival(3)=2
   else if (mname == 'ruc13_native') then
   	meta_nemsio%varival(3)=1		!RAP data has newer vegetation type
   endif
   
   meta_nemsio%variname(4)='levs'
   meta_nemsio%varival(4)=nlevs
   meta_nemsio%variname(5)='itrun'
   meta_nemsio%varival(5)=1
   meta_nemsio%variname(6)='icen2'
   meta_nemsio%varival(6)=0
   meta_nemsio%variname(7)='nvcoord'
   meta_nemsio%varival(7)=1
   meta_nemsio%variname(8)='isgrbsrc'

   
   if (mname=='gfs4' .or. mname=='gfs3') then
   		! 1 for gfs and nam
   		meta_nemsio%varival(8)=1
   	else if (mname == 'nam') then
   		! 2 for nam
   		meta_nemsio%varival(8)=2
   	else if (mname == 'ruc13_native') then
   		! 2 for rap/ruc
   		meta_nemsio%varival(8)=3
   	endif
   
   ct=1
   DO j=1,nlats
      DO i=1,nlons
         meta_nemsio%lon(ct)      = lons(i)
         meta_nemsio%lat(ct)      = lats(j)
	 ct=ct+1
      ENDDO
   ENDDO
   
   meta_nemsio%ri = (/286.0500,461.5,173.2247/)
   meta_nemsio%cpi = (/1004.600, 1846.000, 820.2391/)
   
   meta_nemsio%aryilen(1)    = 200 
   allocate(meta_nemsio%aryival(meta_nemsio%aryilen(1),meta_nemsio%nmetaaryi))
   meta_nemsio%aryiname(1)   = 'kgds'
   !meta_nemsio%aryival(1,:) = meta_nemsio%kgds
   !meta_nemsio%reclev(:)=1
   
   
   DO i=1,nvar2d
   		print*,'adding record ', trim(names2d(i)(:)), ' at level ', trim(levs2d(i)(:))
   		meta_nemsio%recname(i)   = names2d(i)
   		meta_nemsio%reclevtyp(i) = levs2d(i)
   		meta_nemsio%reclev(i) = one
   		
   ENDDO

!  loop through 3d variables	
   DO k = 1, nlevs
      meta_nemsio%recname(k+nvar2d)	          = 'ugrd'
      meta_nemsio%reclevtyp(k+nvar2d)         =  'mid layer'
      meta_nemsio%reclev(k+nvar2d)	          =  k
      	 
      meta_nemsio%recname(k+nvar2d+nlevs)     =  'vgrd'
      meta_nemsio%reclevtyp(k+nvar2d+nlevs)   =  'mid layer'
      meta_nemsio%reclev(k+nvar2d+nlevs)      =  k
      
      meta_nemsio%recname(k+nvar2d+nlevs*2)   =  'tmp'
      meta_nemsio%reclevtyp(k+nvar2d+nlevs*2) =  'mid layer'
      meta_nemsio%reclev(k+nvar2d+nlevs*2)    =  k
      
      meta_nemsio%recname(k+nvar2d+nlevs*3)   =  'spfh'
      meta_nemsio%reclevtyp(k+nvar2d+nlevs*3) =  'mid layer'
      meta_nemsio%reclev(k+nvar2d+nlevs*3)    =  k
      
      meta_nemsio%recname(k+nvar2d+nlevs*4)   =  'o3mr'
      meta_nemsio%reclevtyp(k+nvar2d+nlevs*4) =  'mid layer'
      meta_nemsio%reclev(k+nvar2d+nlevs*4)    =  k
      
      meta_nemsio%recname(k+nvar2d+nlevs*5)   =  'clwmr'
	  meta_nemsio%reclevtyp(k+nvar2d+nlevs*5) =  'mid layer'
	  meta_nemsio%reclev(k+nvar2d+nlevs*5)    =  k
      
      if (mname .eq. 'ruc13_native') then
		  
		  
		  meta_nemsio%recname(k+nvar2d+nlevs*6)   =  'rwmr'
		  meta_nemsio%reclevtyp(k+nvar2d+nlevs*6) =  'mid layer'
		  meta_nemsio%reclev(k+nvar2d+nlevs*6)    =  k
		  
		  meta_nemsio%recname(k+nvar2d+nlevs*7)   =  'cicemr'
		  meta_nemsio%reclevtyp(k+nvar2d+nlevs*7) =  'mid layer'
		  meta_nemsio%reclev(k+nvar2d+nlevs*7)    =  k
		  
		  meta_nemsio%recname(k+nvar2d+nlevs*8)   =  'grplemr'
		  meta_nemsio%reclevtyp(k+nvar2d+nlevs*8) =  'mid layer'
		  meta_nemsio%reclev(k+nvar2d+nlevs*8)    =  k
		  
		  meta_nemsio%recname(k+nvar2d+nlevs*9)   =  'snmr'
		  meta_nemsio%reclevtyp(k+nvar2d+nlevs*9) =  'mid layer'
		  meta_nemsio%reclev(k+nvar2d+nlevs*9)    =  k
	  
	   endif

   ENDDO

  end subroutine define_nemsio_meta

  subroutine nems_write_init(filename,meta_nemsio,gfile)
 
   
    implicit none

    type(nemsio_meta)                                                :: meta_nemsio
    character(len=200)                                               :: datapath
    character(len=400)                                               :: filename
    type(nemsio_gfile)                                               :: gfile
    integer                                                          :: nemsio_iret
    integer                                                          :: i, j, k

    call nemsio_init(iret=nemsio_iret)
    print*,'iret=',nemsio_iret
    !gfile%gtype           = 'NEMSIO'
    meta_nemsio%gdatatype = 'bin4'
    print *, trim(meta_nemsio%modelname)
    print *, 'in nems_write', meta_nemsio%aryival
    call nemsio_open(gfile,trim(filename),'write',                                  &
         & iret=nemsio_iret,                                                        &
         & modelname=trim(meta_nemsio%modelname),                                   &
         & version=meta_nemsio%version,gdatatype=meta_nemsio%gdatatype,             &
         & dimx=meta_nemsio%dimx,dimy=meta_nemsio%dimy,                             &
         & dimz=meta_nemsio%dimz,rlon_min=meta_nemsio%rlon_min,                     &
         & rlon_max=meta_nemsio%rlon_max,rlat_min=meta_nemsio%rlat_min,             &
         & rlat_max=meta_nemsio%rlat_max,                                           &
         & lon=meta_nemsio%lon,lat=meta_nemsio%lat,                                 &
         & idate=meta_nemsio%idate,nrec=meta_nemsio%nrec,                           &
         & nframe=meta_nemsio%nframe,idrt=meta_nemsio%idrt,ncldt=                   &
         & meta_nemsio%ncldt,idvc=meta_nemsio%idvc,                                 &
         & nfhour=meta_nemsio%nfhour,nfminute=meta_nemsio%nfminute,                 &
         & nfsecondn=meta_nemsio%nfsecondn,nmeta=meta_nemsio%nmeta,                 &
         & nfsecondd=meta_nemsio%nfsecondd,extrameta=.true.,                        &
         & nmetaaryi=meta_nemsio%nmetaaryi,recname=meta_nemsio%recname,             &
         & nmetavari=meta_nemsio%nmetavari,variname=meta_nemsio%variname,           &
         & varival=meta_nemsio%varival, nmetaaryr=meta_nemsio%nmetaaryr,             &
         & reclevtyp=meta_nemsio%reclevtyp,                                         &
         & reclev=meta_nemsio%reclev,jcap=meta_nemsio%jcap,idsl=meta_nemsio%idsl, &
         & idvm=meta_nemsio%idvm,vcoord=meta_nemsio%vcoord, ntrac=meta_nemsio%ntrac, &
         & aryiname=meta_nemsio%aryiname,aryival=meta_nemsio%aryival,aryilen=meta_nemsio%aryilen)

   end subroutine nems_write_init
 
  
!------------------------------------------------------  
  subroutine nems_write(gfile,recname,reclevtyp,level,dimx,data2d,iret)
 
  implicit none
    type(nemsio_gfile)         :: gfile
    integer                    :: iret,level,dimx
    real                       :: data2d(dimx)
    character(len=25) :: recname, reclevtyp

     call nemsio_writerecv(gfile,recname,levtyp=reclevtyp,lev=level,data=data2d,iret=iret)
     if (iret.NE.0) then
         print*,'error writing ',recname, level, iret
         STOP
     ENDIF

  end subroutine nems_write  
  
  
end module grb2nemsio_module
