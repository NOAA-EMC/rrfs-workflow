! (C) Copyright 2017-2022 UCAR
! (C) Copyright 2024 NOAA NCEP EMC
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

!> Fortran module for sfccorrected observation operator

module ufo_sfccorrected_mod

 use oops_variables_mod
 use obs_variables_mod
 use ufo_vars_mod
 use missing_values_mod
 use iso_c_binding
 use kinds
 use ufo_constants_mod, only : grav, rd, Lclr, t2tv
 use gnssro_mod_transform, only : geop2geometric, geometric2geop
 use mpi

 implicit none
 private
 integer, parameter :: max_string = 800

! Fortran derived type for observation type
 type, public :: ufo_sfccorrected
 private
   type(obs_variables), public :: obsvars ! Variables to be simulated
   integer, allocatable, public :: obsvarindices(:) ! Indices of obsvars in the list of all
                                                    ! simulated variables in the ObsSpace.
                                                    ! allocated/deallocated at interface layer
   type(oops_variables), public :: geovars
   character(len=MAXVARLEN)     :: da_sfc_scheme
   character(len=MAXVARLEN)     :: station_altitude
   character(len=MAXVARLEN)     :: lapse_rate_option
   real(kind_real)              :: lapse_rate
   integer                      :: local_lapse_rate_level
   logical                      :: threshold
   real(kind_real)              :: min_threshold, max_threshold
 contains
   procedure :: setup  => ufo_sfccorrected_setup
   procedure :: simobs => ufo_sfccorrected_simobs
 end type ufo_sfccorrected

 character(len=MAXVARLEN), dimension(6) :: geovars_list = (/ var_ps, var_geomz, var_sfc_geomz, var_ts, var_prs, var_sfc_t2m /)

contains

! ------------------------------------------------------------------------------
subroutine ufo_sfccorrected_setup(self, f_conf)
use fckit_configuration_module, only: fckit_configuration
use fckit_log_module,  only : fckit_log
implicit none
class(ufo_sfccorrected), intent(inout)     :: self
type(fckit_configuration), intent(in) :: f_conf
character(len=:), allocatable         :: str_sfc_scheme, str_var_sfc_geomz, str_var_geomz, str_lapse_rate_option
character(len=:), allocatable         :: str_obs_height
real(kind_real)                       :: constant_lapse_rate
integer                               :: local_lapse_rate_level
logical                               :: threshold
real(kind_real)                       :: min_threshold, max_threshold

character(max_string)                 :: debug_msg

!> In case where a user wants to specify geoVaLs variable name of model
!> height of vertical levels and/or sfc height.  Example: MPAS is height
!> but FV-3 uses geopotential_height.

call f_conf%get_or_die("geovar_geomz", str_var_geomz)
write(debug_msg,*) "ufo_sfccorrected_mod.F90: var_geomz is", trim(str_var_geomz)
call fckit_log%debug(debug_msg)
geovars_list(2) = trim(str_var_geomz)

call f_conf%get_or_die("geovar_sfc_geomz", str_var_sfc_geomz)
write(debug_msg,*) "ufo_sfccorrected_mod.F90: var_sfc_geomz is ", trim(str_var_sfc_geomz)
call fckit_log%debug(debug_msg)
geovars_list(3) = trim(str_var_sfc_geomz)

call self%geovars%push_back(geovars_list)

call f_conf%get_or_die("da_sfc_scheme",str_sfc_scheme)
self%da_sfc_scheme = str_sfc_scheme

call f_conf%get_or_die("station_altitude", str_obs_height)
self%station_altitude = str_obs_height

if (self%da_sfc_scheme.eq."GSL") then
   call f_conf%get_or_die("lapse_rate_option", str_lapse_rate_option)
   self%lapse_rate_option = str_lapse_rate_option
   select case (trim(self%lapse_rate_option))
   case ("Constant")
      call f_conf%get_or_die("lapse_rate", constant_lapse_rate)
      self%lapse_rate = constant_lapse_rate * 0.001
   case ("Local")
      call f_conf%get_or_die("local_lapse_rate_level", local_lapse_rate_level)
      self%local_lapse_rate_level = local_lapse_rate_level
      call f_conf%get_or_die("threshold", threshold)
      self%threshold = threshold
      if (self%threshold) then
         call f_conf%get_or_die("min_threshold", min_threshold)
         self%min_threshold = min_threshold * 0.001
         call f_conf%get_or_die("max_threshold", max_threshold)
         self%max_threshold = max_threshold * 0.001
      end if
   case ("NoAdjustment")
      ! Do nothing in this case
   case default
      write(debug_msg,*) "ufo_sfccorrected: lapse_rate_option not recognized"
      call fckit_log%debug(debug_msg)
      call abor1_ftn(debug_msg)
   end select
