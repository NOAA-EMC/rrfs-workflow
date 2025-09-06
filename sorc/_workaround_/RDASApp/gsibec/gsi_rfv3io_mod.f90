module gsi_rfv3io_mod
!$$$   module documentation block
!             .      .    .                                       .
! module:     gsi_rfv3io_mod
!   prgmmr:
!
! abstract: IO routines for regional FV3
!
! program history log:
!   2017-03-08  parrish - create new module gsi_rfv3io_mod, starting from
!                           gsi_nemsio_mod as a pattern.
!   2017-10-10  wu      - setup A grid and interpolation coeff in generate_anl_grid
!   2018-02-22  wu      - add subroutines for read/write fv3_ncdf
!   2019        ting    - modifications for use for ensemble IO and cold start files 
!   2019-03-13  CAPS(C. Tong) - Port direct radar DA capabilities.
!   2021-11-01  lei     - modify for fv3-lam parallel IO
!   2022-01-07  Hu      - add code to read/write subdomain restart files.
!                         This function is needed when fv3 model sets
!                         io_layout(2)>1
!   2022-02-15 Lu @ Wang - add time label it for FGAT. POC: xuguang.wang@ou.edu
!   2022-03-01 X.Lu @ X.Wang - add gsi_rfv3io_get_ens_grid_specs for dual ens HAFS. POC: xuguang.wang@ou.edu
!   2022-03-15  Hu      - add code to read/write 2m T and Q for they will be
!                         used as background for surface observation operator
!   2022-04-15  Wang    - add IO for regional FV3-CMAQ (RRFS-CMAQ) model 
!   2022-08-10  Wang    - add IO for regional FV3-SMOKE (RRFS-SMOKE) model 
!   2023-07-30  Zhao    - add IO for the analysis of the significant wave height
!                         (SWH, aka howv in GSI) in fv3-lam based DA (eg., RRFS-3DRTMA)
!   2024-01-24  X.Zhang - bug fix for reading the soil temp and mois from the wram start file 
!
! subroutines included:
!   sub gsi_rfv3io_get_grid_specs
!   sub gsi_rfv3io_get_ens_grid_specs
!   sub read_fv3_files 
!   sub read_fv3_netcdf_guess
!   sub gsi_fv3ncdf2d_read
!   sub gsi_fv3ncdf_read
!   sub gsi_fv3ncdf_readuv
!   sub wrfv3_netcdf
!   sub gsi_fv3ncdf_writeuv
!   sub gsi_fv3ncdf_writeps
!   sub gsi_fv3ncdf_write
!   sub gsi_fv3ncdf_write_v1
!   sub gsi_fv3ncdf2d_write
!   sub check
!
! variable definitions:
!
! attributes:
!   langauge: f90
!    machine:
!
!$$$ end documentation block

  use m_kinds, only: r_kind,i_kind
  use gridmod, only: nlon_regional,nlat_regional,nlon_regionalens,nlat_regionalens
  use constants, only:max_varname_length,max_filename_length
  use gsi_bundlemod, only : gsi_bundle
  use general_sub2grid_mod, only: sub2grid_info
  use gridmod,  only: fv3_io_layout_y
  use guess_grids, only: nfldsig,ntguessig,ifilesig
  use rapidrefresh_cldsurf_mod, only: i_use_2mq4b,i_use_2mt4b
  use chemmod, only: naero_cmaq_fv3,aeronames_cmaq_fv3,imodes_cmaq_fv3,laeroana_fv3cmaq
  use chemmod, only: naero_smoke_fv3,aeronames_smoke_fv3,laeroana_fv3smoke  
  use rapidrefresh_cldsurf_mod, only: i_howv_3dda, i_gust_3dda

  implicit none
  public type_fv3regfilenameg
  public bg_fv3regfilenameg
  public fv3sar_bg_opt

!    directory names (hardwired for now)
  type type_fv3regfilenameg
      character(len=:),allocatable :: grid_spec !='fv3_grid_spec'
      character(len=:),allocatable :: ak_bk     !='fv3_akbk'
      character(len=:),allocatable :: dynvars   !='fv3_dynvars'
      character(len=:),allocatable :: tracers   !='fv3_tracer'
      character(len=:),allocatable :: phyvars   !='fv3_phyvars'
      character(len=:),allocatable :: sfcdata   !='fv3_sfcdata'
      character(len=:),allocatable :: couplerres!='coupler.res'
      contains
      procedure , pass(this):: init=>fv3regfilename_init
  end type type_fv3regfilenameg

  integer(i_kind):: fv3sar_bg_opt=0
  
  type(type_fv3regfilenameg),allocatable:: bg_fv3regfilenameg(:)
  integer(i_kind) nx,ny,nz
  integer(i_kind) nxens,nyens
  integer(i_kind),dimension(:),allocatable :: ny_layout_len,ny_layout_b,ny_layout_e
  integer(i_kind),dimension(:),allocatable :: ny_layout_lenens,ny_layout_bens,ny_layout_eens
  real(r_kind),allocatable:: grid_lon(:,:),grid_lont(:,:),grid_lat(:,:),grid_latt(:,:)
  real(r_kind),allocatable:: ak(:),bk(:)
  integer(i_kind),allocatable:: ijns2d(:),displss2d(:),ijns(:),displss(:)
  integer(i_kind),allocatable:: ijnz(:),displsz_g(:)

  real(r_kind),dimension(:,:  ),allocatable:: ges_ps_bg 
  real(r_kind),dimension(:,:  ),allocatable:: ges_ps_inc 
  real(r_kind),dimension(:,:,:  ),allocatable:: ges_delp_bg 
  type(sub2grid_info) :: grd_fv3lam_dynvar_ionouv 
  type(sub2grid_info) :: grd_fv3lam_tracer_ionouv 
  type(sub2grid_info) :: grd_fv3lam_tracerchem_ionouv
  type(sub2grid_info) :: grd_fv3lam_tracersmoke_ionouv 
  type(sub2grid_info) :: grd_fv3lam_phyvar_ionouv
  type(sub2grid_info) :: grd_fv3lam_uv 
  integer(i_kind) ,parameter:: ndynvarslist=13, ntracerslist=8, nphyvarslist=2

  character(len=max_varname_length), dimension(ndynvarslist), parameter :: &
    vardynvars = [character(len=max_varname_length) :: &
      "u","v","u_w","u_s","v_w","v_s","t","tv","tsen","w","delp","ps","delzinc"]
  character(len=max_varname_length), dimension(ntracerslist+naero_cmaq_fv3+7+naero_smoke_fv3), parameter :: & 
    vartracers =  [character(len=max_varname_length) :: &
      'q','oz','ql','qi','qr','qs','qg','qnr',aeronames_cmaq_fv3,'pm25at','pm25ac','pm25co','pm2_5','amassi','amassj','amassk',aeronames_smoke_fv3]
  character(len=max_varname_length), dimension(nphyvarslist), parameter :: &
    varphyvars = [character(len=max_varname_length) :: 'dbz','fed']
  character(len=max_varname_length), dimension(16+naero_cmaq_fv3+7+naero_smoke_fv3+1), parameter :: &
    varfv3name = [character(len=max_varname_length) :: &
      'u','v','W','T','delp','sphum','o3mr','liq_wat','ice_wat','rainwat','snowwat','graupel','rain_nc','ref_f3d','flash_extent_density','ps','DZ', & 
      aeronames_cmaq_fv3,'pm25at','pm25ac','pm25co','pm2_5','amassi','amassj','amassk',aeronames_smoke_fv3], &
      vgsiname = [character(len=max_varname_length) :: &
        'u','v','w','tsen','delp','q','oz','ql','qi','qr','qs','qg','qnr','dbz','fed','ps','delzinc', &
        aeronames_cmaq_fv3,'pm25at','pm25ac','pm25co','pm2_5','amassi','amassj','amassk',aeronames_smoke_fv3]

  integer(i_kind) ,parameter:: nnonnegtracer=7
  character(len=max_varname_length), dimension(nnonnegtracer), parameter :: &
    vnames_nonnegativetracers = [character(len=max_varname_length) :: &
      "sphum","o3mr","liq_wat","ice_wat","rainwat","snowwat","graupel"]
  character(len=max_varname_length),dimension(:),allocatable:: name_metvars2d
  character(len=max_varname_length),dimension(:),allocatable:: name_metvars3d
  character(len=max_varname_length),dimension(:),allocatable:: name_chemvars3d

! set default to private
  private
! set subroutines to public
  public :: gsi_rfv3io_get_grid_specs
  public :: m_gsi_rfv3io_get_grid_specs
  public :: gsi_rfv3io_get_ens_grid_specs
  public :: gsi_fv3ncdf_read
  public :: gsi_fv3ncdf_read_v1
  public :: gsi_fv3ncdf_readuv
  public :: gsi_fv3ncdf_readuv_v1
  public :: gsi_fv3ncdf_read_ens_parallel_over_ens
  public :: gsi_fv3ncdf_readuv_ens_parallel_over_ens
  public :: gsi_fv3ncdf2d_read_v1

  public :: mype_u,mype_v,mype_t,mype_q,mype_p,mype_oz,mype_ql
  public :: mype_qi,mype_qr,mype_qs,mype_qg,mype_qnr,mype_w
  public :: k_slmsk,k_tsea,k_vfrac,k_vtype,k_stype,k_zorl,k_smc,k_stc
  public :: k_snwdph,k_f10m,mype_2d,n2d,k_orog,k_psfc,k_t2m,k_q2m,k_howv,k_gust
  public :: ijns,ijns2d,displss,displss2d,ijnz,displsz_g
  public :: fv3lam_io_dynmetvars3d_nouv,fv3lam_io_tracermetvars3d_nouv
  public :: fv3lam_io_tracerchemvars3d_nouv,fv3lam_io_tracersmokevars3d_nouv
  public :: fv3lam_io_phymetvars3d_nouv
  public :: fv3lam_io_dynmetvars2d_nouv,fv3lam_io_tracermetvars2d_nouv

  integer(i_kind) mype_u,mype_v,mype_t,mype_q,mype_p,mype_delz,mype_oz,mype_ql
  integer(i_kind) mype_qi,mype_qr,mype_qs,mype_qg,mype_qnr,mype_w

  integer(i_kind) k_slmsk,k_tsea,k_vfrac,k_vtype,k_stype,k_zorl,k_smc,k_stc
  integer(i_kind) k_snwdph,k_f10m,mype_2d,n2d,k_orog,k_psfc,k_t2m,k_q2m,k_howv,k_gust
  parameter(                   &  
    k_f10m =1,                  &   !fact10
    k_stype=2,                  &   !soil_type
    k_vfrac=3,                  &   !veg_frac
    k_vtype=4,                 &   !veg_type
    k_zorl =5,                &   !sfc_rough
    k_tsea =6,                  &   !sfct ?
    k_snwdph=7,                &   !sno ?
    k_stc  =8,                  &   !soil_temp
    k_smc  =9,                  &   !soil_moi
    k_slmsk=10,                 &   !isli
    k_t2m =11,                 & ! 2 m T
    k_q2m  =12,                 & ! 2 m Q
    k_orog =13,                 & !terrain
    k_howv =14,                 &   ! significant wave height (aka howv in GSI)
    k_gust =15,                 &   ! wind gust (aka gust in GSI)
    n2d=15                   )
  logical :: grid_reverse_flag
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_io_dynmetvars3d_nouv 
                                    ! copy of cvars3d excluding uv 3-d fields   
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_io_tracermetvars3d_nouv 
                                    ! copy of cvars3d excluding uv 3-d fields   
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_io_phymetvars3d_nouv
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_io_tracerchemvars3d_nouv
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_io_tracersmokevars3d_nouv 
                                    ! copy of cvars3d excluding uv 3-d fields
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_io_dynmetvars2d_nouv 
                                    ! copy of cvars3d excluding uv 3-d fields   
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_io_tracermetvars2d_nouv 
                                    ! copy of cvars3d excluding uv 3-d fields   
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_names_gsibundle_dynvar_nouv 
                                    !to define names in gsibundle 
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_names_gsibundle_tracer_nouv 
                                    !to define names in gsibundle 
  character(len=max_varname_length),allocatable,dimension(:) :: fv3lam_names_gsibundle_phyvar_nouv
  type(gsi_bundle):: gsibundle_fv3lam_dynvar_nouv 
  type(gsi_bundle):: gsibundle_fv3lam_tracer_nouv 
  type(gsi_bundle):: gsibundle_fv3lam_phyvar_nouv
  type(gsi_bundle):: gsibundle_fv3lam_tracerchem_nouv
  type(gsi_bundle):: gsibundle_fv3lam_tracersmoke_nouv 
 
contains
  subroutine fv3regfilename_init(this,it)
  implicit None

  class(type_fv3regfilenameg),intent(inout):: this
  integer(i_kind),            intent(in   ) :: it

  character(255):: filename
  if (it == ntguessig) then
    this%grid_spec='fv3_grid_spec'
  else
    write(filename,"(A14,I2.2)") 'fv3_grid_spec_',ifilesig(it)
    this%grid_spec=trim(filename)
  endif
  if (it == ntguessig) then
    this%ak_bk='fv3_ak_bk'
  else
    write(filename,"(A10,I2.2)") 'fv3_ak_bk_',ifilesig(it)
    this%ak_bk=trim(filename)
  endif
  if (it == ntguessig) then
    this%dynvars='fv3_dynvars'
  else
    write(filename,"(A12,I2.2)") 'fv3_dynvars_',ifilesig(it)
    this%dynvars=trim(filename)
  endif
  if (it == ntguessig) then
    this%tracers='fv3_tracer'
  else
    write(filename,"(A11,I2.2)") 'fv3_tracer_',ifilesig(it)
    this%tracers=trim(filename)
  endif
  if (it == ntguessig) then
    this%phyvars='fv3_phyvars'
  else
    write(filename,"(A12,I2.2)") 'fv3_phyvars_',ifilesig(it)
    this%phyvars=trim(filename)
  endif
  if (it == ntguessig) then
    this%sfcdata='fv3_sfcdata'
  else
    write(filename,"(A12,I2.2)") 'fv3_sfcdata_',ifilesig(it)
    this%sfcdata=trim(filename)
  endif
  if (it == ntguessig) then
    this%couplerres='coupler.res'
  else
    write(filename,"(A12,I2.2)") 'coupler.res_',ifilesig(it)
    this%couplerres=trim(filename)
  endif
end subroutine fv3regfilename_init


subroutine gsi_rfv3io_get_grid_specs(ierr)
!$$$  subprogram documentation block
!                .      .    .                                        .
! subprogram:    gsi_rfv3io_get_grid_specs
!   pgrmmr: parrish     org: np22                date: 2017-04-03
!
! abstract:  obtain grid dimensions nx,ny and grid definitions
!                grid_x,grid_xt,grid_y,grid_yt,grid_lon,grid_lont,grid_lat,grid_latt
!                nz,ak(nz),bk(nz)
!
! program history log:
!   2017-04-03  parrish - initial documentation
!   2017-10-10  wu - setup A grid and interpolation coeff with generate_anl_grid
!   2018-02-16  wu - read in time info from file coupler.res
!                    read in lat, lon at the center and corner of the grid cell
!                    from file fv3_grid_spec, and vertical grid infor from file fv3_akbk
!                    setup A grid and interpolation/rotation coeff
!   input argument list:
!    grid_spec
!    ak_bk
!    lendian_out
!
!   output argument list:
!    ierr
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block

  use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
  use netcdf, only: nf90_nowrite,nf90_inquire,nf90_inquire_dimension
  use netcdf, only: nf90_inquire_variable
  use m_mpimod, only: mype
  use mod_fv3_lola, only: generate_anl_grid
  use gridmod,  only:nsig,regional_time,regional_fhr,regional_fmin,aeta1_ll,aeta2_ll
  use gridmod,  only:nlon_regional,nlat_regional,eta1_ll,eta2_ll
  use gridmod,  only:grid_type_fv3_regional
  use m_kinds, only: i_kind,r_kind
  use constants, only: half,zero
  use m_mpimod, only: gsi_mpi_comm_world,mpi_itype,mpi_rtype

  implicit none
  integer(i_kind),intent(  out) :: ierr

  integer(i_kind) gfile_grid_spec
  character(:),allocatable    :: grid_spec
  character(:),allocatable    :: ak_bk
  character(len=:),allocatable :: coupler_res_filenam 
  integer(i_kind) i,k,ndimensions,iret,nvariables,nattributes,unlimiteddimid
  integer(i_kind) len,gfile_loc
  character(len=max_varname_length) :: name
  integer(i_kind) myear,mmonth,mday,mhour,mminute,msecond
  real(r_kind),allocatable:: abk_fv3(:)
  integer(i_kind) imiddle,jmiddle
! if fv3_io_layout_y > 1
  integer(i_kind) :: nio,nylen
  integer(i_kind),allocatable :: gfile_loc_layout(:)
  character(len=180)  :: filename_layout

    coupler_res_filenam='coupler.res'
    grid_spec='fv3_grid_spec'
    ak_bk='fv3_akbk'

!!!!! set regional_time
    open(24,file=trim(coupler_res_filenam),form='formatted')
    read(24,*)
    read(24,*)
    read(24,*)myear,mmonth,mday,mhour,mminute,msecond
    close(24)
    if(mype==0)  write(6,*)' myear,mmonth,mday,mhour,mminute,msecond=', myear,mmonth,mday,mhour,mminute,msecond
    regional_time(1)=myear
    regional_time(2)=mmonth
    regional_time(3)=mday
    regional_time(4)=mhour
    regional_time(5)=mminute
    regional_time(6)=msecond
    regional_fhr=zero          ! forecast hour set zero for now
    regional_fmin=zero          ! forecast min set zero for now

!!!!!!!!!!    grid_spec  !!!!!!!!!!!!!!!
    ierr=0
    iret=nf90_open(trim(grid_spec),nf90_nowrite,gfile_grid_spec)
    if(iret/=nf90_noerr) then
       write(6,*)' gsi_rfv3io_get_grid_specs: problem opening ',trim(grid_spec),', Status = ',iret
       ierr=1
       return
    endif

    iret=nf90_inquire(gfile_grid_spec,ndimensions,nvariables,nattributes,unlimiteddimid)
    gfile_loc=gfile_grid_spec
    do k=1,ndimensions
       iret=nf90_inquire_dimension(gfile_loc,k,name,len)
       if(trim(name)=='grid_xt') nx=len
       if(trim(name)=='grid_yt') ny=len
    enddo
    nlon_regional=nx
    nlat_regional=ny

    allocate(ny_layout_len(0:fv3_io_layout_y-1))
    allocate(ny_layout_b(0:fv3_io_layout_y-1))
    allocate(ny_layout_e(0:fv3_io_layout_y-1))
    ny_layout_len=ny
    ny_layout_b=0
    ny_layout_e=0
    if(fv3_io_layout_y > 1) then
       allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
       do nio=0,fv3_io_layout_y-1
          write(filename_layout,'(a,a,I4.4)') trim(grid_spec),'.',nio
          iret=nf90_open(filename_layout,nf90_nowrite,gfile_loc_layout(nio))
          if(iret/=nf90_noerr) then
             write(6,*)' problem opening ',trim(filename_layout),', Status =',iret
             ierr=1
             return
          endif
          iret=nf90_inquire(gfile_loc_layout(nio),ndimensions,nvariables,nattributes,unlimiteddimid)
          do k=1,ndimensions
              iret=nf90_inquire_dimension(gfile_loc_layout(nio),k,name,len)
              if(trim(name)=='grid_yt') ny_layout_len(nio)=len
          enddo
          iret=nf90_close(gfile_loc_layout(nio))
       enddo
       deallocate(gfile_loc_layout)
! figure out begin and end of each subdomain restart file
       nylen=0
       do nio=0,fv3_io_layout_y-1
          ny_layout_b(nio)=nylen + 1
          nylen=nylen+ny_layout_len(nio)
          ny_layout_e(nio)=nylen
       enddo
    endif
   ! if(mype==0)write(6,*),'nx,ny=',nx,ny
   ! if(mype==0)write(6,*),'ny_layout_len=',ny_layout_len
   ! if(mype==0)write(6,*),'ny_layout_b=',ny_layout_b
   ! if(mype==0)write(6,*),'ny_layout_e=',ny_layout_e

!!!    get nx,ny,grid_lon,grid_lont,grid_lat,grid_latt,nz,ak,bk

    allocate(grid_lat(nx+1,ny+1))
    allocate(grid_lon(nx+1,ny+1))
    allocate(grid_latt(nx,ny))
    allocate(grid_lont(nx,ny))

    do k=ndimensions+1,nvariables
       iret=nf90_inquire_variable(gfile_loc,k,name,len)
       if(trim(name)=='grid_lat') then
          iret=nf90_get_var(gfile_loc,k,grid_lat)
       endif
       if(trim(name)=='grid_lon') then
          iret=nf90_get_var(gfile_loc,k,grid_lon)
       endif
       if(trim(name)=='grid_latt') then
          iret=nf90_get_var(gfile_loc,k,grid_latt)
       endif
       if(trim(name)=='grid_lont') then
          iret=nf90_get_var(gfile_loc,k,grid_lont)
       endif
    enddo
!
!  need to decide the grid orientation of the FV regional model    
!
!   grid_type_fv3_regional = 0 : decide grid orientation based on
!                                grid_lat/grid_lon
!                            1 : input is E-W N-S grid
!                            2 : input is W-E S-N grid
!
    if(grid_type_fv3_regional == 0) then
        imiddle=nx/2
        jmiddle=ny/2
        if( (grid_latt(imiddle,1) < grid_latt(imiddle,ny)) .and. &
            (grid_lont(1,jmiddle) < grid_lont(nx,jmiddle)) ) then 
            grid_type_fv3_regional = 2
        else
            grid_type_fv3_regional = 1
        endif
    endif
