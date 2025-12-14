! (C) Copyright 2017 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

module mpas_fields_mod

! atlas
use atlas_module, only: atlas_field, atlas_fieldset, atlas_real, atlas_metadata

! fckit
use fckit_configuration_module, only: fckit_configuration
use fckit_log_module, only: fckit_log
use iso_c_binding

!oops
use datetime_mod
use kinds, only: kind_real
use oops_variables_mod, only: oops_variables
use string_utils, only: swap_name_member

!ufo
use ufo_vars_mod, only: MAXVARLEN, ufo_vars_getindex, var_prsi
use ufo_geovals_mod, only: ufo_geovals

!MPAS-Model
use atm_core, only: atm_simulation_clock_init, atm_compute_output_diagnostics
use mpas_constants
use mpas_derived_types
use mpas_kind_types, only: StrKIND
use mpas_pool_routines
use mpas_stream_manager
use mpas_timekeeping
use mpas_dmpar, only : mpas_dmpar_exch_halo_field, mpas_dmpar_exch_halo_adj_field

!mpas-jedi
use mpas_constants_mod
use mpas_geom_mod
use mpas4da_mod
use mpas2ufo_vars_mod, only: w_to_q, theta_to_temp, vv_to_vva
use mpas_kinds, only : c_real_type

implicit none

private

public :: mpas_fields, mpas_fields_registry, &
          create_fields, delete_fields, &
          copy_fields, copy_pool, &
          update_diagnostic_fields, &
          mpas_hydrometeor_fields,  &
          mpas_re_fields, &
          cellCenteredWindFields, &
          moistureFields, &
          analysisThermoFields, &
          modelThermoFields, &
          sacaStateFields, sacaObsFields

! ------------------------------------------------------------------------------

   !> Fortran derived type to hold MPAS field
   type :: mpas_fields
     private

     type (mpas_geom), pointer, public :: geom                            ! grid and MPI infos
     type (MPAS_streamManager_type), pointer, public :: manager
     type (MPAS_Clock_type), pointer, public :: clock
     integer, public :: nf                                                ! Number of variables in subFields
     character(len=MAXVARLEN), allocatable, public :: fldnames(:)         ! Variable identifiers
     type (mpas_pool_type), pointer, public        :: subFields => null() !---> state variables (to be analyzed)
     integer, public :: nf_ci                                             ! Number of variables in CI
     character(len=MAXVARLEN), allocatable, public :: fldnames_ci(:)      ! Control increment identifiers
     integer, allocatable, public :: nvert(:)                             ! number of vertical levels of each field

     contains

     procedure :: axpy         => axpy_
     procedure :: dot_prod     => dot_prod_
     procedure :: gpnorm       => gpnorm_
     procedure :: random       => random_
     procedure :: rms          => rms_
     procedure :: self_add     => self_add_
     procedure :: self_schur   => self_schur_
     procedure :: self_mult    => self_mult_
     procedure :: self_sub     => self_sub_
     procedure :: zeros        => zeros_
     procedure :: ones         => ones_

     procedure :: copy         => copy_fields
     procedure :: create       => create_fields
     procedure :: populate     => populate_subfields
     procedure :: delete       => delete_fields
     procedure :: read_file    => read_fields
     procedure :: write_file   => write_fields
     procedure :: serial_size  => serial_size
     procedure :: serialize    => serialize_fields
     procedure :: deserialize  => deserialize_fields
     procedure :: to_fieldset
     procedure :: from_fieldset
     !has
     generic, public :: has => has_field, has_fields
     procedure :: has_field
     procedure :: has_fields

     !get
     generic, public :: get => &
        get_data, &
        get_field_i1, get_field_i2, &
        get_field_r1, get_field_r2, &
        get_array_i1, get_array_i2, &
        get_array_r1, get_array_r2
     procedure :: &
        get_data, &
        get_field_i1, get_field_i2, &
        get_field_r1, get_field_r2, &
        get_array_i1, get_array_i2, &
        get_array_r1, get_array_r2

     !copy_to
     generic, public :: copy_to => &
        copy_to_other_fields_field, &
        copy_to_other_fields, &
        copy_to_other_pool_field, &
        copy_to_other_pool
     procedure :: &
        copy_to_other_fields_field, &
        copy_to_other_fields, &
        copy_to_other_pool_field, &
        copy_to_other_pool

     !copy_to_ad
     generic, public :: copy_to_ad => &
        copy_to_other_fields_field_ad, &
        copy_to_other_fields_ad, &
        copy_to_other_pool_field_ad, &
        copy_to_other_pool_ad
     procedure :: &
        copy_to_other_fields_field_ad, &
        copy_to_other_fields_ad, &
        copy_to_other_pool_field_ad, &
        copy_to_other_pool_ad

     !copy_from
     generic, public :: copy_from => &
        copy_from_other_fields_field, &
        copy_from_other_fields, &
        copy_from_other_pool_field, &
        copy_from_other_pool
     procedure :: &
        copy_from_other_fields_field, &
        copy_from_other_fields, &
        copy_from_other_pool_field, &
        copy_from_other_pool

     !push_back
     generic, public :: push_back => &
        push_back_other_fields_field, &
        push_back_other_fields, &
        push_back_other_pool_field, &
        push_back_other_pool
     procedure :: &
        push_back_other_fields_field, &
        push_back_other_fields, &
        push_back_other_pool_field, &
        push_back_other_pool


  end type mpas_fields

!   abstract interface
!
!   ! ------------------------------------------------------------------------------
!
!      subroutine read_file_(self, f_conf, vdate)
!         import mpas_fields, fckit_configuration, datetime
!         implicit none
!         class(mpas_fields),         intent(inout) :: self
!         type(fckit_configuration), intent(in)    :: f_conf
!         type(datetime),            intent(inout) :: vdate
!      end subroutine read_file_
!
!   ! ------------------------------------------------------------------------------
!
!   end interface

   character(len=MAXVARLEN) :: mpas_hydrometeor_fields(12) = &
      [ character(len=MAXVARLEN) :: &
      "cloud_liquid_water", "cloud_liquid_ice", "rain_water", "snow_water", "graupel", "hail", &
      "cloud_droplet_number_concentration", "cloud_ice_number_concentration", "rain_number_concentration", &
      "snow_number_concentration", "graupel_number_concentration", "hail_number_concentration" ]
   character(len=MAXVARLEN) :: mpas_re_fields(3) = &
      [ character(len=MAXVARLEN) :: &
      "re_cloud", "re_ice  ", "re_snow " ]
   character(len=MAXVARLEN), parameter :: cellCenteredWindFields(2) = &
      [character(len=MAXVARLEN) :: &
       'eastward_wind', 'northward_wind']
   character(len=MAXVARLEN), parameter :: moistureFields(2) = &
      [character(len=MAXVARLEN) :: &
       'water_vapor_mixing_ratio_wrt_dry_air', 'water_vapor_mixing_ratio_wrt_moist_air']
   character(len=MAXVARLEN), parameter :: analysisThermoFields(2) = &
      [character(len=MAXVARLEN) :: &
       'air_pressure_at_surface', 'air_temperature']
   character(len=MAXVARLEN), parameter :: modelThermoFields(4) = &
      [character(len=MAXVARLEN) :: &
       'water_vapor_mixing_ratio_wrt_dry_air', 'air_pressure', 'dry_air_density', 'air_potential_temperature']
   character(len=MAXVARLEN), parameter :: sacaStateFields(9) = &
      [character(len=MAXVARLEN) :: &
       'water_vapor_mixing_ratio_wrt_dry_air', 'cloud_liquid_water', 'cloud_liquid_ice', 'snow_water', &
       'cldfrac', 'dry_air_density', 'air_temperature', 'air_pressure', 'xland']
   character(len=MAXVARLEN), parameter :: sacaObsFields(2) = &
      [character(len=MAXVARLEN) :: &
       'cldmask', 'brtemp']


   integer, parameter    :: max_string=8000
   character(max_string) :: message