endif

end subroutine ufo_sfccorrected_setup

! ------------------------------------------------------------------------------
subroutine ufo_sfccorrected_simobs(self, geovals, obss, nvars, nlocs, hofx)
use ufo_geovals_mod, only: ufo_geovals, ufo_geoval, ufo_geovals_get_var
use obsspace_mod
use vert_interp_mod
use fckit_log_module,  only : fckit_log
implicit none
class(ufo_sfccorrected), intent(in) :: self
integer, intent(in)               :: nvars, nlocs
type(ufo_geovals),  intent(in)    :: geovals
real(c_double),     intent(inout) :: hofx(nvars, nlocs)
type(c_ptr), value, intent(in)    :: obss

! Local variables
real(c_double)                    :: missing
real(kind_real)                   :: H2000 = 2000.0
integer                           :: nobs, iobs, ivar, iobsvar, k, kbot, ktop_lr, idx_geop
real(kind_real),    allocatable   :: cor_tsfc(:)
type(ufo_geoval),   pointer       :: model_ps, model_p, model_sfc_geomz, model_t, model_geomz, model_t2m
character(len=*), parameter       :: myname_="ufo_sfccorrected_simobs"
character(max_string)             :: err_msg
real(kind_real)                   :: wf
integer                           :: wi
logical                           :: variable_present, variable_present_t, variable_present_q
real(kind_real), dimension(:), allocatable :: obs_height, obs_t, obs_q, obs_psfc, obs_lat, obs_lon, obs_tv
real(kind_real), dimension(:), allocatable :: model_ts, model_zs, model_level1, model_p_2000, model_t_2000, model_psfc, lr
real(kind_real), dimension(:), allocatable :: H2000_geop
real(kind_real), dimension(:), allocatable :: avg_tv
real(kind_real)                            :: model_znew

integer :: rank, ierr, unit_lr
character(len=30) :: filename

missing = missing_value(missing)
nobs    = obsspace_get_nlocs(obss)

! check if nobs is consistent in geovals & nlocs
if (geovals%nlocs /= nobs) then
   write(err_msg,*) myname_, 'error: nlocs of model and obs is inconsistent!'
   call abor1_ftn(err_msg)
endif

! cor_tsfc: model sfc temp at obs height or observed temp at model sfc height
allocate(cor_tsfc(nobs))
cor_tsfc = missing

! get obs variables
allocate(obs_height(nobs))
allocate(obs_psfc(nobs))
call obsspace_get_db(obss, "MetaData", trim(self%station_altitude),obs_height)
call obsspace_get_db(obss, "ObsValue", "stationPressure", obs_psfc)

! get model variables; geovars_list = (/ var_ps, var_geomz, var_sfc_geomz, var_ts, var_prs /)
! MPAS-JEDI: var_sfc_geomz = lowest zgrid interface (surface), geom%zgrid(1,:)
!            var_geomz     = midpoint model layer, geom%height

write(err_msg,'(a)') 'ufo_sfccorrected:'//new_line('a')// &
             'retrieving GeoVaLs with names: '//trim(geovars_list(1))// &
             ', '//trim(geovars_list(2))//', '//trim(geovars_list(3))// &
             ', '//trim(geovars_list(4))//', '//trim(geovars_list(5))// &
             ', '//trim(geovars_list(6))
call fckit_log%debug(err_msg)
call ufo_geovals_get_var(geovals, trim(geovars_list(1)), model_ps)
call ufo_geovals_get_var(geovals, trim(geovars_list(2)), model_geomz)
call ufo_geovals_get_var(geovals, trim(geovars_list(3)), model_sfc_geomz)
call ufo_geovals_get_var(geovals, trim(geovars_list(4)), model_t)
call ufo_geovals_get_var(geovals, trim(geovars_list(5)), model_p)
call ufo_geovals_get_var(geovals, trim(geovars_list(6)), model_t2m)