! check the grid type
    if( grid_type_fv3_regional == 1 ) then
       !if(mype==0) write(6,*) 'FV3 regional input grid is  E-W N-S grid'
       grid_reverse_flag=.true.    ! grid is revered comparing to usual map view
    else if(grid_type_fv3_regional == 2) then
       !if(mype==0) write(6,*) 'FV3 regional input grid is  W-E S-N grid'
       grid_reverse_flag=.false.   ! grid orientated just like we see on map view    
    else
       write(6,*) 'Error: FV3 regional input grid is unknown grid'
       call stop2(678)
    endif
!
    if(grid_type_fv3_regional == 2) then
       call reverse_grid_r(grid_lont,nx,ny,1)
       call reverse_grid_r(grid_latt,nx,ny,1)
       call reverse_grid_r(grid_lon,nx+1,ny+1,1)
       call reverse_grid_r(grid_lat,nx+1,ny+1,1)
    endif

    iret=nf90_close(gfile_loc)

    iret=nf90_open(ak_bk,nf90_nowrite,gfile_loc)
    if(iret/=nf90_noerr) then
       write(6,*)'gsi_rfv3io_get_grid_specs: problem opening ',trim(ak_bk),', Status = ',iret
       ierr=1
       return
    endif
    iret=nf90_inquire(gfile_loc,ndimensions,nvariables,nattributes,unlimiteddimid)
    do k=1,ndimensions
       iret=nf90_inquire_dimension(gfile_loc,k,name,len)
       if(trim(name)=='xaxis_1') nz=len
    enddo
    !if(mype==0)write(6,'(" nz=",i5)') nz

    !nsig=nz-1

!!!    get ak,bk

    if(.not.allocated(aeta1_ll))allocate(aeta1_ll(nsig))
    if(.not.allocated(aeta2_ll))allocate(aeta2_ll(nsig))
    if(.not.allocated(eta1_ll))allocate(eta1_ll(nsig+1))
    if(.not.allocated(eta2_ll))allocate(eta2_ll(nsig+1))
    if(.not.allocated(ak))allocate(ak(nz))
    if(.not.allocated(bk))allocate(bk(nz))
    if(.not.allocated(abk_fv3))allocate(abk_fv3(nz))

    do k=ndimensions+1,nvariables
       iret=nf90_inquire_variable(gfile_loc,k,name,len)
       if(trim(name)=='ak'.or.trim(name)=='AK') then
          iret=nf90_get_var(gfile_loc,k,abk_fv3)
          do i=1,nz
             ak(i)=abk_fv3(nz+1-i)
          enddo
       endif
       if(trim(name)=='bk'.or.trim(name)=='BK') then
          iret=nf90_get_var(gfile_loc,k,abk_fv3)
          do i=1,nz
             bk(i)=abk_fv3(nz+1-i)
          enddo
       endif
    enddo
    iret=nf90_close(gfile_loc)

!!!!! change unit of ak 
    do i=1,nsig+1
       eta1_ll(i)=ak(i)*0.001_r_kind
       eta2_ll(i)=bk(i)
    enddo
    do i=1,nsig
       aeta1_ll(i)=half*(ak(i)+ak(i+1))*0.001_r_kind
       aeta2_ll(i)=half*(bk(i)+bk(i+1))
    enddo
    !if(mype==0)then
    !   do i=1,nz
    !      write(6,'(" ak,bk(",i3,") = ",2f17.6)') i,ak(i),bk(i)
    !   enddo
    !endif

!!!!!!! setup A grid and interpolation/rotation coeff.
    call generate_anl_grid(nx,ny,grid_lon,grid_lont,grid_lat,grid_latt)



    deallocate (grid_lon,grid_lat,grid_lont,grid_latt)
    deallocate (ak,bk,abk_fv3)

    return
end subroutine gsi_rfv3io_get_grid_specs

subroutine gsi_rfv3io_get_ens_grid_specs(grid_spec,ierr)
!$$$  subprogram documentation block
!                .      .    .                                        .
! subprogram:    gsi_rfv3io_get_ens_grid_specs
! modified from     gsi_rfv3io_get_grid_specs
!   pgrmmr: parrish     org: np22                date: 2017-04-03
!
! abstract:  obtain grid dimensions nx,ny and grid definitions
!                grid_x,grid_xt,grid_y,grid_yt,grid_lon,grid_lont,grid_lat,grid_latt
!                nz,ak(nz),bk(nz)
!
! program history log:
!   2017-04-03  parrish - initial documentation
!   2017-10-10  wu - setup A grid and interpolation coeff with generate_anl_grid
!   2018-02-16  wu - read in time info from file coupler.res
!                    read in lat, lon at the center and corner of the grid cell
!                    from file fv3_grid_spec, and vertical grid infor from file
!                    fv3_akbk
!                    setup A grid and interpolation/rotation coeff
!   input argument list:
!    grid_spec
!    ak_bk
!    lendian_out
!
!   output argument list:
!    ierr
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block
  use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
  use netcdf, only: nf90_nowrite,nf90_mpiio,nf90_inquire,nf90_inquire_dimension
  use netcdf, only: nf90_inquire_variable
  use m_mpimod, only: mype
  use mod_fv3_lola, only: definecoef_regular_grids
  use gridmod,  only:nlon_regionalens,nlat_regionalens
  use gridmod,  only:grid_type_fv3_regional
  use m_kinds, only: i_kind,r_kind
  use constants, only: half,zero
  use m_mpimod, only: gsi_mpi_comm_world,mpi_itype,mpi_rtype
  implicit none
  character(:),allocatable,intent(in   ) :: grid_spec
  integer(i_kind),         intent(  out) :: ierr

  integer(i_kind) gfile_grid_spec
  integer(i_kind) k,ndimensions,iret,nvariables,nattributes,unlimiteddimid
  integer(i_kind) gfile_loc,len
  character(len=128) :: name
  integer(i_kind) :: nio,nylen
  integer(i_kind),allocatable :: gfile_loc_layout(:)
  character(len=180)  :: filename_layout
  integer(i_kind) imiddle,jmiddle,grid_ens_type_fv3_regional


    iret=nf90_open(trim(grid_spec),nf90_nowrite,gfile_grid_spec)
    if(iret/=nf90_noerr) then
       write(6,*)' problem opening1 ',trim(grid_spec),', Status = ',iret
       ierr=1
       return
    endif
    iret=nf90_inquire(gfile_grid_spec,ndimensions,nvariables,nattributes,unlimiteddimid)
    gfile_loc=gfile_grid_spec
    do k=1,ndimensions
       iret=nf90_inquire_dimension(gfile_loc,k,name,len)
       if(trim(name)=='grid_xt') nxens=len
       if(trim(name)=='grid_yt') nyens=len
    enddo
    allocate(grid_lat(nxens+1,nyens+1))
    allocate(grid_lon(nxens+1,nyens+1))
    allocate(grid_latt(nxens,nyens))
    allocate(grid_lont(nxens,nyens))
    do k=ndimensions+1,nvariables
       iret=nf90_inquire_variable(gfile_loc,k,name,len)
       if(trim(name)=='grid_lat') then
          iret=nf90_get_var(gfile_loc,k,grid_lat)
       endif
       if(trim(name)=='grid_lon') then
          iret=nf90_get_var(gfile_loc,k,grid_lon)
       endif
       if(trim(name)=='grid_latt') then
          iret=nf90_get_var(gfile_loc,k,grid_latt)
       endif
       if(trim(name)=='grid_lont') then
          iret=nf90_get_var(gfile_loc,k,grid_lont)
       endif
    enddo
    iret=nf90_close(gfile_loc)

    nlon_regionalens=nxens
    nlat_regionalens=nyens
    allocate(ny_layout_lenens(0:fv3_io_layout_y-1))
    allocate(ny_layout_bens(0:fv3_io_layout_y-1))
    allocate(ny_layout_eens(0:fv3_io_layout_y-1))
    ny_layout_lenens=nyens
    ny_layout_bens=0
    ny_layout_eens=0
    if(fv3_io_layout_y > 1) then
       allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
       do nio=0,fv3_io_layout_y-1
          write(filename_layout,'(a,a,I4.4)') trim(grid_spec),'.',nio
          iret=nf90_open(filename_layout,nf90_nowrite,gfile_loc_layout(nio))
          if(iret/=nf90_noerr) then
             write(6,*)' problem opening ',trim(filename_layout),', Status =',iret
             ierr=1
             return
          endif
          iret=nf90_inquire(gfile_loc_layout(nio),ndimensions,nvariables,nattributes,unlimiteddimid)
          do k=1,ndimensions
              iret=nf90_inquire_dimension(gfile_loc_layout(nio),k,name,len)
              if(trim(name)=='grid_yt') ny_layout_lenens(nio)=len
          enddo
          iret=nf90_close(gfile_loc_layout(nio))
       enddo
       deallocate(gfile_loc_layout)
! figure out begin and end of each subdomain restart file
       nylen=0
       do nio=0,fv3_io_layout_y-1
          ny_layout_bens(nio)=nylen + 1
          nylen=nylen+ny_layout_lenens(nio)
          ny_layout_eens(nio)=nylen
       enddo
    endif
    if(mype==0)write(6,*),'nxens,nyens=',nxens,nyens
    if(mype==0)write(6,*),'ny_layout_lenens=',ny_layout_lenens
    if(mype==0)write(6,*),'ny_layout_bens=',ny_layout_bens
    if(mype==0)write(6,*),'ny_layout_eens=',ny_layout_eens

    imiddle=nxens/2
    jmiddle=nyens/2
    if( (grid_latt(imiddle,1) < grid_latt(imiddle,nyens)) .and. &
        (grid_lont(1,jmiddle) < grid_lont(nxens,jmiddle)) ) then
        grid_ens_type_fv3_regional = 2
    else
        grid_ens_type_fv3_regional = 1
    endif
! check the grid type
    if( grid_type_fv3_regional == grid_ens_type_fv3_regional ) then
       if(mype==0) write(6,*) 'Ensemble has the same orientation as the control, Cool!'
    else
       write(6,*) 'Warning! Ensemble has a different orientation as the control. This case needs further tests, Abort!'
       call stop2(678)
    endif
!
    if(grid_type_fv3_regional == 2) then
       call reverse_grid_r(grid_lont,nxens,nyens,1)
       call reverse_grid_r(grid_latt,nxens,nyens,1)
       call reverse_grid_r(grid_lon,nxens+1,nyens+1,1)
       call reverse_grid_r(grid_lat,nxens+1,nyens+1,1)
    endif

    call definecoef_regular_grids(nxens,nyens,grid_lon,grid_lont,grid_lat,grid_latt)
    deallocate (grid_lon,grid_lat,grid_lont,grid_latt)
    return
end subroutine gsi_rfv3io_get_ens_grid_specs

subroutine gsi_fv3ncdf2d_read_v1(filenamein,varname,varname2,work_sub,mype_io)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    gsi_fv23ncdf2d_readv1       
!   prgmmr: T. Lei                               date: 2019-03-28
!           modified from gsi_fv3ncdf_read and gsi_fv3ncdf2d_read
!
! abstract: read in a 2d field from a netcdf FV3 file in mype_io
!          then scatter the field to each PE 
! program history log:
!
!   input argument list:
!     filename    - file name to read from       
!     varname     - variable name to read in
!     varname2    - variable name to read in
!     mype_io     - pe to read in the field
!
!   output argument list:
!     work_sub    - output sub domain field
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$  end documentation block


    use m_kinds, only: r_kind,i_kind
    use m_mpimod, only: ierror,gsi_mpi_comm_world,npe,mpi_rtype,mype
    use gridmod, only: lat2,lon2,nlat,nlon,itotsub,ijn_s,displs_s
    use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
    use netcdf, only: nf90_nowrite,nf90_inquire,nf90_inquire_dimension
    use netcdf, only: nf90_inq_varid
    use netcdf, only: nf90_inquire_variable
    use mod_fv3_lola, only: fv3_h_to_ll
    use general_commvars_mod, only: ltosi_s,ltosj_s

    implicit none
    character(*)   ,   intent(in   ) :: varname,varname2,filenamein
    real(r_kind)   ,   intent(out  ) :: work_sub(lat2,lon2) 
    integer(i_kind)   ,intent(in   ) :: mype_io
    real(r_kind),allocatable,dimension(:,:,:):: uu
    real(r_kind),allocatable,dimension(:):: work
    real(r_kind),allocatable,dimension(:,:):: a


    integer(i_kind) n,ndim
    integer(i_kind) gfile_loc,var_id,iret
    integer(i_kind) kk,j,mm1,ii,jj
    integer(i_kind) ndimensions,nvariables,nattributes,unlimiteddimid

    mm1=mype+1
    allocate (work(itotsub))

    if(mype==mype_io ) then
       iret=nf90_open(filenamein,nf90_nowrite,gfile_loc)
       if(iret/=nf90_noerr) then
          write(6,*)' gsi_fv3ncdf2d_read_v1: problem opening ',trim(filenamein),gfile_loc,', Status = ',iret
          write(6,*)' gsi_fv3ncdf2d_read_v1: problem opening with varnam ',trim(varname)
          return
       endif

       iret=nf90_inquire(gfile_loc,ndimensions,nvariables,nattributes,unlimiteddimid)
       allocate(a(nlat,nlon))

       iret=nf90_inq_varid(gfile_loc,trim(adjustl(varname)),var_id)
       if(iret/=nf90_noerr) then
         iret=nf90_inq_varid(gfile_loc,trim(adjustl(varname2)),var_id)
         if(iret/=nf90_noerr) then
           write(6,*)' wrong to get var_id ',var_id
         endif
       endif

       iret=nf90_inquire_variable(gfile_loc,var_id,ndims=ndim)
       if(allocated(uu       )) deallocate(uu       )
       allocate(uu(nx,ny,1))
       iret=nf90_get_var(gfile_loc,var_id,uu)
          call fv3_h_to_ll(uu(:,:,1),a,nx,ny,nlon,nlat,grid_reverse_flag)
          kk=0
          do n=1,npe
             do j=1,ijn_s(n)
                kk=kk+1
                ii=ltosi_s(kk)
                jj=ltosj_s(kk)
                work(kk)=a(ii,jj)
             end do
          end do

       iret=nf90_close(gfile_loc)
       deallocate (uu,a)

    endif !mype

    call mpi_scatterv(work,ijn_s,displs_s,mpi_rtype,&
       work_sub,ijn_s(mm1),mpi_rtype,mype_io,gsi_mpi_comm_world,ierror)

    deallocate (work)
    return
end subroutine  gsi_fv3ncdf2d_read_v1 

subroutine gsi_fv3ncdf_read(grd_ionouv,cstate_nouv,filenamein,fv3filenamegin,ensgrid)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    gsi_fv3ncdf_read       
!   prgmmr: wu               org: np22                date: 2017-10-10
!           lei  re-write for parallelization         date: 2021-09-29
!                 similar for horizontal recurisve filtering
! abstract: read in fields excluding u and v
! program history log:
!
!   input argument list:
!     filename    - file name to read from       
!     varname     - variable name to read in
!     varname2    - variable name to read in
!     mype_io     - pe to read in the field
!
!   output argument list:
!     work_sub    - output sub domain field
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$  end documentation block


    use m_kinds, only: r_kind,i_kind
    use m_mpimod, only: gsi_mpi_comm_world,mpi_rtype,mype,npe,setcomm,mpi_integer,mpi_max
    use m_mpimod, only:  MPI_INFO_NULL
    use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
    use netcdf, only: nf90_nowrite,nf90_mpiio,nf90_inquire,nf90_inquire_dimension
    use netcdf, only: nf90_inquire_variable
    use netcdf, only: nf90_inq_varid
    use mod_fv3_lola, only: fv3_h_to_ll,fv3_h_to_ll_ens
    use gsi_bundlemod, only: gsi_bundle
    use general_sub2grid_mod, only: sub2grid_info,general_grid2sub

    implicit none
    type(sub2grid_info),        intent(in   ) :: grd_ionouv 
    type(gsi_bundle),           intent(inout) :: cstate_nouv
    character(*),               intent(in   ) :: filenamein
    type (type_fv3regfilenameg),intent(in   ) ::fv3filenamegin
    logical,                    intent(in   ) :: ensgrid

    real(r_kind),allocatable,dimension(:,:):: uu2d
    real(r_kind),dimension(1,grd_ionouv%nlat,grd_ionouv%nlon,grd_ionouv%kbegin_loc:grd_ionouv%kend_alloc):: hwork
    character(len=max_varname_length) :: varname,vgsiname
    character(len=max_varname_length) :: name
    character(len=max_filename_length) :: filenamein2
    real(r_kind),allocatable,dimension(:,:):: uu2d_tmp
    integer(i_kind) :: countloc_tmp(4),startloc_tmp(4)

    integer(i_kind) nlatcase,nloncase,nxcase,nycase,countloc(4),startloc(4)
    integer(i_kind) ilev,ilevtot,inative
    integer(i_kind) kbgn,kend,len
    logical   :: phy_smaller_domain
    integer(i_kind) gfile_loc,iret,var_id
    integer(i_kind) nz,nzp1,mm1,nx_phy

    integer(i_kind):: iworld,iworld_group,nread,mpi_comm_read,i,ierror
    integer(i_kind),dimension(npe):: members,members_read,mype_read_rank
    logical:: procuse

! for io_layout > 1
    real(r_kind),allocatable,dimension(:,:):: uu2d_layout
    integer(i_kind) :: nio
    integer(i_kind),allocatable :: gfile_loc_layout(:)
    character(len=180)  :: filename_layout

    mm1=mype+1
    nloncase=grd_ionouv%nlon
    nlatcase=grd_ionouv%nlat
    if (ensgrid) then
     nxcase=nxens
     nycase=nyens
    else
     nxcase=nx
     nycase=ny
    end if
    kbgn=grd_ionouv%kbegin_loc
    kend=grd_ionouv%kend_loc
    allocate(uu2d(nxcase,nycase))

    procuse = .false.
    members=-1
    members_read=-1
    if (kbgn<=kend) then
       procuse = .true.
       members(mm1) = mype
    endif
    call mpi_allreduce(members,members_read,npe,mpi_integer,mpi_max,gsi_mpi_comm_world,ierror)

    nread=0
    mype_read_rank=-1
    do i=1,npe
       if (members_read(i) >= 0) then
          nread=nread+1
          mype_read_rank(nread) = members_read(i)
       endif
    enddo
    
    call setcomm(iworld,iworld_group,nread,mype_read_rank,mpi_comm_read,ierror)

    if (procuse) then

       if(fv3_io_layout_y > 1) then
          allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
          do nio=0,fv3_io_layout_y-1
             write(filename_layout,'(a,a,I4.4)') trim(filenamein),'.',nio
             iret=nf90_open(filename_layout,ior(nf90_nowrite,nf90_mpiio),gfile_loc_layout(nio),comm=mpi_comm_read,info=MPI_INFO_NULL) !clt
             if(iret/=nf90_noerr) then
                write(6,*)' gsi_fv3ncdf_read: problem opening ',trim(filename_layout),gfile_loc_layout(nio),', Status = ',iret
                call stop2(333)
             endif
          enddo
       else
          iret=nf90_open(filenamein,ior(nf90_nowrite,nf90_mpiio),gfile_loc,comm=mpi_comm_read,info=MPI_INFO_NULL) !clt
          if(iret/=nf90_noerr) then
             write(6,*)' gsi_fv3ncdf_read: problem opening ',trim(filenamein),gfile_loc,', Status = ',iret
             call stop2(333)
          endif
       endif
       do ilevtot=kbgn,kend
          vgsiname=grd_ionouv%names(1,ilevtot)
          if(trim(vgsiname)=='delzinc') cycle  !delzinc is not read from DZ ,it's started from hydrostatic height 
          if(trim(vgsiname)=='amassi') cycle 
          if(trim(vgsiname)=='amassj') cycle 
          if(trim(vgsiname)=='amassk') cycle 
          if(trim(vgsiname)=='pm2_5') cycle 
          call getfv3lamfilevname(vgsiname,fv3filenamegin,filenamein2,varname)
          name=trim(varname)
          if(trim(filenamein) /= trim(filenamein2)) then
             write(6,*)'filenamein and filenamein2 are not the same as expected, stop'
             call stop2(333)
          endif
          ilev=grd_ionouv%lnames(1,ilevtot)
          nz=grd_ionouv%nsig
          nzp1=nz+1
          inative=nzp1-ilev
          startloc=(/1,1,inative,1/)
          countloc=(/nxcase,nycase,1,1/)
          ! Variable ref_f3d in phy_data.nc has a smaller domain size than
          ! dynvariables and tracers as well as a reversed order in vertical
          if ( trim(adjustl(varname)) == 'ref_f3d' .or. trim(adjustl(varname)) == 'flash_extent_density' )then
             iret=nf90_inquire_dimension(gfile_loc,1,name,len)
             if(trim(name)=='xaxis_1') nx_phy=len
             if( nx_phy == nxcase )then
                allocate(uu2d_tmp(nxcase,nycase))
                countloc_tmp=(/nxcase,nycase,1,1/)
                phy_smaller_domain = .false.
             else
                allocate(uu2d_tmp(nxcase-6,nycase-6))
                countloc_tmp=(/nxcase-6,nycase-6,1,1/)
                phy_smaller_domain = .true.
             end if
             startloc_tmp=(/1,1,ilev,1/)
          end if
          
          if(fv3_io_layout_y > 1) then
             do nio=0,fv3_io_layout_y-1
                if (ensgrid) then
                   countloc=(/nxcase,ny_layout_lenens(nio)+1,1,1/)
                   allocate(uu2d_layout(nxcase,ny_layout_lenens(nio)+1))
                else
                   countloc=(/nxcase,ny_layout_len(nio),1,1/)
                   allocate(uu2d_layout(nxcase,ny_layout_len(nio)))
                end if
                iret=nf90_inq_varid(gfile_loc_layout(nio),trim(adjustl(varname)),var_id)
                iret=nf90_get_var(gfile_loc_layout(nio),var_id,uu2d_layout,start=startloc,count=countloc)
                if (ensgrid) then
                   uu2d(:,ny_layout_bens(nio):ny_layout_eens(nio))=uu2d_layout
                else
                   uu2d(:,ny_layout_b(nio):ny_layout_e(nio))=uu2d_layout
                end if
                deallocate(uu2d_layout)
             enddo
          else
             iret=nf90_inq_varid(gfile_loc,trim(adjustl(varname)),var_id)
             if ( trim(adjustl(varname)) == 'ref_f3d'.or. trim(adjustl(varname)) == 'flash_extent_density' )then
                uu2d = 0.0_r_kind
                iret=nf90_get_var(gfile_loc,var_id,uu2d_tmp,start=startloc_tmp,count=countloc_tmp)
                where(uu2d_tmp < 0.0_r_kind)
                   uu2d_tmp = 0.0_r_kind
                endwhere
                
                if( phy_smaller_domain )then
                   uu2d(4:nxcase-3,4:nycase-3) = uu2d_tmp
                else
                   uu2d(1:nxcase,1:nycase) = uu2d_tmp
                end if
                deallocate(uu2d_tmp)
             else
                iret=nf90_get_var(gfile_loc,var_id,uu2d,start=startloc,count=countloc)
             end if
          endif
          
          if (ensgrid) then
             call fv3_h_to_ll_ens(uu2d,hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,grid_reverse_flag)
          else
             call fv3_h_to_ll(uu2d,hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,grid_reverse_flag)
          endif
       enddo  ! ilevtot
       
       if(fv3_io_layout_y > 1) then
          do nio=1,fv3_io_layout_y-1
             iret=nf90_close(gfile_loc_layout(nio))
          enddo
          deallocate(gfile_loc_layout)
       else
          iret=nf90_close(gfile_loc)
       endif
    endif
    call mpi_barrier(gsi_mpi_comm_world,ierror)
       
    deallocate (uu2d)
    call general_grid2sub(grd_ionouv,hwork,cstate_nouv%values)
    
    return
  end subroutine gsi_fv3ncdf_read