#define LISTED_TYPE mpas_fields

!> Linked list interface - defines registry_t type
#include <oops/util/linkedList_i.f>

!> Global registry
type(registry_t) :: mpas_fields_registry

! ------------------------------------------------------------------------------

contains

! ------------------------------------------------------------------------------

!> Linked list implementation
#include <oops/util/linkedList_c.f>

! ------------------------------------------------------------------------------

subroutine create_fields(self, geom, vars, vars_ci)

    implicit none

    class(mpas_fields),   intent(inout)       :: self
    type(mpas_geom),      intent(in), pointer :: geom
    type(oops_variables), intent(in)          :: vars, vars_ci

    integer :: ivar, ierr

    self % nf = vars % nvars()
    allocate(self % fldnames(self % nf))
    do ivar = 1, self % nf
       self % fldnames(ivar) = trim(vars % variable(ivar))
    end do

    self % nf_ci = vars_ci % nvars()
    allocate(self % fldnames_ci(self % nf_ci))
    do ivar = 1, self % nf_ci
       self % fldnames_ci(ivar) = trim(vars_ci % variable(ivar))
    end do

    write(message,*) "DEBUG: create_fields: self % fldnames(:) =",self % fldnames(:)
    call fckit_log%debug(message)

    ! link geom
    if (associated(geom)) then
      self % geom => geom
    else
      call abor1_ftn("--> create_fields: geom not associated")
    end if

    ! clock creation
    allocate(self % clock)
    call atm_simulation_clock_init(self % clock, self % geom % domain % blocklist % configs, ierr)
    if ( ierr .ne. 0 ) then
       call abor1_ftn("--> create_fields: atm_simulation_clock_init problem")
    end if

    call self%populate()

    ! pre-determine number of vertical levels for each variables
    allocate(self % nvert(self % nf))
    do ivar = 1, self % nf
       self % nvert(ivar) = getVertLevels(self % subFields, self % fldnames(ivar))
    end do

    return

end subroutine create_fields

! ------------------------------------------------------------------------------

subroutine populate_subFields(self)

    implicit none
    class(mpas_fields), intent(inout) :: self

    call da_template_pool(self % geom, self % subFields, self % nf, self % fldnames)

end subroutine populate_subFields

! ------------------------------------------------------------------------------

subroutine delete_fields(self)

   implicit none
   class(mpas_fields), intent(inout) :: self
   integer :: ierr = 0

   if (allocated(self % fldnames)) deallocate(self % fldnames)
   if (allocated(self % fldnames_ci)) deallocate(self % fldnames_ci)
   if (allocated(self % nvert)) deallocate(self % nvert)

   call fckit_log%debug('--> delete_fields: deallocate subFields Pool')
   call delete_pool(self % subFields)

   call mpas_destroy_clock(self % clock, ierr)
   if ( ierr .ne. 0  ) then
      call fckit_log%info ('--> delete_fields deallocate clock failed')
   end if
   call fckit_log%debug('--> delete_fields done')

   return

end subroutine delete_fields

! ------------------------------------------------------------------------------

subroutine delete_pool(pool)

   implicit none
   type(mpas_pool_type), pointer, intent(inout) :: pool

   if (associated(pool)) then
      call mpas_pool_destroy_pool(pool)
   end if

end subroutine delete_pool

! ------------------------------------------------------------------------------

subroutine copy_fields(self,rhs)

   implicit none
   class(mpas_fields), intent(inout) :: self
   class(mpas_fields), intent(in)    :: rhs
   type (MPAS_Time_type) :: rhs_time
   integer :: ierr

   call fckit_log%debug('--> copy_fields: copy subFields Pool')

   self % nf = rhs % nf
   if (allocated(self % fldnames)) deallocate(self % fldnames)
   allocate(self % fldnames(self % nf))
   self % fldnames(:) = rhs % fldnames(:)

   self % nf_ci = rhs % nf_ci
   if (allocated(self % fldnames_ci)) deallocate(self % fldnames_ci)
   allocate(self % fldnames_ci(self % nf_ci))
   self % fldnames_ci(:) = rhs % fldnames_ci(:)

   rhs_time = mpas_get_clock_time(rhs % clock, MPAS_NOW, ierr)
   call mpas_set_clock_time(self % clock, rhs_time, MPAS_NOW)

   call copy_pool(rhs % subFields, self % subFields)

   call fckit_log%debug('--> copy_fields done')

end subroutine copy_fields

! ------------------------------------------------------------------------------

subroutine copy_pool(pool_src, pool)

   implicit none
   type(mpas_pool_type), pointer, intent(in)    :: pool_src
   type(mpas_pool_type), pointer, intent(inout) :: pool

   ! Duplicate the members of pool_src into pool and
   ! do a deep copy of the fields
   call delete_pool(pool)
   call mpas_pool_create_pool(pool)
   call mpas_pool_clone_pool(pool_src, pool)

end subroutine copy_pool

! ------------------------------------------------------------------------------