! discover if the model vertical profiles are ordered top-bottom or not
kbot = 1
do iobs = 1, nlocs
  if (model_geomz%vals(1,iobs) .ne. missing) then
    if (model_geomz%vals(1,iobs) .gt. model_geomz%vals(model_geomz%nval,iobs)) then
      write(err_msg,'(a)') '  ufo_sfccorrected:'//new_line('a')//                   &
                          '  Model vertical height profile is from top to bottom'
      call fckit_log%debug(err_msg)
      kbot = model_geomz%nval
    endif
    exit
  endif
enddo

allocate(model_zs(nobs))
allocate(model_level1(nobs))
allocate(model_psfc(nobs))

! Sijie Pan, read lat and lon
if (.not. allocated(obs_lat)) then
   variable_present = obsspace_has(obss, "MetaData", "latitude")
   if (variable_present) then
      call fckit_log%debug(' allocating obs_lat array')
      allocate(obs_lat(nobs))
      call obsspace_get_db(obss, "MetaData", "latitude", obs_lat)
   else
      call abor1_ftn('Variable latitude@MetaData does not exist, aborting')
   endif
endif
if (.not. allocated(obs_lon)) then
   variable_present = obsspace_has(obss, "MetaData", "longitude")
   if (variable_present) then
      call fckit_log%debug(' allocating obs_lon array')
      allocate(obs_lon(nobs))
      call obsspace_get_db(obss, "MetaData", "longitude", obs_lon)
   else
      call abor1_ftn('Variable longitude@MetaData does not exist, aborting')
   endif
endif

! If needed, we can convert geopotential heights to geometric altitude
! for full model vertical column using gnssro_mod_transform. We need
! to get the latitude of observation to do this.

idx_geop = -1
idx_geop = index(trim(geovars_list(2)),'geopotential')
model_level1 = model_geomz%vals(kbot,:)

if (idx_geop.gt.0) then
   write(err_msg,'(a)') 'ufo_sfccorrected:'//new_line('a')// &
                        ' converting '//trim(geovars_list(2))// &
                        ' variable to z-geometric'
   call fckit_log%debug(err_msg)
   if (.not. allocated(obs_lat)) then
      variable_present = obsspace_has(obss, "MetaData", "latitude")
      if (variable_present) then
         call fckit_log%debug(' allocating obs_lat array')
         allocate(obs_lat(nobs))
         call obsspace_get_db(obss, "MetaData", "latitude", obs_lat)
      else
         call abor1_ftn('Variable latitude@MetaData does not exist, aborting')
      endif
   endif

   if (trim(self%da_sfc_scheme) == "UKMO") allocate(H2000_geop(nobs))

!---------------------------------------------------------------------
   do iobs = 1, nlocs
      if (obs_psfc(iobs).ne.missing) then
         call geop2geometric(latitude=obs_lat(iobs),              &
                        geopotentialH=model_geomz%vals(kbot,iobs),   &
                        geometricZ=model_znew)
         model_level1(iobs) = model_znew
         if (trim(self%da_sfc_scheme) == "UKMO") then
            call geometric2geop(latitude=obs_lat(iobs), &
                           geometricZ=H2000, &
                           geopotentialH=H2000_geop(iobs))
         endif
      else
        if (trim(self%da_sfc_scheme) == "UKMO") H2000_geop(iobs) = missing
      endif
   enddo
endif

! Now do the same if needed for sfc geopotential height.
idx_geop = -1
idx_geop = index(trim(geovars_list(3)),'geopotential')
model_zs = model_sfc_geomz%vals(1,:)
if (idx_geop.gt.0) then
   write(err_msg,'(a)') 'ufo_sfccorrected:'//new_line('a')//      &
                        ' converting '//trim(geovars_list(3))//     &
                        ' variable to z-sfc-geometric'
   call fckit_log%debug(err_msg)
   if (.not. allocated(obs_lat)) then
      variable_present = obsspace_has(obss, "MetaData", "latitude")
      if (variable_present) then
         call fckit_log%debug(' allocating obs_lat array')
         allocate(obs_lat(nobs))
         call obsspace_get_db(obss, "MetaData", "latitude", obs_lat)
      else
         call abor1_ftn('Variable latitude@MetaData does not exist, aborting')
      endif
   endif
   do iobs = 1, nlocs
      if (obs_psfc(iobs).ne.missing) then
         call geop2geometric(latitude=obs_lat(iobs),            &
                   geopotentialH=model_sfc_geomz%vals(1,iobs),  &
                   geometricZ=model_znew)
         model_zs(iobs) = model_znew
      endif
   enddo