subroutine gsi_fv3ncdf_read_v1(grd_ionouv,cstate_nouv,filenamein,fv3filenamegin,ensgrid)
  
!$$$  subprogram documentation block
!                 .      .    .                                       .
! subprogram:    gsi_fv3ncdf_read _v1      
!            Lei modified from gsi_fv3ncdf_read
!   prgmmr: wu               org: np22                date: 2017-10-10
!
! abstract: read in a field from a netcdf FV3 file in mype_io
!          then scatter the field to each PE 
! program history log:
!
!   input argument list:
!     filename    - file name to read from       
!     varname     - variable name to read in
!     varname2    - variable name to read in
!     mype_io     - pe to read in the field
!
!   output argument list:
!     work_sub    - output sub domain field
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$  end documentation block


    use m_kinds, only: r_kind,i_kind
    use m_mpimod, only:  npe,mpi_rtype,gsi_mpi_comm_world,mype,MPI_INFO_NULL
    use m_mpimod, only: gsi_mpi_comm_world,mpi_rtype,mype,setcomm,mpi_integer,mpi_max
    use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
    use netcdf, only: nf90_nowrite,nf90_mpiio,nf90_inquire,nf90_inquire_dimension
    use netcdf, only: nf90_inquire_variable
    use netcdf, only: nf90_inq_varid
    use mod_fv3_lola, only: fv3_h_to_ll,fv3_h_to_ll_ens
    use gsi_bundlemod, only: gsi_bundle
    use general_sub2grid_mod, only: sub2grid_info,general_grid2sub

    implicit none
    type(sub2grid_info),         intent(in):: grd_ionouv 
    character(*),                intent(in):: filenamein
    logical,                     intent(in ) :: ensgrid
    type (type_fv3regfilenameg), intent(in) :: fv3filenamegin
    type(gsi_bundle),            intent(inout) :: cstate_nouv

    real(r_kind),allocatable,dimension(:,:):: uu2d
    real(r_kind),dimension(1,grd_ionouv%nlat,grd_ionouv%nlon,grd_ionouv%kbegin_loc:grd_ionouv%kend_alloc):: hwork
    character(len=max_filename_length) :: filenamein2
    character(len=max_varname_length) :: varname,vgsiname


    integer(i_kind) nlatcase,nloncase,nxcase,nycase,countloc(4),startloc(4)
    integer(i_kind) kbgn,kend
    integer(i_kind) var_id
    integer(i_kind) inative,ilev,ilevtot
    integer(i_kind) gfile_loc,iret
    integer(i_kind) nzp1,mm1
    
    integer(i_kind):: iworld,iworld_group,nread,mpi_comm_read,i,ierror
    integer(i_kind),dimension(npe):: members,members_read,mype_read_rank
    logical:: procuse



    mm1=mype+1

    nloncase=grd_ionouv%nlon
    nlatcase=grd_ionouv%nlat
    if (ensgrid) then
     nxcase=nxens
     nycase=nyens
    else
     nxcase=nx
     nycase=ny
    end if
    allocate(uu2d(nxcase,nycase))

    kbgn=grd_ionouv%kbegin_loc
    kend=grd_ionouv%kend_loc
    procuse = .false.
    members=-1
    members_read=-1
    if (kbgn<=kend) then
       procuse = .true.
       members(mm1) = mype
    endif
    call mpi_allreduce(members,members_read,npe,mpi_integer,mpi_max,gsi_mpi_comm_world,ierror)

    nread=0
    mype_read_rank=-1
    do i=1,npe
       if (members_read(i) >= 0) then
          nread=nread+1
          mype_read_rank(nread) = members_read(i)
       endif
    enddo
    
    call setcomm(iworld,iworld_group,nread,mype_read_rank,mpi_comm_read,ierror)

    if (procuse) then 
    iret=nf90_open(filenamein,ior(nf90_nowrite,nf90_mpiio),gfile_loc,comm=mpi_comm_read,info=MPI_INFO_NULL) !clt
    if(iret/=nf90_noerr) then
       write(6,*)' gsi_fv3ncdf_read_v1: problem opening ',trim(filenamein),gfile_loc,', Status = ',iret
       call stop2(333)
    endif


    do ilevtot=kbgn,kend
      vgsiname=grd_ionouv%names(1,ilevtot)
      call getfv3lamfilevname(vgsiname,fv3filenamegin,filenamein2,varname)
      if(trim(filenamein) /= trim(filenamein2)) then
        write(6,*)'filenamein and filenamein2 are not the same as expected, stop'
        call stop2(333)
      endif
      ilev=grd_ionouv%lnames(1,ilevtot)
      nz=grd_ionouv%nsig
      nzp1=nz+1
      inative=nzp1-ilev
      startloc=(/1,1,inative+1,1/)
      countloc=(/nxcase,nycase,1,1/)
      iret=nf90_inq_varid(gfile_loc,trim(adjustl(varname)),var_id)
      if(iret/=nf90_noerr) then
        write(6,*)' wrong to get var_id ',var_id
        call stop2(333)
      endif
      
      iret=nf90_get_var(gfile_loc,var_id,uu2d,start=startloc,count=countloc)

      if (ensgrid) then
        call fv3_h_to_ll_ens(uu2d,hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,grid_reverse_flag)
      else
        call fv3_h_to_ll(uu2d,hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,grid_reverse_flag)
      end if
        
    enddo ! i
    iret=nf90_close(gfile_loc)
    endif
    call general_grid2sub(grd_ionouv,hwork,cstate_nouv%values)

    deallocate (uu2d)


    return
end subroutine gsi_fv3ncdf_read_v1

subroutine gsi_fv3ncdf_readuv(grd_uv,ges_u,ges_v,fv3filenamegin,ensgrid)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    gsi_fv3ncdf_readuv
!   prgmmr: wu w             org: np22                date: 2017-11-22
!
! abstract: read in a field from a netcdf FV3 file in mype_u,mype_v
!           then scatter the field to each PE 
! program history log:
!
!   input argument list:
!
!   output argument list:
!     ges_u       - output sub domain u field
!     ges_v       - output sub domain v field
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$  end documentation block
    use m_kinds, only: r_kind,i_kind
    use m_mpimod, only: gsi_mpi_comm_world,mpi_rtype,mype,mpi_info_null,npe,setcomm,mpi_integer,mpi_max
    use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
    use netcdf, only: nf90_nowrite,nf90_mpiio,nf90_inquire,nf90_inquire_dimension
    use netcdf, only: nf90_inquire_variable
    use netcdf, only: nf90_inq_varid
    use mod_fv3_lola, only: fv3_h_to_ll,fv3uv2earth,fv3_h_to_ll_ens,fv3uv2earthens
    use general_sub2grid_mod, only: sub2grid_info,general_grid2sub

    implicit none
    type(sub2grid_info),        intent(in):: grd_uv 
    real(r_kind),dimension(grd_uv%lat2,grd_uv%lon2,grd_uv%nsig),intent(inout)::ges_u
    real(r_kind),dimension(grd_uv%lat2,grd_uv%lon2,grd_uv%nsig),intent(inout)::ges_v
    type (type_fv3regfilenameg),intent (in) :: fv3filenamegin
    logical,                    intent(in ) :: ensgrid

    real(r_kind),dimension(2,grd_uv%nlat,grd_uv%nlon,grd_uv%kbegin_loc:grd_uv%kend_alloc):: hwork
    character(:), allocatable:: filenamein
    real(r_kind),allocatable,dimension(:,:):: u2d,v2d
    real(r_kind),allocatable,dimension(:,:):: uc2d,vc2d
    character(len=max_filename_length) :: filenamein2
    character(len=max_varname_length) :: varname,vgsiname
    real(r_kind),allocatable,dimension(:,:,:,:):: worksub
    integer(i_kind) u_grd_VarId,v_grd_VarId
    integer(i_kind) nlatcase,nloncase
    integer(i_kind) nxcase,nycase
    integer(i_kind) u_countloc(4),u_startloc(4),v_countloc(4),v_startloc(4)
    integer(i_kind) inative,ilev,ilevtot
    integer(i_kind) kbgn,kend

    integer(i_kind) gfile_loc,iret
    integer(i_kind) nz,nzp1,mm1

    integer(i_kind):: iworld,iworld_group,nread,mpi_comm_read,i,ierror
    integer(i_kind),dimension(npe):: members,members_read,mype_read_rank
    logical:: procuse