subroutine read_fields(self, f_conf, vdate)

   implicit none
   class(mpas_fields),        intent(inout) :: self     !< Field
   type(fckit_configuration), intent(in)    :: f_conf   !< Configuration
   type(datetime),            intent(inout) :: vdate    !< DateTime
   character(len=:), allocatable :: str
   character(len=20)       :: sdate
   type (MPAS_Time_type)   :: local_time
   character (len=StrKIND) :: dateTimeString, streamID, time_string, filename, temp_filename
   integer                 :: ierr = 0, ngrid
   logical :: Model2AnalysisVariableChange
   type (mpas_pool_type), pointer :: state, diag, mesh
   type (field2DReal), pointer    :: pressure, pressure_base, pressure_p

   call fckit_log%debug('--> read_fields')
   if (f_conf%get("date", str)) then
      sdate = str
      call datetime_set(sdate, vdate)
      dateTimeString = '$Y-$M-$D_$h:$m:$s'
      call cvt_oopsmpas_date(sdate,dateTimeString,1)
   else
      dateTimeString = '2023-09-21_00:00:00' ! 1st MPAS-JEDI tutorial
   end if

   call f_conf%get_or_die("filename",str)
   call swap_name_member(f_conf, str)
   temp_filename = str
   write(message,*) '--> read_fields: Reading ',trim(temp_filename)
   call fckit_log%debug(message)

   ! streamID (default: background)
   ! Name of the stream in streams.atmosphere or 'streams_file' associated with self%geom
   ! associated with this state.  Can be any string as long as it is included within the
   ! applicable streams.atmosphere file. Examples of stream names in the MPAS-JEDI distribution
   ! are 'background', 'analysis', 'ensemble', 'control', 'da_state'. Each of those streams has
   ! unique properties, including the MPAS fields that are read/written.
   streamID = 'background'
   if (f_conf%get("stream name", str)) then
     streamID = str
   end if

   ! temp_filename = 'restart.$Y-$M-$D_$h.$m.$s.nc'
   ! GD look at oops/src/util/datetime_mod.F90
   ! we probably need to extract from vdate a string to enforce the reading ..
   ! and then can be like this ....
   ierr = 0
   self % manager => self % geom % domain % streamManager
   write(message,*) '--> read_fields: dateTimeString: ',trim(dateTimeString)
   call fckit_log%debug(message)
   call mpas_set_time(local_time, dateTimeString=dateTimeString, ierr=ierr)
   call mpas_set_clock_time(self % clock, local_time, MPAS_NOW)
   call mpas_set_clock_time(self % geom % domain % clock, local_time, MPAS_START_TIME)
   call mpas_expand_string(dateTimeString, -1, temp_filename, filename)
   call MPAS_stream_mgr_set_property(self % manager, streamID, MPAS_STREAM_PROPERTY_FILENAME, filename)
   write(message,*) '--> read_fields: Reading ',trim(filename)
   call fckit_log%debug(message)
   if (trim(streamID) == "ensemble") then
      call MPAS_stream_mgr_read(self % manager, streamID=streamID, &
                           & when=dateTimeString, rightNow=.True., whence=MPAS_STREAM_NEAREST, ierr=ierr)
   else
      call MPAS_stream_mgr_read(self % manager, streamID=streamID, &
                           & when=dateTimeString, rightNow=.True., ierr=ierr)
   endif
   if ( ierr .ne. 0  ) then
      write(message,*) '--> read_fields: MPAS_stream_mgr_read failed ierr=',ierr
      call abor1_ftn(message)
   end if

   ! Model2AnalysisVariableChange (default: true):
   ! indicates whether to transform from model fields (pressure_p, pressure_base, theta, qv)
   ! to analysis fields (temperature, specific_humidity).
   ! When streamID=='control' or 'saca_obs', the default value is changed to false.
   ! For example, the transform is not carried out when reading analysis fields directly (e.g.,
   ! background error standard deviation is read/written using streamID=='control') or
   ! when reading the obs-related fields for Non-Variational SAtellite-based Cloud Analysis (SACA).
   Model2AnalysisVariableChange = .True.
   if(streamID == 'control'.or. streamID == 'saca_obs') Model2AnalysisVariableChange = .False.
   if (f_conf%has("transform model to analysis")) then
      call f_conf%get_or_die("transform model to analysis", Model2AnalysisVariableChange)
   end if

   if(Model2AnalysisVariableChange) then
      !(1) diagnose pressure
      call mpas_pool_get_subpool(self % geom % domain % blocklist % structs, 'diag', diag)
      call mpas_pool_get_field(diag, 'pressure_p', pressure_p)
      call mpas_pool_get_field(diag, 'pressure_base', pressure_base)
      call mpas_pool_get_field(diag, 'pressure', pressure)
      ngrid = self % geom % nCellsSolve
      pressure%array(:,1:ngrid) = pressure_base%array(:,1:ngrid) + pressure_p%array(:,1:ngrid)

      !(2) copy all to subFields & diagnose temperature
      if ( self % has('upward_air_velocity') )then
         call update_diagnostic_fields(self % geom, self % subFields, self % geom % nCellsSolve, self % geom % nVertLevels)
      else
         call update_diagnostic_fields(self % geom, self % subFields, self % geom % nCellsSolve)
      end if
   else
      call da_copy_all2sub_fields(self % geom, self % subFields)
   endif

end subroutine read_fields


subroutine update_diagnostic_fields(geom, subFields, ngrid, nVL)

   implicit none
   type (mpas_geom),      pointer,  intent(in)    :: geom
   type (mpas_pool_type), pointer,  intent(inout) :: subFields
   integer,                         intent(in)    :: ngrid
   integer, optional,               intent(in)    :: nVL
   type (field2DReal), pointer    :: theta, pressure, temperature, specific_humidity
   type (field2DReal), pointer    :: vertical_velocity_unstagger, vertical_velocity, dbztest
   type (field3DReal), pointer    :: scalars
   type (mpas_pool_type), pointer :: state
   integer, pointer :: index_qv

   !(1) copy all to subFields
   call da_copy_all2sub_fields(geom, subFields)

   !(2) diagnose temperature
   !Special case: Convert theta and pressure to temperature
   !              Convert water vapor mixing ratio to specific humidity [ q = w / (1 + w) ]
   !NOTE: This formula is somewhat different with MPAS one's (in physics, they use "exner")
   !    : If T diagnostic is added in, for example, subroutine atm_compute_output_diagnostics,
   !    : we need to include "exner" in stream_list.for.reading

   call mpas_pool_get_field(geom % domain % blocklist % allFields, 'theta', theta)
   call mpas_pool_get_field(geom % domain % blocklist % allFields, 'pressure', pressure)
   call mpas_pool_get_field(subFields, 'air_temperature', temperature)
   call mpas_pool_get_field(geom % domain % blocklist % allFields, 'scalars', scalars)
   call mpas_pool_get_field(subFields, 'water_vapor_mixing_ratio_wrt_moist_air', specific_humidity)

   call mpas_pool_get_field(geom % domain % blocklist % allFields, 'w', vertical_velocity)
   call mpas_pool_get_field(subFields, 'upward_air_velocity', vertical_velocity_unstagger)

   call mpas_pool_get_subpool(geom % domain % blocklist % structs,'state',state)
   call mpas_pool_get_dimension(state, 'index_qv', index_qv)

   call theta_to_temp(theta % array(:,1:ngrid), pressure % array(:,1:ngrid), temperature % array(:,1:ngrid))
   call w_to_q( scalars % array(index_qv,:,1:ngrid) , specific_humidity % array(:,1:ngrid) )
   if (present(nVL)) then
      call vv_to_vva( vertical_velocity % array(1:nVL+1, 1:ngrid), &
                                        vertical_velocity_unstagger % array(1:nVL,1:ngrid), ngrid, nVL)
   end if
   ! Only accept background refl10cm no lower than 0 dBZ
   call da_posdef( subFields, ['equivalent_reflectivity_factor'])

end subroutine update_diagnostic_fields

! ------------------------------------------------------------------------------

