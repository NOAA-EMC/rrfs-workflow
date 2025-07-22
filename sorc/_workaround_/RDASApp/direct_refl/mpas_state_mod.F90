! (C) Copyright 2017 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

module mpas_state_mod

use fckit_configuration_module, only: fckit_configuration
use fckit_mpi_module, only: fckit_mpi_comm, fckit_mpi_sum
use fckit_log_module, only: fckit_log

!oops
use datetime_mod
use kinds, only: kind_real
use oops_variables_mod, only: oops_variables

!dcmip initialization
use dcmip_initial_conditions_test_1_2_3, only : test1_advection_deformation, &
       test1_advection_hadley, test3_gravity_wave
use dcmip_initial_conditions_test_4, only : test4_baroclinic_wave

!ufo
use ufo_geovals_mod
use ufo_vars_mod

!MPAS-Model
use mpas_constants
use mpas_derived_types
use mpas_field_routines
use mpas_kind_types, only: StrKIND
use mpas_pool_routines
use mpas_dmpar, only: mpas_dmpar_exch_halo_field

!mpas-jedi
use mpas_constants_mod
use mpas_geom_mod
use mpas_fields_mod
use mpas_saca_interface_mod, only: update_cloud_fields
use mpas2ufo_vars_mod
use mpas4da_mod

implicit none

private

public :: add_incr, analytic_IC

! ------------------------------------------------------------------------------

contains


