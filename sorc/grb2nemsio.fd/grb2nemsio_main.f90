program gfs_main
  USE, INTRINSIC :: IEEE_ARITHMETIC
  use gfs_module
  use netcdf
  use nemsio_module   
  implicit none

  type(nemsio_gfile)         :: gfile
  type(nemsio_meta)          :: meta_nemsio
  integer,parameter			 :: nslev=4
  integer, allocatable		 :: fhours(:)
  character(len=25), allocatable 			:: nameslin(:),nameslout(:), lvlslout(:)
  character(len=25), dimension(:), allocatable :: name2din, name2dout,lvl2dout
  character(len=25), dimension(:), allocatable :: name2dmeta,lvls2dmeta
  character(len=25), dimension(:), allocatable :: name3din, name3dout
  character(len=25) 		 :: levtype, pnamein
  character(len=300)         :: inpath
  character(len=200)         :: fname,fname_pre,fname_latlon
  character(len=400) 		 :: outfile
  character(len=1000)		 :: cmdline_msg
  character(len=10)          :: analdate, cfhour,  gridc
  character(len=15)			 :: file_start, out_start, mname
  character(len=15)			 :: latname, lonname, xgridname, ygridname
  character(len=3)           :: cfhr,cfhr_end,cfhr_freq,hr_name
  character(len=4)			 :: cfhr_in, cfhr_out                  
  real , allocatable         :: lons(:),lats(:),tmp1d(:), tmp1dx(:), p_i(:), vcoord (:), dummy(:)
  real ,allocatable          :: tmp2d(:,:),tmp2dx(:,:),tmp2dT(:,:,:), psfc(:,:), tmp2dx2(:,:)
  real, allocatable			 :: tmp3dx(:,:,:), tmp3d(:,:,:), tmp3dhyb(:,:,:)
  real						 :: zeros, q_cur, xmsg, maxlats, minlats, maxlons, minlons, dlon, dlat
  real(nemsio_realkind), allocatable		 :: sigma(:)
  integer                    :: fhour, isnative, doslconvert, hasspfh

  
  integer :: ii,i,j,k,kk,ncid3d,ifhr,ifhr_end,ifhr_freq,ifhr_name,nlevs,nlons,nlats,ntimes
  integer :: nargs,iargc,YYYY,MM,DD,HH,stat,varid,hr
  integer :: status, nvar2d, nvar2dmeta, nvarsoil, nvar3d,ncid3d_new
  