subroutine write_fields(self, f_conf, vdate)

   implicit none
   class(mpas_fields),        intent(inout) :: self   !< Field
   type(fckit_configuration), intent(in)    :: f_conf !< Configuration
   type(datetime),            intent(in)    :: vdate  !< DateTime
   character(len=:), allocatable :: str
   character(len=20)       :: validitydate
   integer                 :: ierr
   type (MPAS_Time_type)   :: fld_time, write_time
   character (len=StrKIND) :: dateTimeString, dateTimeString2, streamID, time_string, filename, temp_filename

   call da_copy_sub2all_fields(self % geom, self % subFields)

   call datetime_to_string(vdate, validitydate)
   write(message,*) '--> write_fields: ',trim(validitydate)
   call fckit_log%debug(message)
   call f_conf%get_or_die("filename",str)
   call swap_name_member(f_conf, str)
   temp_filename = str
   write(message,*) '--> write_fields: ',trim(temp_filename)
   call fckit_log%debug(message)
   !temp_filename = 'restart.$Y-$M-$D_$h.$m.$s.nc'
   ! GD look at oops/src/util/datetime_mod.F90
   ! we probably need to extract from vdate a string to enforce the reading ..
   ! and then can be like this ....
   dateTimeString = '$Y-$M-$D_$h:$m:$s'
   call cvt_oopsmpas_date(validitydate,dateTimeString,-1)
   ierr = 0
   call mpas_set_time(write_time, dateTimeString=dateTimeString, ierr=ierr)
   fld_time = mpas_get_clock_time(self % clock, MPAS_NOW, ierr)
   call mpas_get_time(fld_time, dateTimeString=dateTimeString2, ierr=ierr)
   write(message,*) 'check time --> write_fields: write_time,fld_time: ',trim(dateTimeString),trim(dateTimeString2)
   call fckit_log%debug(message)
   call mpas_expand_string(dateTimeString, -1, trim(temp_filename), filename)

   self % manager => self % geom % domain % streamManager

   ! streamID (default: da_state)
   ! Name of the stream in streams.atmosphere or 'streams_file' associated with self%geom
   ! associated with this state.  Can be any string as long as it is included within the
   ! applicable streams.atmosphere file. Examples of stream names in the MPAS-JEDI distribution
   ! are 'background', 'analysis', 'ensemble', 'control', 'da_state'. Each of those streams has
   ! unique properties, including the MPAS fields that are read/written.
   streamID = 'da_state'
   if (f_conf%get("stream name", str)) then
     streamID = str
   end if

   call MPAS_stream_mgr_set_property(self % manager, streamID, MPAS_STREAM_PROPERTY_FILENAME, filename)

   write(message,*) '--> write_fields: writing ',trim(filename)
   call fckit_log%debug(message)
   call mpas_stream_mgr_write(self % geom % domain % streamManager, streamID=streamID, &
        forceWriteNow=.true., writeTime=dateTimeString, ierr=ierr)
   if ( ierr .ne. 0  ) then
     write(message,*) '--> write_fields: MPAS_stream_mgr_write failed ierr=',ierr
     call abor1_ftn(message)
   end if

end subroutine write_fields

! ------------------------------------------------------------------------------

subroutine zeros_(self)

   implicit none
   class(mpas_fields), intent(inout) :: self

   call da_constant(self % subFields, MPAS_JEDI_ZERO_kr, fld_select = self % fldnames_ci)

end subroutine zeros_

! ------------------------------------------------------------------------------

subroutine ones_(self)

   implicit none
   class(mpas_fields), intent(inout) :: self

   call da_constant(self % subFields, MPAS_JEDI_ONE_kr, fld_select = self % fldnames_ci)

end subroutine ones_

! ------------------------------------------------------------------------------

subroutine random_(self)

   implicit none
   class(mpas_fields), intent(inout) :: self

   call da_random(self % subFields, fld_select = self % fldnames_ci)

end subroutine random_

! ------------------------------------------------------------------------------

subroutine gpnorm_(self, nf, pstat)

   implicit none
   class(mpas_fields),   intent(in)  :: self
   integer,              intent(in)  :: nf
   real(kind=RKIND), intent(out) :: pstat(3, nf)

   call da_gpnorm(self % subFields, self % geom % domain % dminfo, nf, pstat, fld_select = self % fldnames_ci(1:nf))

end subroutine gpnorm_

! ------------------------------------------------------------------------------

subroutine rms_(self, prms)

   implicit none
   class(mpas_fields),   intent(in)  :: self
   real(kind=RKIND), intent(out) :: prms

   call da_fldrms(self % subFields, self % geom % domain % dminfo, prms, fld_select = self % fldnames_ci)

end subroutine rms_

! ------------------------------------------------------------------------------

subroutine self_add_(self,rhs)

   implicit none
   class(mpas_fields), intent(inout) :: self
   class(mpas_fields), intent(in)    :: rhs
   character(len=StrKIND) :: kind_op

   kind_op = 'add'
   call da_operator(trim(kind_op), self % subFields, rhs % subFields, fld_select = self % fldnames_ci)

end subroutine self_add_

! ------------------------------------------------------------------------------

subroutine self_schur_(self,rhs)

   implicit none
   class(mpas_fields), intent(inout) :: self
   class(mpas_fields), intent(in)    :: rhs
   character(len=StrKIND) :: kind_op

   kind_op = 'schur'
   call da_operator(trim(kind_op), self % subFields, rhs % subFields, fld_select = self % fldnames_ci)

end subroutine self_schur_

! ------------------------------------------------------------------------------

subroutine self_sub_(self,rhs)

   implicit none
   class(mpas_fields), intent(inout) :: self
   class(mpas_fields), intent(in)    :: rhs
   character(len=StrKIND) :: kind_op

   kind_op = 'sub'
   call da_operator(trim(kind_op), self % subFields, rhs % subFields, fld_select = self % fldnames_ci)

end subroutine self_sub_

! ------------------------------------------------------------------------------

subroutine self_mult_(self,zz)

   implicit none
   class(mpas_fields),   intent(inout) :: self
   real(kind=RKIND), intent(in)    :: zz

   call da_self_mult(self % subFields, zz)

end subroutine self_mult_

! ------------------------------------------------------------------------------

subroutine axpy_(self,zz,rhs)

   implicit none
   class(mpas_fields),   intent(inout) :: self
   real(kind=RKIND), intent(in)    :: zz
   class(mpas_fields),   intent(in)    :: rhs

   call da_axpy(self % subFields, rhs % subFields, zz, fld_select = self % fldnames_ci)

end subroutine axpy_

! ------------------------------------------------------------------------------

subroutine dot_prod_(self,fld,zprod)

   implicit none
   class(mpas_fields),    intent(in)    :: self, fld
   real(kind=RKIND),  intent(inout) :: zprod

   call da_dot_product(self % subFields, fld % subFields, self % geom % domain % dminfo, zprod)

end subroutine dot_prod_

!------------------------------------------------------------------------------

subroutine serial_size(self, vsize)

   implicit none

   ! Passed variables
   class(mpas_fields),intent(in) :: self
   integer(c_size_t),intent(out) :: vsize !< Size

   ! Local variables
   type (mpas_pool_iterator_type) :: poolItr
   integer, allocatable :: dimSizes(:)

   ! Initialize
   vsize = 0

   call mpas_pool_begin_iteration(self%subFields)
   do while ( mpas_pool_get_next_member(self%subFields, poolItr) )
      if (poolItr % memberType == MPAS_POOL_FIELD) then
         dimSizes = getSolveDimSizes(self%subFields, poolItr%memberName)
         vsize = vsize + product(dimSizes)
         deallocate(dimSizes)
      endif
   enddo

end subroutine serial_size

! ------------------------------------------------------------------------------