! ------------------------------------------------------------------------------
!> add increment to state
!!
!! \details **add_incr()** adds "increment" to "state", such as
!!          state (containing analysis) = state (containing guess) + increment
!!          Here, we also update "theta", "rho", and "u" (edge-normal wind), which are
!!          close to MPAS prognostic variable.
!!          Intermediate 3D pressure is diagnosed with hydrostatic balance.
!!          While conversion to "theta" and "rho" uses full state variables,
!!          conversion to "u" from cell center winds uses their increment to reduce
!!          the smoothing effect.
!!
subroutine add_incr(self, increment)

   implicit none
   class(mpas_fields), intent(inout) :: self !< state
   class(mpas_fields), intent(in)    :: increment
   character(len=StrKIND) :: kind_op

   integer :: i, k, ngrid
   type (mpas_pool_type), pointer :: state, diag, mesh
   type (field2DReal), pointer :: fld2d_pb, fld2d_u, fld2d_u_inc, fld2d_uRm, fld2d_uRz
   type (field2DReal), pointer :: fld2d_p, fld2d_dp, fld2d_drho, fld2d_dth, fld2d_dqv
   real(kind=RKIND), dimension(:,:), pointer :: ptrr2_qv, ptrr2_sh
   real(kind=RKIND), dimension(:,:), pointer :: ptrr2_p, ptrr2_rho, ptrr2_t, ptrr2_th, ptrr2_pp
   real(kind=RKIND), dimension(:,:), pointer :: ptrr2_dp, ptrr2_drho, ptrr2_dt, ptrr2_dth, ptrr2_dsh
   real(kind=RKIND), dimension(:,:), pointer :: ptrr2_w, ptrr2_wa
   real(kind=RKIND), dimension(:), pointer :: ptrr1_ps, ptrr1_dps

   ! Difference with self_add other is that self%subFields can contain extra fields
   ! beyond increment%subFields and the resolution of increment can be different.

   if (self%geom%nCells==increment%geom%nCells .and. self%geom%nVertLevels==increment%geom%nVertLevels) then

      !SACA
      if ( all(self%has(sacaStateFields)) .and. all(increment%has(sacaObsFields)) ) then
         !call interface to the main SACA algorithm
         call update_cloud_fields ( self, increment )

         !early return for this specific usecase
         return
      endif

      ngrid = self%geom%nCellsSolve

      ! First, update variables which are closely related to MPAS prognostic vars.
      ! Use the linearized hydrostatic balance to get the 3D pressure increment
      ! from the increments of temperature, specific humidity, and surface pressure.
      ! The specific humidity increment is converted to a water vaport mixing ratio increment.
      ! Then, the increments of rho and theta are also updated by using the linearized state equation and
      ! the linearized Poisson's equation.
      ! note: linear change of variables
      if ( all(self%has(analysisThermoFields)) .and. &
           all(self%has(modelThermoFields)) .and. &
           all(increment%has(analysisThermoFields)) .and. &
           .not. all(increment%has(modelThermoFields)) ) then

         call self%get(              'water_vapor_mixing_ratio_wrt_dry_air', ptrr2_qv)
         call self%get(        'air_pressure', ptrr2_p)
         call self%get(             'dry_air_density', ptrr2_rho)
         call self%get('air_pressure_at_surface', ptrr1_ps)
         call self%get(     'air_temperature', ptrr2_t)
         call self%get(           'air_potential_temperature', ptrr2_th)
         call increment%get(     'air_temperature', ptrr2_dt)
         call increment%get('air_pressure_at_surface', ptrr1_dps)

         call increment%get(         'water_vapor_mixing_ratio_wrt_moist_air', ptrr2_dsh) ! converted to dqv below
         do i = 1, ngrid
            do k = 20, self%geom%nVertLevels
               if (ptrr2_p(k,i) .le. 15000.) then
                  ptrr2_dsh(k,i) = 0.
               end if
            end do
         end do

         call self%get(              'water_vapor_mixing_ratio_wrt_moist_air', ptrr2_sh)  !    for trajectory

         !duplicate dp, drho, dtheta
         call mpas_pool_get_field(self%subFields, 'air_pressure', fld2d_p)
         call mpas_duplicate_field(fld2d_p, fld2d_dp)   ! intermediate output
         call mpas_duplicate_field(fld2d_p, fld2d_drho) ! intermediate output
         call mpas_duplicate_field(fld2d_p, fld2d_dth)  ! intermediate output
         call mpas_duplicate_field(fld2d_p, fld2d_dqv)  ! dsh (specific humidity) --> dqv (mixing ratio)

         !get dqv from dsh
         call q_to_w_tl( ptrr2_dsh(:,1:ngrid), ptrr2_sh(:,1:ngrid), fld2d_dqv%array(:,1:ngrid) )

         call linearized_hydrostatic_balance( ngrid, self%geom%nVertLevels, self%geom%zgrid(:,1:ngrid), &
                   ptrr2_t(:,1:ngrid), ptrr2_qv(:,1:ngrid), ptrr1_ps(1:ngrid), ptrr2_p(:,1:ngrid), &
                   ptrr2_dt(:,1:ngrid), fld2d_dqv%array(:,1:ngrid), ptrr1_dps(1:ngrid), &
                   fld2d_dp%array(:,1:ngrid), fld2d_drho%array(:,1:ngrid), fld2d_dth%array(:,1:ngrid) )

         ptrr2_p(:,1:ngrid)   = ptrr2_p(:,1:ngrid)   + fld2d_dp%array(:,1:ngrid)
         ptrr2_rho(:,1:ngrid) = ptrr2_rho(:,1:ngrid) + fld2d_drho%array(:,1:ngrid)
         ptrr2_th(:,1:ngrid)  = ptrr2_th(:,1:ngrid)  + fld2d_dth%array(:,1:ngrid)

         call mpas_deallocate_field( fld2d_dp )
         call mpas_deallocate_field( fld2d_drho )
         call mpas_deallocate_field( fld2d_dth )
         call mpas_deallocate_field( fld2d_dqv )
      endif

      ! Second, update subFields that are common between self and increment
      kind_op = 'add'
      call da_operator(trim(kind_op), self%subFields, increment%subFields, fld_select = increment%fldnames_ci)

      ! Impose positive-definite limits on hydrometeors and moistureFields
      ! note: nonlinear change of variable
      call da_posdef( self%subFields, mpas_hydrometeor_fields)
      call da_posdef( self%subFields, moistureFields)
      call da_posdef( self%subFields, ['equivalent_reflectivity_factor'])

      ! Update qv (water vapor mixing ratio) from spechum (specific humidity) [ w = q / (1 - q) ]
      ! note: nonlinear change of variable
      if ( all(self%has(moistureFields)) .and. &
           increment%has('water_vapor_mixing_ratio_wrt_moist_air') .and. &
           .not. increment%has('water_vapor_mixing_ratio_wrt_dry_air') ) then
         call self%get(     'water_vapor_mixing_ratio_wrt_dry_air', ptrr2_qv)
         call self%get('water_vapor_mixing_ratio_wrt_moist_air', ptrr2_sh)
         call q_to_w( ptrr2_sh(:,1:ngrid), ptrr2_qv(:,1:ngrid) )
      endif

      ! Update pressure_p (pressure perturbation) , which is a diagnostic variable
      if ( self%has('pressure_p') .and. self%has('air_pressure') .and. &
           .not.increment%has('pressure_p') ) then
         call self%get(  'air_pressure', ptrr2_p)
         call self%get('pressure_p', ptrr2_pp)
         call mpas_pool_get_field(self%geom%domain%blocklist%allFields, 'pressure_base', fld2d_pb)
         ptrr2_pp(:,1:ngrid) = ptrr2_p(:,1:ngrid) - fld2d_pb%array(:,1:ngrid)
      endif

      ! Update edge normal wind u from cell centered winds "incrementally"
      ! note: linear change of variable
      if ( self%has('u') .and. &
           all(increment%has(cellCenteredWindFields)) .and. &
           .not.increment%has('u') ) then
         call mpas_pool_get_field(self%subFields, 'u', fld2d_u)
         call mpas_pool_get_field(increment%subFields, 'northward_wind', fld2d_uRm)
         call mpas_pool_get_field(increment%subFields, 'eastward_wind', fld2d_uRz)

         call mpas_duplicate_field(fld2d_u, fld2d_u_inc)

         call mpas_dmpar_exch_halo_field(fld2d_uRz)
         call mpas_dmpar_exch_halo_field(fld2d_uRm)
         call uv_cell_to_edges(self%geom%domain, fld2d_uRz, fld2d_uRm, fld2d_u_inc, &
                    self%geom%lonCell, self%geom%latCell, self%geom%nCells, &
                    self%geom%edgeNormalVectors, self%geom%nEdgesOnCell, self%geom%edgesOnCell, &
                    self%geom%nVertLevels)
         ngrid = self%geom%nEdgesSolve
         fld2d_u%array(:,1:ngrid) = fld2d_u%array(:,1:ngrid) + fld2d_u_inc%array(:,1:ngrid)

         ! TODO: DO we need HALO exchange here or in ModelMPAS::initialize for model integration?
         call mpas_deallocate_field( fld2d_u_inc )
      endif

       ! Update vertical velocity from upward_air_velocity
       ! note: linear change of variable
       if ( self%has('w') .and. &
         increment%has('upward_air_velocity') .and. &
         .not.increment%has('w')  )then
         call self%get('upward_air_velocity', ptrr2_wa)
         call self%get('w',                   ptrr2_w )
         do k = 1, self%geom%nVertLevels
            ! Increment at unstagger grid is added to stagger grid directly
            ! x_a(i) - 0.5*[ x(i) + x(i+1) ] + x(i)
            ptrr2_w(k,:) = ptrr2_wa(k,:) - MPAS_JEDI_HALF_kr * (ptrr2_w(k+1,:) - ptrr2_w(k,:))
         end do   
      endif
   else
      call abor1_ftn("mpas_state:add_incr: dimension mismatch")
   endif

   return

