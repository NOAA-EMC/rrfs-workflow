! (C) Copyright 2022 United States Government as represented by the Administrator of the National
!     Aeronautics and Space Administration
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

module gsi_grid_mod

! netcdf
use netcdf

! atlas
use atlas_module,                   only: atlas_field, atlas_fieldset, atlas_real

! fckit
use fckit_mpi_module,               only: fckit_mpi_comm
use fckit_configuration_module,     only: fckit_configuration

! oops
use kinds,                          only: kind_real

! saber
use gsi_utils_mod,                  only: nccheck

! gsibec
use gsimod,                         only: gsimain_gridopts
use m_gsibec,                       only: gsibec_get_grid
use m_gsibec,                       only: gsibec_set_grid

implicit none
private
public gsi_grid

! Fortran class header
type :: gsi_grid
  type(fckit_mpi_comm) :: comm
  character(len=2055) :: filename
  integer :: npx, npy, npz          ! Grid points in global grid
  integer :: layout(2)              ! Number of processors in x (index 1) and y (index 2) directions
  integer :: lat2,lon2
  integer :: isc, iec, jsc, jec     ! Start and ending grid points for each processor
  logical :: vflip                  ! Flip vertical grid (gsi k=1=top)
  logical :: noGSI
  real(kind=kind_real), allocatable :: lats(:), lons(:)
  real(kind=kind_real), allocatable :: lats2(:,:), lons2(:,:)
  real(kind=kind_real), allocatable :: grid_lats(:,:), grid_lons(:,:)
  integer :: ngrid ! Number of grid points for each processor
  logical :: debug
  logical :: regional
  contains
    procedure, public :: create
    procedure, public :: delete
    procedure, public :: print
    procedure, public :: get_levels
    procedure, public :: set_atlas_lonlat
end type gsi_grid

! --------------------------------------------------------------------------------------------------

contains

! --------------------------------------------------------------------------------------------------

subroutine create(self, conf, comm)

! Arguments
class(gsi_grid),           intent(inout) :: self
type(fckit_configuration), intent(in)    :: conf
type(fckit_mpi_comm),      intent(in)    :: comm

! Locals
integer :: ncid, dimid(3), varid(2)
character(len=:), allocatable :: str
integer :: posx, posy, i, j
logical :: verbose

! Create copy of comm
! -------------------
self%comm = comm
verbose = comm%rank()==0

! Debug mode
! ----------
call conf%get_or_die("debugging mode", self%debug)
call conf%get_or_die("debugging bypass gsi", self%noGSI)

! Regional mode
! -------------
self%regional = .false.
if (conf%has("regional mode")) then
  call conf%get_or_die("regional mode", self%regional)
end if

! Domain decomposition
! --------------------
if (conf%has("processor layout x direction").and.conf%has("processor layout y direction")) then
  call conf%get_or_die("processor layout x direction", self%layout(1))
  call conf%get_or_die("processor layout y direction", self%layout(2))
else
  self%layout(1) = floor(sqrt(real(comm%size(),kind_real)))
  self%layout(2) = comm%size()/self%layout(1)
end if

! Handle vertical grid opt
! ------------------------
call conf%get_or_die("flip vertical grid", self%vflip)

! Open file with GSI grid info (for now here)
! ----------------------------
if (comm%rank() == 0) then

  ! Get filename
  call conf%get_or_die("gsi error covariance file", str)
  self%filename = str

endif

if (self%noGSI) then
  call woGSI()
else
  call wGSI()
endif

! Create arrays of lon/lat to be compatible with interpolation
if(.not.allocated(self%grid_lons)) allocate(self%grid_lons(self%isc:self%iec, self%jsc:self%jec))
if(.not.allocated(self%grid_lats)) allocate(self%grid_lats(self%isc:self%iec, self%jsc:self%jec))

if(self%regional) then
  do i = self%isc, self%iec
    do j = self%jsc, self%jec
      self%grid_lons(i,j) = self%lons2(i,j)
      self%grid_lats(i,j) = self%lats2(i,j)
    enddo
  enddo
else
  do i = self%isc, self%iec
    self%grid_lons(i,:) = self%lons(i)
  enddo
  do j = self%jsc, self%jec
    self%grid_lats(:,j) = self%lats(j)
  enddo
endif

if ( self%debug ) then
 if(self%comm%rank() == 0) then
    do j=1,self%layout(1)*self%layout(2)
       write(6,'(a,6(i5,1x))') 'grid dist indexes: task, is,ie, js,je ', j, &
                                self%isc, self%iec, &
                                self%jsc, self%jec, &
                                self%ngrid
    enddo
 endif
endif