subroutine serialize_fields(self, vsize, vect_inc)

   implicit none

   ! Passed variables
   class(mpas_fields),intent(in) :: self          !< Increment
   integer(c_size_t),intent(in) :: vsize          !< Size
   real(c_real_type),intent(out) :: vect_inc(vsize) !< Vector

   ! Local variables
   integer :: index, nvert, nhoriz, vv, hh
   type (mpas_pool_iterator_type) :: poolItr
   integer, allocatable :: dimSizes(:)

   real (kind=RKIND), dimension(:), pointer :: r1d_ptr_a
   real (kind=RKIND), dimension(:,:), pointer :: r2d_ptr_a
   integer, dimension(:), pointer :: i1d_ptr_a
   integer, dimension(:,:), pointer :: i2d_ptr_a

   ! Initialize
   index = 0

   call mpas_pool_begin_iteration(self%subFields)
   do while ( mpas_pool_get_next_member(self%subFields, poolItr) )
      if (poolItr % memberType == MPAS_POOL_FIELD) then
         dimSizes = getSolveDimSizes(self%subFields, poolItr%memberName)
         if (poolItr % nDims == 1) then
            nhoriz = dimSizes(1)
            if (poolItr % dataType == MPAS_POOL_INTEGER) then
               call mpas_pool_get_array(self%subFields, trim(poolItr % memberName), i1d_ptr_a)
               do hh = 1, nhoriz
                  vect_inc(index + 1) = real(i1d_ptr_a(hh), kind=c_real_type)
                  index = index + 1
               enddo
            else if (poolItr % dataType == MPAS_POOL_REAL) then
               call mpas_pool_get_array(self%subFields, trim(poolItr % memberName), r1d_ptr_a)
               do hh = 1, nhoriz
                  vect_inc(index + 1) = r1d_ptr_a(hh)
                  index = index + 1
               enddo
            endif
         elseif (poolItr % nDims == 2) then
            nvert = dimSizes(1)
            nhoriz = dimSizes(2)
            if (poolItr % dataType == MPAS_POOL_INTEGER) then
               call mpas_pool_get_array(self%subFields, trim(poolItr % memberName), i2d_ptr_a)
               do vv = 1, nvert
                  do hh = 1, nhoriz
                     vect_inc(index + 1) = real(i2d_ptr_a(vv, hh), kind=c_real_type)
                     index = index + 1
                  enddo
               enddo
            else if (poolItr % dataType == MPAS_POOL_REAL) then
               call mpas_pool_get_array(self%subFields, trim(poolItr % memberName), r2d_ptr_a)
               do vv = 1, nvert
                  do hh = 1, nhoriz
                     vect_inc(index + 1) = r2d_ptr_a(vv, hh)
                     index = index + 1
                  enddo
               enddo
            endif
         else
            write(message,*) '--> serialize_fields: poolItr % nDims == ',poolItr % nDims,' not handled'
            call abor1_ftn(message)
         endif
         deallocate(dimSizes)
      endif
   enddo

end subroutine serialize_fields

! --------------------------------------------------------------------------------------------------

subroutine deserialize_fields(self, vsize, vect_inc, index)

   implicit none

   ! Passed variables
   class(mpas_fields),intent(inout) :: self      !< Increment
   integer(c_size_t),intent(in) :: vsize         !< Size
   real(c_real_type),intent(in) :: vect_inc(vsize) !< Vector
   integer(c_size_t),intent(inout) :: index      !< Index

   ! Local variables
   integer :: nvert, nhoriz, vv, hh
   type (mpas_pool_iterator_type) :: poolItr
   integer, allocatable :: dimSizes(:)

   real (kind=RKIND), dimension(:), pointer :: r1d_ptr_a
   real (kind=RKIND), dimension(:,:), pointer :: r2d_ptr_a
   integer, dimension(:), pointer :: i1d_ptr_a
   integer, dimension(:,:), pointer :: i2d_ptr_a

   call mpas_pool_begin_iteration(self%subFields)
   do while ( mpas_pool_get_next_member(self%subFields, poolItr) )
      if (poolItr % memberType == MPAS_POOL_FIELD) then
         dimSizes = getSolveDimSizes(self%subFields, poolItr%memberName)
         if (poolItr % nDims == 1) then
            nhoriz = dimSizes(1)
            if (poolItr % dataType == MPAS_POOL_INTEGER) then
               call mpas_pool_get_array(self%subFields, trim(poolItr % memberName), i1d_ptr_a)
               do hh = 1, nhoriz
                  i1d_ptr_a(hh) = nint ( vect_inc(index + 1) )
                  index = index + 1
               enddo
            else if (poolItr % dataType == MPAS_POOL_REAL) then
               call mpas_pool_get_array(self%subFields, trim(poolItr % memberName), r1d_ptr_a)
               do hh = 1, nhoriz
                  r1d_ptr_a(hh) = vect_inc(index + 1)
                  index = index + 1
               enddo
            endif
         elseif (poolItr % nDims == 2) then
            nvert = dimSizes(1)
            nhoriz = dimSizes(2)
            if (poolItr % dataType == MPAS_POOL_INTEGER) then
               call mpas_pool_get_array(self%subFields, trim(poolItr % memberName), i2d_ptr_a)
               do vv = 1, nvert
                  do hh = 1, nhoriz
                     i2d_ptr_a(vv, hh) = nint ( vect_inc(index + 1) )
                     index = index + 1
                  enddo
               enddo
            else if (poolItr % dataType == MPAS_POOL_REAL) then
               call mpas_pool_get_array(self%subFields, trim(poolItr % memberName), r2d_ptr_a)
               do vv = 1, nvert
                  do hh = 1, nhoriz
                     r2d_ptr_a(vv, hh) = vect_inc(index + 1)
                     index = index + 1
                  enddo
               enddo
            endif
         else
            write(message,*) '--> deserialize_fields: poolItr % nDims == ',poolItr % nDims,' not handled'
            call abor1_ftn(message)
         endif
         deallocate(dimSizes)
      endif
   enddo

end subroutine deserialize_fields

! has
function has_field(self, fieldname) result(has)
   class(mpas_fields), intent(in) :: self
   character(len=*), intent(in) :: fieldname
   logical :: has
   has = (ufo_vars_getindex(self % fldnames, fieldname) > 0)
end function has_field

function has_fields(self, fieldnames) result(has)
   class(mpas_fields), intent(in) :: self
   character(len=*), intent(in) :: fieldnames(:)
   integer :: i
   logical, allocatable :: has(:)
   allocate(has(size(fieldnames)))
   do i = 1, size(fieldnames)
      has(i) = self%has(fieldnames(i))
   end do
end function has_fields

! get
subroutine get_data(self, key, data)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   type(mpas_pool_data_type), pointer, intent(out) :: data
   if (self%has(key)) then
     data => pool_get_member(self % subFields, key, MPAS_POOL_FIELD)
   else
     write(message,*) 'self%get_data: field not present, ', key
     call abor1_ftn(message)
   end if
end subroutine get_data

subroutine get_field_i1(self, key, i1)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   type(field1DInteger), pointer, intent(out) :: i1
   type(mpas_pool_data_type), pointer :: data
   call self%get(key, data)
   i1 => data%i1
end subroutine get_field_i1

subroutine get_field_i2(self, key, i2)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   type(field2DInteger), pointer, intent(out) :: i2
   type(mpas_pool_data_type), pointer :: data
   call self%get(key, data)
   i2 => data%i2
end subroutine get_field_i2

subroutine get_field_r1(self, key, r1)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   type(field1DReal), pointer, intent(out) :: r1
   type(mpas_pool_data_type), pointer :: data
   call self%get(key, data)
   r1 => data%r1