endif

!if (allocated(obs_lat)) deallocate(obs_lat)

model_psfc = model_ps%vals(1,:)

   ! get extra obs values
   variable_present_t = .false.
   variable_present_q = .false.

   if (obsspace_has(obss, "ObsValue", "airTemperature")) then
      variable_present_t = .true.
      allocate(obs_t(nobs))
      call obsspace_get_db(obss, "ObsValue", "airTemperature", obs_t)

      variable_present_q = obsspace_has(obss, "ObsValue", "specificHumidity")
      if (variable_present_q) then
         allocate(obs_q(nobs))
         call obsspace_get_db(obss, "ObsValue", "specificHumidity", obs_q)
      end if
   end if

   allocate(model_ts(nobs))

!--------------------------------------------
! do terrain height correction, three options
!--------------------------------------------

select case (trim(self%da_sfc_scheme))
!-------------
case ("WRFDA")
!-------------
! Extrapolate from model lowest level (mid-layer) to model surface w constant lapse

   model_ts = model_t%vals(kbot,:) + Lclr * ( model_level1 - model_zs )  !Lclr = 0.0065 K/m

! get simulation at model surface or obs height
   if (variable_present_t) then
    call da_int(nobs, missing, cor_tsfc, obs_height, obs_t, model_zs, model_ts)
   end if

!------------
case ("UKMO")
!------------
   allocate(model_p_2000(nobs))
   allocate(model_t_2000(nobs))

   do iobs = 1, nobs
      ! vertical interpolation for getting model P and temp at 2000 m
      if (allocated(H2000_geop)) then
         call vert_interp_weights(model_geomz%nval, H2000_geop(iobs), &
              model_geomz%vals(:,iobs), wi, wf)
      else
         call vert_interp_weights(model_geomz%nval, H2000, &
              model_geomz%vals(:,iobs), wi, wf)
      end if

      call vert_interp_apply(model_p%nval, model_p%vals(:,iobs), model_p_2000(iobs), wi, wf)
      call vert_interp_apply(model_t%nval, model_t%vals(:,iobs), model_t_2000(iobs), wi, wf)
   end do
   if (allocated(H2000_geop)) deallocate(H2000_geop)

! get simulation at obs height or bring OBS to model surface height
   call da_int_ukmo(nobs, missing, cor_tsfc, obs_height, obs_t, model_zs, model_psfc, model_t_2000, model_p_2000, model_ts)

   deallocate(model_p_2000)
   deallocate(model_t_2000)

!----------------
case ("GSL")
!----------------

   model_ts = model_t2m%vals(1,:)

   allocate(lr(nobs))

   if (self%lapse_rate_option.eq."Local") then

      if (kbot == 1) then
         ktop_lr = self%local_lapse_rate_level
      else
         ktop_lr = kbot - self%local_lapse_rate_level + 1
      end if

      ! Local lapse rate in K/m
      lr = -1. * (model_t%vals(ktop_lr,:) - model_t%vals(kbot,:)) / &
           (model_geomz%vals(ktop_lr,:) - model_geomz%vals(kbot,:))

      call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)
      write(filename, '(a, i4.4, a)') "local_lapse_rate_", rank, ".txt"
      unit_lr = 100+rank
      open(unit=unit_lr, file=filename, status='unknown')
      do iobs = 1, nobs
        if (model_p%vals(kbot,iobs) > 0 .and. model_p%vals(ktop_lr,iobs) > 0) then
          write(unit_lr, '(i5, 9(f10.3))') &
                iobs, obs_lat(iobs), obs_lon(iobs), model_p%vals(kbot,iobs)/100.0, &
                model_p%vals(ktop_lr,iobs)/100.0, model_geomz%vals(ktop_lr,iobs), &
                model_geomz%vals(kbot,iobs), &
                (model_p%vals(kbot,iobs) - model_p%vals(ktop_lr,iobs)) / 100.0, &
                model_geomz%vals(ktop_lr,iobs) - model_geomz%vals(kbot,iobs), &
                lr(iobs) * 1000.0
        end if
      end do

      if (self%threshold) then
         lr = min(self%max_threshold, max(self%min_threshold, lr))
      end if

   else if (self%lapse_rate_option.eq."Constant") then

      ! Local lapse rate in K/m
      lr = self%lapse_rate

   else

      write(err_msg, '(a)') &
           "No terrain adjustment applied to temperature observations."
      call fckit_log%debug(err_msg)

   endif

   if (self%lapse_rate_option.eq."NoAdjustment") then
      cor_tsfc = obs_t
   else
      call da_int_lr(nobs, missing, cor_tsfc, obs_height, obs_t, model_zs, lr)
   end if

