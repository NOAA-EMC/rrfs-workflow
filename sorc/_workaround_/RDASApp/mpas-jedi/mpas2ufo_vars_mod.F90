!***********************************************************************
! Copyright (c) 2018, National Atmospheric for Atmospheric Research (NCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.com/license.html
!
!-----------------------------------------------------------------------

module mpas2ufo_vars_mod

!***********************************************************************
!
!  Module mpas2ufo_vars_mod to convert/extract variables from MPAS
!  needed for Data assimilation purpose.
!> \author  Gael Descombes/Mickael Duda NCAR/MMM
!> \date    Februray 2018
!
!-----------------------------------------------------------------------

use fckit_log_module, only : fckit_log

!oops
use kinds, only : kind_real

!ufo
use gnssro_mod_transform, only: geometric2geop
use ufo_vars_mod

!MPAS-Model
use atm_core
!use mpas_abort, only : mpas_dmpar_global_abort
use mpas_constants, only : gravity, rgas, rv, cp
!use mpas_dmpar
use mpas_derived_types
use mpas_field_routines
use mpas_pool_routines

!MPAS-JEDI
use mpas_constants_mod
use mpas_geom_mod
use mpas_kinds, only : kind_double

implicit none

private

! public variable conversions
! model2analysis
public :: theta_to_temp, &
          w_to_q, &
          vv_to_vva

! analysis2model
public :: hydrostatic_balance
public :: linearized_hydrostatic_balance

! model2geovars only
public :: effectrad_graupel, &
          effectrad_rainwater
public :: pressure_half_to_full
public :: convert_type_soil, convert_type_veg_usgs, convert_type_veg_igbp
public :: tropopause_pressure_th
public :: tropopause_pressure_wmo
!public :: uv_to_wdir

! model2geovars+tlad
public :: q_to_w, &
          tw_to_tv, &
          q_fields_forward, &
          dryrho_to_moistrho
public :: tw_to_tv_tl, tw_to_tv_ad, &
          q_to_w_tl, q_to_w_ad, &
          q_fields_tl, q_fields_ad


! unknown purpose
!public :: twp_to_rho, temp_to_theta

! for fckit_log
integer, parameter    :: max_string=8000
character(max_string) :: message

contains

!-------------------------------------------------------------------------------------------

!-- from WRFDA/da_crtm.f90
function convert_type_soil(type_in) result(t)
  integer, intent(in) :: type_in
  integer :: t

  ! CRTM soil types in crtm/src/SfcOptics/CRTM_MW_Land_SfcOptics.f90
  ! INTEGER, PARAMETER :: COARSE          =  1
  ! INTEGER, PARAMETER :: MEDIUM          =  2
  ! INTEGER, PARAMETER :: FINE            =  3
  ! INTEGER, PARAMETER :: COARSE_MEDIUM   =  4
  ! INTEGER, PARAMETER :: COARSE_FINE     =  5
  ! INTEGER, PARAMETER :: MEDIUM_FINE     =  6
  ! INTEGER, PARAMETER :: COARSE_MED_FINE =  7
  ! INTEGER, PARAMETER :: ORGANIC         =  8
  ! Note: 9 corresponds to glacial soil, for which the land fraction
  !       must be equal to zero.
  integer, parameter :: n_soil_type = 16  ! wrf num_soil_cat
  integer, parameter :: wrf_to_crtm_soil(n_soil_type) = &
    (/ 1, 1, 4, 2, 2, 8, 7, 2, 6, 5, 2, 3, 8, 1, 6, 9 /)

  t = max( 1, wrf_to_crtm_soil(type_in) )
end function convert_type_soil! CRTM vegetation types in crtm/src/SfcOptics/CRTM_MW_Land_SfcOptics.f90

! CRTM vegetation types in crtm/src/SfcOptics/CRTM_MW_Land_SfcOptics.f90
! INTEGER, PARAMETER :: BROADLEAF_EVERGREEN_TREES      =  1
! INTEGER, PARAMETER :: BROADLEAF_DECIDUOUS_TREES      =  2
! INTEGER, PARAMETER :: BROADLEAF_NEEDLELEAF_TREES     =  3
! INTEGER, PARAMETER :: NEEDLELEAF_EVERGREEN_TREES     =  4
! INTEGER, PARAMETER :: NEEDLELEAF_DECIDUOUS_TREES     =  5
! INTEGER, PARAMETER :: BROADLEAF_TREES_GROUNDCOVER    =  6
! INTEGER, PARAMETER :: GROUNDCOVER                    =  7
! INTEGER, PARAMETER :: GROADLEAF_SHRUBS_GROUNDCOVER   =  8
! INTEGER, PARAMETER :: BROADLEAF_SHRUBS_BARE_SOIL     =  9
! INTEGER, PARAMETER :: DWARF_TREES_SHRUBS_GROUNDCOVER = 10
! INTEGER, PARAMETER :: BARE_SOIL                      = 11
! INTEGER, PARAMETER :: CULTIVATIONS                   = 12
! Note: 13 corresponds to glacial vegetation, for which the land fraction
!       must be equal to zero.

function convert_type_veg_usgs(type_in) result(t)
  integer, intent(in) :: type_in
  integer :: t

  ! vegetation type mapping for GFS classification scheme
  ! REL-2.1.3.CRTM_User_Guide.pdf table 4.16
  integer, parameter :: n_type = 24
  integer, parameter :: usgs_to_crtm_veg(n_type) = &
     (/  7, 12, 12, 12, 12, 12,  7,  9,  8,  6, &
         2,  5,  1,  4,  3,  0,  8,  8, 11, 10, &
        10, 10, 11, 13 /)

  t = max( 1, usgs_to_crtm_veg(type_in) )
end function convert_type_veg_usgs

function convert_type_veg_igbp(type_in) result(t)
  integer, intent(in) :: type_in
  integer :: t

  ! vegetation type mapping for GFS classification scheme
  ! REL-2.1.3.CRTM_User_Guide.pdf table 4.16
  integer, parameter :: n_type = 20
  integer, parameter :: igbp_to_crtm_veg(n_type) = &
     (/  4,  1,  5,  2,  3,  8,  9,  6,  6,  7, &
         8, 12,  7, 12, 13, 11,  0, 10, 10, 11 /)

  t = max( 1, igbp_to_crtm_veg(type_in) )
end function convert_type_veg_igbp

!  !-- from GSI/crtm_interface.f90
!  integer(i_kind), parameter :: USGS_N_TYPES = 24
!  integer(i_kind), parameter :: IGBP_N_TYPES = 20
!  integer(i_kind), parameter :: NAM_SOIL_N_TYPES = 16
!  integer(i_kind), parameter, dimension(1:IGBP_N_TYPES) :: igbp_to_gfs=(/4, &
!    1, 5, 2, 3, 8, 9, 6, 6, 7, 8, 12, 7, 12, 13, 11, 0, 10, 10, 11/)
!  integer(i_kind), parameter, dimension(1:USGS_N_TYPES) :: usgs_to_gfs=(/7, &
!    12, 12, 12, 12, 12, 7, 9, 8, 6, 2, 5, 1, 4, 3, 0, 8, 8, 11, 10, 10, &
!    10, 11, 13/)
!  integer(i_kind), parameter, dimension(1:NAM_SOIL_N_TYPES) :: nmm_soil_to_crtm=(/1, &
!    1, 4, 2, 2, 8, 7, 2, 6, 5, 2, 3, 8, 1, 6, 9/)

!-------------------------------------------------------------------------------------------

!!-from subroutine call_crtm in GSI/crtm_interface.f90
!subroutine uv_to_wdir(uu5, vv5, wind10_direction)
!
!   implicit none
!
!   real (kind=kind_real), intent(in)  :: uu5, vv5
!   real (kind=kind_real), intent(out) :: wind10_direction
!   real (kind=kind_real)              :: windratio, windangle
!   integer                            :: iquadrant
!   real(kind=RKIND),parameter:: windscale = 999999.0_kind_real
!   real(kind=RKIND),parameter:: windlimit = 0.0001_kind_real
!   real(kind=RKIND),parameter:: quadcof  (4, 2  ) = &
!      reshape((/MPAS_JEDI_ZERO_kr,  MPAS_JEDI_ONE_kr,  MPAS_JEDI_ONE_kr,  MPAS_JEDI_TWO_kr, &
!                MPAS_JEDI_ONE_kr,  -MPAS_JEDI_ONE_kr,  MPAS_JEDI_ONE_kr, -MPAS_JEDI_ONE_kr/), (/4, 2/))
!
!   if (uu5 >= MPAS_JEDI_ZERO_kr .and. vv5 >= MPAS_JEDI_ZERO_kr) iquadrant = 1
!   if (uu5 >= MPAS_JEDI_ZERO_kr .and. vv5 <  MPAS_JEDI_ZERO_kr) iquadrant = 2
!   if (uu5 <  MPAS_JEDI_ZERO_kr .and. vv5 >= MPAS_JEDI_ZERO_kr) iquadrant = 4
!   if (uu5 <  MPAS_JEDI_ZERO_kr .and. vv5 <  MPAS_JEDI_ZERO_kr) iquadrant = 3
!   if (abs(vv5) >= windlimit) then
!      windratio = uu5 / vv5
!   else
!      windratio = MPAS_JEDI_ZERO_kr
!      if (abs(uu5) > windlimit) then
!         windratio = windscale * uu5
!      endif
!   endif
!   windangle        = atan(abs(windratio))   ! wind azimuth is in radians
!   wind10_direction = ( quadcof(iquadrant, 1) * MPAS_JEDI_PII_kr + windangle * quadcof(iquadrant, 2) )
!
!end subroutine uv_to_wdir

!-------------------------------------------------------------------------------------------
elemental subroutine w_to_q(mixing_ratio, specific_humidity)
   implicit none
   real (kind=RKIND), intent(in)  :: mixing_ratio
   real (kind=RKIND), intent(out) :: specific_humidity

   specific_humidity = mixing_ratio / (MPAS_JEDI_ONE_kr + mixing_ratio)
end subroutine w_to_q
!-------------------------------------------------------------------------------------------
elemental subroutine q_to_w(specific_humidity, mixing_ratio)
   implicit none
   real (kind=RKIND), intent(in)  :: specific_humidity
   real (kind=RKIND), intent(out) :: mixing_ratio

   mixing_ratio = specific_humidity / (MPAS_JEDI_ONE_kr - specific_humidity)
end subroutine q_to_w
!-------------------------------------------------------------------------------------------
elemental subroutine q_to_w_tl(specific_humidity_tl, sh_traj, mixing_ratio_tl)
   implicit none
   real (kind=RKIND), intent(in)  :: specific_humidity_tl
   real (kind=RKIND), intent(in)  :: sh_traj
   real (kind=RKIND), intent(out) :: mixing_ratio_tl

   mixing_ratio_tl = specific_humidity_tl / (MPAS_JEDI_ONE_kr - sh_traj)**2
end subroutine q_to_w_tl
!-------------------------------------------------------------------------------------------
elemental subroutine q_to_w_ad(specific_humidity_ad, sh_traj, mixing_ratio_ad)
   implicit none
   real (kind=RKIND), intent(inout) :: specific_humidity_ad
   real (kind=RKIND), intent(in)    :: sh_traj
   real (kind=RKIND), intent(in)    :: mixing_ratio_ad

   specific_humidity_ad = specific_humidity_ad + &
                 MPAS_JEDI_ONE_kr / ( MPAS_JEDI_ONE_kr - sh_traj)**2 * mixing_ratio_ad
end subroutine q_to_w_ad
!-------------------------------------------------------------------------------------------
elemental subroutine tw_to_tv(temperature,mixing_ratio,virtual_temperature)
   implicit none
   real (kind=RKIND), intent(in)  :: temperature
   real (kind=RKIND), intent(in)  :: mixing_ratio
   real (kind=RKIND), intent(out) :: virtual_temperature

   virtual_temperature = temperature * &
                  ( MPAS_JEDI_ONE_kr + (rv/rgas - MPAS_JEDI_ONE_kr)*mixing_ratio )
end subroutine tw_to_tv
!-------------------------------------------------------------------------------------------
elemental subroutine tw_to_tv_tl(temperature_tl,mixing_ratio_tl,t_traj,m_traj,virtual_temperature_tl)
   implicit none
   real (kind=RKIND), intent(in)  :: temperature_tl
   real (kind=RKIND), intent(in)  :: mixing_ratio_tl
   real (kind=RKIND), intent(in)  :: t_traj
   real (kind=RKIND), intent(in)  :: m_traj
   real (kind=RKIND), intent(out) :: virtual_temperature_tl

   virtual_temperature_tl = temperature_tl * &
                  ( MPAS_JEDI_ONE_kr + (rv/rgas - MPAS_JEDI_ONE_kr)*m_traj )  + &
                  t_traj * (rv/rgas - MPAS_JEDI_ONE_kr)*mixing_ratio_tl
end subroutine tw_to_tv_tl
!-------------------------------------------------------------------------------------------
elemental subroutine tw_to_tv_ad(temperature_ad,mixing_ratio_ad,t_traj,m_traj,virtual_temperature_ad)
   implicit none
   real (kind=RKIND), intent(inout) :: temperature_ad
   real (kind=RKIND), intent(inout) :: mixing_ratio_ad
   real (kind=RKIND), intent(in)    :: t_traj
   real (kind=RKIND), intent(in)    :: m_traj
   real (kind=RKIND), intent(in)    :: virtual_temperature_ad

   temperature_ad = temperature_ad + virtual_temperature_ad * &
                  ( MPAS_JEDI_ONE_kr + (rv/rgas - MPAS_JEDI_ONE_kr)*m_traj )
   mixing_ratio_ad = mixing_ratio_ad + virtual_temperature_ad * &
                  t_traj * (rv/rgas - MPAS_JEDI_ONE_kr)
end subroutine tw_to_tv_ad
!-------------------------------------------------------------------------------------------
elemental subroutine theta_to_temp(theta,pressure,temperature)
   implicit none
   real (kind=RKIND), intent(in)  :: theta
   real (kind=RKIND), intent(in)  :: pressure
   real (kind=RKIND), intent(out) :: temperature

   temperature = theta / &
             ( MPAS_JEDI_P0_kr / pressure ) ** ( rgas / cp )
   !TODO: Following formula would give the same result with the formular above,
   !      but gives a slightly different precision. Need to check.
   !temperature = theta * &
   !          ( pressure / MPAS_JEDI_P0_kr ) ** ( rgas / cp )
end subroutine theta_to_temp
!-------------------------------------------------------------------------------------------
!elemental subroutine temp_to_theta(temperature,pressure,theta)
!   implicit none
!   real (kind=kind_real), intent(in)  :: temperature
!   real (kind=kind_real), intent(in)  :: pressure
!   real (kind=kind_real), intent(out) :: theta
!   theta = temperature * &
!             ( MPAS_JEDI_P0_kr / pressure ) ** ( rgas / cp )
!end subroutine temp_to_theta
!-------------------------------------------------------------------------------------------
!elemental subroutine twp_to_rho(temperature,mixing_ratio,pressure,rho)
!   implicit none
!   real (kind=kind_real), intent(in)  :: temperature
!   real (kind=kind_real), intent(in)  :: mixing_ratio
!   real (kind=kind_real), intent(in)  :: pressure
!   real (kind=kind_real), intent(out) :: rho
!   rho = pressure / ( rgas * temperature * &
!                                ( MPAS_JEDI_ONE_kr + (rv/rgas) * mixing_ratio ) )
!end subroutine twp_to_rho
!-------------------------------------------------------------------------------------------

subroutine vv_to_vva(w, wa, nC, nV)
   implicit none
   real (kind=RKIND), dimension(nV+1,nC), intent(in) :: w
   real (kind=RKIND), dimension(nV,nC), intent(out)  :: wa
   integer, intent(in) :: nC, nV

   wa(:,1:nC) = MPAS_JEDI_HALF_kr * ( w(1:nV,1:nC) + w(2:nV+1,1:nC) )
end subroutine vv_to_vva
!-------------------------------------------------------------------------------------------
subroutine pressure_half_to_full(pressure, zgrid, surface_pressure, nC, nV, pressure_f)
   implicit none
   real (kind=RKIND), dimension(nV,nC), intent(in) :: pressure
   real (kind=RKIND), dimension(nV+1,nC), intent(in) :: zgrid
   real (kind=RKIND), dimension(nC), intent(in) :: surface_pressure
   integer, intent(in) :: nC, nV
   real (kind=RKIND), dimension(nV+1,nC), intent(out) :: pressure_f

   real (kind=RKIND) :: z0, z1, z2, w1, w2
   integer :: i, k, its, ite, kts, kte

   ! 07OCT2022:
   !-- linearly interpolate/extrapolate log(p) following natural variation of pressure with height

   ! Before 07OCT2022; linear interpolation of P:
   !-- ~/libs/MPAS-Release/src/core_atmosphere/physics/mpas_atmphys_manager.F
   !-- ~/libs/MPAS-Release/src/core_atmosphere/physics/mpas_atmphys_interface.F
   !-- ~/libs/MPAS-Release/src/core_atmosphere/physics/mpas_atmphys_vars.F

   its=1 ; ite = nC
   kts=1 ; kte = nV

   ! bottom
   k = kts
   do i = its,ite
     pressure_f(k,i) = surface_pressure(i)
   enddo

   ! internal levels (interpolation)
   do k = kts+1,kte
     do i = its,ite
       w1 = ( zgrid(k,i) - zgrid(k-1,i)) / (zgrid(k+1,i) - zgrid(k-1,i))
       w2 = MPAS_JEDI_ONE_kr - w1
       pressure_f(k,i) = exp( w1*log(pressure(k,i)) + w2*log(pressure(k-1,i)) )
     enddo
   enddo

   ! top (extrapolation)
   k = kte+1
   do i = its,ite
     z0 = zgrid(k,i)
     z1 = MPAS_JEDI_HALF_kr*(zgrid(k,i)+zgrid(k-1,i))
     z2 = MPAS_JEDI_HALF_kr*(zgrid(k-1,i)+zgrid(k-2,i))
     w1 = (z0-z2)/(z1-z2)
     w2 = MPAS_JEDI_ONE_kr-w1
     pressure_f(k,i) = exp( w1*log(pressure(k-1,i)) + w2*log(pressure(k-2,i)) )
   enddo

end subroutine pressure_half_to_full
!-------------------------------------------------------------------------------------------
subroutine hydrostatic_balance(ncells, nlevels, zw, t, qv, ps, p, rho, theta)
!---------------------------------------------------------------------------------------
! Purpose:
!    Derive 3D pressure, dry air density, and dry potential temperature
!    from analyzed surface pressure, temperature, and water vapor mixing
!    ratio by applying hypsometric equation, equation of state, and
!    Poisson's equation from bottom to top.
! Method:
!    1. Vertical integral of pressure from half level k-1 to k is split
!       into two steps: step-1 does integral from half level k-1 to full
!       level k, followed by a step-2 integral from full level k to half level k.
!       Full-level Tv is derived using bilinear interpolation of half level Tv.
!    2. Layer's virtual T: Tv = T * (1 + 0.608*Qv)
!    3. Hypsometric Eq.: P(z2) = P(z1) * exp[-g*(z2-z1)/(Rd*Tv)]
!    4. Eq. of State: rho_m = P/(Rd*Tv); rho_d = rho_m/(1+Qv). Add Qc/Qi/Qs/Qg?
!    5. Poisson's Eq.: theta_d = T * (P0/P)^(Rd/cp)
! References:
!    MPAS-A model user's guide version 7.0, Appendix C.2 for vertical grid.
!--------------------------------------------------------------------------
   implicit none
   integer,                                            intent(in)  :: ncells, nlevels
   real (kind=RKIND), dimension(nlevels+1,ncells), intent(in)  :: zw    ! physical height m at w levels
   real (kind=RKIND), dimension(nlevels,ncells),   intent(in)  :: t     ! temperature, K
   real (kind=RKIND), dimension(nlevels,ncells),   intent(in)  :: qv    ! mixing ratio, kg/kg
   real (kind=RKIND), dimension(ncells),           intent(in)  :: ps    ! surface P, Pa
   real (kind=RKIND), dimension(nlevels,ncells),   intent(out) :: p     ! 3D P, Pa
   real (kind=RKIND), dimension(nlevels,ncells),   intent(out) :: rho   ! dry air density, kg/m^3
   real (kind=RKIND), dimension(nlevels,ncells),   intent(out) :: theta ! dry potential T, K

   integer                :: icell, k
   real (kind=RKIND)  :: rvordm1   ! rv/rd - 1. = 461.6/287-1 ~= 0.60836
   real (kind=RKIND), dimension(nlevels)   :: tv_h  ! half level virtual T
   real (kind=RKIND), dimension(nlevels+1) :: pf    ! full level pressure
   real (kind=RKIND), dimension(nlevels)   :: zu    ! physical height at u level
   real (kind=RKIND)  :: tv_f, tv, w

      rvordm1 = rv/rgas - MPAS_JEDI_ONE_kr

      do icell=1,ncells

         k = 1 ! 1st half level
         pf(k) = ps(icell) ! first full level P is at surface
         zu(k) = MPAS_JEDI_HALF_kr * ( zw(k,icell) + zw(k+1,icell) )
         tv_h(k) = t(k,icell) * ( MPAS_JEDI_ONE_kr + rvordm1*qv(k,icell) )

       ! integral from full level k to half level k
         p(k,icell) = pf(k) * exp( -gravity * (zu(k)-zw(k,icell))/(rgas*tv_h(k)) )
         rho(k,icell) = p(k,icell)/( rgas*tv_h(k)*(MPAS_JEDI_ONE_kr+qv(k,icell)) )
         theta(k,icell) = t(k,icell) * ( MPAS_JEDI_P0_kr/p(k,icell) )**(rgas/cp)

       do k=2,nlevels ! loop over half levels

       ! half level physical height, zu(k-1) -> zw(k) -> zu(k)
         zu(k) = MPAS_JEDI_HALF_kr * ( zw(k,icell) + zw(k+1,icell) )

       ! bilinear interpolation weight for value at the half level below the full level
         w = ( zu(k) - zw(k,icell) )/( zu(k) - zu(k-1) )

       ! half level Tv
         tv_h(k)   = t(k,  icell) * ( MPAS_JEDI_ONE_kr + rvordm1*qv(k,  icell) )

       ! interpolate two half levels Tv to a full level Tv
         tv_f = w * tv_h(k-1) + (MPAS_JEDI_ONE_kr - w) * tv_h(k)

       ! two-step integral from half level k-1 to k
       !-----------------------------------------------------------

       ! step-1: tv used for integral from half level k-1 to full level k
         tv = MPAS_JEDI_HALF_kr * ( tv_h(k-1) + tv_f )

       ! step-1: integral from half level k-1 to full level k, hypsometric Eq.
         pf(k) = p(k-1,icell) * exp( -gravity * (zw(k,icell)-zu(k-1))/(rgas*tv) )

       ! step-2: tv used for integral from full level k to half level k
         tv = MPAS_JEDI_HALF_kr * ( tv_h(k) + tv_f )

       ! step-2: integral from full level k to half level k
         p(k,icell) = pf(k) * exp( -gravity * (zu(k)-zw(k,icell))/(rgas*tv) )

       !------------------------------------------------------------
       ! dry air density at half level, equation of state
         rho(k,icell) = p(k,icell)/( rgas*tv_h(k)*(MPAS_JEDI_ONE_kr+qv(k,icell)) )

       ! dry potential T at half level, Poisson's equation
         theta(k,icell) = t(k,icell) * ( MPAS_JEDI_P0_kr/p(k,icell) )**(rgas/cp)

       end do
      end do

end subroutine hydrostatic_balance
!-------------------------------------------------------------------------------------------
subroutine linearized_hydrostatic_balance(ncells, nlevels, zw, t, qv, ps, p, dt, dqv, dps, dp, drho, dtheta)

   implicit none
   integer,                                            intent(in)  :: ncells, nlevels
   real (kind=RKIND), dimension(nlevels+1,ncells), intent(in)  :: zw     ! physical height m at w levels
   real (kind=RKIND), dimension(nlevels,ncells),   intent(in)  :: t      ! temperature, K
   real (kind=RKIND), dimension(nlevels,ncells),   intent(in)  :: qv     ! mixing ratio, kg/kg      ! background
   real (kind=RKIND), dimension(ncells),           intent(in)  :: ps     ! surface P, Pa            ! background
   real (kind=RKIND), dimension(nlevels,ncells),   intent(in)  :: p      ! 3D P, Pa                 ! background
   real (kind=RKIND), dimension(nlevels,ncells),   intent(in)  :: dt     ! temperature, K           ! increment
   real (kind=RKIND), dimension(nlevels,ncells),   intent(in)  :: dqv    ! mixing ratio, kg/kg      ! increment
   real (kind=RKIND), dimension(ncells),           intent(in)  :: dps    ! surface P, Pa            ! increment
   real (kind=RKIND), dimension(nlevels,ncells),   intent(out) :: dp     ! 3D P, Pa                 ! increment
   real (kind=RKIND), dimension(nlevels,ncells),   intent(out) :: drho   ! dry air density, kg/m^3  ! increment
   real (kind=RKIND), dimension(nlevels,ncells),   intent(out) :: dtheta ! dry potential T, K       ! increment

   integer                :: icell, k
   real (kind=RKIND)  :: rvordm1   ! rv/rd - 1. = 461.6/287-1 ~= 0.60836
   real (kind=RKIND), dimension(nlevels)   :: tv_h, dtv_h  ! half level virtual T
   real (kind=RKIND), dimension(nlevels+1) :: pf, dpf      ! full level pressure
   real (kind=RKIND), dimension(nlevels)   :: zu           ! physical height at u level
   real (kind=RKIND)  :: tv_f, dtv_f, tv, dtv, w

      rvordm1 = rv/rgas - MPAS_JEDI_ONE_kr

      do icell=1,ncells

         k = 1 ! 1st half level
         pf(k)  =  ps(icell) ! first full level P is at surface
         dpf(k) = dps(icell)
         zu(k)  = MPAS_JEDI_HALF_kr * ( zw(k,icell) + zw(k+1,icell) )
         tv_h(k)  =  t(k,icell) * ( MPAS_JEDI_ONE_kr + rvordm1*qv(k,icell) )
         dtv_h(k) = dt(k,icell) * ( MPAS_JEDI_ONE_kr + rvordm1*qv(k,icell) ) + &
                     t(k,icell) * rvordm1*dqv(k,icell) 

       ! integral from full level k to half level k
!         p(k,icell) = pf(k) * exp( -gravity * (zu(k)-zw(k,icell))/(rgas*tv_h(k)) )
         dp(k,icell) = dpf(k) * exp( -gravity * (zu(k)-zw(k,icell))/(rgas*tv_h(k)) ) + &
                        pf(k) * exp( -gravity * (zu(k)-zw(k,icell))/(rgas*tv_h(k)) ) * &
                        gravity * (zu(k)-zw(k,icell))/(rgas*tv_h(k)**2) * dtv_h(k)

!         rho(k,icell) = p(k,icell)/( rgas*tv_h(k)*(MPAS_JEDI_ONE_kr+qv(k,icell)) )
         drho(k,icell) = dp(k,icell)/( rgas*tv_h(k)*(MPAS_JEDI_ONE_kr+qv(k,icell)) ) - &
                         p(k,icell)/( rgas*tv_h(k)**2*(MPAS_JEDI_ONE_kr+qv(k,icell)) ) * dtv_h(k) - &
                         p(k,icell)/( rgas*tv_h(k)*(MPAS_JEDI_ONE_kr+qv(k,icell))**2 ) * dqv(k,icell)
!         theta(k,icell) = t(k,icell) * ( MPAS_JEDI_P0_kr/p(k,icell) )**(rgas/cp)
         dtheta(k,icell) = dt(k,icell) * ( MPAS_JEDI_P0_kr/p(k,icell) )**(rgas/cp) - &
                           t(k,icell) * rgas/cp * ( MPAS_JEDI_P0_kr/p(k,icell) )**(rgas/cp-MPAS_JEDI_ONE_kr) * &
                           MPAS_JEDI_P0_kr/p(k,icell)**2 * dp(k,icell)

       do k=2,nlevels ! loop over half levels

       ! half level physical height, zu(k-1) -> zw(k) -> zu(k)
         zu(k) = MPAS_JEDI_HALF_kr * ( zw(k,icell) + zw(k+1,icell) )

       ! bilinear interpolation weight for value at the half level below the full level
         w = ( zu(k) - zw(k,icell) ) / ( zu(k) - zu(k-1) )

       ! half level Tv
         tv_h(k)  =  t(k, icell) * ( MPAS_JEDI_ONE_kr + rvordm1*qv(k, icell) )
         dtv_h(k) = dt(k, icell) * ( MPAS_JEDI_ONE_kr + rvordm1*qv(k, icell) ) + &
                      t(k, icell) * rvordm1*dqv(k, icell)

       ! interpolate two half levels Tv to a full level Tv
         tv_f  = w *  tv_h(k-1) + (MPAS_JEDI_ONE_kr - w) *  tv_h(k)
         dtv_f = w * dtv_h(k-1) + (MPAS_JEDI_ONE_kr - w) * dtv_h(k)

       ! two-step integral from half level k-1 to k
       !-----------------------------------------------------------

       ! step-1: tv used for integral from half level k-1 to full level k
         tv  = MPAS_JEDI_HALF_kr * (  tv_h(k-1) +  tv_f )
         dtv = MPAS_JEDI_HALF_kr * ( dtv_h(k-1) + dtv_f )

       ! step-1: integral from half level k-1 to full level k, hypsometric Eq.
         pf(k)  =  p(k-1,icell) * exp( -gravity * (zw(k,icell)-zu(k-1))/(rgas*tv) )
         dpf(k) = dp(k-1,icell) * exp( -gravity * (zw(k,icell)-zu(k-1))/(rgas*tv) ) + &
                   p(k-1,icell) * exp( -gravity * (zw(k,icell)-zu(k-1))/(rgas*tv) ) * &
                   gravity * (zw(k,icell)-zu(k-1))/(rgas*tv**2) * dtv

       ! step-2: tv used for integral from full level k to half level k
         tv  = MPAS_JEDI_HALF_kr * (  tv_h(k) +  tv_f )
         dtv = MPAS_JEDI_HALF_kr * ( dtv_h(k) + dtv_f )

       ! step-2: integral from full level k to half level k
!         p(k,icell) = pf(k) * exp( -gravity * (zu(k)-zw(k,icell))/(rgas*tv) )
         dp(k,icell) = dpf(k) * exp( -gravity * (zu(k)-zw(k,icell))/(rgas*tv) ) + &
                        pf(k) * exp( -gravity * (zu(k)-zw(k,icell))/(rgas*tv) ) * &
                        gravity * (zu(k)-zw(k,icell))/(rgas*tv**2) * dtv

       !------------------------------------------------------------
       ! dry air density at half level, equation of state
!         rho(k,icell) = p(k,icell)/( rgas*tv_h(k)*(MPAS_JEDI_ONE_kr+qv(k,icell)) )
         drho(k,icell) = dp(k,icell)/( rgas*tv_h(k)*(MPAS_JEDI_ONE_kr+qv(k,icell)) ) - &
                         p(k,icell)/( rgas*tv_h(k)**2*(MPAS_JEDI_ONE_kr+qv(k,icell)) ) * dtv_h(k) - &
                         p(k,icell)/( rgas*tv_h(k)*(MPAS_JEDI_ONE_kr+qv(k,icell))**2 ) * dqv(k,icell)

       ! dry potential T at half level, Poisson's equation
!         theta(k,icell) = t(k,icell) * ( MPAS_JEDI_P0_kr/p(k,icell) )**(rgas/cp)
         dtheta(k,icell) = dt(k,icell) * ( MPAS_JEDI_P0_kr/p(k,icell) )**(rgas/cp) - &
                           t(k,icell) * rgas/cp * ( MPAS_JEDI_P0_kr/p(k,icell) )**(rgas/cp-MPAS_JEDI_ONE_kr) * &
                           MPAS_JEDI_P0_kr/p(k,icell)**2 * dp(k,icell)

       end do
      end do

end subroutine linearized_hydrostatic_balance
!-------------------------------------------------------------------------------------------
subroutine tropopause_pressure_th(p, z, t, nCells, nVertLevels, tprs)
   !..Adapted from FV3-JEDI tropprs_th subroutine written by Greg Thompson
   !..Find tropopause height based on delta-Theta / delta-Z. The 10/1500 ratio
   !.. approximates a vertical line on typical SkewT chart near typical (mid-latitude)
   !.. tropopause height.  Since messy data could give us a false signal of such a
   !.. transition, do the check over at least 35 mb delta-pres, not just a level-to-level
   !.. check.  This method has potential failure in arctic-like conditions with extremely
   !.. low tropopause height, as would any other diagnostic, so ensure resulting k_tropo
   !.. level is above 700hPa.

   implicit none

   real(kind=RKIND), intent(in ) :: p(nVertLevels, nCells)   !Pressure, midpoint [Pa]
   real(kind=RKIND), intent(in ) :: t(nVertLevels, nCells)   !Temperature [K]
   real(kind=RKIND), intent(in ) :: z(nVertLevels, nCells)   !Height/altitude [m]
   real(kind=RKIND), intent(out) :: tprs(nCells)             !Tropopause pressure [Pa]
   integer,              intent(in ) :: nCells                   !number of grid cells
   integer,              intent(in ) :: nVertLevels              !number of vertical levels

   ! Local
   integer :: k1, k2, k_p50, k_p150, k_tropo
   real(kind=RKIND) :: theta(nVertLevels)
   integer :: iCell, iLevel

   ! Compute tropopause pressure
   do iCell = 1, nCells
      k_p150 = 0
      k_p50  = 0
      do iLevel = nVertLevels, 1, -1
        theta(iLevel) = t(iLevel,iCell)*((MPAS_JEDI_P0_kr/p(iLevel,iCell))**(rgas/cp))
        if (p(iLevel,iCell) .gt. 4999.0  .and. k_p50  .eq. 0) k_p50  = iLevel
        if (p(iLevel,iCell) .gt. 14999.0 .and. k_p150 .eq. 0) k_p150 = iLevel
      enddo
      if ( (k_p50-k_p150) .lt. 3) k_p150 = k_p50-3
      do iLevel = k_p150-2, 1, -1
        k1 = iLevel
        k2 = k1+2
        do while (k1.gt.1 .and. (p(k1,iCell)-p(k2,iCell)).lt.3500.0 .and. p(k1,iCell).lt.70000.)
          k1 = k1-1
        enddo
        if ( ((theta(k2)-theta(k1))/(z(k2,iCell)-z(k1,iCell))) .lt. 10./1500.) exit
      enddo
      k_tropo = max(3, min(nint(0.5*(k1+k2+1)), k_p50-1))
      tprs(iCell) = p(k_tropo,iCell)
   enddo
end subroutine tropopause_pressure_th
!-------------------------------------------------------------------------------------------
subroutine tropopause_pressure_wmo(p, z, t, nCells, nVertLevels, tropk)
   ! Adapted from WRFDA
   !----------------------------------------------------------------------------
   ! * Computes tropopause T, P, and/or level based on code from Cameron Homeyer
   !     and WMO definition
   !
   ! * WMO tropopause definition:
   !     The boundary between the troposphere and the stratosphere, where an
   !     abrupt change in lapse rate usually occurs. It is defined as the lowest
   !     level at which the lapse rate decreases to 2 °C/km or less, provided
   !     that the average lapse rate between this level and all higher levels
   !     within 2 km does not exceed 2 °C/km.
   !----------------------------------------------------------------------------

   implicit none

   real(kind=RKIND), intent(in ) :: p(nVertLevels, nCells)   !Pressure, midpoint [Pa]
   real(kind=RKIND), intent(in ) :: t(nVertLevels, nCells)   !Temperature [K]
   real(kind=RKIND), intent(in ) :: z(nVertLevels, nCells)   !Height/altitude [m]
   real(kind=RKIND), intent(out) :: tropk(nCells)            !Tropopause pressure [Pa]
   integer,              intent(in ) :: nCells                   !number of grid cells
   integer,              intent(in ) :: nVertLevels              !number of vertical levels

   ! Local
   real    :: dtdz, laps  !LAPS
   integer :: dtdztest(nVertLevels), ztest(nVertLevels)
   integer :: i, j, k, kk, ktrop, iCell

   !Loop over levels to find tropopause (single column)
   do iCell = 1, nCells
       ktrop = nVertLevels-1
       do  k = 1, nVertLevels-1  ! trop_loop
          if ( p(k,iCell) .le. 50000.0 ) then
             ! Compute lapse rate (-dT/dz)
             dtdz = ( t(k+1,iCell) - t(k,iCell)   ) / &
                    ( z(k,iCell)   - z(k+1,iCell) )
          else
             ! Set lapse rate for p > 500 hPa
             dtdz = 999.9
          endif
          !Check if local lapse rate <= 2 K/km
          if (dtdz .le. 0.002) then
             ! Initialize lapse rate and altitude test arrays
             dtdztest = 0
             ztest = 0

             ! Compute average lapse rate across levels above current candidate
             do kk = k+1, nVertLevels-1
                dtdz = ( t(kk+1,iCell) - t(k,iCell)   ) / &
                       ( z(k,iCell)    - z(kk+1,iCell) )

                !If avg. lapse rate <= 2 K/km and z <= trop + 2 km, set pass flag
                if ( ( dtdz .le. 0.002 ) .and. &
                     ( (z(k,iCell) - z(kk,iCell)) .le. 2000.0 ) ) then
                   dtdztest(kk) = 1
                endif

                ! If z <= trop + 2 km, set pass flag
                if ( (z(k,iCell) - z(kk,iCell)) .le. 2000.0 ) then
                   ztest(kk) = 1
                endif
             enddo   !kk loop
             laps=dtdz !LAPS
             if (sum(dtdztest) .eq. sum(ztest)) then
                ! If qualified as tropopause, set altitude index and return value
                ktrop = k
                exit
             endif
          endif
       enddo  ! trop_loop
       tropk(iCell) = p(ktrop,iCell)
   enddo
end subroutine tropopause_pressure_wmo
!-------------------------------------------------------------------------------------------
subroutine q_fields_forward(mqName, modelFields, qGeo, plevels, nCells, nVertLevels)

   implicit none

   character (len=*),              intent(in)    :: mqName
   type (mpas_pool_type), pointer, intent(in)    :: modelFields  !< model state fields
   type (field2DReal),    pointer, intent(inout) :: qGeo      !< geovar q field
   real (kind=RKIND),          intent(in)    :: plevels(nVertLevels+1,nCells)
   integer,                        intent(in)    :: nCells       !< number of grid cells
   integer,                        intent(in)    :: nVertLevels

   real (kind=RKIND), pointer :: qModel(:,:)
   real (kind=RKIND) :: kgkg_kgm2
   integer :: i, k

   call mpas_pool_get_array(modelFields, mqName, qModel) !- [kg/kg]
   do i=1,nCells
      do k=1,nVertLevels
         kgkg_kgm2=( plevels(k,i)-plevels(k+1,i) ) / gravity !- Still bottom-to-top
         qGeo % array(k,i) = qModel(k,i) * kgkg_kgm2 !- [kg/kg] --> [kg/m**2]
      enddo
   enddo

   ! Ensure positive-definite mixing ratios
   !  with respect to precision of crtm::CRTM_Parameters::ZERO.
   !  Note: replacing MPAS_JEDI_GREATERZERO_kr with MPAS_JEDI_ZERO_kr
   !   will cause some profiles to fail in CRTM.
   ! TODO: this should be moved to the mpas_fields%read step
   !       only other place it should be needed is add_incr (already there)
   where(qGeo % array(:,1:nCells) < MPAS_JEDI_GREATERZERO_kr)
      qGeo % array(:,1:nCells) = MPAS_JEDI_GREATERZERO_kr
   end where

end subroutine q_fields_forward
!-------------------------------------------------------------------------------------------
subroutine q_fields_TL(mqName, modelFields_tl, qGeo_tl, plevels, nCells, nVertLevels)

   implicit none

   character (len=*),              intent(in)    :: mqName
   type (mpas_pool_type), pointer, intent(in)    :: modelFields_tl !< model state fields
   type (field2DReal),    pointer, intent(inout) :: qGeo_tl        !< geovar q field
   real (kind=RKIND),          intent(in)    :: plevels(nVertLevels+1,nCells)
   integer,                        intent(in)    :: nCells          !< number of grid cells
   integer,                        intent(in)    :: nVertLevels

   real (kind=RKIND), pointer :: qModel_tl(:,:)
   real (kind=RKIND) :: kgkg_kgm2
   integer :: i, k

   call mpas_pool_get_array(modelFields_tl, mqName, qModel_tl) !- [kg/kg]
   do i=1,nCells
      do k=1,nVertLevels
         kgkg_kgm2=( plevels(k,i)-plevels(k+1,i) ) / gravity !- Still bottom-to-top
         qGeo_tl%array(k,i) = qModel_tl(k,i) * kgkg_kgm2
      enddo
   enddo

end subroutine q_fields_TL
!-------------------------------------------------------------------------------------------
subroutine q_fields_AD(mqName, modelFields_ad, qGeo_ad, plevels, nCells, nVertLevels)

   implicit none

   character (len=*),              intent(in)    :: mqName
   type (mpas_pool_type), pointer, intent(inout) :: modelFields_ad !< model state fields
   type (field2DReal),    pointer, intent(in)    :: qGeo_ad        !< geovar q field
   real (kind=RKIND),          intent(in)    :: plevels(nVertLevels+1,nCells)
   integer,                        intent(in)    :: nCells         !< number of grid cells
   integer,                        intent(in)    :: nVertLevels

   real (kind=RKIND), pointer :: qModel_ad(:,:)
   real (kind=RKIND) :: kgkg_kgm2
   integer :: i, k

   call mpas_pool_get_array(modelFields_ad, mqName, qModel_ad) !- [kg/kg]
   do i=1,nCells
      do k=1,nVertLevels
         kgkg_kgm2=( plevels(k,i)-plevels(k+1,i) ) / gravity !- Still bottom-to-top
         qModel_ad(k,i) = qModel_ad(k,i) + qGeo_ad % array(k,i) * kgkg_kgm2
      enddo
   enddo

end subroutine q_fields_AD
!-------------------------------------------------------------------------------------------
real (kind=kind_real) function wgamma(y)
implicit none
real (kind=kind_real), intent(in) :: y

wgamma = exp(gammln(y))

end function wgamma
!-------------------------------------------------------------------------------------------
real (kind=kind_real) function gammln(xx)
implicit none
real (kind=kind_real), intent(in)  :: xx
real (kind=kind_double), parameter :: stp = 2.5066282746310005_kind_double
real (kind=kind_double), parameter :: &
   cof(6) = (/   76.18009172947146_kind_double,    -86.50532032941677_kind_double, &
                 24.01409824083091_kind_double,    -1.231739572450155_kind_double, &
              0.001208650973866179_kind_double, -0.000005395239384953_kind_double/)
real (kind=kind_double) :: ser,tmp,x,y
integer :: j

x=real(xx,kind_double)
y=x
tmp=x+5.5_kind_double
tmp=(x+0.5_kind_double)*log(tmp)-tmp
ser=1.000000000190015_kind_double
do j=1,6
   y=y+1.0_kind_double
   ser=ser+cof(j)/y
end do
gammln=real(tmp+log(stp*ser/x),kind_real)
end function gammln

!-------------------------------------------------------------------------------------------
subroutine effectRad_rainwater (qr, rho, nr, re_qr, mp_scheme, ngrid, nVertLevels)
!-----------------------------------------------------------------------
!  Compute radiation effective radii of rainwater for WSM6/Thompson microphysics.
!  These are consistent with microphysics equations.
!  References: WRF/phys/module_mp_wsm6.F
!              Lin, Y. L., Farley, R. D., & Orville, H. D. (1983). Bulk parameterization of the snow field in a cloud model. Journal of climate and applied meteorology, 22(6), 1065-1092.
!              WRF/phys/module_mp_thompson.F
!              Thompson, G., Rasmussen, R. M., & Manning, K. (2004). Explicit forecasts of winter precipitation using an improved bulk microphysics scheme. Part I: Description and sensitivity analysis. Monthly Weather Review, 132(2), 519-542.
!              Thompson, G., Field, P. R., Rasmussen, R. M., & Hall, W. D. (2008). Explicit forecasts of winter precipitation using an improved bulk microphysics scheme. Part II: Implementation of a new snow parameterization. Monthly Weather Review, 136(12), 5095-5115.
!-----------------------------------------------------------------------

implicit none

real(kind=RKIND), dimension( nVertLevels, ngrid ), intent(in)  :: qr, rho
real(kind=RKIND), dimension( nVertLevels, ngrid ), intent(in)  :: nr
integer,                                               intent(in)  :: ngrid, nVertLevels
character(len=StrKIND),                                intent(in)  :: mp_scheme
real(kind=RKIND), dimension( nVertLevels, ngrid ), intent(out) :: re_qr

!Local variables
! constants
real(kind=kind_real), parameter :: denr = MPAS_JEDI_THOUSAND_kr, n0r = 8.e6
real(kind=kind_real), parameter :: R1 = MPAS_JEDI_ONE_kr / &
                                        MPAS_JEDI_MILLION_kr / &
                                        MPAS_JEDI_MILLION_kr, &
                                   R2 = MPAS_JEDI_ONE_kr / &
                                        MPAS_JEDI_MILLION_kr
real(kind=kind_real), parameter :: mu_r = MPAS_JEDI_ZERO_kr
real(kind=kind_real), parameter :: am_r = MPAS_JEDI_PII_kr*denr/6.0_kind_real
real(kind=kind_real), parameter :: bm_r = MPAS_JEDI_THREE_kr

real(kind=kind_double) :: lamdar
integer                :: i, k

real(kind=kind_real), dimension( nVertLevels, ngrid ) :: rqr, nr_rho
!For Thompson scheme
real(kind=kind_real) :: cre2,cre3,crg2,crg3,org2,obmr
!Generalized gamma distributions for rain
! N(D) = N_0 * D**mu * exp(-lamda*D);  mu=0 is exponential.

!-----------------------------------------------------------------------
cre2 = mu_r + MPAS_JEDI_ONE_kr
cre3 = bm_r + mu_r + MPAS_JEDI_ONE_kr
crg2 = wgamma(cre2)
crg3 = wgamma(cre3)
org2 = MPAS_JEDI_ONE_kr/crg2
obmr = MPAS_JEDI_ONE_kr/bm_r

do i = 1, ngrid
   do k = 1, nVertLevels
      rqr(k,i) = max(R1, real(qr(k,i),kind=kind_real) * real(rho(k,i),kind=kind_real))
   enddo
enddo


   do i = 1, ngrid
      do k = 1, nVertLevels
         re_qr(k,i) = 99.e-6
         if (rqr(k,i).le.R1) CYCLE
         select case (trim(mp_scheme))
         case ('mp_wsm6')
            lamdar = sqrt(sqrt(MPAS_JEDI_PII_kr*denr*n0r/rqr(k,i)))
            re_qr(k,i) =  max(99.9D-6,min(1.5_kind_double/lamdar,1999.D-6))
         case ('mp_thompson')
            nr_rho(k,i) = max(R2, nr(k,i)*rho(k,i))
            lamdar = (am_r*crg3*org2*nr_rho(k,i)/rqr(k,i))**obmr
            re_qr(k,i) = max(99.9e-6, min(real(MPAS_JEDI_HALF_kr*(MPAS_JEDI_THREE_kr+mu_r),kind_double)/lamdar, 1999.e-6))
         case default
            re_qr(k,i) = 999.e-6
         end select
      enddo
   enddo


end subroutine effectRad_rainwater

!-------------------------------------------------------------------------------------------
subroutine effectRad_graupel (qg, rho, re_qg, mp_scheme, ngrid, nVertLevels)

!-----------------------------------------------------------------------
!  Compute radiation effective radii of graupel for WSM6/Thompson microphysics.
!  These are consistent with microphysics equations.
!  References: WRF/phys/module_mp_wsm6.F
!              Lin, Y. L., Farley, R. D., & Orville, H. D. (1983). Bulk parameterization of the snow field in a cloud model. Journal of climate and applied meteorology, 22(6), 1065-1092.
!              WRF/phys/module_mp_thompson.F
!              Thompson, G., Rasmussen, R. M., & Manning, K. (2004). Explicit forecasts of winter precipitation using an improved bulk microphysics scheme. Part I: Description and sensitivity analysis. Monthly Weather Review, 132(2), 519-542.
!              Thompson, G., Field, P. R., Rasmussen, R. M., & Hall, W. D. (2008). Explicit forecasts of winter precipitation using an improved bulk microphysics scheme. Part II: Implementation of a new snow parameterization. Monthly Weather Review, 136(12), 5095-5115.
!-----------------------------------------------------------------------

implicit none

real(kind=RKIND), dimension( nVertLevels, ngrid ), intent(in) :: qg, rho
integer,                                               intent(in) :: ngrid, nVertLevels
character (len=StrKIND),                               intent(in) :: mp_scheme
real(kind=RKIND), dimension( nVertLevels, ngrid ), intent(out):: re_qg

!Local variables
integer                :: i, k
real(kind=kind_double) :: lamdag, lam_exp, N0_exp
real(kind=kind_real)   :: n0g, deng
real(kind=kind_real), parameter :: R1 = MPAS_JEDI_ONE_kr / &
                                        MPAS_JEDI_MILLION_kr / &
                                        MPAS_JEDI_MILLION_kr
real(kind=kind_real), dimension( nVertLevels, ngrid ):: rqg
!MPAS model set it as 0, WRF model set it through namelist
integer:: hail_opt = 0
! for Thompson scheme
real(kind=kind_real) :: mu_g = MPAS_JEDI_ZERO_kr
real(kind=kind_real) :: obmg, cge1,cgg1,oge1,cge3,cgg3,ogg1,cge2,cgg2,ogg2
real(kind=kind_real) :: ygra1, zans1
real(kind=kind_real), parameter :: am_g = MPAS_JEDI_PII_kr*500.0_kind_real/6.0_kind_real
real(kind=kind_real), parameter :: bm_g = MPAS_JEDI_THREE_kr

!-----------------------------------------------------------------------
obmg = MPAS_JEDI_ONE_kr/bm_g
cge1 = bm_g + MPAS_JEDI_ONE_kr
cgg1 = wgamma(cge1)
oge1 = MPAS_JEDI_ONE_kr/cge1
cge3 = bm_g + mu_g + MPAS_JEDI_ONE_kr
cgg3 = wgamma(cge3)
ogg1 = MPAS_JEDI_ONE_kr/cgg1
cge2 = mu_g + MPAS_JEDI_ONE_kr
cgg2 = wgamma(cge2)
ogg2 = MPAS_JEDI_ONE_kr/cgg2

if (hail_opt .eq. 1) then
   n0g  = 4.e4
   deng = 700.0_kind_real
else
   n0g  = 4.e6
   deng = 500.0_kind_real
endif

do i = 1, ngrid
   do k = 1, nVertLevels
      rqg(k,i) = max(R1, real(qg(k,i), kind=kind_real) * real(rho(k,i), kind=kind_real))
   enddo
enddo

   select case (trim(mp_scheme))
   case ('mp_wsm6')
      re_qg = 49.7e-6
      do i = 1, ngrid
         do k = 1, nVertLevels
            if (rqg(k,i).le.R1) CYCLE
            lamdag = sqrt(sqrt(MPAS_JEDI_PII_kr*deng*n0g/rqg(k,i)))
            re_qg(k,i) = max(50.D-6,min(1.5_kind_double/lamdag,9999.D-6))
         end do
      end do
   case ('mp_thompson')
      re_qg = 99.5e-6
      do i = 1, ngrid
         do k = nVertLevels, 1, -1
            if (rqg(k,i).le.R1) CYCLE
            ygra1 = alog10(sngl(max(1.e-9, rqg(k,i))))
            zans1 = (2.5_kind_real + 2.5_kind_real/7.0_kind_real * (ygra1+7.0_kind_real))
            zans1 = max(MPAS_JEDI_TWO_kr, min(zans1, 7.0_kind_real)) ! new in WRF V4.2
            N0_exp = 10.0_kind_real**(zans1)
            lam_exp = (N0_exp*am_g*cgg1/rqg(k,i))**oge1
            lamdag = lam_exp * (cgg3*ogg2*ogg1)**obmg ! we can simplify this without considering rainwater
            re_qg(k,i) = max(99.9e-6, min(real(MPAS_JEDI_HALF_kr*(MPAS_JEDI_THREE_kr+mu_g),kind_double)/lamdag, 9999.e-6))
         enddo
      enddo
   case default
      re_qg = 600.e-6
   end select


end subroutine effectRad_graupel

!-------------------------------------------------------------------------------------------
subroutine dryrho_to_moistrho (rho,qv,ngrid,nVertLevels)

!----------------------------------------------------------------------
! compute density of moist air from dry air density
!-----------------------------------------------------------------------
real(kind=RKIND), dimension( nVertLevels, ngrid ), intent(inout) :: rho  ! kg/m^3
real(kind=RKIND), dimension( nVertLevels, ngrid ), intent(in)    :: qv   ! kg/kg
          !qc,qi,qr,qs,qg    ! kg/kg
integer,                                           intent(in)    :: ngrid, nVertLevels

integer  :: i, k

 do i = 1, ngrid
   do k = 1, nVertLevels
     rho(k,i) = rho(k,i) * ( MPAS_JEDI_ONE_kr + qv(k,i) ) !+ qc(k,i) &
                                   ! + qi(k,i) + qr(k,i) + qs(k,i) + qg(k,i) )
   enddo
 enddo

end subroutine dryrho_to_moistrho
!-------------------------------------------------------------------------------------------

end module mpas2ufo_vars_mod