end subroutine get_field_r1

subroutine get_field_r2(self, key, r2)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   type(field2DReal), pointer, intent(out) :: r2
   type(mpas_pool_data_type), pointer :: data
   call self%get(key, data)
   r2 => data%r2
end subroutine get_field_r2

subroutine get_array_i1(self, key, i1)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   integer, pointer, intent(out) :: i1(:)
   type(mpas_pool_data_type), pointer :: data
   call self%get(key, data)
   i1 => data%i1%array
end subroutine get_array_i1

subroutine get_array_i2(self, key, i2)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   integer, pointer, intent(out) :: i2(:,:)
   type(mpas_pool_data_type), pointer :: data
   call self%get(key, data)
   i2 => data%i2%array
end subroutine get_array_i2

subroutine get_array_r1(self, key, r1)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   real(kind=RKIND), pointer, intent(out) :: r1(:)
   type(mpas_pool_data_type), pointer :: data

   call self%get(key, data)
   r1 => data%r1%array
end subroutine get_array_r1

subroutine get_array_r2(self, key, r2)
   class(mpas_fields), intent(in) :: self
   character (len=*), intent(in) :: key
   real(kind=RKIND), pointer, intent(out) :: r2(:,:)
   type(mpas_pool_data_type), pointer :: data
   call self%get(key, data)
   r2 => data%r2%array
end subroutine get_array_r2


! all copy_to and copy_from methods eventually call
! copy_field_between_pools
subroutine copy_field_between_pools(from, fromKey, to, toKey)
  type(mpas_pool_type), pointer, intent(in) :: from
  type(mpas_pool_type), pointer, intent(inout) :: to
  character (len=*), intent(in) :: fromKey, toKey
  type(mpas_pool_data_type), pointer :: toData, fromData
  toData => pool_get_member(to, toKey, MPAS_POOL_FIELD)
  if (associated(toData)) then
    fromData => pool_get_member(from, fromKey, MPAS_POOL_FIELD)
    if (associated(fromData)) then
      if (associated(fromData%r1) .and. associated(toData%r1)) then
        toData%r1%array = fromData%r1%array
      else if (associated(fromData%r2) .and. associated(toData%r2)) then
        toData%r2%array = fromData%r2%array
      else if (associated(fromData%r3) .and. associated(toData%r3)) then
        toData%r3%array = fromData%r3%array
      else if (associated(fromData%i1) .and. associated(toData%i1)) then
        toData%i1%array = fromData%i1%array
      else if (associated(fromData%i2) .and. associated(toData%i2)) then
        toData%i2%array = fromData%i2%array
      else
        call abor1_ftn('copy_field_between_pools: data mismatch between to/from pools')
      end if
    else
      write(message,*) 'copy_field_between_pools: field not present in "from" pool, ', fromKey
      call abor1_ftn(message)
    end if
  else
    write(message,*) 'copy_field_between_pools: field not present in "to" pool, ', toKey
    call abor1_ftn(message)
  end if
end subroutine copy_field_between_pools

! copy_from
subroutine copy_from_other_pool_field(self, selfKey, otherPool, otherKey)
  class(mpas_fields), intent(inout) :: self
  type(mpas_pool_type), pointer, intent(in) :: otherPool
  character (len=*), intent(in) :: selfKey, otherKey
  type(mpas_pool_data_type), pointer :: selfData, otherData
  call copy_field_between_pools(otherPool, otherKey, self%subFields, selfKey)
end subroutine copy_from_other_pool_field

subroutine copy_from_other_pool(self, key, otherPool)
  class(mpas_fields), intent(inout) :: self
  character (len=*), intent(in) :: key
  type(mpas_pool_type), pointer, intent(in) :: otherPool
  call self%copy_from(key, otherPool, key)
end subroutine copy_from_other_pool

subroutine copy_from_other_fields_field(self, selfKey, other, otherKey)
  class(mpas_fields), intent(inout) :: self
  class(mpas_fields), intent(in) :: other
  character (len=*), intent(in) :: selfKey, otherKey
  call self%copy_from(selfKey, other%subFields, otherKey)
end subroutine copy_from_other_fields_field

subroutine copy_from_other_fields(self, key, other)
  class(mpas_fields), intent(inout) :: self
  character (len=*), intent(in) :: key
  class(mpas_fields), intent(in) :: other
  call self%copy_from(key, other%subFields, key)
end subroutine copy_from_other_fields

! copy_to
subroutine copy_to_other_pool_field(self, selfKey, otherPool, otherKey)
  class(mpas_fields), intent(in) :: self
  type(mpas_pool_type), pointer, intent(inout) :: otherPool
  character (len=*), intent(in) :: selfKey, otherKey
  type(mpas_pool_data_type), pointer :: selfData, otherData
  call copy_field_between_pools(self%subFields, selfKey, otherPool, otherKey)
end subroutine copy_to_other_pool_field

subroutine copy_to_other_pool(self, key, otherPool)
  class(mpas_fields), intent(in) :: self
  character (len=*), intent(in) :: key
  type(mpas_pool_type), pointer, intent(inout) :: otherPool
  call self%copy_to(key, otherPool, key)
end subroutine copy_to_other_pool

subroutine copy_to_other_fields_field(self, selfKey, other, otherKey)
  class(mpas_fields), intent(in) :: self
  class(mpas_fields), intent(inout) :: other
  character (len=*), intent(in) :: selfKey, otherKey
  call self%copy_to(selfKey, other%subFields, otherKey)
end subroutine copy_to_other_fields_field

subroutine copy_to_other_fields(self, key, other)
  class(mpas_fields), intent(in) :: self
  character (len=*), intent(in) :: key
  class(mpas_fields), intent(inout) :: other
  call self%copy_to(key, other%subFields, key)
end subroutine copy_to_other_fields

! all copy_to_ad methods eventually call
! copy_field_between_pools_ad
subroutine copy_field_between_pools_ad(to, toKey, from, fromKey)
  type(mpas_pool_type), pointer, intent(inout) :: to
  type(mpas_pool_type), pointer, intent(in) :: from
  character (len=*), intent(in) :: fromKey, toKey
  type(mpas_pool_data_type), pointer :: toData, fromData
  toData => pool_get_member(to, toKey, MPAS_POOL_FIELD)
  if (associated(toData)) then
    fromData => pool_get_member(from, fromKey, MPAS_POOL_FIELD)
    if (associated(fromData)) then
      if (associated(fromData%r1) .and. associated(toData%r1)) then
        toData%r1%array = toData%r1%array + fromData%r1%array
      else if (associated(fromData%r2) .and. associated(toData%r2)) then
        toData%r2%array = toData%r2%array + fromData%r2%array
      else if (associated(fromData%r3) .and. associated(toData%r3)) then
        toData%r3%array = toData%r3%array + fromData%r3%array
      else
        call abor1_ftn('copy_field_between_pools_ad: data mismatch between to/from pools')
      end if
    else
      write(message,*) 'copy_field_between_pools_ad: field not present in "from" pool, ', fromKey
      call abor1_ftn(message)
    end if
  else
    write(message,*) 'copy_field_between_pools_ad: field not present in "to" pool, ', toKey
    call abor1_ftn(message)
  end if
end subroutine copy_field_between_pools_ad