contains
! ------------------
! Actual hook to GSI (lat/lon to come from GSI)
! ------------------
  subroutine wGSI

  integer :: npe,igdim
  logical :: eqspace
  character(len=:), allocatable :: nml,vgrdfn
  real(kind=kind_real), allocatable :: mylats(:), mylons(:)

  npe = self%layout(1)*self%layout(2)

  ! Check that user choices match comm size
  if (.not. self%layout(1)*self%layout(2) == comm%size()) &
    call abor1_ftn("GSI grid: number of processor in layout does not match number in communicator")

  ! Get required name of resources for GSI B error
  ! ----------------------------------------------
   call conf%get_or_die("gsi berror namelist file",  nml)
   call conf%get_or_die("gsi akbk",  vgrdfn)

  ! Initialize GSIbec grid
  ! ----------------------
  call gsimain_gridopts (nml,comm%rank(),self%layout(1),self%layout(2),&
                         self%npy,self%npx,self%npz,eqspace,&
                         self%lon2,self%lat2,&
                         self%isc,self%iec,self%jsc,self%jec,igdim)

  ! Allocate the lat/lon arrays
  ! ---------------------------
  if(self%regional) then
    if(.not.allocated(self%lons2)) allocate(self%lons2(self%npx,self%npy))
    if(.not.allocated(self%lats2)) allocate(self%lats2(self%npx,self%npy))
  else
    if(.not.allocated(self%lons)) allocate(self%lons(self%npx))
    if(.not.allocated(self%lats)) allocate(self%lats(self%npy))
  endif

  ! Read the latitudes and longitudes per GSIbec
  ! --------------------------------------------
  if(self%regional) then
    call gsibec_get_grid ('degree',self%lats2,self%lons2)
  else
    call gsibec_get_grid (eqspace,'degree',self%lats,self%lons)
  endif
  call gsibec_set_grid (comm%rank(),vgrdfn)

  ! If debugging, read the latitude and longitude from file
  ! and compare with those from GSIbec
  ! ---------------------------------------------
  if (self%debug .and. comm%rank() == 0) then

    allocate(mylons(self%npx))
    allocate(mylats(self%npy))

    ! Open NetCDF
    call nccheck(nf90_open(trim(self%filename), NF90_NOWRITE, ncid), "nf90_open "//trim(self%filename))

    call nccheck(nf90_inq_varid(ncid, "lon", varid(1)), "nf90_inq_varid lon")
    call nccheck(nf90_inq_varid(ncid, "lat", varid(2)), "nf90_inq_varid lat")

    call nccheck(nf90_get_var(ncid, varid(1), mylons), "nf90_get_var lon" )
    call nccheck(nf90_get_var(ncid, varid(2), mylats), "nf90_get_var lat" )

    ! Close NetCDF with GSI grid info
    call nccheck(nf90_close(ncid), "nf90_close")

    do i=1,self%npx
       print *, 'lons: gsi, file: ',self%lons(i),mylons(i) 
    enddo
    do j=1,self%npy
       print *, 'lats: gsi, file: ',self%lats(j),mylats(j) 
    enddo
    deallocate(mylons)
    deallocate(mylats)

  end if

  self%ngrid = (self%iec-self%isc+1)*(self%jec-self%jsc+1)
  if (self%ngrid /= igdim) then
    call abor1_ftn("gsi_grid_mod: inconsistent distribution")
  endif

  end subroutine wGSI

! ---------------------------------------
! Provides a stub for testing without GSI
! ---------------------------------------
  subroutine woGSI

  integer :: npx_per_proc, npy_per_proc

! Read the GSI grid info from file
! --------------------------------
  if (comm%rank() == 0) then

    ! Open NetCDF
    call nccheck(nf90_open(trim(self%filename), NF90_NOWRITE, ncid), "nf90_open "//trim(self%filename))

    ! Get grid dimension from file
    call nccheck(nf90_inq_dimid(ncid, "lon", dimid(1)), "nf90_inq_dimid lon")
    call nccheck(nf90_inq_dimid(ncid, "lat", dimid(2)), "nf90_inq_dimid lat")
    call nccheck(nf90_inq_dimid(ncid, "lev", dimid(3)), "nf90_inq_dimid lev")

    call nccheck(nf90_inquire_dimension(ncid, dimid(1), len=self%npx), "nf90_inquire_dimension lon" )
    call nccheck(nf90_inquire_dimension(ncid, dimid(2), len=self%npy), "nf90_inquire_dimension lat" )
    call nccheck(nf90_inquire_dimension(ncid, dimid(3), len=self%npz), "nf90_inquire_dimension lev" )

  endif

  ! Broadcast the dimensions
  ! ------------------------
  call comm%broadcast(self%npx, 0)
  call comm%broadcast(self%npy, 0)
  call comm%broadcast(self%npz, 0)


  ! Allocate the lat/lon arrays
  ! ---------------------------
  if(.not.allocated(self%lons)) allocate(self%lons(self%npx))
  if(.not.allocated(self%lats)) allocate(self%lats(self%npy))

  ! Read the latitude and longitude
  ! -------------------------------
  if (comm%rank() == 0) then

    call nccheck(nf90_inq_varid(ncid, "lon", varid(1)), "nf90_inq_varid lon")
    call nccheck(nf90_inq_varid(ncid, "lat", varid(2)), "nf90_inq_varid lat")

    call nccheck(nf90_get_var(ncid, varid(1), self%lons), "nf90_get_var lon" )
    call nccheck(nf90_get_var(ncid, varid(2), self%lats), "nf90_get_var lat" )

    ! Close NetCDF with GSI grid info
    call nccheck(nf90_close(ncid), "nf90_close")

  end if


  ! Broadcast the grid
  ! ------------------
  call comm%broadcast(self%lons, 0)
  call comm%broadcast(self%lats, 0)

  ! Check that user choices match comm size
  if (.not. self%layout(1)*self%layout(2) == comm%size()) &
    call abor1_ftn("GSI grid: number of processor in layout does not match number in communicator")


  ! Doing gsi stuff ...
  ! -------------------
  call conf%get_or_die("debugging bypass gsi", self%noGSI)

  ! Grid point per processor in each direction
  npx_per_proc = floor(real(self%npx, kind_real)/real(self%layout(1), kind_real))
  npy_per_proc = floor(real(self%npy, kind_real)/real(self%layout(2), kind_real))

  ! Start and end points in the x direction
  posx = mod(comm%rank(), self%layout(1))
  self%isc = posx * npx_per_proc + 1
  self%iec = self%isc + npx_per_proc - 1
  if (posx == self%layout(1) -1) self%iec = self%npx

  ! Start and end points in the y direction
  do j = 0, self%layout(2)-1
    if ( comm%rank() >= j*self%layout(1) .and. comm%rank() < (j+1)*self%layout(1) ) then
      posy = j
    end if
  end do
  self%jsc = posy * npy_per_proc + 1
  self%jec = self%jsc + npy_per_proc - 1
  if (posy == self%layout(2) -1) self%jec = self%npy

  self%ngrid = (self%iec-self%isc+1)*(self%jec-self%jsc+1)

  end subroutine woGSI
end subroutine create

! --------------------------------------------------------------------------------------------------

subroutine delete(self)

! Arguments
class(gsi_grid), intent(inout) :: self

! Deallocate arrays
deallocate(self%lons)
deallocate(self%lats)
deallocate(self%grid_lons)
deallocate(self%grid_lats)
call self%comm%final()

! Set grid to zero
self%npx = 0
self%npy = 0
self%npz = 0
self%layout = 0
self%isc = 0
self%iec = 0
self%jsc = 0
self%jec = 0

end subroutine delete

! --------------------------------------------------------------------------------------------------

subroutine print(self)

! Arguments
class(gsi_grid), intent(in) :: self

! Root PE prints grid info
if (self%comm%rank() == 0) then

  write(*,'(A28)')      "ErrorCovarianceGSI GSI grid:"
  write(*,'(A38, I5)')  "  Number of longitudinal grid points: ", self%npx
  write(*,'(A37, I5)')  "  Number of latitudinal grid points: ", self%npy
  write(*,'(A34, I5)')  "  Number of vertical grid points: ", self%npz
  write(*,'(A1)')       " "
  write(*,'(A43, I5)')  "  Number of processors in the x direction: ", self%layout(1)
  write(*,'(A43, I5)')  "  Number of processors in the y direction: ", self%layout(2)

endif

if (self%debug) then
  ! Print index ranges
  write(*,'(A7, I6, A7, I6, A7, I6, A7, I6, A7, I6)')  "  Proc ", self%comm%rank(), &
                        ' isc = ', self%isc, ' iec = ', self%iec, &
                        ' jsc = ', self%jsc, ' jec = ', self%jec

  ! Print latlon
  write(*,'(A10, F10.3, A10, F10.3, A10, F10.3, A10, F10.3)')  &
        "  Lat min ", minval(self%grid_lats), &
        "  Lat max ", maxval(self%grid_lats), &
        "  Lon min ", minval(self%grid_lons), &
        "  Lon max ", maxval(self%grid_lons)
endif

end subroutine print

! --------------------------------------------------------------------------------------------------

subroutine get_levels(self, levels)

! Arguments
class(gsi_grid), intent(in)    :: self
integer,         intent(inout) :: levels

! Get number of levels
! --------------------
levels = self%npz

end subroutine get_levels

! --------------------------------------------------------------------------------------------------

subroutine set_atlas_lonlat(self, grid_fieldset)

!Arguments
class(gsi_grid),      intent(inout) :: self
type(atlas_fieldset), intent(inout) :: grid_fieldset

!Locals
real(kind_real), pointer :: real_ptr(:,:)
type(atlas_field) :: lonlat_field

! Create lon/lat field
lonlat_field = atlas_field(name="lonlat", kind=atlas_real(kind_real), shape=(/2,self%ngrid/))

! Get pointer to the data
call lonlat_field%data(real_ptr)

! Fill lon/lat
real_ptr(1,:) = reshape(self%grid_lons(self%isc:self%iec, &
                                       self%jsc:self%jec), (/self%ngrid/))
real_ptr(2,:) = reshape(self%grid_lats(self%isc:self%iec, &
                                       self%jsc:self%jec), (/self%ngrid/))

! Add field to fieldset
call grid_fieldset%add(lonlat_field)

! Release memory
call lonlat_field%final()

end subroutine set_atlas_lonlat

! --------------------------------------------------------------------------------------------------

end module gsi_grid_mod