!=========================================================================================
 
   ! read in from command line
   nargs=iargc()
   IF (nargs .NE. 6) THEN
      print*,'usage fv3_interface mname analdate ifhr ifhr_end ifhr_freq inpath '
      print *, ' '
      print *, 'valid mname options are gfs3 (1-degree gfs), gfs4 (0.5-degree gfs), &
      			ruc13 (13-km RUC/RAP data on the pressure grid), or ruc13_native (&
      			13-km RUC/RAP data on the native sigma grid)'
      STOP 1
   ENDIF
   call getarg(1,mname)			! Model name: gfs4, or ruc_native currently
   call getarg(2,analdate)		! Analysis date: YYYYMMDD
   call getarg(3,cfhr)			! Forecast hour 
   call getarg(4,cfhr_end)		! End forecast hour to be converted
   call getarg(5,cfhr_freq)		! Forecast hour frequency 
   call getarg(6,inpath)		! Location of the grb files
                        
   
   read(cfhr,'(i0.3)')  ifhr
   read(cfhr_end, '(i3.1)') ifhr_end
   read(cfhr_freq, '(i3.1)') ifhr_freq
   read(analdate(1:4),'(i4)')  YYYY
   read(analdate(5:6),'(i2)')  MM
   read(analdate(7:8),'(i2)')  DD
   read(analdate(9:10),'(i2)') HH
   print*,"ifhr,fhour,analdate,ifhr_end,ifhr_freq ",ifhr,fhour,analdate,ifhr_end,ifhr_freq    
 	doslconvert = 0
 	isnative = 0
 	hasspfh = 0
    if (trim(mname) == 'gfs4') then
	
		nvar2d = 9
		nvar2dmeta = 17
		nvarsoil = 2
		nvar3d = 6
		
		allocate(name3din(nvar3d))
		allocate(name3dout(nvar3d))
		allocate(name2din(nvar2d))
		allocate(name2dout(nvar2d))
		allocate(lvl2dout(nvar2d))
		allocate(nameslin(nvarsoil))
		allocate(nameslout(nvarsoil))
		allocate(lvlslout(nslev))
		allocate(name2dmeta(nvar2dmeta))
		allocate(lvls2dmeta(nvar2dmeta))
	
		name3din=(/'UGRD_P0_L100_GLL0','VGRD_P0_L100_GLL0','TMP_P0_L100_GLL0','RH_P0_L100_GLL0','O3MR_P0_L100_GLL0',&
				'CLWMR_P0_L100_GLL0'/)
				
		name2din=(/'PRES_P0_L1_GLL0','TMP_P0_L1_GLL0','TMP_P0_L103_GLL0','WEASD_P0_L1_GLL0',&
		'HGT_P0_L1_GLL0','LAND_P0_L1_GLL0','ICEC_P0_L1_GLL0','SPFH_P0_L103_GLL0','SNOD_P0_L1_GLL0'/)
		
		!At some point, the grib table soil variable names changed for GFS files. 
		! I'm actually not sure when this happened, though. Change "2017" accordingly.
		
		if (YYYY .gt. 2017) then !
			nameslin=(/'TSOIL_P0_2L106_GLL0','SOILW_P0_2L106_GLL0'/)
		else
			nameslin=(/'TMP_P0_2L106_GLL0','SOILW_P0_2L106_GLL0'/)
		endif
		
		!Look for files that start with gfs_4
		file_start = '/gfs_4_'
		pnamein = 'lv_ISBL0' 
		latname = 'lat_0'
		lonname = 'lon_0'
		
		out_start = '/gfs.t'
		ygridname = latname
		xgridname = lonname
		
   		name3dout=(/'ugrd','vgrd','tmp','spfh','o3mr','clwmr'/)
   
		name2dout=(/'pres','tmp','tmp','weasd','hgt','land','icec','spfh','snwdph'/)
		lvl2dout=(/'sfc','2 m above gnd','sfc','sfc','sfc','sfc','sfc','2 m above gnd','sfc'/)
    
	    nameslout=(/'tmp','soilw'/)
		lvlslout=(/'0-10 cm down','10-40 cm down','40-100 cm down','100-200 cm down'/)
		
		
		name2dmeta = (/'pres','tmp','tmp','weasd','hgt','land','icec','spfh', 'snwdph', &
					'tmp','tmp','tmp','tmp','soilw','soilw','soilw','soilw'/)
		lvls2dmeta = (/'sfc','2 m above gnd','sfc','sfc','sfc','sfc','sfc','2 m above gnd','sfc', &
					'0-10 cm down','10-40 cm down','40-100 cm down','100-200 cm down', &
					'0-10 cm down','10-40 cm down','40-100 cm down','100-200 cm down'/)
    elseif (trim(mname) == 'ruc13_native') then
    
		nvar2d = 13
		nvar2dmeta = 21
		nvarsoil = 2
		nvar3d = 10

		allocate(name2din(nvar2d))
		allocate(name2dout(nvar2d))
		allocate(name3din(nvar3d))
		allocate(name3dout(nvar3d))
		allocate(lvl2dout(nvar2d))
		allocate(name2dmeta(nvar2dmeta))
		allocate(lvls2dmeta(nvar2dmeta))
		allocate(nameslin(nvarsoil))
		allocate(nameslout(nvarsoil))
		allocate(lvlslout(nslev))
   
   		! RUC native grids have a lot more tracers (microphysical quantities). 
   		name3din = (/'UGRD_P0_L105_GLL0','VGRD_P0_L105_GLL0','TMP_P0_L105_GLL0','SPFH_P0_L105_GLL0','O3MR_P0_L105_GLL0', &
   					'CLWMR_P0_L105_GLL0','RWMR_P0_L105_GLL0', 'SNMR_P0_L105_GLL0', 'GRLE_P0_L105_GLL0', &
   					'CIMIXR_P0_L105_GLL0'/)
   		
   		name3dout=(/'ugrd','vgrd','tmp','spfh','o3mr','clwmr','rwmr','snmr','grplemr','cicemr'/)
   		
   
		name2din=(/'PRES_P0_L1_GLL0','TMP_P0_L1_GLL0','TMP_P0_L103_GLL0','WEASD_P0_L1_GLL0',&
			'HGT_P0_L1_GLL0','LAND_P0_L1_GLL0','ICEC_P0_L1_GLL0','SPFH_P0_L103_GLL0', 'FRICV_P0_L1_GLL0', &
			 'VGTYP_P0_L1_GLL0','SOTYP_P0_L1_GLL0','CNWAT_P0_L1_GLL0','SNOD_P0_L1_GLL0'/)

		name2dout=(/'pres','tmp','tmp','weasd','hgt','land','icec','spfh','fricv','vtype','sotyp','cnwat','snod'/)
		lvl2dout=(/'sfc','2 m above gnd','sfc','sfc','sfc','sfc','sfc','2 m above gnd','sfc','sfc','sfc','sfc','sfc'/)
		
		nameslin=(/'TSOIL_P0_2L106_GLL0','SOILW_P0_2L106_GLL0'/)
		
		nameslout=(/'tmp','soilw'/)
		lvlslout=(/'0-10 cm down','10-40 cm down','40-100 cm down','100-300 cm down'/)
		
		
		name2dmeta = (/'pres','tmp','tmp','weasd','hgt','land','icec','spfh', &
						'fricv','vtype','sotyp','cnwat','snod', &
					'tmp','tmp','tmp','tmp','soilw','soilw','soilw','soilw'/)
		lvls2dmeta = (/'sfc','2 m above gnd','sfc','sfc','sfc','sfc','sfc','2 m above gnd', &
						'sfc','sfc','sfc','sfc','sfc', &
					'0-10 cm down','10-40 cm down','40-100 cm down','100-300 cm down', &
					'0-10 cm down','10-40 cm down','40-100 cm down','100-300 cm down'/)
					
	  
    	pnamein = 'lv_HYBL0'
    	file_start = '/rap.t'
    	out_start = '/rap.t'
    	gridc = '130b'
    	latname = 'lat_0'
    	lonname = 'lon_0'
    	ygridname = 'lat_0'
    	xgridname = 'lon_0'
    	isnative=1
    	doslconvert = 1
    	hasspfh = 1
    else
    	print *, 'This code only supports conversion of gfs3 (1-degree), gfs4 (0.5-degree) data, &
    				or ruc13 (13-km) data on pressure (ruc13) or native (ruc13_native) grids'
    	STATUS = 0
	    call EXIT(STATUS)
    	
    endif
    	

    
    ntimes=(ifhr_end)/ifhr_freq+1
    allocate(fhours(ntimes))
    call gen_fhours_array(0,ifhr_end,ifhr_freq,ntimes,fhours)
    print *, fhours(:)
    hr = 1
    do kk=1,ntimes
    	print *, fhours(hr)
    	
		if (mname == 'ruc13_native') then
			write(hr_name,'(I0.2)') fhours(kk)
			write(cfhr_in, '(I0.2)') ifhr
			write(cfhr_out, '(I0.2)') ifhr
			fname_pre=trim(inpath)//trim(file_start)//trim(cfhr_in)//'z.awp130bgrbf'//trim(hr_name)//'.grib2'
			
			fname=trim(inpath)//trim(file_start)//trim(cfhr_in)//'z.awp130bgrbf'//trim(hr_name)//'_latlon.nc'
			
			fname_latlon = trim(inpath)//trim(file_start)//trim(cfhr_in)//'z.awp130bgrbf'//trim(hr_name)//'_latlon.grb2'
			
			cmdline_msg='~/tmp/wgrib2/wgrib2/wgrib2 '//trim(fname_pre)//' -set_bitmap 1 -set_grib_type c3 &
				-new_grid_winds grid -new_grid_interpolation neighbor -new_grid latlon &
				-139.85:550:0.15 16.25:281:0.15 '//trim(fname_latlon)//' &> wgrb.out'
			
			CALL execute_command_line(trim(cmdline_msg))
		
			CALL execute_command_line('ncl_convert2nc '//trim(fname_latlon)//' -o '//trim(inpath)//' &> convert.out')
			
			outfile=trim(inpath)//trim(out_start)//trim(cfhr_out)//'.atmf'//trim(hr_name)//'.nemsio'
		else
		
			write(hr_name,'(I0.3)') fhours(kk)
			write(cfhr_in, '(I0.4)') ifhr
			write(cfhr_out, '(I0.2)') ifhr
			fname_pre=trim(inpath)//trim(file_start)//trim(analdate)//'_'//trim(cfhr_in)// &
				'_'//trim(hr_name)//'.grb2'
				
			print *, 'reading ', fname_pre
			
			fname=trim(inpath)//trim(file_start)//trim(analdate)//'_'//trim(cfhr_in)// &
				'_'//trim(hr_name)//'.nc'

			CALL execute_command_line('ncl_convert2nc '//trim(fname_pre)//' -o '//trim(inpath)//' &> convert2nc.out')
			
			outfile=trim(inpath)//trim(out_start)//trim(cfhr_out)//'.atmf'//trim(hr_name)//'.nemsio'
		endif
		
		
		print *, 'reading ', fname
		stat = nf90_open(fname,NF90_NOWRITE, ncid3d)
		if (stat .NE.0) print*,stat
		
		! For the first file only, inquire about grid information and set up nemsio meta data 
		! that will be shared across all files
    	if (kk .eq. 1) then
			print*, 'inquire about lons'
			stat = nf90_inq_dimid(ncid3d,trim(xgridname),varid)
			if (stat .NE.0) print*,stat,varid
			if (stat .NE. 0) STOP 1
			print *, 'reading in num lons'
			stat = nf90_inquire_dimension(ncid3d,varid,len=nlons)
			if (stat .NE.0) print*,stat,nlons
			if (stat .NE. 0) STOP 1
		
			print *, 'reading in num lats'
			stat = nf90_inq_dimid(ncid3d,trim(ygridname),varid)
			if (stat .NE.0) print*,stat
			if (stat .NE. 0) STOP 1
			stat = nf90_inquire_dimension(ncid3d,varid,len=nlats)
			if (stat .NE.0) print*,stat
			if (stat .NE. 0) STOP 1
		
			allocate(lons(nlons))
			allocate(tmp1d(nlons))
			stat = nf90_inq_varid(ncid3d,trim(lonname),varid)
			if (stat .NE. 0) STOP 1
			stat = nf90_get_var(ncid3d,varid,tmp1d)
			if (stat .NE.0) print*,stat
			if (stat .NE. 0) STOP 1
			lons=real(tmp1d,kind=4)
			!print*,lons(1),lons(3072)
			deallocate(tmp1d)

			allocate(lats(nlats))
			allocate(tmp1d(nlats))
			allocate(tmp1dx(nlats))
			stat = nf90_inq_varid(ncid3d,trim(latname),varid)
			stat = nf90_get_var(ncid3d,varid,tmp1dx,start=(/1/),count=(/nlats/))
			if (stat .NE.0) print*,stat
			if (stat .NE. 0) STOP 1
			
			if (.not. isnative) then
				 do j=1,nlats
				   tmp1d(j)=tmp1dx(nlats-j+1)
				 enddo
			 else
			 	tmp1d = tmp1dx
			 endif
			 
			lats=real(tmp1d,kind=4)
			print*,"lats_beg, lats_end",lats(1),lats(nlats)
			print *, "lons_beg, lons_end", lons(1), lons(nlons)
			deallocate(tmp1d, tmp1dx)


			stat = nf90_inq_dimid(ncid3d,pnamein,varid)
			if (stat .NE.0) print*,stat
			if (stat .NE. 0) STOP 1
			stat = nf90_inquire_dimension(ncid3d,varid,len=nlevs)
			if (stat .NE.0) print*,stat
			if (stat .NE. 0) STOP 1

			print *, 'nlats = ', nlats
			print *, 'nlons = ', nlons
			print *, 'nlevs = ', nlevs	
			!allocate(meta_nemsio%vcoord(meta_nemsio%dimz+1))
			call define_nemsio_meta(meta_nemsio,nlons,nlats,nlevs,nvar2dmeta,nvar3d,& 	
					name2dmeta,lvls2dmeta,lons,lats,mname)
	     
		   deallocate(lons,lats)
		   deallocate(name2dmeta,lvls2dmeta)
					
		   meta_nemsio%idate(1)=YYYY
		   meta_nemsio%idate(2)=MM
		   meta_nemsio%idate(3)=DD
		   meta_nemsio%idate(4)=HH
		   
		   zeros = 0.0
		   	allocate(sigma(nlevs))
		   	if (.not. isnative) then
				print *, 'Reading in isobaric pressure levels'
		
				allocate(p_i(nlevs))
				allocate(dummy(nlevs))
			
				call fv3_netcdf_read_1d(ncid3d,meta_nemsio,pnamein,p_i)

				if (p_i(1) .eq. 10) then
					p_i(:) = p_i(:) * 100.0
				endif
			
				print *, 'Create sigma levels'
				sigma(:) = p_i(:) / 101325.0
				dummy(:) = zeros
				
				print *, 'Assign vcoord values from sigma levels'
				meta_nemsio%vcoord(1:nlevs,1,1) = sigma(nlevs:1:-1)
				meta_nemsio%vcoord(nlevs+1,1,1) = zeros
				
			else
				sigma(:) = (/1.0000, 0.9980, 0.9940, 0.9870, 0.9750, 0.9590, &
          		0.9390, 0.9160, 0.8920, 0.8650, 0.8350, 0.8020, 0.7660, &
          		0.7270, 0.6850, 0.6400, 0.5920, 0.5420, 0.4970, 0.4565, &
          		0.4205, 0.3877, 0.3582, 0.3317, 0.3078, 0.2863, 0.2670, &
          		0.2496, 0.2329, 0.2188, 0.2047, 0.1906, 0.1765, 0.1624, &
          		0.1483, 0.1342, 0.1201, 0.1060, 0.0919, 0.0778, 0.0657, &
          		0.0568, 0.0486, 0.0409, 0.0337, 0.0271, 0.0209, 0.0151, &
          		0.0097, 0.0047/)
          		
          		print *, 'Assign vcoord values from sigma levels'
				meta_nemsio%vcoord(1:nlevs,1,1) = sigma
				meta_nemsio%vcoord(nlevs+1,1,1) = zeros 
          	endif
			
		endif
		
		!Allocate temporary arrays
		allocate (tmp2d(nlons,nlats))
		allocate (tmp2dT(nlons,nlats,nlevs))
		allocate (tmp2dx(nlons,nlats))

		allocate(tmp3dhyb(nlons,nlats,nlevs))
	    allocate(tmp3d(nlons,nlats,nlevs))
		allocate(tmp1d(nlevs))
		allocate(tmp1dx(nlevs))
		allocate(psfc(nlons,nlats))
		
		meta_nemsio%nfhour= fhours(hr)
		meta_nemsio%fhour= fhours(hr)

		print *, 'Call nems write init'
		call nems_write_init(outfile,meta_nemsio,gfile)
		
	! read in all of the 2d variables   and write out
		print *,'loop over 2d variables'
	   DO i=1,nvar2d
		  print *,i
		  
		  ! 2-m T and 2-m Q are contained in a 3d array in grb files, so read them in differently
		  IF (trim(name2din(i)) == 'TMP_P0_L103_GLL0' .OR. trim(name2din(i)) == 'TMP_P0_L103_GLC0' &
		  	.OR. trim(name2din(i)) == 'TMP_3_SFC' .OR. trim(name2din(i)) == 'SPFH_P0_L103_GLL0' &
		  	.OR. trim(name2din(i)) == 'SPFH_P0_L103_GLC0' .OR.  trim(name2din(i)) == 'SPF_H_3_HTG') THEN
			PRINT *, 'READING IN ', trim(name2din(i))
			call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,name2din(i),1,1,tmp2dx)
		  ELSE
			PRINT *, 'READING IN ', trim(name2din(i))
			call fv3_netcdf_read_2d(ncid3d,1,meta_nemsio,name2din(i),tmp2dx)
		  ENDIF
		
		! When processed through chgres, RAP data looked strange. I thought it might be a problem
		! with the dimensional order, so this was my attempt to remedy that. Still not sure.
		if (isnative) then
		  tmp2d = RESHAPE(tmp2dx,(/nlats,nlons/),ORDER=(/2,1/)) !(:,nlats:1:-1)
		else
		  tmp2d = tmp2dx
		endif 
		
		
		
		if (trim(name2din(i)) == 'SNOD_P0_L1_GLL0' .OR. trim(name2din(i)) .eq. 'WEASD_P0_L1_GLL0') then
			WHERE(tmp2d .gt. 1000.0)tmp2d=IEEE_VALUE(tmp2d,IEEE_QUIET_NAN)
		endif
		call nems_write(gfile,name2dout(i),lvl2dout(i),1, nlons*nlats,tmp2d,stat)
		print *, 'Min ', trim(name2din(i)), ' = ', minval(tmp2d)
		print *, 'Max ', trim(name2din(i)), ' = ', maxval(tmp2d)
		! Save psfc data for converting non-native grids to sigma coordinates
		if (i .eq. 1) then
			psfc(:,:) = tmp2d(:,:)
		endif
		
	   ENDDO !loop over 2d variables
!		deallocate(tmp2dx)
!		allocate(tmp2dx(nlons,nlats))

		print *, 'loop over soil variables'
		DO i=1,nvarsoil
			print *, i, trim(nameslin(i))
			if (.not. mname == 'ruc13_native') then
				do k=1,nslev
					print *, k
					call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,nameslin(i),k,1,tmp2dx)

					call nems_write(gfile,nameslout(i),lvlslout(k),1, nlons*nlats,tmp2d,stat)
				enddo
			else
				! RAP soil variables are at the box edges (0, 10, 40 cm, etc.), so average data at the edges
				! to get data valid over the box depth (i.e. 0-10 cm, 10-40 cm, etc.). Is this correct?
				allocate (tmp2dx2(nlons,nlats))
				do k = 1,nslev
					print *, k
					call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,nameslin(i),k,1,tmp2dx)
					call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,nameslin(i),k+1,1,tmp2dx2)
					tmp2d = (tmp2dx(:,nlats:1:-1)+tmp2dx2(:,nlats:1:-1)) / 2.0
				
					call nems_write(gfile,nameslout(i),lvlslout(k),1, nlons*nlats,tmp2d,stat)
				enddo
				deallocate(tmp2dx2)
			endif
		
		ENDDO !loop over soil variables

		
		levtype='mid layer'
	! loop through 3d fields
	   print *,'loop over 3d variables'
	   DO i=1,nvar3d    
		  print*,i,trim(name3din(i))

		  
		 IF (i .EQ. 5) THEN !Ozone mixing ratio
		 	if (mname .ne. 'ruc13_native') then
		 
				if (YYYY .gt. 2017) then !Only available for the top 17 layers for older data; !!!!!DATE UNCERTAIN!!!!!
					allocate(tmp3dx(nlons,nlats,17))
					call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,name3din(i),1,17,tmp3dx)
					tmp3d(:,:,1:17) = tmp3dx(:,:,:)
					do k = 18,nlevs
						tmp3d(:,:,k) = tmp3dx(:,:,17)
					enddo
					deallocate(tmp3dx)
				else !Only available for the top 6 layers
					allocate(tmp3dx(nlons,nlats,6))
					call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,name3din(i),1,6,tmp3dx)
					tmp3d(:,:,1:6) = tmp3dx(:,:,:)
					do k = 7,nlevs
						tmp3d(:,:,k) = tmp3dx(:,:,6)
					enddo
					deallocate(tmp3dx)
				endif
			else
				tmp3d(:,:,:) = 1E-7
			endif
		 !RH not available at the second layer from TOA in older, non-native data; !!!!!DATE UNCERTAIN!!!!!
		 ELSEIF (i .EQ. 4 .AND. YYYY .le. 2017 .AND. .not. isnative) THEN 
		 	allocate(tmp3dx(nlons,nlats,nlevs-1))
		 	call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,name3din(i),1,nlevs-1,tmp3dx)
		 	
		 	tmp3d(:,:,1) = tmp3dx(:,:,1)
		 	tmp3d(:,:,2) = tmp3dx(:,:,1)
		 	tmp3d(:,:,3:nlevs) = tmp3dx(:,:,2:nlevs-1)
			deallocate(tmp3dx)
		 ELSEIF (i .EQ. 6 .AND. .not. isnative) THEN !Q_cloud
		 	if (YYYY .gt. 2017) then !Not available in the top 10 layers; !!!!!DATE UNCERTAIN!!!!!
		 		allocate(tmp3dx(nlons,nlats,nlevs-10))
				call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,name3din(i),1,nlevs-10,tmp3dx)
				DO k = 1,10
					tmp3d(:,:,k)= zeros
				ENDDO
				tmp3d(:,:,11:nlevs) = tmp3dx
				deallocate(tmp3dx)
		 	else	!Not available in the top 5 layers in newer data
				allocate(tmp3dx(nlons,nlats,nlevs-5))
				call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,name3din(i),1,nlevs-5,tmp3dx)
				DO k = 1,5
					tmp3d(:,:,k)= zeros
				ENDDO
				tmp3d(:,:,6:nlevs) = tmp3dx
				deallocate(tmp3dx)
			endif
		 ELSE	!All other variables are available across all levels
			call fv3_netcdf_read_3d(ncid3d,1,meta_nemsio,name3din(i),1,nlevs,tmp3d)
		 ENDIF
		 
		 

		 !Need to convert isobaric to sigma coordinates if not on a native grid
		 if (.not. isnative) then
			 call p2hyo(p_i,nlons,nlats,nlevs,tmp3d,psfc,100000.0,dummy,sigma,nlevs,tmp3dhyb, &
					xmsg,4,stat)
		 else
		 	tmp3dhyb = tmp3d(:,nlats:1:-1,:)
		 endif
		 
		 ! Save temperature for RH->SPHUM computation if not on a native grid (only RH in file)
		 if (i .eq. 3 .and. .not. isnative) then
		 	tmp2dT = tmp3dhyb
		 endif
		
		!Nemsio data is written separately for each level
		
		! Non-native grids are in reverse vertical order from nemsio format, so read/write from last to first
		if (.not. isnative) then	
			DO k = nlevs,1,-1

				tmp2dx(:,:) = tmp3dhyb(:,:,k)			
				 do ii=1,nlons
				 do j=1,nlats
					IF (i .EQ. 4 .and. .not. hasspfh) THEN
						!Convert RH to Q_vapor
						call fv3_comp_sphum(tmp2dT(ii,j,k),tmp2dx(ii,j),p_i(k),q_cur)
										tmp2d(ii,j) = q_cur
					ELSE
						tmp2d(ii,j)=tmp2dx(ii,j)
					ENDIF
				
				 enddo
				 enddo
				!Write data to nemsio
				call nems_write(gfile,name3dout(i),levtype,nlevs-k+1,nlons*nlats,tmp2d(:,:),stat)
				 IF (stat .NE. 0) then
					 print*,'error writing ,named3dout(i)',stat
					 STOP 1
				 ENDIF    
			  ENDDO
		! Native grids are in the proper vertical order, so read/write in first->last order
		else
			DO k = 1,nlevs
				tmp2dx(:,:) = tmp3dhyb(:,:,k)
				 do ii=1,nlons
				 do j=1,nlats
					IF (i .EQ. 4 .and. .not. hasspfh) THEN
						!Convert RH to Q_vapor
						call fv3_comp_sphum(tmp2dT(ii,j,k),tmp2d(ii,j),p_i(k),q_cur)
						tmp2d(ii,j) = q_cur
					ELSE
						tmp2d(ii,j)=tmp2dx(ii,j)

					ENDIF
				 enddo
				 enddo
				!Write data to nemsio
				call nems_write(gfile,name3dout(i),levtype,k,nlons*nlats,tmp2d(:,:),stat)
				 IF (stat .NE. 0) then
					 print*,'error writing ,named3dout(i)',stat
					 STOP 1
				 ENDIF    
		  ENDDO
		endif
		
			!Deallocate tmp2dT when we're done with RH
		  if (i .eq. 4) THEN
		  	deallocate(tmp2dT)
		  end if
		  
	   ENDDO !loop over 3d variables


	   call nemsio_close(gfile,iret=stat)
	   stat = nf90_close(ncid3d)
	   stat = nf90_close(ncid3d_new)
	   
	   !deallocate temporary arrays
	   deallocate(tmp3d,tmp3dhyb)
	   deallocate(tmp2dx,tmp2d,psfc)
	   deallocate(tmp1dx,tmp1d)
	   
	   		
	enddo !loop over files
	
	!deallocate arrays that stayed the same across all files
	deallocate(name3din,name3dout,name2din,name2dout,nameslin,nameslout)
	deallocate(lvlslout,lvl2dout)
	deallocate(fhours)
	deallocate(sigma,dummy,p_i)



   stop
end program gfs_main