! copy_to_ad
subroutine copy_to_other_pool_field_ad(self, selfKey, otherPool, otherKey)
  class(mpas_fields), intent(inout) :: self
  type(mpas_pool_type), pointer, intent(in) :: otherPool
  character (len=*), intent(in) :: selfKey, otherKey
  type(mpas_pool_data_type), pointer :: selfData, otherData
  call copy_field_between_pools_ad(self%subFields, selfKey, otherPool, otherKey)
end subroutine copy_to_other_pool_field_ad

subroutine copy_to_other_pool_ad(self, key, otherPool)
  class(mpas_fields), intent(inout) :: self
  character (len=*), intent(in) :: key
  type(mpas_pool_type), pointer, intent(in) :: otherPool
  call self%copy_to_ad(key, otherPool, key)
end subroutine copy_to_other_pool_ad

subroutine copy_to_other_fields_field_ad(self, selfKey, other, otherKey)
  class(mpas_fields), intent(inout) :: self
  class(mpas_fields), intent(in) :: other
  character (len=*), intent(in) :: selfKey, otherKey
  call self%copy_to_ad(selfKey, other%subFields, otherKey)
end subroutine copy_to_other_fields_field_ad

subroutine copy_to_other_fields_ad(self, key, other)
  class(mpas_fields), intent(inout) :: self
  character (len=*), intent(in) :: key
  class(mpas_fields), intent(in) :: other
  call self%copy_to_ad(key, other%subFields, key)
end subroutine copy_to_other_fields_ad

! push_back
! all push_back methods eventually call
! pool_push_back_field_from_pool
subroutine pool_push_back_field_from_pool(to, toKey, from, fromKey)
  type(mpas_pool_type), pointer, intent(inout) :: to
  type(mpas_pool_type), pointer, intent(in) :: from
  character (len=*), intent(in) :: fromKey, toKey
  type(mpas_pool_data_type), pointer :: fromData
  type(field1DReal), pointer :: fieldr1
  type(field2DReal), pointer :: fieldr2
  type(field3DReal), pointer :: fieldr3
  type(field1DInteger), pointer :: fieldi1
  type(field2DInteger), pointer :: fieldi2
  fromData => pool_get_member(from, fromKey, MPAS_POOL_FIELD)
  if (associated(fromData)) then
    if (associated(fromData%r1)) then
      call mpas_duplicate_field(fromData%r1, fieldr1)
      fieldr1 % fieldName = toKey
      call mpas_pool_add_field(to, toKey, fieldr1)
    else if (associated(fromData%r2)) then
      call mpas_duplicate_field(fromData%r2, fieldr2)
      fieldr2 % fieldName = toKey
      call mpas_pool_add_field(to, toKey, fieldr2)
    else if (associated(fromData%r3)) then
      call mpas_duplicate_field(fromData%r3, fieldr3)
      fieldr3 % fieldName = toKey
      call mpas_pool_add_field(to, toKey, fieldr3)
    else if (associated(fromData%i1)) then
      call mpas_duplicate_field(fromData%i1, fieldi1)
      fieldi1 % fieldName = toKey
      call mpas_pool_add_field(to, toKey, fieldi1)
    else if (associated(fromData%i2)) then
      call mpas_duplicate_field(fromData%i2, fieldi2)
      fieldi2 % fieldName = toKey
      call mpas_pool_add_field(to, toKey, fieldi2)
    else
      call abor1_ftn('pool_push_back_field_from_pool: data type not supported')
    end if
  else
    write(message,*) 'pool_push_back_field_from_pool: field not present in "from" pool, ', fromKey
    call abor1_ftn(message)
  end if
end subroutine pool_push_back_field_from_pool

subroutine push_back_other_pool_field(self, selfKey, otherPool, otherKey)
  class(mpas_fields), intent(inout) :: self
  type(mpas_pool_type), pointer, intent(in) :: otherPool
  character (len=*), intent(in) :: selfKey, otherKey
  type(mpas_pool_data_type), pointer :: selfData, otherData
  character(len=MAXVARLEN), allocatable :: fldnames(:)
  if (self%has(selfKey)) then
    write(message,*) 'push_back_other_pool_field: field already present in self, cannot push_back, ', selfKey
    call abor1_ftn(message)
  end if

  ! Add field to self%subFields pool
  call pool_push_back_field_from_pool(self%subFields, selfKey, otherPool, otherKey)

  ! Extend self%fldnames
  allocate(fldnames(self%nf+1))
  fldnames(1:self%nf) = self%fldnames(:)
  fldnames(self%nf+1) = trim(selfKey)
  self%nf = self%nf+1
  deallocate(self%fldnames)
  allocate(self%fldnames(self%nf))
  self%fldnames = fldnames
  deallocate(fldnames)
end subroutine push_back_other_pool_field

subroutine push_back_other_pool(self, key, otherPool)
  class(mpas_fields), intent(inout) :: self
  character (len=*), intent(in) :: key
  type(mpas_pool_type), pointer, intent(in) :: otherPool
  call self%push_back(key, otherPool, key)
end subroutine push_back_other_pool

subroutine push_back_other_fields_field(self, selfKey, other, otherKey)
  class(mpas_fields), intent(inout) :: self
  class(mpas_fields), intent(in) :: other
  character (len=*), intent(in) :: selfKey, otherKey
  call self%push_back(selfKey, other%subFields, otherKey)
end subroutine push_back_other_fields_field

subroutine push_back_other_fields(self, key, other)
  class(mpas_fields), intent(inout) :: self
  character (len=*), intent(in) :: key
  class(mpas_fields), intent(in) :: other
  call self%push_back(key, other%subFields, key)
end subroutine push_back_other_fields