!-----------
case default
!-----------
   write(err_msg,*) "ufo_sfccorrected: da_sfc_scheme not recognized"
   call fckit_log%debug(err_msg)
   call abor1_ftn(err_msg)
end select

!----------------
! update sfc temp
!----------------
do iobsvar = 1, size(self%obsvarindices)
! Get index of row of hofx
   ivar = self%obsvarindices(iobsvar)

! cor_tsfc is corrected obs temp at model sfc
!
   do iobs = 1, nlocs
     if (cor_tsfc(iobs) /= missing) then
! for T_o2m, adjusted hofx - O = model_ts - T_o2m, OBS not adjusted.
       hofx(ivar,iobs) = model_ts(iobs) + obs_t(iobs) - cor_tsfc(iobs)
     else
       hofx(ivar,iobs) = model_ts(iobs)
     end if
   enddo

enddo

deallocate(obs_height)
if (allocated(obs_lat)) deallocate(obs_lat)
if (allocated(obs_lon)) deallocate(obs_lon)
if (variable_present_t) deallocate(obs_t)
if (variable_present_q) deallocate(obs_q)

deallocate(model_zs)
deallocate(model_ts)
deallocate(model_level1)
deallocate(model_psfc)

end subroutine ufo_sfccorrected_simobs

! -----------------------------------------------------------
!> \Conduct terrain height correction for sfc temp
!!
!! \Method: hydrosatic equation
!!
!!  P_o2m = P_o * exp [-grav/rd * (H_m-H_o) / (TV_m + TV_o)/2)
!!
!!  Where:
!!  H_m   = model sfc height
!!  H_o   = obs station height
!!  T_m   = model temp at model sfc level from model 1st level mid-layer
!!  T_o   = obs temp at station height
!!  T_o2m = obs temp interpolated from station height to model sfc level
!!  grav  = gravitational acceleration
!!  rd    = gas constant per mole

subroutine da_int(nobs, missing, cor_tsfc, H_o, T_o, H_m, T_m)
implicit none
integer,                          intent (in)  :: nobs
real(c_double),                   intent (in)  :: missing
real(kind_real), dimension(nobs), intent (in)  :: H_o
real(kind_real), dimension(nobs), intent (in)  :: H_m, T_m
real(kind_real), dimension(nobs), intent (in)  :: T_o
real(kind_real), dimension(nobs), intent (out) :: cor_tsfc
real(kind_real), dimension(nobs)               :: T_m2o, T_o2m
integer i

! T_o2m : obs temp interpolated to model sfc
! T_m2o : model temp interpolated to obs station height

! extrapolate temp from station height to model sfc
! -------------------------------------------------
where ( H_o /= missing .and. T_o /= missing )

   T_o2m = T_o - Lclr * ( H_m - H_o)
   T_m2o = T_m + Lclr * ( H_m - H_o)

elsewhere
   T_o2m = T_m   ! to give zero analysis increment
   T_m2o = T_o   ! to give zero analysis increment
end where

   cor_tsfc = T_o2m
!  cor_tsfc = T_m2o   ! for testing only

end subroutine da_int