end subroutine add_incr

! ------------------------------------------------------------------------------
!> Analytic Initialization for the MPAS Model
!!
!! \details **analytic_IC()** initializes the MPAS Field and State objects using one of
!! several alternative idealized analytic models.  This is intended to facilitate testing by
!! eliminating the need to read in the initial state from a file and by providing exact expressions
!! to test interpolations.  This function is activated by setting the "analytic_init" field in the
!! "initial" or "StateFile" section of the configuration file.
!!
!! Initialization options that begin with "dcmip" refer to tests defined by the multi-institutional
!! 2012 [Dynamical Core Intercomparison Project](https://earthsystealcmcog.org/projects/dcmip-2012)
!! and the associated Summer School, sponsored by NOAA, NSF, DOE, NCAR, and the University of Michigan.
!!
!! Currently implemented options for analytic_init include:
!! * dcmip-test-1-1: 3D deformational flow
!! * dcmip-test-1-2: 3D Hadley-like meridional circulation
!! * dcmip-test-3-1: Non-hydrostatic gravity wave
!! * dcmip-test-4-0: Baroclinic instability
!!
!! \author J. Guerrette (adapted from fv3jedi code by M. Miesch)
!! \date July, 2018: Created
!!
subroutine analytic_IC(self, f_conf, vdate)

!  !MPAS Test Cases
!  !JJG: This initialization requires the init_atmospher_core core_type
!  !      in the MPAS library for OOPS, but currently it is not included
!  use init_atm_core, only: init_atm_core_run!, init_atm_core_finalize (could be used for cleanup...)

  implicit none

  class(mpas_fields),        intent(inout) :: self   !< State
  type(fckit_configuration), intent(in)    :: f_conf !< Configuration
  type(datetime),            intent(inout) :: vdate  !< DateTime

  type(mpas_geom), pointer :: geom

  character(len=:), allocatable :: str
  character(len=30) :: IC
  character(len=20) :: sdate
  character(len=1024) :: buf
  integer :: jlev, ii, iVar
  integer :: ierr = 0
  real(kind=kind_real) :: rlat, rlon
  real(kind=kind_real) :: pk
  real(kind=kind_real) :: u0,v0,w0,t0,phis0,ps0,rho0,hum0,q1,q2,q3,q4

  real (kind=kind_real), dimension(:), allocatable :: ps
  real (kind=kind_real), dimension(:,:), allocatable :: &
    p, temperature, u, v, qv

  character(len=StrKIND) :: varName
  type(mpas_pool_data_type), pointer :: fieldData

  real(kind=kind_real) :: zhalf

  ! Establish member pointer to geometry
  geom => self%geom

  call f_conf%get_or_die("analytic init.method",str)
  IC = str
  call fckit_log%info ("mpas_state:analytic_init: "//IC)

  call f_conf%get_or_die("date",str)
  sdate = str
  call fckit_log%info ("validity date is: "//sdate)

  call datetime_set(sdate, vdate)

  ! For most MPAS-JEDI applications, the State object is constructed with background state fields
  ! related to MPAS-Atmosphere model fields (mpas_fields.create), then the quantitative values for
  ! those fields are read from an input file (mpas_fields.read)

  ! When analytic_IC is used, the State is constructed with whichever fields the user wishes, as
  ! long as they are implemented below.  Then the quantitative values are filled in here based
  ! on a user-selected analytical equation.  For the GetValues interface test, only the
  ! variables available in ufo_geovals_analytic_init can be included in the state, i.e.,
  ! air_pressure and virtual_temperature. For the State interface test, the background state
  ! fields are used.  Here we account for both scenarios.

  ! allocate the 3d fields
  allocate(u(geom%nVertLevels, geom%nCellsSolve))
  allocate(v(geom%nVertLevels, geom%nCellsSolve))
  allocate(temperature(geom%nVertLevels, geom%nCellsSolve))
  allocate(p(geom%nVertLevels, geom%nCellsSolve))
  allocate(qv(geom%nVertLevels, geom%nCellsSolve))

  ! allocate the 2d fields
  allocate(ps(geom%nCellsSolve))

  !===========================================================
  ! initialize the variable fields with an analytical equation

  init_option: select case (IC)

     case ("dcmip-test-1-1")
        do ii = 1, geom%nCellsSolve
           rlat = geom%latCell(ii)
           rlon = geom%lonCell(ii)

           ! Now loop over all levels
           do jlev = 1, geom%nVertLevels

              zhalf = MPAS_JEDI_HALF_kr * (geom%zgrid(jlev,ii) + geom%zgrid(jlev+1,ii))
              Call test1_advection_deformation(rlon,rlat,pk,zhalf,1,u0,v0,w0,t0,&
                                               phis0,ps0,rho0,hum0,q1,q2,q3,q4)
              p(jlev,ii) = pk
              temperature(jlev,ii) = t0
              u(jlev,ii) = u0
              v(jlev,ii) = v0
              qv(jlev,ii) = hum0
           enddo
           ps(ii) = ps0
        enddo

     case ("dcmip-test-1-2")

        do ii = 1, geom%nCellsSolve
           rlat = geom%latCell(ii)
           rlon = geom%lonCell(ii)

           ! Now loop over all levels
           do jlev = 1, geom%nVertLevels

              zhalf = MPAS_JEDI_HALF_kr * (geom%zgrid(jlev,ii) + geom%zgrid(jlev+1,ii))
              Call test1_advection_hadley(rlon,rlat,pk,zhalf,1,u0,v0,w0,&
                                          t0,phis0,ps0,rho0,hum0,q1)
              p(jlev,ii) = pk
              temperature(jlev,ii) = t0
              u(jlev,ii) = u0
              v(jlev,ii) = v0
              qv(jlev,ii) = hum0
           enddo
           ps(ii) = ps0
        enddo

     case ("dcmip-test-3-1")

        do ii = 1, geom%nCellsSolve
           rlat = geom%latCell(ii)
           rlon = geom%lonCell(ii)

           ! Now loop over all levels
           do jlev = 1, geom%nVertLevels

              zhalf = MPAS_JEDI_HALF_kr * (geom%zgrid(jlev,ii) + geom%zgrid(jlev+1,ii))
              Call test3_gravity_wave(rlon,rlat,pk,zhalf,1,u0,v0,w0,&
                                      t0,phis0,ps0,rho0,hum0)

              p(jlev,ii) = pk
              temperature(jlev,ii) = t0
              u(jlev,ii) = u0
              v(jlev,ii) = v0
              qv(jlev,ii) = hum0
           enddo
           ps(ii) = ps0
        enddo

     case ("dcmip-test-4-0")

        do ii = 1, geom%nCellsSolve
           rlat = geom%latCell(ii)
           rlon = geom%lonCell(ii)

           ! Now loop over all levels
           do jlev = 1, geom%nVertLevels

              zhalf = MPAS_JEDI_HALF_kr * (geom%zgrid(jlev,ii) + geom%zgrid(jlev+1,ii))
              Call test4_baroclinic_wave(0,MPAS_JEDI_ONE_kr,rlon,rlat,pk,zhalf,1,u0,v0,w0,&
                                      t0,phis0,ps0,rho0,hum0,q1,q2)

              p(jlev,ii) = pk
              temperature(jlev,ii) = t0
              u(jlev,ii) = u0
              v(jlev,ii) = v0
              qv(jlev,ii) = hum0
           enddo
           ps(ii) = ps0
        enddo

     case default
        call abor1_ftn("mpas_state.analytic_IC: invalid selection for ''analytic init.method''")

  end select init_option

  !================================================
  ! copy the analytical values to this State object
  do iVar = 1, self % nf
    varName = trim(self % fldnames(iVar))
    call self%get(varName, fieldData)

    select case (trim(varName))
      case('air_pressure')
        fieldData%r2%array(:,1:geom%nCellsSolve) = p

      case('virtual_temperature', 'air_temperature')
        fieldData%r2%array(:,1:geom%nCellsSolve) = temperature

      case('eastward_wind')
        fieldData%r2%array(:,1:geom%nCellsSolve) = u

      case('northward_wind')
        fieldData%r2%array(:,1:geom%nCellsSolve) = v

      case('water_vapor_mixing_ratio_wrt_moist_air')
        fieldData%r2%array(:,1:geom%nCellsSolve) = qv

      case('air_pressure_at_surface')
        fieldData%r1%array(1:geom%nCellsSolve) = ps

    end select
  end do

  !========
  ! cleanup
  deallocate(p, temperature, u, v, qv, ps)

  call fckit_log%debug ('==> end mpas_state:analytic_init')

end subroutine analytic_IC

! ------------------------------------------------------------------------------

end module mpas_state_mod