subroutine to_fieldset(self, geom, vars, afieldset, include_halo, flip_vert_lev)

   implicit none

   class(mpas_fields),   intent(in)    :: self
   type(mpas_geom),      intent(in)    :: geom
   type(oops_variables), intent(in)    :: vars
   type(atlas_fieldset), intent(inout) :: afieldset
   logical,               intent(in)    :: include_halo
   logical,               intent(in)    :: flip_vert_lev

   integer :: jvar, nlevels
   real(kind=kind_real), pointer :: real_ptr(:,:)
   real(kind=RKIND), pointer :: r1d_ptr_a(:), r2d_ptr_a(:,:)
   integer, pointer :: i1d_ptr_a(:)
   logical :: var_found
   type(atlas_field) :: afield
   type(atlas_metadata) :: meta
   type(mpas_pool_iterator_type) :: poolItr

   type(mpas_pool_data_type), pointer :: data_aux
   integer :: nx, ilev, jlev
   integer :: j

   ! note:
   ! get-or-create atlas field, flip_vert_level,
   ! pass data/field to atlas, assign 'default, interp_type' in atlas's metadata

   if (include_halo) then
      nx=geom%nCells
   else
      nx=geom%nCellsSolve
   endif
   do jvar = 1,vars%nvars()
      var_found = .false.
      call mpas_pool_begin_iteration(self%subFields)
      do while (mpas_pool_get_next_member(self%subFields, poolItr))
         if (trim(vars%variable(jvar))==trim(poolItr%memberName)) then
            !
            ! Revealed a potetial bug in function getVertLevels(self%subFields, vars%variable(jvar))
            ! why getVertLevels .NE. 0 when nDims=1 ???
            ! Is there a purpose for this setup in getVertLevels ?
            !
            if (poolItr%nDims==1) then
               nlevels = 1
            else if (poolItr%nDims==2) then
               nlevels = getVertLevels(self%subFields, vars%variable(jvar))
            else if (poolItr%nDims==3) then
               call abor1_ftn('not implemented yet')
            end if

            if (afieldset%has_field(vars%variable(jvar))) then
               ! Get Atlas field
               afield = afieldset%field(vars%variable(jvar))
            else
               ! Create Atlas field
                afield = geom%afunctionspace%create_field &
                     (name=vars%variable(jvar),kind=atlas_real(kind_real),levels=nlevels)
               ! Add field
               call afieldset%add(afield)
            end if
            !
            call self%get_data(poolItr%memberName, data_aux)
            ! equiv. ref. data_aux = pool_get_member(self % subFields, poolItr%memberName, MPAS_POOL_FIELD)
            if (poolItr % dataType == MPAS_POOL_REAL) then
               if (poolItr%nDims==1) then
                  call mpas_pool_get_array(self%subFields, trim(poolItr%memberName), r1d_ptr_a)
                  call afield%data(real_ptr)
                  real_ptr(1,1:nx) = real(r1d_ptr_a(1:nx), kind_real)
                  !
               else if (poolItr%nDims==2) then
                  call mpas_pool_get_array(self%subFields, trim(poolItr%memberName), r2d_ptr_a)
                  call afield%data(real_ptr)
                  ! for CRTM: vertical level flip
                  do jlev = 1, nlevels
                     if (flip_vert_lev) then
                        ilev = nlevels - jlev + 1
                     else
                        ilev = jlev
                     endif
                     real_ptr(ilev,1:nx) = real(r2d_ptr_a(jlev,1:nx), kind_real)
                  enddo
               end if
            elseif (poolItr % dataType == MPAS_POOL_INTEGER) then
               if (poolItr%nDims==1) then
                  call mpas_pool_get_array(self%subFields, trim(poolItr%memberName), i1d_ptr_a)
                  call afield%data(real_ptr)
                  real_ptr(1,1:nx) = real(i1d_ptr_a(1:nx), kind_real)
               else if (poolItr%nDims==2) then
                  write(message,*) '--> to_fieldset: nDims == 2:  not handled for integers'
                  call abor1_ftn(message)
               end if
            else
               STOP 'poolItr % dataType neither real nor integer'
            endif

            ! Fill atlas-generated halos with 0 and mark as out-of-date
            real_ptr(:, nx+1:) = 0.0_kind_real
            call afield%set_dirty(.true.)

            meta = afield%metadata()
            if (poolItr % dataType == MPAS_POOL_REAL) then
               call meta%set('interp_type', 'default')
            elseif (poolItr % dataType == MPAS_POOL_INTEGER) then
               call meta%set('interp_type', 'integer')
            else
               call abor1_ftn('poolItr % dataType .NE. real OR integer, unexpected')
            endif
            call meta%set('nearest 3d level', 'bottom')

            ! Set flag
            var_found = .true.
            exit
         end if   ! if (trim(vars%variable(jvar))==trim(poolItr%memberName))
      end do      ! mpas_pool_get_next_member
      if (.not.var_found) call abor1_ftn('variable '//trim(vars%variable(jvar))//' not found in increment')
   end do         ! do jvar=1, vars%nvars()
   call afield%final()
   call meta%final()
end subroutine to_fieldset


subroutine from_fieldset(self, geom, vars, afieldset, include_halo, flip_vert_lev)

   implicit none

   class(mpas_fields),   intent(inout) :: self
   type(mpas_geom),      intent(in)    :: geom
   type(oops_variables), intent(in)    :: vars
   type(atlas_fieldset), intent(in)    :: afieldset
   logical,              intent(in)    :: include_halo
   logical,              intent(in)    :: flip_vert_lev

   integer :: jvar
   real(kind=kind_real), pointer :: real_ptr(:,:)
   real(kind=RKIND), pointer :: r1d_ptr_a(:), r2d_ptr_a(:,:)
   integer, pointer :: i1d_ptr_a(:)
   logical :: var_found
   type(atlas_field) :: afield
   type(mpas_pool_iterator_type) :: poolItr

   type(mpas_pool_data_type), pointer :: data_aux
   integer :: nlevels, nx, ilev, jlev

   ! Note:
   !   1. pass data from atlas_field to MPAS field
   !      a. real-type(afield) --> real/integer (MPAS type), bc atlas has only real
   !      b. flip back vertical levels

   if (include_halo) then
      nx=geom%nCells
   else
      nx=geom%nCellsSolve
   endif

   do jvar = 1,vars%nvars()
      var_found = .false.
      call mpas_pool_begin_iteration(self%subFields)
      do while (mpas_pool_get_next_member(self%subFields, poolItr))
         if (trim(vars%variable(jvar))==trim(poolItr%memberName)) then
            ! Get atlas field
            afield = afieldset%field(vars%variable(jvar))
            ! Get MPAS data (pool_data_type)
            call self%get_data(poolItr%memberName, data_aux)
            nlevels = getVertLevels(self%subFields, vars%variable(jvar))
            if (poolItr % dataType == MPAS_POOL_REAL) then
               if (poolItr%nDims==1) then
                  call afield%data(real_ptr)
                  call mpas_pool_get_array(self%subFields, trim(poolItr%memberName), r1d_ptr_a)
                  r1d_ptr_a(1:nx) = real(real_ptr(1,1:nx), RKIND)
                  r1d_ptr_a(nx+1:) = real(0.0, RKIND)  ! set mpas halos (if any) to zero
               else if (poolItr%nDims==2) then
                  call afield%data(real_ptr)
                  call mpas_pool_get_array(self%subFields, trim(poolItr%memberName), r2d_ptr_a)
                  ! for CRTM: vertical level flip
                  do jlev = 1, nlevels
                     if (flip_vert_lev) then
                        ilev = nlevels - jlev + 1
                     else
                        ilev = jlev
                     endif
                     r2d_ptr_a(jlev,1:nx) = real(real_ptr(ilev,1:nx), RKIND)
                  enddo
                  r2d_ptr_a(:,nx+1:) = real(0.0, RKIND)  ! set mpas halos (if any) to zero
               end if
            elseif (poolItr % dataType == MPAS_POOL_INTEGER) then
               if (poolItr%nDims==1) then
                  call mpas_pool_get_array(self%subFields, trim(poolItr%memberName), i1d_ptr_a)
                  call afield%data(real_ptr)
                  i1d_ptr_a(1:nx) = nint(real_ptr(1,1:nx))
               else if (poolItr%nDims==2) then
                  write(message,*) '--> from_fieldset: nDims == 2:  not handled for integers'
                  call abor1_ftn(message)
               end if
            else
               call abor1_ftn('poolItr % dataType neither real nor integer')
            endif

            ! Set flag
            var_found = .true.
            exit
         end if
      end do
      if (.not.var_found) call abor1_ftn('variable '//trim(vars%variable(jvar))//' not found in increment')
   end do
   call afield%final()
end subroutine from_fieldset

! ------------------------------------------------------------------------------

end module mpas_fields_mod