! ------------------------------------------------------------------------------
!> \Conduct terrain height correction for sfc temp
!!
!! \Reference: Ingleby,2013. UKMO Technical Report No: 582. Appendix 1.
!!
!! \Method: integrate hydrosatic equation dp/dz=-rho*g/RT to get P_m2o first, equation:
!!
!!  (P_m2o/P_m) = (T_m2o/T_m)** (grav/rd*L)
!!
!!  Where:
!!  P_m2o : model sfc pressure at station height
!!  P_m   : model sfc pressure
!!  T_m   : temp at model sfc height; derived from T_2000
!!  T_m2o : model sfc temp at station height
!!  grav  : gravitational acceleration
!!  rd    : gas constant per mole
!!  Lclr  : constant lapse rate (0.0065 K/m)
!!
!!  To avoid dirunal/local variations, use T_2000 (2000 m above model sfc height) instead of direct T_m
!!
!!  T_m = T_2000 * (P_m / P_2000) ** (rd*L/grav)
!!
!! Where:
!!  P_2000 : model pressure at 2000 m
!!  T_2000 : model dry temp at 2000 m

subroutine da_int_ukmo(nobs, missing, cor_tsfc, H_o, T_o, H_m, P_m, T_2000, P_2000, T_m)
implicit none
integer,                          intent (in)  :: nobs  ! total observation number
real(c_double),                   intent (in)  :: missing
real(kind_real), dimension(nobs), intent (in)  :: H_o, T_o  ! observed Height and temp
real(kind_real), dimension(nobs), intent (in)  :: H_m, P_m, T_2000, P_2000 ! model Height, and TV/P at 2000 m

real(kind_real), dimension(nobs), intent (out) :: T_m  ! model sfc temp from 2000m)

real(kind_real), dimension(nobs), intent (out) :: cor_tsfc
real(kind_real), dimension(nobs)               :: T_m2o, T_o2m ! model Temp at obs height; observed Temp at model sfc height
real(kind_real)                                :: ind
integer i

! constant power exponent
ind = rd * Lclr / grav

where ( H_o /= missing .and. T_o /= missing )
   ! T_m   : bg temp at model sfc
   ! T_o2m : obs temp at model sfc
   ! T_m2o : bg temp at obs station height

   T_m = T_2000 * (P_m / P_2000) ** ind  ! P_2000 to model surface
   T_o2m = T_o - Lclr * ( H_m - H_o)     ! OBS height to model surface
   T_m2o = T_m + Lclr * ( H_m - H_o)     ! model surface to OBS height

elsewhere
   T_o2m = T_m
   T_m2o = T_o
end where

   cor_tsfc = T_o2m
!  cor_tsfc = T_m2o   ! for testing only

end subroutine da_int_ukmo

! -----------------------------------------------------------
!> \Conduct terrain height correction for sfc temp
!!
!! \Method: Constant Lapse Rate (adiabatic by default)
!!
!!  Where:
!!  H_m   = model sfc height
!!  H_o   = obs station height
!!  T_o   = obs temp at station height
!!  T_lr  = temperature lapse rate
!!  T_o2m = obs temp interpolated from station height to model sfc level

subroutine da_int_lr(nobs, missing, cor_tsfc, H_o, T_o, H_m, T_lr)
implicit none
integer,                          intent (in)  :: nobs
real(c_double),                   intent (in)  :: missing
real(kind_real), dimension(nobs), intent (in)  :: H_o
real(kind_real), dimension(nobs), intent (in)  :: H_m
real(kind_real), dimension(nobs), intent (in)  :: T_o
real(kind_real), dimension(nobs), intent (in)  :: T_lr
real(kind_real), dimension(nobs), intent (out) :: cor_tsfc
real(kind_real), dimension(nobs)               :: T_o2m, T_m2o
integer i

! T_o2m : obs temp interpolated to model sfc

! Adjust temp from station height to model sfc based on lapse rate
! -------------------------------------------------
where ( H_o /= missing .and. T_o /= missing )

   T_o2m = T_o - T_lr * ( H_m - H_o)

elsewhere
   T_o2m = T_o
end where

   cor_tsfc = T_o2m

end subroutine da_int_lr

! ------------------------------------------------------------------------------
end module ufo_sfccorrected_mod