! for fv3_io_layout_y > 1
    real(r_kind),allocatable,dimension(:,:):: u2d_layout,v2d_layout
    integer(i_kind) :: nio
    integer(i_kind),allocatable :: gfile_loc_layout(:)
    character(len=180)  :: filename_layout

    mm1=mype+1
    nloncase=grd_uv%nlon
    nlatcase=grd_uv%nlat
    if (ensgrid) then
     nxcase=nxens
     nycase=nyens
    else
     nxcase=nx
     nycase=ny
    end if
    kbgn=grd_uv%kbegin_loc
    kend=grd_uv%kend_loc
    allocate(u2d(nxcase,nycase+1))
    allocate(v2d(nxcase+1,nycase))
    allocate(uc2d(nxcase,nycase))
    allocate(vc2d(nxcase,nycase))
    allocate (worksub(2,grd_uv%lat2,grd_uv%lon2,grd_uv%nsig))
    filenamein=fv3filenamegin%dynvars

    procuse = .false.
    members=-1
    members_read=-1
    if (kbgn<=kend) then
       procuse = .true.
       members(mm1) = mype
    endif

    call mpi_allreduce(members,members_read,npe,mpi_integer,mpi_max,gsi_mpi_comm_world,ierror)

    nread=0
    mype_read_rank=-1
    do i=1,npe
       if (members_read(i) >= 0) then
          nread=nread+1
          mype_read_rank(nread) = members_read(i)
       endif
    enddo

    call setcomm(iworld,iworld_group,nread,mype_read_rank,mpi_comm_read,ierror)

    if (procuse) then
       if(fv3_io_layout_y > 1) then
          allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
          do nio=0,fv3_io_layout_y-1
             write(filename_layout,'(a,a,I4.4)') trim(filenamein),".",nio
             iret=nf90_open(filename_layout,nf90_nowrite,gfile_loc_layout(nio),comm=mpi_comm_read,info=MPI_INFO_NULL)
             if(iret/=nf90_noerr) then
                write(6,*)'problem opening6 ',trim(filename_layout),gfile_loc_layout(nio),', Status = ',iret
                call stop2(333)
             endif
          enddo
       else
          iret=nf90_open(filenamein,ior(nf90_nowrite,nf90_mpiio),gfile_loc,comm=mpi_comm_read,info=MPI_INFO_NULL) !clt
          if(iret/=nf90_noerr) then
             write(6,*)' problem opening6 ',trim(filenamein),', Status = ',iret
             call stop2(333)
          endif
       endif
       
       do ilevtot=kbgn,kend
          vgsiname=grd_uv%names(1,ilevtot)
          call getfv3lamfilevname(vgsiname,fv3filenamegin,filenamein2,varname)
          if(trim(filenamein) /= trim(filenamein2)) then
             write(6,*)'filenamein and filenamein2 are not the same as expected, stop'
             call stop2(333)
          endif
          ilev=grd_uv%lnames(1,ilevtot)
          nz=grd_uv%nsig
          nzp1=nz+1
          inative=nzp1-ilev
          u_countloc=(/nxcase,nycase+1,1,1/)
          v_countloc=(/nxcase+1,nycase,1,1/)
          u_startloc=(/1,1,inative,1/)
          v_startloc=(/1,1,inative,1/)
          if(fv3_io_layout_y > 1) then
             do nio=0,fv3_io_layout_y-1
                if (ensgrid) then
                   u_countloc=(/nxcase,ny_layout_lenens(nio)+1,1,1/)
                   allocate(u2d_layout(nxcase,ny_layout_lenens(nio)+1))
                else
                   u_countloc=(/nxcase,ny_layout_len(nio)+1,1,1/)
                   allocate(u2d_layout(nxcase,ny_layout_len(nio)+1))
                end if
                call check( nf90_inq_varid(gfile_loc_layout(nio),'u',u_grd_VarId) ) 
                iret=nf90_get_var(gfile_loc_layout(nio),u_grd_VarId,u2d_layout,start=u_startloc,count=u_countloc)
                if (ensgrid) then
                   u2d(:,ny_layout_bens(nio):ny_layout_eens(nio))=u2d_layout(:,1:ny_layout_lenens(nio))
                   if(nio==fv3_io_layout_y-1) u2d(:,ny_layout_eens(nio)+1)=u2d_layout(:,ny_layout_lenens(nio)+1) 
                   deallocate(u2d_layout)
                   v_countloc=(/nxcase+1,ny_layout_lenens(nio),1,1/)
                   allocate(v2d_layout(nxcase+1,ny_layout_lenens(nio)))
                else
                   u2d(:,ny_layout_b(nio):ny_layout_e(nio))=u2d_layout(:,1:ny_layout_len(nio))
                   if(nio==fv3_io_layout_y-1) u2d(:,ny_layout_e(nio)+1)=u2d_layout(:,ny_layout_len(nio)+1) 
                   deallocate(u2d_layout)
                   v_countloc=(/nxcase+1,ny_layout_len(nio),1,1/)
                   allocate(v2d_layout(nxcase+1,ny_layout_len(nio)))
                end if
                call check( nf90_inq_varid(gfile_loc_layout(nio),'v',v_grd_VarId) ) 
                iret=nf90_get_var(gfile_loc_layout(nio),v_grd_VarId,v2d_layout,start=v_startloc,count=v_countloc)
                if (ensgrid) then
                   v2d(:,ny_layout_bens(nio):ny_layout_eens(nio))=v2d_layout
                else
                   v2d(:,ny_layout_b(nio):ny_layout_e(nio))=v2d_layout
                end if
                deallocate(v2d_layout)
             enddo
          else
             call check( nf90_inq_varid(gfile_loc,'u',u_grd_VarId) ) 
             iret=nf90_get_var(gfile_loc,u_grd_VarId,u2d,start=u_startloc,count=u_countloc)
             call check( nf90_inq_varid(gfile_loc,'v',v_grd_VarId) ) 
             iret=nf90_get_var(gfile_loc,v_grd_VarId,v2d,start=v_startloc,count=v_countloc)
          endif
          
          if(.not.grid_reverse_flag) then 
             call reverse_grid_r_uv (u2d,nxcase,nycase+1,1)
             call reverse_grid_r_uv (v2d,nxcase+1,nycase,1)
          endif
          if (ensgrid) then
             call fv3uv2earthens(u2d(:,:),v2d(:,:),nxcase,nycase,uc2d,vc2d)
          else
             call fv3uv2earth(u2d(:,:),v2d(:,:),nxcase,nycase,uc2d,vc2d)
          end if
          
          !    NOTE on transfor to earth u/v:
          !       The u and v before transferring need to be in E-W/N-S grid, which is
          !       defined as reversed grid here because it is revered from map view.
          !
          !       Have set the following flag for grid orientation
          !         grid_reverse_flag=true:  E-W/N-S grid
          !         grid_reverse_flag=false: W-E/S-N grid 
          !
          !       So for preparing the wind transferring, need to reverse the grid from
          !       W-E/S-N grid to E-W/N-S grid when grid_reverse_flag=false:
          !
          !            if(.not.grid_reverse_flag) call reverse_grid_r_uv
          !
          !       and the last input parameter for fv3_h_to_ll is alway true:
          !
          !
          if (ensgrid) then
            call fv3_h_to_ll_ens(uc2d,hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,.true.)
            call fv3_h_to_ll_ens(vc2d,hwork(2,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,.true.)
          else
            call fv3_h_to_ll(uc2d,hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,.true.)
            call fv3_h_to_ll(vc2d,hwork(2,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,.true.)
          end if
       enddo ! i
       
       if(fv3_io_layout_y > 1) then
          do nio=0,fv3_io_layout_y-1
             iret=nf90_close(gfile_loc_layout(nio))
          enddo
          deallocate(gfile_loc_layout)
       else
          iret=nf90_close(gfile_loc)
       endif
    endif

    call mpi_barrier(gsi_mpi_comm_world,ierror)
    deallocate(u2d,v2d,uc2d,vc2d)
    
    call general_grid2sub(grd_uv,hwork,worksub) 
    ges_u=worksub(1,:,:,:)
    ges_v=worksub(2,:,:,:)
    deallocate(worksub)

end subroutine gsi_fv3ncdf_readuv
subroutine gsi_fv3ncdf_readuv_v1(grd_uv,ges_u,ges_v,fv3filenamegin,ensgrid)
!$$$  subprogram documentation block
! subprogram:    gsi_fv3ncdf_readuv_v1
!   prgmmr: wu w             org: np22                date: 2017-11-22
! program history log:
!   2019-04 lei  modified from  gsi_fv3ncdf_readuv to deal with cold start files                                       .
! abstract: read in a field from a "cold start" netcdf FV3 file in mype_u,mype_v
!           then scatter the field to each PE 
! program history log:
!
!   input argument list:
!
!   output argument list:
!     ges_u       - output sub domain u field
!     ges_v       - output sub domain v field
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$  end documentation block
    use constants, only:  half
    use m_kinds, only: r_kind,i_kind
    use m_mpimod, only: setcomm,mpi_integer,mpi_max, npe,gsi_mpi_comm_world,mpi_rtype,mype,mpi_info_null
    use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
    use netcdf, only: nf90_nowrite,nf90_mpiio,nf90_inquire,nf90_inquire_dimension
    use netcdf, only: nf90_var_par_access,nf90_netcdf4
    use netcdf, only: nf90_inquire_variable
    use netcdf, only: nf90_inq_varid
    use mod_fv3_lola, only: fv3_h_to_ll,fv3_h_to_ll_ens
    use general_sub2grid_mod, only: sub2grid_info,general_grid2sub

    implicit none
    type(sub2grid_info),        intent(in):: grd_uv 
    real(r_kind)   ,            intent(out  ) :: ges_u(grd_uv%lat2,grd_uv%lon2,grd_uv%nsig) 
    real(r_kind)   ,            intent(out  ) :: ges_v(grd_uv%lat2,grd_uv%lon2,grd_uv%nsig) 
    type (type_fv3regfilenameg),intent (in) :: fv3filenamegin
    logical,                    intent(in ) :: ensgrid

    real(r_kind),dimension(2,grd_uv%nlat,grd_uv%nlon,grd_uv%kbegin_loc:grd_uv%kend_alloc):: hwork
    character(len=:),allocatable :: filenamein
    real(r_kind),allocatable,dimension(:,:):: us2d,vw2d
    real(r_kind),allocatable,dimension(:,:):: uorv2d
    real(r_kind),allocatable,dimension(:,:,:,:):: worksub
    character(len=max_filename_length) :: filenamein2 
    character(len=max_varname_length) :: varname
    integer(i_kind) nlatcase,nloncase
    integer(i_kind) kbgn,kend

    integer(i_kind) var_id
    integer(i_kind) gfile_loc,iret
    integer(i_kind) j,nzp1,mm1
    integer(i_kind) ilev,ilevtot,inative
    integer(i_kind) nxcase,nycase
    integer(i_kind) us_countloc(3),us_startloc(3)
    integer(i_kind) vw_countloc(3),vw_startloc(3)
    integer(i_kind):: iworld,iworld_group,nread,mpi_comm_read,i,ierror
    integer(i_kind),dimension(npe):: members,members_read,mype_read_rank
    logical:: procuse

    allocate (worksub(2,grd_uv%lat2,grd_uv%lon2,grd_uv%nsig))
    mm1=mype+1
    nloncase=grd_uv%nlon
    nlatcase=grd_uv%nlat
    if (ensgrid) then
     nxcase=nxens
     nycase=nyens
    else
     nxcase=nx
     nycase=ny
    end if
    kbgn=grd_uv%kbegin_loc
    kend=grd_uv%kend_loc
    allocate (us2d(nxcase,nycase+1),vw2d(nxcase+1,nycase))
    allocate (uorv2d(nxcase,nycase))
    procuse = .false.
    members=-1
    members_read=-1
    if (kbgn<=kend) then
       procuse = .true.
       members(mm1) = mype
    endif

    call mpi_allreduce(members,members_read,npe,mpi_integer,mpi_max,gsi_mpi_comm_world,ierror)

    nread=0
    mype_read_rank=-1
    do i=1,npe
       if (members_read(i) >= 0) then
          nread=nread+1
          mype_read_rank(nread) = members_read(i)
       endif
    enddo

    call setcomm(iworld,iworld_group,nread,mype_read_rank,mpi_comm_read,ierror)

    if (procuse) then
    
    filenamein=fv3filenamegin%dynvars
    iret=nf90_open(filenamein,ior(nf90_netcdf4,ior(nf90_nowrite,nf90_mpiio)),gfile_loc,comm=mpi_comm_read,info=MPI_INFO_NULL) !clt
    if(iret/=nf90_noerr) then
       write(6,*)' gsi_fv3ncdf_read_v1: problem opening ',trim(filenamein),gfile_loc,', Status = ',iret
       call stop2(333)
    endif
    
    do ilevtot=kbgn,kend
      varname=grd_uv%names(1,ilevtot)
      filenamein2=fv3filenamegin%dynvars
      if(trim(filenamein) /=  trim(filenamein2)) then
        write(6,*)'filenamein and filenamein2 are not the same as expected, stop'
        call stop2(333)
      endif
      ilev=grd_uv%lnames(1,ilevtot)
      nz=grd_uv%nsig
      nzp1=nz+1
      inative=nzp1-ilev
      if (ensgrid) then
       us_countloc= (/nlon_regionalens,nlat_regionalens+1,1/)
       vw_countloc= (/nlon_regionalens+1,nlat_regionalens,1/)
      else
       us_countloc= (/nlon_regional,nlat_regional+1,1/)
       vw_countloc= (/nlon_regional+1,nlat_regional,1/)
      end if
      us_startloc=(/1,1,inative+1/)
      vw_startloc=(/1,1,inative+1/)


! transfor to earth u/v, interpolate to analysis grid, reverse vertical order
      call check(nf90_inq_varid(gfile_loc,trim(adjustl("u_s")),var_id))
           
      call check(nf90_get_var(gfile_loc,var_id,us2d,start=us_startloc,count=us_countloc))
      iret=nf90_inq_varid(gfile_loc,trim(adjustl("v_w")),var_id)
      iret=nf90_get_var(gfile_loc,var_id,vw2d,start=vw_startloc,count=vw_countloc)
      do j=1,ny
        uorv2d(:,j)=half*(us2d(:,j)+us2d(:,j+1))
      enddo
          
      if (ensgrid) then
        call fv3_h_to_ll_ens(uorv2d(:,:),hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,.true.)
      else
        call fv3_h_to_ll(uorv2d(:,:),hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,grid_reverse_flag)
      end if
      do j=1,nx
        uorv2d(j,:)=half*(vw2d(j,:)+vw2d(j+1,:))
      enddo
      if (ensgrid) then
        call fv3_h_to_ll_ens(uorv2d(:,:),hwork(2,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,.true.)
      else
        call fv3_h_to_ll(uorv2d(:,:),hwork(2,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,grid_reverse_flag)
      end if
          
    enddo ! iilevtoto
    iret=nf90_close(gfile_loc)
    endif !procuse
    call general_grid2sub(grd_uv,hwork,worksub) 
    ges_u=worksub(1,:,:,:)
    ges_v=worksub(2,:,:,:)
    deallocate (us2d,vw2d,worksub)

end subroutine gsi_fv3ncdf_readuv_v1

subroutine gsi_fv3ncdf_read_ens_parallel_over_ens(filenamein,fv3filenamegin, &
           delp,tsen,w,q,oz,ql,qr,qs,qi,qg,dbz,fed,iope)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    gsi_fv3ncdf_read_ens_parallel_over_ens    
! program history log:
!     2022-04-01 Y. Wang and X. Wang, changed from gsi_fv3ncdf_read_ens 
!                                     for FV3LAM ensemble parallel IO in hybrid EnVar
!                                     poc: xuguang.wang@ou.edu    
!
! abstract: read in fields excluding u and v
! program history log:
!
!   input argument list:
!     filenamein    - file name to read from       
!     iope     - pe to read in the field
!
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$  end documentation block


    use m_kinds, only: r_kind,i_kind
    use m_mpimod, only: gsi_mpi_comm_world,mpi_rtype,mype
    use m_mpimod, only:  MPI_INFO_NULL
    use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
    use netcdf, only: nf90_nowrite,nf90_mpiio,nf90_inquire,nf90_inquire_dimension
    use netcdf, only: nf90_inquire_variable
    use netcdf, only: nf90_inq_varid
    use gridmod, only: nsig,nlon,nlat
    use mod_fv3_lola, only: fv3_h_to_ll
    use gsi_bundlemod, only: gsi_bundle
    use general_sub2grid_mod, only: sub2grid_info,general_grid2sub

    implicit none
    character(*),                          intent(in) :: filenamein
    type (type_fv3regfilenameg),           intent(in) ::fv3filenamegin
    integer(i_kind)   ,                    intent(in) :: iope
    real(r_kind),dimension(nlat,nlon,nsig),intent(out),optional:: delp,tsen,w,q,oz,ql,qr,qs,qi,qg,dbz,fed
    real(r_kind),allocatable,dimension(:,:):: uu2d, uu2d_tmp
    real(r_kind),dimension(nlat,nlon,nsig):: hwork
    character(len=max_varname_length) :: varname
    character(len=max_varname_length) :: name
    character(len=max_filename_length), allocatable,dimension(:) :: varname_files

    integer(i_kind) nlatcase,nloncase,nxcase,nycase,countloc(4),startloc(4),countloc_tmp(4),startloc_tmp(4)
    integer(i_kind) ilev,ilevtot,inative,ivar
    integer(i_kind) kbgn,kend
    integer(i_kind) gfile_loc,iret,var_id
    integer(i_kind) nz,nzp1,mm1,len,nx_phy
    logical  :: phy_smaller_domain
! for io_layout > 1
    real(r_kind),allocatable,dimension(:,:):: uu2d_layout
    integer(i_kind) :: nio
    integer(i_kind),allocatable :: gfile_loc_layout(:)
    character(len=180)  :: filename_layout

    mm1=mype+1
    nloncase=nlon
    nlatcase=nlat
    nxcase=nx
    nycase=ny
    kbgn=1
    kend=nsig

    if( mype == iope )then
       allocate(uu2d(nxcase,nycase))
       if( present(delp).or.present(tsen).or.present(w) )then  ! dynvars
          if( present(w) )then
             allocate(varname_files(3))
             varname_files = (/'T   ','delp','W   '/)
          else
             allocate(varname_files(2))
             varname_files = (/'T   ','delp'/)
          end if
       end if
       if( present(q).or.present(ql).or.present(qr) )then ! tracers
          if(present(qr))then
             allocate(varname_files(7))
             varname_files = (/'sphum  ','o3mr   ','liq_wat','ice_wat','rainwat','snowwat','graupel'/)
          else
             allocate(varname_files(2))
             varname_files = (/'sphum',' o3mr'/)
          end if
       end if
       if( present(dbz) .and. present(fed) )then  ! phyvars: dbz, fed
          allocate(varname_files(2))
          varname_files = (/'ref_f3d             ','flash_extent_density'/)
       elseif( present(dbz) )then            ! phyvars: dbz
          allocate(varname_files(1))
          varname_files = (/'ref_f3d'/)
       elseif( present(fed) )then            ! phyvars: fed 
          allocate(varname_files(1))
          varname_files = (/'flash_extent_density'/)
       end if


       if(fv3_io_layout_y > 1) then
          allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
          do nio=0,fv3_io_layout_y-1
             write(filename_layout,'(a,a,I4.4)') trim(filenamein),'.',nio
             iret=nf90_open(filename_layout,nf90_nowrite,gfile_loc_layout(nio),comm=gsi_mpi_comm_world,info=MPI_INFO_NULL)
             if(iret/=nf90_noerr) then
                write(6,*)' gsi_fv3ncdf_read: problem opening ',trim(filename_layout),gfile_loc_layout(nio),', Status = ',iret
                call stop2(333)
             endif
          enddo
       else
          iret=nf90_open(filenamein,ior(nf90_nowrite,nf90_mpiio),gfile_loc)
          if(iret/=nf90_noerr) then
             write(6,*)' gsi_fv3ncdf_read: problem opening ',trim(filenamein),gfile_loc,', Status = ',iret
             call stop2(333)
          endif
       endif
       do ivar = 1, size(varname_files)
          do ilevtot=kbgn,kend
             ilev=ilevtot
             nz=nsig
             nzp1=nz+1
             inative=nzp1-ilev
             startloc=(/1,1,inative,1/)
             countloc=(/nxcase,nycase,1,1/)
             varname = trim(varname_files(ivar))
             ! Variable ref_f3d in phy_data.nc has a smaller domain size than
             ! dynvariables and tracers as well as a reversed order in vertical
             if ( trim(adjustl(varname)) == 'ref_f3d' .or. trim(adjustl(varname)) == 'flash_extent_density' )then
                iret=nf90_inquire_dimension(gfile_loc,1,name,len)
                if(trim(name)=='xaxis_1') nx_phy=len
                if( nx_phy == nxcase )then
                   allocate(uu2d_tmp(nxcase,nycase))
                   countloc_tmp=(/nxcase,nycase,1,1/)
                   phy_smaller_domain = .false.
                else
                   allocate(uu2d_tmp(nxcase-6,nycase-6))
                   countloc_tmp=(/nxcase-6,nycase-6,1,1/)
                   phy_smaller_domain = .true.
                end if
                startloc_tmp=(/1,1,ilev,1/)
             end if

             if(fv3_io_layout_y > 1) then
                do nio=0,fv3_io_layout_y-1
                  countloc=(/nxcase,ny_layout_len(nio),1,1/)
                  allocate(uu2d_layout(nxcase,ny_layout_len(nio)))
                  iret=nf90_inq_varid(gfile_loc_layout(nio),trim(adjustl(varname)),var_id)
                  iret=nf90_get_var(gfile_loc_layout(nio),var_id,uu2d_layout,start=startloc,count=countloc)
                  uu2d(:,ny_layout_b(nio):ny_layout_e(nio))=uu2d_layout
                  deallocate(uu2d_layout)
                enddo
             else
                iret=nf90_inq_varid(gfile_loc,trim(adjustl(varname)),var_id)
                if ( trim(adjustl(varname)) == 'ref_f3d' .or. trim(adjustl(varname)) == 'flash_extent_density' )then
                   uu2d = 0.0_r_kind
                   iret=nf90_get_var(gfile_loc,var_id,uu2d_tmp,start=startloc_tmp,count=countloc_tmp)
                   where(uu2d_tmp < 0.0_r_kind)
                      uu2d_tmp = 0.0_r_kind
                   endwhere
                   if(phy_smaller_domain)then
                      uu2d(4:nxcase-3,4:nycase-3) = uu2d_tmp
                   else
                      uu2d = uu2d_tmp
                   end if
                   deallocate(uu2d_tmp)
                else
                   iret=nf90_get_var(gfile_loc,var_id,uu2d,start=startloc,count=countloc)
                end if
             endif
             call fv3_h_to_ll(uu2d,hwork(:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,grid_reverse_flag)
          enddo  ! ilevtot
          if( present(delp).or.present(tsen).or.present(w) )then  ! dynvars
              if(ivar == 1)then
                 tsen = hwork
              else if(ivar == 2)then
                 delp = hwork
              end if
              if( present(w) .and. ivar == 3 )then
                 w = hwork
              end if
          end if
          if( present(q).or.present(ql).or.present(qr) )then ! tracers
            if(ivar == 1)then
               q = hwork
            else if(ivar == 2)then
               oz = hwork
            end if
            if(present(qr))then
              if(ivar == 3)then
                 ql = hwork
              else if(ivar == 4)then
                 qi = hwork
              else if(ivar == 5)then
                 qr = hwork
              else if(ivar == 6)then
                 qs = hwork
              else if(ivar == 7)then
                 qg = hwork
              end if
            end if
          end if
          if( present(dbz) .and. present(fed) )then ! phyvars: dbz,fed
            if(ivar == 1) dbz = hwork
            if(ivar == 2) fed = hwork
          elseif( present(dbz) )then            ! phyvars: dbz
            dbz = hwork
          elseif( present(fed) )then            ! phyvars: fed 
            fed = hwork
          end if

       end do

       if(fv3_io_layout_y > 1) then
          do nio=1,fv3_io_layout_y-1
            iret=nf90_close(gfile_loc_layout(nio))
          enddo
          deallocate(gfile_loc_layout)
        else
          iret=nf90_close(gfile_loc)
       endif

       deallocate (uu2d,varname_files)
    end if

    return
end subroutine gsi_fv3ncdf_read_ens_parallel_over_ens

subroutine gsi_fv3ncdf_readuv_ens_parallel_over_ens(ges_u,ges_v,fv3filenamegin,iope)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    gsi_fv3ncdf_readuv_ens_parallel_over_ens    
! program history log:
!     2022-04-01 Y. Wang and X. Wang, changed from gsi_fv3ncdf_readuv_ens 
!                                     for FV3LAM ensemble parallel IO in hybrid EnVar
!                                     poc: xuguang.wang@ou.edu 
!
! abstract: read in a field from a netcdf FV3 file in mype_u,mype_v
!           then scatter the field to each PE 
! program history log:
!
!   input argument list:
!
!   output argument list:
!     ges_u       - output sub domain u field
!     ges_v       - output sub domain v field
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$  end documentation block
    use m_kinds, only: r_kind,i_kind
    use m_mpimod, only: gsi_mpi_comm_world,mpi_rtype,mype,mpi_info_null
    use gridmod, only: nsig,nlon,nlat
    use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
    use netcdf, only: nf90_nowrite,nf90_inquire,nf90_inquire_dimension
    use netcdf, only: nf90_inquire_variable
    use netcdf, only: nf90_inq_varid
    use mod_fv3_lola, only: fv3_h_to_ll,fv3uv2earth
    use general_sub2grid_mod, only: sub2grid_info,general_grid2sub

    implicit none
    real(r_kind)   ,intent(out  ) :: ges_u(nlat,nlon,nsig)
    real(r_kind)   ,intent(out  ) :: ges_v(nlat,nlon,nsig)
    type (type_fv3regfilenameg),intent (in) :: fv3filenamegin
    integer(i_kind),intent(in)    :: iope

    real(r_kind),dimension(2,nlat,nlon,nsig):: hwork
    character(:), allocatable:: filenamein
    real(r_kind),allocatable,dimension(:,:):: u2d,v2d
    real(r_kind),allocatable,dimension(:,:):: uc2d,vc2d
    integer(i_kind) u_grd_VarId,v_grd_VarId
    integer(i_kind) nlatcase,nloncase
    integer(i_kind) nxcase,nycase
    integer(i_kind) u_countloc(4),u_startloc(4),v_countloc(4),v_startloc(4)
    integer(i_kind) inative,ilev,ilevtot
    integer(i_kind) kbgn,kend

    integer(i_kind) gfile_loc,iret
    integer(i_kind) nz,nzp1,mm1

! for fv3_io_layout_y > 1
    real(r_kind),allocatable,dimension(:,:):: u2d_layout,v2d_layout
    integer(i_kind) :: nio
    integer(i_kind),allocatable :: gfile_loc_layout(:)
    character(len=180)  :: filename_layout

    mm1=mype+1
    nloncase=nlon
    nlatcase=nlat
    nxcase=nx
    nycase=ny
    kbgn=1
    kend=nsig
    if( mype == iope )then
       allocate(u2d(nxcase,nycase+1))
       allocate(v2d(nxcase+1,nycase))
       allocate(uc2d(nxcase,nycase))
       allocate(vc2d(nxcase,nycase))
       filenamein=fv3filenamegin%dynvars

       if(fv3_io_layout_y > 1) then
         allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
         do nio=0,fv3_io_layout_y-1
            write(filename_layout,'(a,a,I4.4)') trim(filenamein),".",nio
            iret=nf90_open(filename_layout,nf90_nowrite,gfile_loc_layout(nio),comm=gsi_mpi_comm_world,info=MPI_INFO_NULL)
            if(iret/=nf90_noerr) then
               write(6,*)'problem opening ',trim(filename_layout),gfile_loc_layout(nio),', Status = ',iret
               call stop2(333)
            endif
         enddo
       else
          iret=nf90_open(filenamein,nf90_nowrite,gfile_loc)
          if(iret/=nf90_noerr) then
             write(6,*)' problem opening ',trim(filenamein),', Status = ',iret
             call stop2(333)
          endif
       endif
       do ilevtot=kbgn,kend
          ilev=ilevtot
          nz=nsig
          nzp1=nz+1
          inative=nzp1-ilev
          u_countloc=(/nxcase,nycase+1,1,1/)
          v_countloc=(/nxcase+1,nycase,1,1/)
          u_startloc=(/1,1,inative,1/)
          v_startloc=(/1,1,inative,1/)

          if(fv3_io_layout_y > 1) then
             do nio=0,fv3_io_layout_y-1
                u_countloc=(/nxcase,ny_layout_len(nio)+1,1,1/)
                allocate(u2d_layout(nxcase,ny_layout_len(nio)+1))
                call check( nf90_inq_varid(gfile_loc_layout(nio),'u',u_grd_VarId) )
                iret=nf90_get_var(gfile_loc_layout(nio),u_grd_VarId,u2d_layout,start=u_startloc,count=u_countloc)
                u2d(:,ny_layout_b(nio):ny_layout_e(nio))=u2d_layout(:,1:ny_layout_len(nio))
                if(nio==fv3_io_layout_y-1) u2d(:,ny_layout_e(nio)+1)=u2d_layout(:,ny_layout_len(nio)+1)
                deallocate(u2d_layout)

                v_countloc=(/nxcase+1,ny_layout_len(nio),1,1/)
                allocate(v2d_layout(nxcase+1,ny_layout_len(nio)))
                call check( nf90_inq_varid(gfile_loc_layout(nio),'v',v_grd_VarId) )
                iret=nf90_get_var(gfile_loc_layout(nio),v_grd_VarId,v2d_layout,start=v_startloc,count=v_countloc)
                v2d(:,ny_layout_b(nio):ny_layout_e(nio))=v2d_layout
                deallocate(v2d_layout)
             enddo
          else
             call check( nf90_inq_varid(gfile_loc,'u',u_grd_VarId) )
             iret=nf90_get_var(gfile_loc,u_grd_VarId,u2d,start=u_startloc,count=u_countloc)
             call check( nf90_inq_varid(gfile_loc,'v',v_grd_VarId) )
             iret=nf90_get_var(gfile_loc,v_grd_VarId,v2d,start=v_startloc,count=v_countloc)
          endif

          if(.not.grid_reverse_flag) then
             call reverse_grid_r_uv (u2d,nxcase,nycase+1,1)
             call reverse_grid_r_uv (v2d,nxcase+1,nycase,1)
          endif
          call fv3uv2earth(u2d(:,:),v2d(:,:),nxcase,nycase,uc2d,vc2d)

     !    NOTE on transfor to earth u/v:
     !       The u and v before transferring need to be in E-W/N-S grid, which is
     !       defined as reversed grid here because it is revered from map view.
     !
     !       Have set the following flag for grid orientation
     !         grid_reverse_flag=true:  E-W/N-S grid
     !         grid_reverse_flag=false: W-E/S-N grid 
     !
     !       So for preparing the wind transferring, need to reverse the grid
     !       from
     !       W-E/S-N grid to E-W/N-S grid when grid_reverse_flag=false:
     !
     !            if(.not.grid_reverse_flag) call reverse_grid_r_uv
     !
     !       and the last input parameter for fv3_h_to_ll is alway true:
     !
     !
          call fv3_h_to_ll(uc2d,hwork(1,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,.true.)
          call fv3_h_to_ll(vc2d,hwork(2,:,:,ilevtot),nxcase,nycase,nloncase,nlatcase,.true.)
       enddo ! ilevtot
       if(fv3_io_layout_y > 1) then
          do nio=0,fv3_io_layout_y-1
             iret=nf90_close(gfile_loc_layout(nio))
          enddo
          deallocate(gfile_loc_layout)
       else
          iret=nf90_close(gfile_loc)
       endif
       deallocate(u2d,v2d,uc2d,vc2d)
       ges_u = hwork(1,:,:,:)
       ges_v = hwork(2,:,:,:)
    end if ! mype

end subroutine gsi_fv3ncdf_readuv_ens_parallel_over_ens


subroutine gsi_fv3ncdf_writeuv(grd_uv,ges_u,ges_v,add_saved,fv3filenamegin)
!$$$  subprogram documentation block
!                .      .    .                                        .
! subprogram:    gsi_nemsio_writeuv
!   pgrmmr: wu
!
! abstract: gather u/v fields to mype_io, put u/v in FV3 model defined directions & orders
!           then write out
!
! program history log:
!
!   input argument list:
!    varu,varv
!    add_saved - true: add analysis increments to readin guess then write out
!              - false: write out total analysis fields
!    mype_io
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block

    use m_mpimod, only:  mpi_rtype,gsi_mpi_comm_world,mype,mpi_info_null,npe,setcomm,mpi_integer,mpi_max
    use netcdf, only: nf90_nowrite,nf90_inquire,nf90_inquire_dimension
    use gridmod, only: nlon_regional,nlat_regional
    use mod_fv3_lola, only: fv3_ll_to_h,fv3_h_to_ll, &
                            fv3uv2earth,earthuv2fv3
    use netcdf, only: nf90_open,nf90_close,nf90_noerr
    use netcdf, only: nf90_write,nf90_mpiio,nf90_inq_varid,nf90_var_par_access,nf90_collective
    use netcdf, only: nf90_put_var,nf90_get_var
    use general_sub2grid_mod, only: sub2grid_info,general_sub2grid

    implicit none
    type(sub2grid_info), intent(in):: grd_uv 

    logical,                    intent(in   ) :: add_saved
    type (type_fv3regfilenameg),intent(in) ::fv3filenamegin
    real(r_kind),dimension(grd_uv%lat2,grd_uv%lon2,grd_uv%nsig),intent(inout)::ges_u
    real(r_kind),dimension(grd_uv%lat2,grd_uv%lon2,grd_uv%nsig),intent(inout)::ges_v

    real(r_kind),dimension(2,grd_uv%nlat,grd_uv%nlon,grd_uv%kbegin_loc:grd_uv%kend_alloc):: hwork
    integer(i_kind) :: ugrd_VarId,gfile_loc,vgrd_VarId
    integer(i_kind) i,j,mm1,k,nzp1
    integer(i_kind) kbgn,kend
    integer(i_kind) inative,ilev,ilevtot
    integer(i_kind) nlatcase,nloncase
    integer(i_kind) nxcase,nycase
    integer(i_kind) u_countloc(4),u_startloc(4),v_countloc(4),v_startloc(4)
    character(:),allocatable:: filenamein ,varname
    real(r_kind),allocatable,dimension(:,:,:,:):: worksub
    real(r_kind),allocatable,dimension(:,:):: work_au,work_av
    real(r_kind),allocatable,dimension(:,:,:):: work_bu,work_bv
    real(r_kind),allocatable,dimension(:,:):: u2d,v2d,workau2,workav2
    real(r_kind),allocatable,dimension(:,:):: workbu2,workbv2

    integer(i_kind):: iworld,iworld_group,nread,mpi_comm_read,ierror
    integer(i_kind),dimension(npe):: members,members_read,mype_read_rank
    logical:: procuse

! for fv3_io_layout_y > 1
    real(r_kind),allocatable,dimension(:,:,:):: u2d_layout,v2d_layout
    integer(i_kind) :: nio
    integer(i_kind),allocatable :: gfile_loc_layout(:)
    character(len=180)  :: filename_layout
    integer(i_kind):: kend_native,kbgn_native
    integer(i_kind):: istat

    mm1=mype+1
    
    nloncase=grd_uv%nlon
    nlatcase=grd_uv%nlat
    nxcase=nx
    nycase=ny
    kbgn=grd_uv%kbegin_loc
    kend=grd_uv%kend_loc
    allocate( u2d(nlon_regional,nlat_regional+1))
    allocate( v2d(nlon_regional+1,nlat_regional))
    allocate (worksub(2,grd_uv%lat2,grd_uv%lon2,grd_uv%nsig))
    allocate( work_au(nlatcase,nloncase),work_av(nlatcase,nloncase))
    do k=1,grd_uv%nsig
       do j=1,grd_uv%lon2
          do i=1,grd_uv%lat2
             worksub(1,i,j,k)=ges_u(i,j,k)
             worksub(2,i,j,k)=ges_v(i,j,k)
          end do
       end do
    end do
    call general_sub2grid(grd_uv,worksub,hwork)
    filenamein=fv3filenamegin%dynvars


    procuse = .false.
    members=-1
    members_read=-1
    if (kbgn<=kend) then
       procuse = .true.
       members(mm1) = mype
    endif

    call mpi_allreduce(members,members_read,npe,mpi_integer,mpi_max,gsi_mpi_comm_world,ierror)

    nread=0
    mype_read_rank=-1
    do i=1,npe
       if (members_read(i) >= 0) then
          nread=nread+1
          mype_read_rank(nread) = members_read(i)
       endif
    enddo

    call setcomm(iworld,iworld_group,nread,mype_read_rank,mpi_comm_read,ierror)

    if (procuse) then
       if(fv3_io_layout_y > 1) then
          allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
          do nio=0,fv3_io_layout_y-1
             write(filename_layout,'(a,a,I4.4)') trim(filenamein),".",nio
             call check( nf90_open(filename_layout,ior(nf90_write, nf90_mpiio),gfile_loc_layout(nio),comm=mpi_comm_read,info=MPI_INFO_NULL) )
          enddo
          gfile_loc=gfile_loc_layout(0)
       else
          call check( nf90_open(filenamein,ior(nf90_write, nf90_mpiio),gfile_loc,comm=mpi_comm_read,info=MPI_INFO_NULL) )
       endif
       nz=grd_uv%nsig
       nzp1=nz+1
       kend_native=nzp1-grd_uv%lnames(1,kbgn)
       kbgn_native=nzp1-grd_uv%lnames(1,kend)
       allocate( work_bu(nlon_regional,nlat_regional+1,kbgn_native:kend_native))
       allocate( work_bv(nlon_regional+1,nlat_regional,kbgn_native:kend_native))
       u_startloc=(/1,1,kbgn_native,1/)
       u_countloc=(/nxcase,nycase+1,kend_native-kbgn_native+1,1/)
       v_startloc=(/1,1,kbgn_native,1/)
       v_countloc=(/nxcase+1,nycase,kend_native-kbgn_native+1,1/)
       if(fv3_io_layout_y > 1) then
          do nio=0,fv3_io_layout_y-1
             allocate(u2d_layout(nxcase,ny_layout_len(nio)+1,kend_native-kbgn_native+1))
             u_countloc=(/nxcase,ny_layout_len(nio)+1,kend_native-kbgn_native+1,1/)
             call check( nf90_get_var(gfile_loc_layout(nio),ugrd_VarId,u2d_layout,start=u_startloc,count=u_countloc) )
             work_bu(:,ny_layout_b(nio):ny_layout_e(nio),:)=u2d_layout(:,1:ny_layout_len(nio),:)
             if(nio==fv3_io_layout_y-1) work_bu(:,ny_layout_e(nio)+1,:)=u2d_layout(:,ny_layout_len(nio)+1,:)
             deallocate(u2d_layout)
             
             allocate(v2d_layout(nxcase+1,ny_layout_len(nio),kend_native-kbgn_native+1))
             v_countloc=(/nxcase+1,ny_layout_len(nio),kend_native-kbgn_native+1,1/)
             call check( nf90_get_var(gfile_loc_layout(nio),vgrd_VarId,v2d_layout,start=v_startloc,count=v_countloc) )
             work_bv(:,ny_layout_b(nio):ny_layout_e(nio),:)=v2d_layout
             deallocate(v2d_layout)
          enddo
       else
          call check( nf90_inq_varid(gfile_loc,'u',ugrd_VarId) )
          call check( nf90_inq_varid(gfile_loc,'v',vgrd_VarId) )
          call check( nf90_var_par_access(gfile_loc, ugrd_VarId, nf90_collective))
          call check( nf90_var_par_access(gfile_loc, vgrd_VarId, nf90_collective))
          call check( nf90_get_var(gfile_loc,ugrd_VarId,work_bu,start=u_startloc,count=u_countloc) )
          call check( nf90_get_var(gfile_loc,vgrd_VarId,work_bv,start=v_startloc,count=v_countloc) )
       endif


       
       do ilevtot=kbgn,kend
          varname=grd_uv%names(1,ilevtot)
          ilev=grd_uv%lnames(1,ilevtot)
          inative=nzp1-ilev
          
          work_au=hwork(1,:,:,ilevtot)
          work_av=hwork(2,:,:,ilevtot)
          
          
          if(add_saved)then
             allocate( workau2(nlatcase,nloncase),workav2(nlatcase,nloncase))
             allocate( workbu2(nlon_regional,nlat_regional+1))
             allocate( workbv2(nlon_regional+1,nlat_regional))
!!!!!!!!  readin work_b !!!!!!!!!!!!!!!!
 
!clt for fv3_io_layout<=1  now the nf90_get_var has been moved outside of this do loop 
!to avoid failure on hercules when L_MPI_EXTRA_FILESYSTEM=1 
             if(.not.grid_reverse_flag) then
                call reverse_grid_r_uv(work_bu(:,:,inative),nlon_regional,nlat_regional+1,1)
                call reverse_grid_r_uv(work_bv(:,:,inative),nlon_regional+1,nlat_regional,1)
             endif
             call fv3uv2earth(work_bu(:,:,inative),work_bv(:,:,inative),nlon_regional,nlat_regional,u2d,v2d)
             call fv3_h_to_ll(u2d,workau2,nlon_regional,nlat_regional,nloncase,nlatcase,.true.)
             call fv3_h_to_ll(v2d,workav2,nlon_regional,nlat_regional,nloncase,nlatcase,.true.)
!!!!!!!! find analysis_inc:  work_a !!!!!!!!!!!!!!!!
             work_au(:,:)=work_au(:,:)-workau2(:,:)
             work_av(:,:)=work_av(:,:)-workav2(:,:)
             call fv3_ll_to_h(work_au(:,:),u2d,nloncase,nlatcase,nlon_regional,nlat_regional,.true.)
             call fv3_ll_to_h(work_av(:,:),v2d,nloncase,nlatcase,nlon_regional,nlat_regional,.true.)
             call earthuv2fv3(u2d,v2d,nlon_regional,nlat_regional,workbu2,workbv2)
!!!!!!!!  add analysis_inc to readin work_b !!!!!!!!!!!!!!!!
             work_bu(:,:,inative)=work_bu(:,:,inative)+workbu2(:,:)
             work_bv(:,:,inative)=work_bv(:,:,inative)+workbv2(:,:)
             deallocate(workau2,workbu2,workav2,workbv2)
          else
             call fv3_ll_to_h(work_au(:,:),u2d,nloncase,nlatcase,nlon_regional,nlat_regional,.true.)
             call fv3_ll_to_h(work_av(:,:),v2d,nloncase,nlatcase,nlon_regional,nlat_regional,.true.)
             call earthuv2fv3(u2d,v2d,nlon_regional,nlat_regional,work_bu(:,:,inative),work_bv(:,:,inative))
          endif
          if(.not.grid_reverse_flag) then
             call reverse_grid_r_uv(work_bu(:,:,inative),nlon_regional,nlat_regional+1,1)
             call reverse_grid_r_uv(work_bv(:,:,inative),nlon_regional+1,nlat_regional,1)
          endif
       enddo !ilevltot
          
       if(fv3_io_layout_y > 1) then
             do nio=0,fv3_io_layout_y-1
                allocate(u2d_layout(nxcase,ny_layout_len(nio)+1,kend_native-kbgn_native+1))
                u_countloc=(/nxcase,ny_layout_len(nio)+1,kend_native-kbgn_native+1,1/)
                u2d_layout=work_bu(:,ny_layout_b(nio):ny_layout_e(nio)+1,:)
                call check( nf90_put_var(gfile_loc_layout(nio),ugrd_VarId,u2d_layout,start=u_startloc,count=u_countloc) )
                deallocate(u2d_layout)
                
                allocate(v2d_layout(nxcase+1,ny_layout_len(nio),kend_native-kbgn_native+1))
                v_countloc=(/nxcase+1,ny_layout_len(nio),kend_native-kbgn_native+1,1/)
                v2d_layout=work_bv(:,ny_layout_b(nio):ny_layout_e(nio),:)
                call check( nf90_put_var(gfile_loc_layout(nio),vgrd_VarId,v2d_layout,start=v_startloc,count=v_countloc) )
                deallocate(v2d_layout)
             enddo
       else
             call check( nf90_put_var(gfile_loc,ugrd_VarId,work_bu,start=u_startloc,count=u_countloc) )
             call check( nf90_put_var(gfile_loc,vgrd_VarId,work_bv,start=v_startloc,count=v_countloc) )
       endif

       if(fv3_io_layout_y > 1) then
          do nio=0,fv3_io_layout_y-1
             call check( nf90_close(gfile_loc_layout(nio)) )
          enddo
          deallocate(gfile_loc_layout)
       else
          call check( nf90_close(gfile_loc) )
       endif
     deallocate(work_bu,work_bv)
    endif

    call mpi_barrier(gsi_mpi_comm_world,ierror)
 
    deallocate(u2d,v2d)
    deallocate(work_au,work_av)

end subroutine gsi_fv3ncdf_writeuv
subroutine gsi_fv3ncdf_writeuv_v1(grd_uv,ges_u,ges_v,add_saved,fv3filenamegin)
!$$$  subprogram documentation block
!                .      .    .                                        .
! subprogram:    gsi_nemsio_writeuv
!   pgrmmr: wu
!
! abstract: gather u/v fields to mype_io, put u/v in FV3 model defined directions & orders
!           then write out
!
! program history log:
! 2019-04-22  lei   modified from gsi_nemsio_writeuv_v1 for update
! u_w,v_w,u_s,v_s in the cold start files!
! 2020-03-06  lei   added ilev0 fix
!   input argument list:
!    varu,varv
!    add_saved - true: add analysis increments to readin guess then write out
!              - false: write out total analysis fields
!    mype_io
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block

    use constants, only: half,zero
    use m_mpimod, only:  npe, setcomm,mpi_integer,mpi_max,mpi_rtype,gsi_mpi_comm_world,mype,mpi_info_null
    use gridmod, only: nlon_regional,nlat_regional
    use mod_fv3_lola, only: fv3_ll_to_h,fv3_h_to_ll, &
                            fv3uv2earth,earthuv2fv3
    use netcdf, only: nf90_open,nf90_close,nf90_noerr
    use netcdf, only: nf90_write, nf90_mpiio,nf90_inq_varid,nf90_var_par_access,nf90_collective
    use netcdf, only: nf90_put_var,nf90_get_var
    use general_sub2grid_mod, only: sub2grid_info,general_sub2grid
    implicit none
    type(sub2grid_info),        intent(in) :: grd_uv 
    real(r_kind),dimension(grd_uv%lat2,grd_uv%lon2,grd_uv%nsig),intent(inout)::ges_u
    real(r_kind),dimension(grd_uv%lat2,grd_uv%lon2,grd_uv%nsig),intent(inout)::ges_v
    logical,                    intent(in) :: add_saved
    type (type_fv3regfilenameg),intent(in) :: fv3filenamegin

    real(r_kind),dimension(2,grd_uv%nlat,grd_uv%nlon,grd_uv%kbegin_loc:grd_uv%kend_alloc):: hwork
    character(len=:),allocatable :: filenamein
    character(len=max_varname_length) :: varname

    integer(i_kind) :: gfile_loc
    integer(i_kind) :: u_wgrd_VarId,v_wgrd_VarId
    integer(i_kind) :: u_sgrd_VarId,v_sgrd_VarId
    integer(i_kind) i,j,mm1,k,nzp1
    integer(i_kind) kbgn,kend
    integer(i_kind) inative,ilev,ilevtot
    real(r_kind),allocatable,dimension(:,:,:,:):: worksub
    real(r_kind),allocatable,dimension(:,:):: work_au,work_av
    real(r_kind),allocatable,dimension(:,:,:):: work_bu_s,work_bv_s
    real(r_kind),allocatable,dimension(:,:,:):: work_bu_w,work_bv_w
    real(r_kind),allocatable,dimension(:,:):: u2d,v2d,workau2,workav2
    real(r_kind),allocatable,dimension(:,:):: workbu_s2,workbv_s2
    real(r_kind),allocatable,dimension(:,:):: workbu_w2,workbv_w2
    integer(i_kind) nlatcase,nloncase,nxcase,nycase
    integer(i_kind) uw_countloc(4),us_countloc(4),uw_startloc(4),us_startloc(4)
    integer(i_kind) vw_countloc(4),vs_countloc(4),vw_startloc(4),vs_startloc(4)
    integer(i_kind):: kend_native,kbgn_native,kdim_native


    integer(i_kind):: iworld,iworld_group,nread,mpi_comm_read,ierror
    integer(i_kind),dimension(npe):: members,members_read,mype_read_rank
    logical:: procuse

    mm1=mype+1
    nloncase=grd_uv%nlon
    nlatcase=grd_uv%nlat
    nxcase=nx
    nycase=ny
    kbgn=grd_uv%kbegin_loc
    kend=grd_uv%kend_loc
    allocate (worksub(2,grd_uv%lat2,grd_uv%lon2,grd_uv%nsig))
    do k=1,grd_uv%nsig
       do j=1,grd_uv%lon2
          do i=1,grd_uv%lat2
             worksub(1,i,j,k)=ges_u(i,j,k)
             worksub(2,i,j,k)=ges_v(i,j,k)
          end do
       end do
    end do
    call general_sub2grid(grd_uv,worksub,hwork)

    allocate( u2d(nlon_regional,nlat_regional)) 
    allocate( v2d(nlon_regional,nlat_regional))
    allocate( work_au(nlatcase,nloncase),work_av(nlatcase,nloncase))

    if(add_saved) allocate( workau2(nlatcase,nloncase),workav2(nlatcase,nloncase))
    allocate( workbu_w2(nlon_regional+1,nlat_regional))
    allocate( workbv_w2(nlon_regional+1,nlat_regional))
    allocate( workbu_s2(nlon_regional,nlat_regional+1))
    allocate( workbv_s2(nlon_regional,nlat_regional+1))
    filenamein=fv3filenamegin%dynvars


    procuse = .false.
    members=-1
    members_read=-1
    if (kbgn<=kend) then
       procuse = .true.
       members(mm1) = mype
    endif

    call mpi_allreduce(members,members_read,npe,mpi_integer,mpi_max,gsi_mpi_comm_world,ierror)

    nread=0
    mype_read_rank=-1
    do i=1,npe
       if (members_read(i) >= 0) then
          nread=nread+1
          mype_read_rank(nread) = members_read(i)
       endif
    enddo

    call setcomm(iworld,iworld_group,nread,mype_read_rank,mpi_comm_read,ierror)

    if (procuse) then





    call check( nf90_open(filenamein,ior(nf90_write, nf90_mpiio),gfile_loc,comm=mpi_comm_read,info=MPI_INFO_NULL) )

    call check( nf90_inq_varid(gfile_loc,'u_s',u_sgrd_VarId) )
    call check( nf90_var_par_access(gfile_loc, u_sgrd_VarId, nf90_collective))
    call check( nf90_inq_varid(gfile_loc,'u_w',u_wgrd_VarId) )
    call check( nf90_var_par_access(gfile_loc, u_wgrd_VarId, nf90_collective))
    call check( nf90_inq_varid(gfile_loc,'v_s',v_sgrd_VarId) )
    call check( nf90_var_par_access(gfile_loc, v_sgrd_VarId, nf90_collective))
    call check( nf90_inq_varid(gfile_loc,'v_w',v_wgrd_VarId) )
    call check( nf90_var_par_access(gfile_loc, v_wgrd_VarId, nf90_collective))
    nz=grd_uv%nsig
    nzp1=nz+1
    kend_native=nzp1-grd_uv%lnames(1,kbgn)
    kbgn_native=nzp1-grd_uv%lnames(1,kend)
    kdim_native=kend_native-kbgn_native+1

    uw_countloc= (/nlon_regional+1,nlat_regional,kdim_native,1/)
    us_countloc= (/nlon_regional,nlat_regional+1,kdim_native,1/)
    vw_countloc= (/nlon_regional+1,nlat_regional,kdim_native,1/)
    vs_countloc= (/nlon_regional,nlat_regional+1,kdim_native,1/)
      
    uw_startloc=(/1,1,kbgn_native+1,1/)  !In the coldstart files, there is an extra top level 
    us_startloc=(/1,1,kbgn_native+1,1/)
    vw_startloc=(/1,1,kbgn_native+1,1/)
    vs_startloc=(/1,1,kbgn_native+1,1/)
    allocate( work_bu_s(nlon_regional,nlat_regional+1,kbgn_native:kend_native))
    allocate( work_bv_s(nlon_regional,nlat_regional+1,kbgn_native:kend_native))
    allocate( work_bu_w(nlon_regional+1,nlat_regional,kbgn_native:kend_native))
    allocate( work_bv_w(nlon_regional+1,nlat_regional,kbgn_native:kend_native))

!!!!!!!!  readin work_b !!!!!!!!!!!!!!!!
    call check( nf90_get_var(gfile_loc,u_sgrd_VarId,work_bu_s,start=us_startloc,count=us_countloc) )
    call check( nf90_get_var(gfile_loc,u_wgrd_VarId,work_bu_w,start=uw_startloc,count=uw_countloc) )
    call check( nf90_get_var(gfile_loc,v_sgrd_VarId,work_bv_s,start=vs_startloc,count=vs_countloc) )
    call check( nf90_get_var(gfile_loc,v_wgrd_VarId,work_bv_w,start=vw_startloc,count=vw_countloc) )
    do ilevtot=kbgn,kend
      varname=grd_uv%names(1,ilevtot)
      ilev=grd_uv%lnames(1,ilevtot)
      inative=nzp1-ilev

      work_au=hwork(1,:,:,ilevtot)
      work_av=hwork(2,:,:,ilevtot)





      if(add_saved)then
        do j=1,nlat_regional
          u2d(:,j)=half * (work_bu_s(:,j,inative)+ work_bu_s(:,j+1,inative))
        enddo
        do i=1,nlon_regional
          v2d(i,:)=half*(work_bv_w(i,:,inative)+work_bv_w(i+1,:,inative))
        enddo
        call fv3_h_to_ll(u2d,workau2,nlon_regional,nlat_regional,nloncase,nlatcase,grid_reverse_flag)
        call fv3_h_to_ll(v2d,workav2,nlon_regional,nlat_regional,nloncase,nlatcase,grid_reverse_flag)
!!!!!!!! find analysis_inc:  work_a !!!!!!!!!!!!!!!!
        work_au(:,:)=work_au(:,:)-workau2(:,:)
        work_av(:,:)=work_av(:,:)-workav2(:,:)
        call fv3_ll_to_h(work_au(:,:),u2d,nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)
        call fv3_ll_to_h(work_av(:,:),v2d,nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)
!!!!!!!!  add analysis_inc to readin work_b !!!!!!!!!!!!!!!!
        do i=2,nlon_regional
          workbu_w2(i,:)=half*(u2d(i-1,:)+u2d(i,:))
          workbv_w2(i,:)=half*(v2d(i-1,:)+v2d(i,:))
        enddo
        workbu_w2(1,:)=u2d(1,:)
        workbv_w2(1,:)=v2d(1,:)
        workbu_w2(nlon_regional+1,:)=u2d(nlon_regional,:)
        workbv_w2(nlon_regional+1,:)=v2d(nlon_regional,:)

        do j=2,nlat_regional
          workbu_s2(:,j)=half*(u2d(:,j-1)+u2d(:,j))
          workbv_s2(:,j)=half*(v2d(:,j-1)+v2d(:,j))
        enddo
        workbu_s2(:,1)=u2d(:,1)
        workbv_s2(:,1)=v2d(:,1)
        workbu_s2(:,nlat_regional+1)=u2d(:,nlat_regional)
        workbv_s2(:,nlat_regional+1)=v2d(:,nlat_regional)



        work_bu_w(:,:,inative)=work_bu_w(:,:,inative)+workbu_w2(:,:)
        work_bu_s(:,:,inative)=work_bu_s(:,:,inative)+workbu_s2(:,:)
        work_bv_w(:,:,inative)=work_bv_w(:,:,inative)+workbv_w2(:,:)
        work_bv_s(:,:,inative)=work_bv_s(:,:,inative)+workbv_s2(:,:)
      else
        call fv3_ll_to_h(work_au(:,:),u2d,nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)
        call fv3_ll_to_h(work_av(:,:),v2d,nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)

        do i=2,nlon_regional
          work_bu_w(i,:,inative)=half*(u2d(i-1,:)+u2d(i,:))
          work_bv_w(i,:,inative)=half*(v2d(i-1,:)+v2d(i,:))
        enddo
        work_bu_w(1,:,inative)=u2d(1,:)
        work_bv_w(1,:,inative)=v2d(1,:)
        work_bu_w(nlon_regional+1,:,inative)=u2d(nlon_regional,:)
        work_bv_w(nlon_regional+1,:,inative)=v2d(nlon_regional,:)

        do j=2,nlat_regional
          work_bu_s(:,j,inative)=half*(u2d(:,j-1)+u2d(:,j))
          work_bv_s(:,j,inative)=half*(v2d(:,j-1)+v2d(:,j))
        enddo
        work_bu_s(:,1,inative)=u2d(:,1)
        work_bv_s(:,1,inative)=v2d(:,1)
        work_bu_s(:,nlat_regional+1,inative)=u2d(:,nlat_regional)
        work_bv_s(:,nlat_regional+1,inative)=v2d(:,nlat_regional)


      endif
    enddo !

    call check( nf90_put_var(gfile_loc,u_wgrd_VarId,work_bu_w,start=uw_startloc,count=uw_countloc) )
    call check( nf90_put_var(gfile_loc,u_sgrd_VarId,work_bu_s,start=us_startloc,count=us_countloc) )
    call check( nf90_put_var(gfile_loc,v_wgrd_VarId,work_bv_w,start=vw_startloc,count=vw_countloc) )
    call check( nf90_put_var(gfile_loc,v_sgrd_VarId,work_bv_s,start=vs_startloc,count=vs_countloc) )
      
    call check( nf90_close(gfile_loc) )
    deallocate(work_bu_w,work_bv_w)
    deallocate(work_bu_s,work_bv_s)
    endif !procuse

    deallocate(work_au,work_av,u2d,v2d)
    if(add_saved) deallocate(workau2,workav2)
    if (allocated(workbu_w2)) then
      deallocate(workbu_w2,workbv_w2)
      deallocate(workbu_s2,workbv_s2)
    endif

    if(allocated(worksub))deallocate(worksub)

end subroutine gsi_fv3ncdf_writeuv_v1

subroutine gsi_fv3ncdf_write_sfc(fv3filenamegin,varname,var,add_saved)
!$$$  subprogram documentation block
!                .      .    .                                        .
! subprogram:    gsi_fv3ncdf_write_sfc
!   pgrmmr: wu
!
! abstract:
!
! program history log:
! 2022-02-25  Hu  write surface fields  
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block

    use m_mpimod, only: ierror,gsi_mpi_comm_world,mpi_rtype,mype
    use gridmod, only: lat1,lon1,lat2,lon2,nlat,nlon
    use gridmod, only: ijn,displs_g,itotsub,iglobal
    use gridmod,  only: nlon_regional,nlat_regional
    use mod_fv3_lola, only: fv3_ll_to_h,fv3_h_to_ll
    use general_commvars_mod, only: ltosi,ltosj
    use netcdf, only: nf90_open,nf90_close
    use netcdf, only: nf90_write,nf90_inq_varid
    use netcdf, only: nf90_put_var,nf90_get_var
    use gridmod, only: strip
    implicit none

    real(r_kind)   ,intent(in   ) :: var(lat2,lon2)
    logical        ,intent(in   ) :: add_saved
    character(*)   ,intent(in   ) :: varname
    type (type_fv3regfilenameg),intent (in) :: fv3filenamegin

    integer(i_kind) :: VarId,gfile_loc
    integer(i_kind) i,mm1
    real(r_kind),allocatable,dimension(:):: work
    real(r_kind),allocatable,dimension(:,:):: work_sub,work_a
    real(r_kind),allocatable,dimension(:,:):: work_b
    real(r_kind),allocatable,dimension(:,:):: workb2,worka2
    character(len=80)   :: filename

! for io_layout > 1
    real(r_kind),allocatable,dimension(:,:):: work_b_layout
    integer(i_kind) :: nio
    integer(i_kind),allocatable :: gfile_loc_layout(:)
    character(len=180)  :: filename_layout

    filename=trim(fv3filenamegin%sfcdata)

    mm1=mype+1
    allocate(work(max(iglobal,itotsub)),work_sub(lat1,lon1))
    call strip(var,work_sub)
    call mpi_gatherv(work_sub,ijn(mm1),mpi_rtype, &
          work,ijn,displs_g,mpi_rtype,0,gsi_mpi_comm_world,ierror)
    deallocate(work_sub)

    if(mype==0) then
       allocate( work_a(nlat,nlon))
       do i=1,iglobal
          work_a(ltosi(i),ltosj(i))=work(i)
       end do
       allocate( work_b(nlon_regional,nlat_regional))


       if(fv3_io_layout_y > 1) then
         allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
         do nio=0,fv3_io_layout_y-1
            write(filename_layout,'(a,a,I4.4)') trim(filename),'.',nio
            call check(nf90_open(trim(filename_layout),nf90_write,gfile_loc_layout(nio)) )
         enddo
         gfile_loc=gfile_loc_layout(0)
       else
         call check( nf90_open(trim(filename),nf90_write,gfile_loc) )
       endif
       call check( nf90_inq_varid(gfile_loc,trim(varname),VarId) )

       if(add_saved)then
          allocate( workb2(nlon_regional,nlat_regional))
          allocate( worka2(nlat,nlon))
!!!!!!!! read in guess !!!!!!!!!!!!!!

          if(fv3_io_layout_y > 1) then
             do nio=0,fv3_io_layout_y-1
                allocate(work_b_layout(nlon_regional,ny_layout_len(nio)))
                call check(nf90_get_var(gfile_loc_layout(nio),VarId,work_b_layout) )
                work_b(:,ny_layout_b(nio):ny_layout_e(nio))=work_b_layout
                deallocate(work_b_layout)
              enddo
          else
             call check( nf90_get_var(gfile_loc,VarId,work_b) )
          endif
          call fv3_h_to_ll(work_b,worka2,nlon_regional,nlat_regional,nlon,nlat,grid_reverse_flag)
!!!!!!! analysis_inc work_a
          work_a(:,:)=work_a(:,:)-worka2(:,:)
          call fv3_ll_to_h(work_a,workb2,nlon,nlat,nlon_regional,nlat_regional,grid_reverse_flag)
             work_b(:,:)=work_b(:,:)+workb2(:,:)
          deallocate(worka2,workb2)
       else
          call fv3_ll_to_h(work_a,work_b,nlon,nlat,nlon_regional,nlat_regional,grid_reverse_flag)
       endif

       if(fv3_io_layout_y > 1) then
         do nio=0,fv3_io_layout_y-1
            allocate(work_b_layout(nlon_regional,ny_layout_len(nio)))
            work_b_layout=work_b(:,ny_layout_b(nio):ny_layout_e(nio))
            call check( nf90_put_var(gfile_loc_layout(nio),VarId,work_b_layout) )
            deallocate(work_b_layout)
         enddo
       else
          call check( nf90_put_var(gfile_loc,VarId,work_b) )
       endif

       if(fv3_io_layout_y > 1) then
         do nio=0,fv3_io_layout_y-1
           call check(nf90_close(gfile_loc_layout(nio)))
         enddo
         deallocate(gfile_loc_layout)
       else
         call check(nf90_close(gfile_loc))
       endif
       deallocate(work_b,work_a)
    end if !mype_io

    deallocate(work)

end subroutine gsi_fv3ncdf_write_sfc

subroutine gsi_fv3ncdf_write(grd_ionouv,cstate_nouv,add_saved,filenamein,fv3filenamegin)
!$$$  subprogram documentation block
!                .      .    .                                        .
! subprogram:    gsi_nemsio_write
!   pgrmmr: wu
!
! abstract:
!
! program history log:
!
!   input argument list:
!    varu,varv
!    add_saved
!    mype     - mpi task id
!    mype_io
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block

    use m_mpimod, only: mpi_rtype,gsi_mpi_comm_world,mype,mpi_info_null,npe,setcomm,mpi_integer,mpi_max
    use mod_fv3_lola, only: fv3_ll_to_h
    use mod_fv3_lola, only: fv3_h_to_ll
    use netcdf, only: nf90_open,nf90_close
    use netcdf, only: nf90_write,nf90_netcdf4, nf90_mpiio,nf90_inq_varid
    use netcdf, only: nf90_put_var,nf90_get_var,nf90_independent,nf90_var_par_access
    use netcdf, only: nf90_inquire_dimension
    use gsi_bundlemod, only: gsi_bundle
    use general_sub2grid_mod, only: sub2grid_info,general_sub2grid
    implicit none

    type(sub2grid_info),           intent(in)   :: grd_ionouv 
    type(gsi_bundle),              intent(inout):: cstate_nouv
    logical,                       intent(in   ):: add_saved
    character(len=:), allocatable, intent(in)   :: filenamein
    type (type_fv3regfilenameg),   intent(in)   :: fv3filenamegin

    real(r_kind),dimension(1,grd_ionouv%nlat,grd_ionouv%nlon,grd_ionouv%kbegin_loc:grd_ionouv%kend_alloc):: hwork
    character(len=max_filename_length) :: filenamein2 
    character(len=max_varname_length) :: varname,vgsiname,name

    integer(i_kind) nlatcase,nloncase,nxcase,nycase,countloc(4),startloc(4)
    integer(i_kind) countloc_tmp(4),startloc_tmp(4)
    integer(i_kind) kbgn,kend
    integer(i_kind) inative,ilev,ilevtot
    integer(i_kind) :: VarId,gfile_loc
    integer(i_kind) mm1,nzp1,len,nx_phy,iret
    logical  :: phy_smaller_domain
    real(r_kind),allocatable,dimension(:,:):: work_a
    real(r_kind),allocatable,dimension(:,:):: work_b
    real(r_kind),allocatable,dimension(:,:):: workb2,worka2
    real(r_kind),allocatable,dimension(:,:):: work_b_tmp

    integer(i_kind):: iworld,iworld_group,nread,mpi_comm_read,i,ierror
    integer(i_kind),dimension(npe):: members,members_read,mype_read_rank
    logical:: procuse
    
! for io_layout > 1
    real(r_kind),allocatable,dimension(:,:):: work_b_layout
    integer(i_kind) :: nio
    integer(i_kind),allocatable :: gfile_loc_layout(:)
    character(len=180)  :: filename_layout

    mm1=mype+1
    ! Convert from subdomain to full horizontal field distributed among
    ! processors
    call general_sub2grid(grd_ionouv,cstate_nouv%values,hwork)
    nloncase=grd_ionouv%nlon
    nlatcase=grd_ionouv%nlat
    nxcase=nx
    nycase=ny
    kbgn=grd_ionouv%kbegin_loc
    kend=grd_ionouv%kend_loc
    allocate( work_a(nlatcase,nloncase))
    allocate( work_b(nlon_regional,nlat_regional))
    allocate( workb2(nlon_regional,nlat_regional))
    allocate( worka2(nlatcase,nloncase))

    procuse = .false.
    members=-1
    members_read=-1
    if (kbgn<=kend) then
       procuse = .true.
       members(mm1) = mype
    endif

    call mpi_allreduce(members,members_read,npe,mpi_integer,mpi_max,gsi_mpi_comm_world,ierror)

    nread=0
    mype_read_rank=-1
    do i=1,npe
       if (members_read(i) >= 0) then
          nread=nread+1
          mype_read_rank(nread) = members_read(i)
       endif
    enddo

    call setcomm(iworld,iworld_group,nread,mype_read_rank,mpi_comm_read,ierror)

    if (procuse) then
       if(fv3_io_layout_y > 1) then
          allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
          do nio=0,fv3_io_layout_y-1
             write(filename_layout,'(a,a,I4.4)') trim(filenamein),'.',nio
             call check( nf90_open(filename_layout,ior(nf90_netcdf4,ior(nf90_write, nf90_mpiio)),gfile_loc_layout(nio),comm=mpi_comm_read,info=MPI_INFO_NULL) )
          enddo
          gfile_loc=gfile_loc_layout(0)
       else
          call check( nf90_open(filenamein,ior(nf90_netcdf4,ior(nf90_write, nf90_mpiio)),gfile_loc,comm=mpi_comm_read,info=MPI_INFO_NULL) )
       endif
       
       do ilevtot=kbgn,kend
          vgsiname=grd_ionouv%names(1,ilevtot)
          if(trim(vgsiname)=='amassi') cycle
          if(trim(vgsiname)=='amassj') cycle
          if(trim(vgsiname)=='amassk') cycle
          if(trim(vgsiname)=='pm2_5') cycle 
          call getfv3lamfilevname(vgsiname,fv3filenamegin,filenamein2,varname)
          if(trim(filenamein) /= trim(filenamein2)) then
             write(6,*)'filenamein and filenamein2 are not the same as expected, stop'
             call stop2(333)
          endif
          ilev=grd_ionouv%lnames(1,ilevtot)
          nz=grd_ionouv%nsig
          nzp1=nz+1
          inative=nzp1-ilev
          countloc=(/nxcase,nycase,1,1/)
          startloc=(/1,1,inative,1/)
          
          work_a=hwork(1,:,:,ilevtot)
          
          if( trim(varname) == 'ref_f3d' .or. trim(adjustl(varname)) == 'flash_extent_density' )then
             iret=nf90_inquire_dimension(gfile_loc,1,name,len)
             if(trim(name)=='xaxis_1') nx_phy=len
             if( nx_phy == nxcase )then
                allocate(work_b_tmp(nxcase,nycase))
                countloc_tmp=(/nxcase,nycase,1,1/)
                phy_smaller_domain = .false.
             else
                allocate(work_b_tmp(nxcase-6,nycase-6))
                countloc_tmp=(/nxcase-6,nycase-6,1,1/)
                phy_smaller_domain = .true.
             end if
             startloc_tmp=(/1,1,ilev,1/)
          end if
          
          call check( nf90_inq_varid(gfile_loc,trim(varname),VarId) )
          call check( nf90_var_par_access(gfile_loc, VarId, nf90_independent))
          
          
          if(index(vgsiname,"delzinc") > 0) then
             if(fv3_io_layout_y > 1) then
                do nio=0,fv3_io_layout_y-1
                   countloc=(/nxcase,ny_layout_len(nio),1,1/)
                   allocate(work_b_layout(nxcase,ny_layout_len(nio)))
                   call check( nf90_get_var(gfile_loc_layout(nio),VarId,work_b_layout,start = startloc, count = countloc) )
                   work_b(:,ny_layout_b(nio):ny_layout_e(nio))=work_b_layout
                   deallocate(work_b_layout)
                enddo
             else
                call check( nf90_get_var(gfile_loc,VarId,work_b,start = startloc, count = countloc) )
             endif
             call fv3_ll_to_h(work_a(:,:),workb2,nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)
             work_b(:,:)=work_b(:,:)+workb2(:,:)
          else
             if(add_saved)then
                if(fv3_io_layout_y > 1) then
                   do nio=0,fv3_io_layout_y-1
                      countloc=(/nxcase,ny_layout_len(nio),1,1/)
                      allocate(work_b_layout(nxcase,ny_layout_len(nio)))
                      call check( nf90_get_var(gfile_loc_layout(nio),VarId,work_b_layout,start = startloc, count = countloc) )
                      work_b(:,ny_layout_b(nio):ny_layout_e(nio))=work_b_layout
                      deallocate(work_b_layout)
                   enddo
                else
                   if( trim(varname) == 'ref_f3d' .or. trim(varname) == 'flash_extent_density' )then
                      work_b = 0.0_r_kind
                      call check( nf90_get_var(gfile_loc,VarId,work_b_tmp,start = startloc_tmp, count = countloc_tmp) )
                      where(work_b_tmp < 0.0_r_kind)
                         work_b_tmp = 0.0_r_kind
                      end where
                      if(phy_smaller_domain)then
                         work_b(4:nxcase-3,4:nycase-3) = work_b_tmp
                      else
                         work_b(1:nxcase,1:nycase) = work_b_tmp
                      end if
                   else
                      call check( nf90_get_var(gfile_loc,VarId,work_b,start = startloc, count = countloc) )
                   end if
                endif
                call fv3_h_to_ll(work_b(:,:),worka2,nlon_regional,nlat_regional,nloncase,nlatcase,grid_reverse_flag)
!!!!!!!! analysis_inc:  work_a !!!!!!!!!!!!!!!!
                work_a(:,:)=work_a(:,:)-worka2(:,:)
                call fv3_ll_to_h(work_a(:,:),workb2,nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)
                work_b(:,:)=work_b(:,:)+workb2(:,:)
             else  
                call fv3_ll_to_h(work_a(:,:),work_b(:,:),nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)
             endif
          endif
          if (ifindstrloc(vnames_nonnegativetracers,trim(varname))> 0) then
              where (work_b <0.0_r_kind)  work_b=0.0_r_kind
          endif
          if(fv3_io_layout_y > 1) then
             do nio=0,fv3_io_layout_y-1
                countloc=(/nxcase,ny_layout_len(nio),1,1/)
                allocate(work_b_layout(nxcase,ny_layout_len(nio)))
                work_b_layout=work_b(:,ny_layout_b(nio):ny_layout_e(nio))
                call check( nf90_put_var(gfile_loc_layout(nio),VarId,work_b_layout, start = startloc, count = countloc) )
                deallocate(work_b_layout)
             enddo
          else
             if( trim(varname) == 'ref_f3d' .or. trim(varname) == 'flash_extent_density' )then
                if(phy_smaller_domain)then
                   work_b_tmp = work_b(4:nxcase-3,4:nycase-3)
                else
                   work_b_tmp = work_b(1:nxcase,1:nycase)
                end if
                where(work_b_tmp < 0.0_r_kind)
                   work_b_tmp = 0.0_r_kind
                end where
                call check( nf90_put_var(gfile_loc,VarId,work_b_tmp, start = startloc_tmp, count = countloc_tmp) )
                deallocate(work_b_tmp)
             else
                call check( nf90_put_var(gfile_loc,VarId,work_b, start = startloc, count = countloc) )
             end if
          endif
          
       enddo !ilevtotl loop
       if(fv3_io_layout_y > 1) then
          do nio=0,fv3_io_layout_y-1
             call check(nf90_close(gfile_loc_layout(nio)))
          enddo
          deallocate(gfile_loc_layout)
       else
          call check(nf90_close(gfile_loc))
       endif
    endif

    call mpi_barrier(gsi_mpi_comm_world,ierror)

    deallocate(work_b,work_a)
    deallocate(workb2,worka2)

end subroutine gsi_fv3ncdf_write
subroutine check(status)
    use m_kinds, only: i_kind
    use netcdf, only: nf90_noerr,nf90_strerror
    integer(i_kind), intent ( in) :: status

    if(status /= nf90_noerr) then
       print *,'ncdf error ', trim(nf90_strerror(status))
       stop  
    end if
end subroutine check
subroutine gsi_fv3ncdf_write_v1(grd_ionouv,cstate_nouv,add_saved,filenamein,fv3filenamegin)
!$$$  subprogram documentation block
!                .      .    .                                        .
! subprogram:    gsi_nemsio_write
!   pgrmmr: wu
!
! abstract:
!
! program history log:
! 2020-03-05  lei  modified from gsi_fv3ncdf_write to gsi_fv3ncdf_write_v1  
!   input argument list:
!    varu,varv
!    add_saved
!    mype     - mpi task id
!    mype_io
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block

    use m_mpimod, only: npe, setcomm,mpi_integer,mpi_max,mpi_rtype,gsi_mpi_comm_world,mype,mpi_info_null
    use mod_fv3_lola, only: fv3_ll_to_h
    use mod_fv3_lola, only: fv3_h_to_ll
    use netcdf, only: nf90_open,nf90_close
    use netcdf, only: nf90_write, nf90_netcdf4,nf90_mpiio,nf90_inq_varid
    use netcdf, only: nf90_put_var,nf90_get_var
    use netcdf, only: nf90_independent,nf90_var_par_access
    use gsi_bundlemod, only: gsi_bundle
    use general_sub2grid_mod, only: sub2grid_info,general_sub2grid
    implicit none

    type(sub2grid_info),        intent(in)   :: grd_ionouv 
    type(gsi_bundle),           intent(inout):: cstate_nouv
    logical,                    intent(in   ):: add_saved
    character(*),               intent(in)   :: filenamein
    type (type_fv3regfilenameg),intent(in)   :: fv3filenamegin

    real(r_kind),dimension(1,grd_ionouv%nlat,grd_ionouv%nlon,grd_ionouv%kbegin_loc:grd_ionouv%kend_alloc):: hwork
    character(len=max_filename_length) :: filenamein2 

    integer(i_kind) kbgn,kend
    integer(i_kind) inative,ilev,ilevtot
    integer(i_kind) :: VarId,gfile_loc
    integer(i_kind) mm1,nzp1
    real(r_kind),allocatable,dimension(:,:):: work_a
    real(r_kind),allocatable,dimension(:,:):: work_b
    real(r_kind),allocatable,dimension(:,:):: workb2,worka2
    character(len=max_varname_length) :: varname,vgsiname
    integer(i_kind) nlatcase,nloncase,nxcase,nycase,countloc(3),startloc(3)

    integer(i_kind):: iworld,iworld_group,nread,mpi_comm_read,i,ierror
    integer(i_kind),dimension(npe):: members,members_read,mype_read_rank
    logical:: procuse


    mm1=mype+1
    nloncase=grd_ionouv%nlon
    nlatcase=grd_ionouv%nlat

    call general_sub2grid(grd_ionouv,cstate_nouv%values,hwork)
    nxcase=nx
    nycase=ny
    kbgn=grd_ionouv%kbegin_loc
    kend=grd_ionouv%kend_loc
    allocate( work_a(nlatcase,nloncase))
    allocate( work_b(nlon_regional,nlat_regional))
    allocate( workb2(nlon_regional,nlat_regional))
    allocate( worka2(nlatcase,nloncase))

    procuse = .false.
    members=-1
    members_read=-1
    if (kbgn<=kend) then
       procuse = .true.
       members(mm1) = mype
    endif

    call mpi_allreduce(members,members_read,npe,mpi_integer,mpi_max,gsi_mpi_comm_world,ierror)

    nread=0
    mype_read_rank=-1
    do i=1,npe
       if (members_read(i) >= 0) then
          nread=nread+1
          mype_read_rank(nread) = members_read(i)
       endif
    enddo

    call setcomm(iworld,iworld_group,nread,mype_read_rank,mpi_comm_read,ierror)

    if (procuse) then
    call check ( nf90_open(filenamein,ior(nf90_netcdf4,ior(nf90_write, nf90_mpiio)),gfile_loc,comm=mpi_comm_read,info=MPI_INFO_NULL)) !clt
    do ilevtot=kbgn,kend
      vgsiname=grd_ionouv%names(1,ilevtot)
      if(trim(vgsiname)=='amassi') cycle
      if(trim(vgsiname)=='amassj') cycle
      if(trim(vgsiname)=='amassk') cycle
      if(trim(vgsiname)=='pm2_5') cycle 
      call getfv3lamfilevname(vgsiname,fv3filenamegin,filenamein2,varname)
      if(trim(filenamein) /= trim(filenamein2)) then
        write(6,*)'filenamein and filenamein2 are not the same as expected, stop'
        call stop2(333)
      endif
      ilev=grd_ionouv%lnames(1,ilevtot)
      nz=grd_ionouv%nsig
      nzp1=nz+1
      inative=nzp1-ilev
      startloc=(/1,1,inative+1/)
      countloc=(/nxcase,nycase,1/)

      work_a=hwork(1,:,:,ilevtot)


      call check( nf90_inq_varid(gfile_loc,trim(varname),VarId) )
      call check( nf90_var_par_access(gfile_loc, VarId, nf90_independent))
      call check( nf90_get_var(gfile_loc,VarId,work_b,start=startloc,count=countloc) )
      if(index(vgsiname,"delzinc") > 0) then
        write(6,*)'delz is not in the cold start fiels with this option, incompatible setup , stop'
        call stop2(333)
      endif

      if(add_saved)then
! for being now only lev between (including )  2 and nsig+1 of work_b (:,:,lev) 
! are updated
        call fv3_h_to_ll(work_b(:,:),worka2,nlon_regional,nlat_regional,nloncase,nlatcase,grid_reverse_flag)
!!!!!!!! analysis_inc:  work_a !!!!!!!!!!!!!!!!
        work_a(:,:)=work_a(:,:)-worka2(:,:)
        call fv3_ll_to_h(work_a(:,:),workb2,nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)
        work_b(:,:)=work_b(:,:)+workb2(:,:)
      else
        call fv3_ll_to_h(work_a(:,:),work_b(:,:),nloncase,nlatcase,nlon_regional,nlat_regional,grid_reverse_flag)
      endif
      if (ifindstrloc(vnames_nonnegativetracers,trim(varname))> 0) then
           where (work_b <0.0_r_kind)  work_b=0.0_r_kind
      endif
      call check( nf90_put_var(gfile_loc,VarId,work_b,start=startloc,count=countloc) )
    enddo  !ilevtot
    call check(nf90_close(gfile_loc))
    endif
    deallocate(work_b,work_a)
    deallocate(worka2,workb2)

end subroutine gsi_fv3ncdf_write_v1

subroutine reverse_grid_r(grid,nx,ny,nz)
!
!  reverse the first two dimension of the array grid
!
    use m_kinds, only: r_kind,i_kind

    implicit none
    integer(i_kind),  intent(in     ) :: nx,ny,nz
    real(r_kind),     intent(inout  ) :: grid(nx,ny,nz)

    real(r_kind)                      :: tmp_grid(nx,ny)
    integer(i_kind)                   :: i,j,k
!
    do k=1,nz
       tmp_grid(:,:)=grid(:,:,k)
       do j=1,ny
          do i=1,nx
             grid(i,j,k)=tmp_grid(nx+1-i,ny+1-j)
          enddo        
       enddo
    enddo

end subroutine reverse_grid_r

subroutine reverse_grid_r_uv(grid,nx,ny,nz)
!
!  reverse the first two dimension of the array grid
!
    use m_kinds, only: r_kind,i_kind

    implicit none
    integer(i_kind), intent(in     ) :: nx,ny,nz
    real(r_kind),    intent(inout  ) :: grid(nx,ny,nz)

    real(r_kind)                     :: tmp_grid(nx,ny)
    integer(i_kind)                  :: i,j,k
!
    do k=1,nz
       tmp_grid(:,:)=grid(:,:,k)
       do j=1,ny
          do i=1,nx
             grid(i,j,k)=-tmp_grid(nx+1-i,ny+1-j)
          enddo
       enddo
    enddo

end subroutine reverse_grid_r_uv

subroutine convert_qx_to_cvpqx(qr_arr,qs_arr,qg_arr,use_cvpqx,cvpqx_pvalue)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    convert_qx_to_cvpqx
!   prgmmr: J. Park(CAPS)                     date: 2021-05-05
!
! abstract: convert qx(mixing ratio) to cvpqx using power transform for qr, qs, qg
!
! program history log:
!   2021-05-05 - initial commit 
!              - this is used when GSI reads qx data from a background file
!                (subroutine read_fv3_netcdf_guess)
!              - since minimum qr, qs, and qg are set for CVlogq,
!                it reads three qx arrays and then processes.
!
!   input argument list:
!     qr_arr         - array of qr 
!     qs_arr         - array of qs 
!     qg_arr         - array of qg 
!     use_cvpqx      - flag to use power transform or not
!     cvpqx_pvalue - value to be used for power transform
!
!   output argument list:
!     qr_arr           - updated array of qr after power transform
!     qs_arr           - updated array of qs after
!     qg_arr           - updated array of qg after power transfrom
!
! attributes:
!   language: f90
!
    use m_kinds, only: r_kind,i_kind
    use gridmod, only: lat2,lon2,nsig
    use guess_grids, only: ges_tsen
    use m_mpimod, only: mype
    use guess_grids, only: ntguessig
    use constants, only: zero, one_tenth

    implicit none
    real(r_kind), intent(inout  ) :: qr_arr(lat2,lon2,nsig)
    real(r_kind), intent(inout  ) :: qs_arr(lat2,lon2,nsig)
    real(r_kind), intent(inout  ) :: qg_arr(lat2,lon2,nsig)
    logical,      intent(in     ) :: use_cvpqx
    real(r_kind), intent(in     ) :: cvpqx_pvalue

    integer(i_kind)                   :: i, j, k, it

    real(r_kind) :: qr_min, qs_min, qg_min
    real(r_kind) :: qr_thrshd, qs_thrshd, qg_thrshd
!
    it=ntguessig
!

!   print info message: CVq, CVlogq, and CVpq
    if(mype==0)then
       if (use_cvpqx) then
          if ( cvpqx_pvalue == 0._r_kind ) then        ! CVlogq
              write(6,*)'read_fv3_netcdf_guess: ',     &
                        ' reset zero of qr/qs/qg to specified values (~0dbz)', &
                        'before log transformation. (for dbz assimilation)' 
              write(6,*)'read_fv3_netcdf_guess: convert qr/qs/qg to log transform.'
          else if ( cvpqx_pvalue > 0._r_kind ) then   ! CVpq
              write(6,*)'read_fv3_netcdf_guess: convert qr/qs/qg with power transform .'
          end if
       else                                         ! CVq
          write(6,*)'read_fv3_netcdf_guess: only reset (qr/qs/qg) to &
                     0.0 for negative analysis value. (regular qx)'
       end if
    end if

    do k=1,nsig
      do i=1,lon2
        do j=1,lat2
!         Apply power transform if option is ON 
          if (use_cvpqx) then
             if ( cvpqx_pvalue == 0._r_Kind ) then ! CVlogq
                 if (ges_tsen(j,i,k,it) > 274.15_r_kind) then
                      qr_min=2.9E-6_r_kind
                      qr_thrshd=qr_min * one_tenth
                      qs_min=0.1E-9_r_kind
                      qs_thrshd=qs_min
                      qg_min=3.1E-7_r_kind
                      qg_thrshd=qg_min * one_tenth
                 else if (ges_tsen(j,i,k,it) <= 274.15_r_kind .and. &
                          ges_tsen(j,i,k,it) >= 272.15_r_kind) then
                      qr_min=2.0E-6_r_kind
                      qr_thrshd=qr_min * one_tenth
                      qs_min=1.3E-7_r_kind
                      qs_thrshd=qs_min * one_tenth
                      qg_min=3.1E-7_r_kind
                      qg_thrshd=qg_min * one_tenth
                 else if (ges_tsen(j,i,k,it) < 272.15_r_kind) then
                      qr_min=0.1E-9_r_kind
                      qr_thrshd=qr_min
                      qs_min=6.3E-6_r_kind
                      qs_thrshd=qs_min * one_tenth
                      qg_min=3.1E-7_r_kind
                      qg_thrshd=qg_min * one_tenth
                 end if

                 if ( qr_arr(j,i,k) <= qr_thrshd )  qr_arr(j,i,k) = qr_min
                 if ( qs_arr(j,i,k) <= qs_thrshd )  qs_arr(j,i,k) = qs_min
                 if ( qg_arr(j,i,k) <= qg_thrshd )  qg_arr(j,i,k) = qg_min

                 qr_arr(j,i,k) = log(qr_arr(j,i,k))
                 qs_arr(j,i,k) = log(qs_arr(j,i,k))
                 qg_arr(j,i,k) = log(qg_arr(j,i,k))

             else if ( cvpqx_pvalue > 0._r_kind ) then   ! CVpq
                 qr_arr(j,i,k)=((max(qr_arr(j,i,k),1.0E-6_r_kind))**cvpqx_pvalue-1)/cvpqx_pvalue
                 qs_arr(j,i,k)=((max(qs_arr(j,i,k),1.0E-6_r_kind))**cvpqx_pvalue-1)/cvpqx_pvalue
                 qg_arr(j,i,k)=((max(qg_arr(j,i,k),1.0E-6_r_kind))**cvpqx_pvalue-1)/cvpqx_pvalue
             end if
          else ! CVq
              qr_min=zero
              qs_min=zero
              qg_min=zero
              qr_arr(j,i,k) = max(qr_arr(j,i,k), qr_min)
              qs_arr(j,i,k) = max(qs_arr(j,i,k), qs_min)
              qg_arr(j,i,k) = max(qg_arr(j,i,k), qg_min)
          end if
        end do
      end do
    end do

end subroutine convert_qx_to_cvpqx

subroutine convert_nx_to_cvpnx(qnx_arr,cvpnr,cvpnr_pvalue)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    convert_nx_to_cvpnx
!   prgmmr: J. Park(CAPS)                     date: 2021-05-05
!
! abstract: convert nx (number concentration) to cvpnx using power transform
!
! program history log:
!   2021-05-05 - initial commit 
!              - this is used when GSI reads nx data from a background file
!                (subroutine read_fv3_netcdf_guess)
!              - this can be used for other nx variables
!
!   input argument list:
!     qnx_arr        - array of qnx
!     cvpnr          - flag to use power transform or not
!     cvpnr_pvalue   - value to be used for power transform
!
!   output argument list:
!     qnx_arr           - updated array of qnx after power transform
!
! attributes:
!   language: f90
!
    use m_kinds, only: r_kind,i_kind
    use gridmod, only: lat2,lon2,nsig
    use m_mpimod, only: mype
    use constants, only: zero, one_tenth

    implicit none
    real(r_kind), intent(inout  ) :: qnx_arr(lat2,lon2,nsig)
    logical,      intent(in     ) :: cvpnr
    real(r_kind), intent(in     ) :: cvpnr_pvalue

    integer(i_kind)                   :: i, j, k
!

!   print info message: CVpnr
    if (mype==0 .and. cvpnr)then
       write(6,*)'read_fv3_netcdf_guess: convert qnx with power transform .'
    end if

    do k=1,nsig
      do i=1,lon2
        do j=1,lat2

!          Treatment on qnx ; power transform
           if (cvpnr) then
              qnx_arr(j,i,k)=((max(qnx_arr(j,i,k),1.0E-2_r_kind)**cvpnr_pvalue)-1)/cvpnr_pvalue
           endif

        end do
      end do
    end do
end subroutine convert_nx_to_cvpnx

subroutine convert_cvpqx_to_qx(qr_arr,qs_arr,qg_arr,use_cvpqx,cvpqx_pvalue)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    convert_cvpqx_to_qx
!   prgmmr: J. Park(CAPS)                     date: 2021-05-05
!
! abstract: convert cvpqx to qx for qr, qs, qg
!
! program history log:
!   2021-05-05 - initial commit 
!              - this is used when GSI writes qx data to a background file
!                (subroutine wrfv3_netcdf)
!              - since minimum qr, qs, and qg are set for CVlogq,
!                it reads three qx arrays and then processes.
!
!   input argument list:
!     qr_arr         - array of qr 
!     qs_arr         - array of qs 
!     qg_arr         - array of qg 
!     use_cvpqx      - flag to use power transform or not
!     cvpqx_pvalue   - value to be used for power transform
!
!   output argument list:
!     qr_arr           - updated array of qr after power transform
!     qs_arr           - updated array of qs after
!     qg_arr           - updated array of qg after power transfrom
!
! attributes:
!   language: f90
!
    use m_kinds, only: r_kind,i_kind
    use gridmod, only: lat2,lon2,nsig
    use guess_grids, only: ges_tsen
    use m_mpimod, only: mype
    use guess_grids, only: ntguessig
    use constants, only: zero, one_tenth,r0_01

    implicit none
    real(r_kind), intent(inout  ) :: qr_arr(lat2,lon2,nsig)
    real(r_kind), intent(inout  ) :: qs_arr(lat2,lon2,nsig)
    real(r_kind), intent(inout  ) :: qg_arr(lat2,lon2,nsig)
    logical,      intent(in     ) :: use_cvpqx
    real(r_kind), intent(in     ) :: cvpqx_pvalue

    integer(i_kind)               :: i, j, k, it

    real(r_kind), dimension(lat2,lon2,nsig) :: tmparr_qr, tmparr_qs
    real(r_kind), dimension(lat2,lon2,nsig) :: tmparr_qg

    real(r_kind) :: qr_min, qs_min, qg_min
    real(r_kind) :: qr_tmp, qs_tmp, qg_tmp
    real(r_kind) :: qr_thrshd, qs_thrshd, qg_thrshd
!
    it=ntguessig
!

!   print info message: CVq, CVlogq, and CVpq
    if(mype==0)then
       if (use_cvpqx) then
          if ( cvpqx_pvalue == 0._r_kind ) then        ! CVlogq
              write(6,*)'wrfv3_netcdf: convert log(qr/qs/qg) back to qr/qs/qg.'
              write(6,*)'wrfv3_netcdf: then reset (qr/qs/qg) to 0.0 for some cases.'
          else if ( cvpqx_pvalue > 0._r_kind ) then   ! CVpq
              write(6,*)'wrfv3_netcdf: convert power transformed (qr/qs/qg) back to qr/qs/qg.'
              write(6,*)'wrfv3_netcdf: then reset (qr/qs/qg) to 0.0 for some cases.'
          end if
       else                                         ! CVq
          write(6,*)'wrfv3_netcdf: only reset (qr/qs/qg) to 0.0 for negative analysis value. (regular qx)'
       end if
    end if

!   Initialized temporary arrays with ges. Will be recalculated later if cvlogq or cvpq is used
    tmparr_qr =qr_arr
    tmparr_qs =qs_arr
    tmparr_qg =qg_arr

    do k=1,nsig
      do i=1,lon2
        do j=1,lat2

!          initialize hydrometeors as zero
           qr_tmp=zero
           qs_tmp=zero
           qg_tmp=zero

           if ( use_cvpqx ) then
              if ( cvpqx_pvalue == 0._r_kind ) then ! CVlogq

                 if (ges_tsen(j,i,k,it) > 274.15_r_kind) then
                    qr_min=2.9E-6_r_kind
                    qr_thrshd=qr_min * one_tenth
                    qs_min=0.1E-9_r_kind
                    qs_thrshd=qs_min
                    qg_min=3.1E-7_r_kind
                    qg_thrshd=qg_min * one_tenth
                 else if (ges_tsen(j,i,k,it) <= 274.15_r_kind .and. &
                          ges_tsen(j,i,k,it) >= 272.15_r_kind ) then
                    qr_min=2.0E-6_r_kind
                    qr_thrshd=qr_min * one_tenth
                    qs_min=1.3E-7_r_kind
                    qs_thrshd=qs_min * one_tenth
                    qg_min=3.1E-7_r_kind
                    qg_thrshd=qg_min * one_tenth
                 else if (ges_tsen(j,i,k,it) < 272.15_r_kind) then
                    qr_min=0.1E-9_r_kind
                    qr_thrshd=qr_min
                    qs_min=6.3E-6_r_kind
                    qs_thrshd=qs_min * one_tenth
                    qg_min=3.1E-7_r_kind
                    qg_thrshd=qg_min * one_tenth
                 end if

                 qr_tmp=exp(qr_arr(j,i,k))
                 qs_tmp=exp(qs_arr(j,i,k))
                 qg_tmp=exp(qg_arr(j,i,k))

!                if no update or very tiny value of qr/qs/qg, re-set/clear it
!                off to zero
                 if ( abs(qr_tmp - qr_min) < (qr_min*r0_01) ) then
                    qr_tmp=zero
                 else if (qr_tmp < qr_thrshd) then
                    qr_tmp=zero
                 end if

                 if ( abs(qs_tmp - qs_min) < (qs_min*r0_01) ) then
                    qs_tmp=zero
                 else if (qs_tmp < qs_thrshd) then
                    qs_tmp=zero
                 end if

                 if ( abs(qg_tmp - qg_min) < (qg_min*r0_01) ) then
                    qg_tmp=zero
                 else if (qg_tmp < qg_thrshd) then
                    qg_tmp=zero
                 end if

              else if ( cvpqx_pvalue > 0._r_kind ) then   ! CVpq

                 qr_tmp=max((cvpqx_pvalue*qr_arr(j,i,k)+1)**(1/cvpqx_pvalue)-1.0E-6_r_kind,0.0_r_kind)
                 qs_tmp=max((cvpqx_pvalue*qs_arr(j,i,k)+1)**(1/cvpqx_pvalue)-1.0E-6_r_kind,0.0_r_kind)
                 qg_tmp=max((cvpqx_pvalue*qg_arr(j,i,k)+1)**(1/cvpqx_pvalue)-1.0E-6_r_kind,0.0_r_kind)

                 !Set a upper limit to hydrometeors to disable overshooting
                 qr_tmp=min(qr_tmp,1E-2_r_kind)
                 qs_tmp=min(qs_tmp,1.0E-2_r_kind)
                 qg_tmp=min(qg_tmp,2E-2_r_kind)
              end if

           else   ! For CVq
              qr_min=zero
              qs_min=zero
              qg_min=zero

              qr_tmp=qr_arr(j,i,k)-1.0E-8_r_kind
              qs_tmp=qs_arr(j,i,k)-1.0E-8_r_kind
              qg_tmp=qg_arr(j,i,k)-1.0E-8_r_kind


              qr_tmp=max(qr_tmp,qr_min)
              qs_tmp=max(qs_tmp,qs_min)
              qg_tmp=max(qg_tmp,qg_min)

           end if         ! cvpqx

           tmparr_qr(j,i,k)=qr_tmp
           tmparr_qs(j,i,k)=qs_tmp
           tmparr_qg(j,i,k)=qg_tmp

        end do
      end do
    end do

    qr_arr=tmparr_qr
    qs_arr=tmparr_qs
    qg_arr=tmparr_qg

end subroutine convert_cvpqx_to_qx

subroutine convert_cvpnx_to_nx(qnx_arr,cvpnr,cvpnr_pvalue,cloud_nt_updt,q_arr,qr_arr,ps_arr)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    convert_cvpnx_to_nx
!   prgmmr: J. Park(CAPS)                     date: 2021-05-05
!
! abstract: convert cvpnx to nx (number concentration)
!
! program history log:
!   2021-05-05 - initial commit 
!              - this is used when GSI writes nx data from a background file
!                (subroutine wrfv3_netcdf)
!              - this can be used for other nx variables
!
!   input argument list:
!     qnx_arr        - array of qnx
!     cvpnr          - flag to use power transform or not
!     cvpnr_pvalue   - value to be used for power transform
!     cloud_nt_updt  - integer flag to use re-initialisation of QNRAIN with analyzed qr and n0r
!     q_arr          - array of qv, used only if cloud_nt_up_dt is 2
!     qr_arr         - array of qr, used only if cloud_nt_up_dt is 2
!     ps_arr         - array of ps, used only if cloud_nt_up_dt is 2
!
!   output argument list:
!     qnx_arr           - updated array of qnx after power transform
!
! attributes:
!   language: f90
!
    use m_kinds, only: r_kind,i_kind
    use gridmod, only: lat2,lon2,nsig
    use m_mpimod, only: mype
    use constants, only: zero, one, one_tenth
    use directDA_radaruse_mod, only: init_mm_qnr
    use guess_grids, only: ges_tsen
    use guess_grids, only: ntguessig
    use gridmod, only: pt_ll, aeta1_ll
    use constants, only: r10, r100, rd


    implicit none
    real(r_kind),    intent(inout)    :: qnx_arr(lat2,lon2,nsig)
    logical,         intent(in   )    :: cvpnr
    real(r_kind),    intent(in   )    :: cvpnr_pvalue
    integer(i_kind), intent(in   )    :: cloud_nt_updt
    real(r_kind),    intent(in   )    :: q_arr(lat2,lon2,nsig)
    real(r_kind),    intent(in   )    :: qr_arr(lat2,lon2,nsig)
    real(r_kind),    intent(in   )    :: ps_arr(lat2,lon2)

    real(r_kind), dimension(lat2,lon2,nsig) :: tmparr_qnr
    integer(i_kind)                   :: i, j, k, it
    real(r_kind)                      :: qnr_tmp

    real(r_kind) :: P1D,T1D,Q1D,RHO,QR1D
    real(r_kind),parameter:: D608=0.608_r_kind


!
    it=ntguessig
!

!   print info message: CVpnr
    if (mype==0 .and. cvpnr)then
       write(6,*)'wrfv3_netcdf: convert power transformed (qnx) back to qnx.'
    end if

! Initialized temp arrays with ges.
    tmparr_qnr=qnx_arr

    do k=1,nsig
      do i=1,lon2
        do j=1,lat2

!          re-initialisation of QNRAIN with analyzed qr and N0r(which is single-moment parameter)
!          equation is used in subroutine init_MM of initlib3d.f90 in arps package
          qnr_tmp = zero
          if ( cloud_nt_updt == 2 ) then
             T1D=ges_tsen(j,i,k,it)                                 ! sensible temperature (K)
             P1D=r100*(aeta1_ll(k)*(r10*ps_arr(j,i)-pt_ll)+pt_ll)   ! pressure hPa --> Pa
             Q1D=q_arr(j,i,k)/(one-q_arr(j,i,k))                    ! mixing ratio 
             RHO=P1D/(rd*T1D*(one+D608*Q1D))                        ! air density in kg m^-3
             QR1D=qr_arr(j,i,k)
             CALL init_mm_qnr(RHO,QR1D,qnr_tmp)
             qnr_tmp = max(qnr_tmp, zero)

          else
            if (cvpnr) then ! power transform
              qnr_tmp=max((cvpnr_pvalue*qnx_arr(j,i,k)+1)**(1/cvpnr_pvalue)-1.0E-2_r_kind,0.0_r_kind)
            else
                qnr_tmp=qnx_arr(j,i,k)
            end if

          end if
          tmparr_qnr(j,i,k)=qnr_tmp

        end do
      end do
    end do

    qnx_arr=tmparr_qnr

end subroutine convert_cvpnx_to_nx
subroutine gsi_copy_bundle(bundi,bundo) 
    use gsi_bundlemod, only:gsi_bundleinquire, gsi_bundlegetpointer,gsi_bundleputvar
    implicit none  
     
 !  copy the variables in the gsi_metguess_bundle_inout to gsi_bundle_inout or
 !  vice versa, according to icopy_flag  
 ! !INPUT PARAMETERS:

    type(gsi_bundle), intent(in   ) :: bundi
    type(gsi_bundle), intent(inout) :: bundo

 ! !INPUT/OUTPUT PARAMETERS:

    character(len=max_varname_length),dimension(:),allocatable:: src_name_vars2d
    character(len=max_varname_length),dimension(:),allocatable:: src_name_vars3d
    character(len=max_varname_length),dimension(:),allocatable:: target_name_vars2d
    character(len=max_varname_length),dimension(:),allocatable:: target_name_vars3d
    character(len=max_varname_length) ::varname 
    real(r_kind),dimension(:,:,:),pointer:: pvar3d=>NULL()
    real(r_kind),dimension(:,:),pointer:: pvar2d =>NULL()
    integer(i_kind):: src_nc3d,src_nc2d,target_nc3d,target_nc2d
    integer(i_kind):: ivar,jvar,istatus
    src_nc3d=bundi%n3d
    src_nc2d=bundi%n2d
    target_nc3d=bundo%n3d
    target_nc2d=bundo%n2d
    allocate(src_name_vars3d(src_nc3d),src_name_vars2d(src_nc2d))
    allocate(target_name_vars3d(target_nc3d),target_name_vars2d(target_nc2d))
    call gsi_bundleinquire(bundi,'shortnames::3d',src_name_vars3d,istatus)
    call gsi_bundleinquire(bundi,'shortnames::2d',src_name_vars2d,istatus)
    call gsi_bundleinquire(bundo,'shortnames::3d',target_name_vars3d,istatus)
    call gsi_bundleinquire(bundo,'shortnames::2d',target_name_vars2d,istatus)
    do ivar=1,src_nc3d
      varname=trim(src_name_vars3d(ivar))
      do jvar=1,target_nc3d
        if(index(target_name_vars3d(jvar),varname) > 0)  then
          call GSI_BundleGetPointer (bundi,varname,pvar3d,istatus)
          call gsi_bundleputvar (bundo,varname,pvar3d,istatus)
          exit
        endif
      enddo
    enddo
    do ivar=1,src_nc2d
      varname=trim(src_name_vars2d(ivar))
      do jvar=1,target_nc2d
        if(index(target_name_vars2d(jvar),varname) > 0)  then
          call GSI_BundleGetPointer (bundi,varname,pvar2d,istatus)
          call gsi_bundleputvar (bundo,varname,pvar2d,istatus)
          exit
        endif
      enddo
    enddo
    deallocate(src_name_vars3d,src_name_vars2d)
    deallocate(target_name_vars3d,target_name_vars2d)
    return
end subroutine gsi_copy_bundle
subroutine getfv3lamfilevname(vgsinamein,fv3filenamegref,filenameout,vname)

    type (type_fv3regfilenameg),intent (in) :: fv3filenamegref
    character(len=*),intent(out):: vname
    character(len=*),intent(out):: filenameout
    character(len=*),intent( in):: vgsinamein

    if (ifindstrloc(vgsiname,vgsinamein)<= 0) then
      write(6,*)'the name ',vgsinamein ,'cannot be treated correctly in getfv3lamfilevname,stop'
      call stop2(333)
    endif
    if(ifindstrloc(vardynvars,vgsinamein)> 0)  then 
        filenameout=fv3filenamegref%dynvars
    else if(ifindstrloc(vartracers,vgsinamein)> 0 )  then 
        filenameout=fv3filenamegref%tracers
    else if(ifindstrloc(varphyvars,vgsinamein)> 0)  then
        filenameout=fv3filenamegref%phyvars
    else
        write(6,*)'the filename corresponding to var ',trim(vgsinamein),' is not found, stop ' 
        call stop2(333)
    endif
    vname=varfv3name(ifindstrloc(vgsiname,vgsinamein))
    if(trim(vname)=="T".and. fv3sar_bg_opt==1) then
       vname="t"
    endif 
    
    return
end subroutine getfv3lamfilevname
function ifindstrloc(str_array,strin)
    integer(i_kind) ifindstrloc
    character(len=max_varname_length),dimension(:) :: str_array
    character(len=*) :: strin
    integer(i_kind) i
    ifindstrloc=0
    do i=1,size(str_array)
      if(trim(str_array(i)) == trim(strin)) then 
        ifindstrloc=i
        exit
      endif
    enddo
end function ifindstrloc
    
subroutine m_gsi_rfv3io_get_grid_specs(gsi_lats,gsi_lons,ierr)
!$$$  subprogram documentation block
!                .      .    .                                        .
! subprogram:    gsi_rfv3io_get_grid_specs
!   pgrmmr: parrish     org: np22                date: 2017-04-03
!
! abstract:  obtain grid dimensions nx,ny and grid definitions
!                grid_x,grid_xt,grid_y,grid_yt,grid_lon,grid_lont,grid_lat,grid_latt
!                nz,ak(nz),bk(nz)
!
! program history log:
!   2017-04-03  parrish - initial documentation
!   2017-10-10  wu - setup A grid and interpolation coeff with generate_anl_grid
!   2018-02-16  wu - read in time info from file coupler.res
!                    read in lat, lon at the center and corner of the grid cell
!                    from file fv3_grid_spec, and vertical grid infor from file fv3_akbk
!                    setup A grid and interpolation/rotation coeff
!   input argument list:
!    grid_spec
!    ak_bk
!    lendian_out
!
!   output argument list:
!    ierr
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block

  use netcdf, only: nf90_open,nf90_close,nf90_get_var,nf90_noerr
  use netcdf, only: nf90_nowrite,nf90_inquire,nf90_inquire_dimension
  use netcdf, only: nf90_inquire_variable
  use m_mpimod, only: mype
  use mod_fv3_lola, only: m_generate_anl_grid
  use gridmod,  only:nsig,regional_time,regional_fhr,regional_fmin,aeta1_ll,aeta2_ll
  use gridmod,  only:nlon_regional,nlat_regional,eta1_ll,eta2_ll
  use gridmod,  only:grid_type_fv3_regional,mpas_regional
  use m_kinds, only: i_kind,r_kind
  use constants, only: half,zero
  use m_mpimod, only: gsi_mpi_comm_world,mpi_itype,mpi_rtype

  implicit none
  integer(i_kind),intent(  out) :: ierr
  real(r_kind),intent(inout) :: gsi_lats(:,:),gsi_lons(:,:)

  integer(i_kind) gfile_grid_spec
  character(:),allocatable    :: grid_spec
  character(:),allocatable    :: ak_bk
  character(len=:),allocatable :: coupler_res_filenam 
  integer(i_kind) i,k,ndimensions,iret,nvariables,nattributes,unlimiteddimid
  integer(i_kind) len,gfile_loc
  character(len=max_varname_length) :: name
  integer(i_kind) myear,mmonth,mday,mhour,mminute,msecond
  real(r_kind),allocatable:: abk_fv3(:)
  integer(i_kind) imiddle,jmiddle
! if fv3_io_layout_y > 1
  integer(i_kind) :: nio,nylen
  integer(i_kind),allocatable :: gfile_loc_layout(:)
  character(len=180)  :: filename_layout
  integer(i_kind) :: ios
  real(r_kind) :: pmpas

    coupler_res_filenam='coupler.res'
    grid_spec='fv3_grid_spec'
    ak_bk='fv3_akbk'

!!!!! set regional_time
    open(24,file=trim(coupler_res_filenam),form='formatted')
    read(24,*)
    read(24,*)
    read(24,*)myear,mmonth,mday,mhour,mminute,msecond
    close(24)
  !  if(mype==0)  write(6,*)' myear,mmonth,mday,mhour,mminute,msecond=', myear,mmonth,mday,mhour,mminute,msecond
    regional_time(1)=myear
    regional_time(2)=mmonth
    regional_time(3)=mday
    regional_time(4)=mhour
    regional_time(5)=mminute
    regional_time(6)=msecond
    regional_fhr=zero          ! forecast hour set zero for now
    regional_fmin=zero          ! forecast min set zero for now

!!!!!!!!!!    grid_spec  !!!!!!!!!!!!!!!
    ierr=0
    iret=nf90_open(trim(grid_spec),nf90_nowrite,gfile_grid_spec)
    if(iret/=nf90_noerr) then
       write(6,*)' gsi_rfv3io_get_grid_specs: problem opening ',trim(grid_spec),', Status = ',iret
       ierr=1
       return
    endif

    iret=nf90_inquire(gfile_grid_spec,ndimensions,nvariables,nattributes,unlimiteddimid)
    gfile_loc=gfile_grid_spec
    do k=1,ndimensions
       iret=nf90_inquire_dimension(gfile_loc,k,name,len)
       if(trim(name)=='grid_xt') nx=len
       if(trim(name)=='grid_yt') ny=len
    enddo
    nlon_regional=nx
    nlat_regional=ny

    if(.not.allocated(ny_layout_len)) allocate(ny_layout_len(0:fv3_io_layout_y-1))
    if(.not.allocated(ny_layout_b)) allocate(ny_layout_b(0:fv3_io_layout_y-1))
    if(.not.allocated(ny_layout_e)) allocate(ny_layout_e(0:fv3_io_layout_y-1))
    ny_layout_len=ny
    ny_layout_b=0
    ny_layout_e=0
    if(fv3_io_layout_y > 1) then
       if(.not.allocated(gfile_loc_layout)) allocate(gfile_loc_layout(0:fv3_io_layout_y-1))
       do nio=0,fv3_io_layout_y-1
          write(filename_layout,'(a,a,I4.4)') trim(grid_spec),'.',nio
          iret=nf90_open(filename_layout,nf90_nowrite,gfile_loc_layout(nio))
          if(iret/=nf90_noerr) then
             write(6,*)' problem opening ',trim(filename_layout),', Status =',iret
             ierr=1
             return
          endif
          iret=nf90_inquire(gfile_loc_layout(nio),ndimensions,nvariables,nattributes,unlimiteddimid)
          do k=1,ndimensions
              iret=nf90_inquire_dimension(gfile_loc_layout(nio),k,name,len)
              if(trim(name)=='grid_yt') ny_layout_len(nio)=len
          enddo
          iret=nf90_close(gfile_loc_layout(nio))
       enddo
       deallocate(gfile_loc_layout)
! figure out begin and end of each subdomain restart file
       nylen=0
       do nio=0,fv3_io_layout_y-1
          ny_layout_b(nio)=nylen + 1
          nylen=nylen+ny_layout_len(nio)
          ny_layout_e(nio)=nylen
       enddo
    endif
   ! if(mype==0)write(6,*),'nx,ny=',nx,ny
   ! if(mype==0)write(6,*),'ny_layout_len=',ny_layout_len
   ! if(mype==0)write(6,*),'ny_layout_b=',ny_layout_b
   ! if(mype==0)write(6,*),'ny_layout_e=',ny_layout_e

!!!    get nx,ny,grid_lon,grid_lont,grid_lat,grid_latt,nz,ak,bk

    if(.not.allocated(grid_lat)) allocate(grid_lat(nx+1,ny+1))
    if(.not.allocated(grid_lon)) allocate(grid_lon(nx+1,ny+1))
    if(.not.allocated(grid_latt)) allocate(grid_latt(nx,ny))
    if(.not.allocated(grid_lont)) allocate(grid_lont(nx,ny))

    do k=ndimensions+1,nvariables
       iret=nf90_inquire_variable(gfile_loc,k,name,len)
       if(trim(name)=='grid_lat') then
          iret=nf90_get_var(gfile_loc,k,grid_lat)
       endif
       if(trim(name)=='grid_lon') then
          iret=nf90_get_var(gfile_loc,k,grid_lon)
       endif
       if(trim(name)=='grid_latt') then
          iret=nf90_get_var(gfile_loc,k,grid_latt)
       endif
       if(trim(name)=='grid_lont') then
          iret=nf90_get_var(gfile_loc,k,grid_lont)
       endif
    enddo
!
!  need to decide the grid orientation of the FV regional model    
!
!   grid_type_fv3_regional = 0 : decide grid orientation based on
!                                grid_lat/grid_lon
!                            1 : input is E-W N-S grid
!                            2 : input is W-E S-N grid
!
    if(grid_type_fv3_regional == 0) then
        imiddle=nx/2
        jmiddle=ny/2
        if( (grid_latt(imiddle,1) < grid_latt(imiddle,ny)) .and. &
            (grid_lont(1,jmiddle) < grid_lont(nx,jmiddle)) ) then 
            grid_type_fv3_regional = 2
        else
            grid_type_fv3_regional = 1
        endif
    endif
! check the grid type
    if( grid_type_fv3_regional == 1 ) then
       !if(mype==0) write(6,*) 'FV3 regional input grid is  E-W N-S grid'
       grid_reverse_flag=.true.    ! grid is revered comparing to usual map view
    else if(grid_type_fv3_regional == 2) then
       !if(mype==0) write(6,*) 'FV3 regional input grid is  W-E S-N grid'
       grid_reverse_flag=.false.   ! grid orientated just like we see on map view    
    else
       write(6,*) 'Error: FV3 regional input grid is unknown grid'
       call stop2(678)
    endif
!
    if(grid_type_fv3_regional == 2) then
       call reverse_grid_r(grid_lont,nx,ny,1)
       call reverse_grid_r(grid_latt,nx,ny,1)
       call reverse_grid_r(grid_lon,nx+1,ny+1,1)
       call reverse_grid_r(grid_lat,nx+1,ny+1,1)
    endif

    iret=nf90_close(gfile_loc)

    iret=nf90_open(ak_bk,nf90_nowrite,gfile_loc)
    if(iret/=nf90_noerr) then
       write(6,*)'gsi_rfv3io_get_grid_specs: problem opening ',trim(ak_bk),', Status = ',iret
       ierr=1
       return
    endif
    iret=nf90_inquire(gfile_loc,ndimensions,nvariables,nattributes,unlimiteddimid)
    do k=1,ndimensions
       iret=nf90_inquire_dimension(gfile_loc,k,name,len)
       if(trim(name)=='xaxis_1') nz=len
    enddo
    !if(mype==0)write(6,'(" nz=",i5)') nz

    nsig=nz-1
    if(mpas_regional) then
      nsig=0
      open(11,file='mpas_pave.txt')
      do
        read(11,*,iostat=ios) pmpas
        if(ios /= 0) exit
        nsig = nsig + 1
      enddo
      close(11)
    endif

!!!    get ak,bk

    if(.not.allocated(aeta1_ll)) allocate(aeta1_ll(nsig))
    if(.not.allocated(aeta2_ll)) allocate(aeta2_ll(nsig))
    if(.not.allocated(eta1_ll)) allocate(eta1_ll(nsig+1))
    if(.not.allocated(eta2_ll)) allocate(eta2_ll(nsig+1))
    if(.not.allocated(ak)) allocate(ak(nz))
    if(.not.allocated(bk)) allocate(bk(nz))
    if(.not.allocated(abk_fv3)) allocate(abk_fv3(nz))

    do k=ndimensions+1,nvariables
       iret=nf90_inquire_variable(gfile_loc,k,name,len)
       if(trim(name)=='ak'.or.trim(name)=='AK') then
          iret=nf90_get_var(gfile_loc,k,abk_fv3)
          do i=1,nz
             ak(i)=abk_fv3(nz+1-i)
          enddo
       endif
       if(trim(name)=='bk'.or.trim(name)=='BK') then
          iret=nf90_get_var(gfile_loc,k,abk_fv3)
          do i=1,nz
             bk(i)=abk_fv3(nz+1-i)
          enddo
       endif
    enddo
    iret=nf90_close(gfile_loc)

!!!!! change unit of ak 
    do i=1,nsig+1
       eta1_ll(i)=ak(i)*0.001_r_kind
       eta2_ll(i)=bk(i)
    enddo
    do i=1,nsig
       aeta1_ll(i)=half*(ak(i)+ak(i+1))*0.001_r_kind
       aeta2_ll(i)=half*(bk(i)+bk(i+1))
    enddo
    !if(mype==0)then
    !   do i=1,nz
    !      write(6,'(" ak,bk(",i3,") = ",2f17.6)') i,ak(i),bk(i)
    !   enddo
    !endif

!!!!!!! setup A grid and interpolation/rotation coeff.
    call m_generate_anl_grid(nx,ny,grid_lon,grid_lont,grid_lat,grid_latt,gsi_lats,gsi_lons)

    deallocate (grid_lon,grid_lat,grid_lont,grid_latt)
    !deallocate (ak,bk,abk_fv3)

    deallocate(ny_layout_len,ny_layout_b,ny_layout_e)
    !deallocate(aeta1_ll,aeta2_ll)
    !deallocate(eta1_ll,eta2_ll)

    return
end subroutine m_gsi_rfv3io_get_grid_specs

end module gsi_rfv3io_mod
