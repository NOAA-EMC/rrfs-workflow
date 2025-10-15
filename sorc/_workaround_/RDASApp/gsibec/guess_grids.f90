module guess_grids
use m_kinds, only: i_kind, r_kind
use m_mpimod, only: mype
use mpeu_util, only: tell,die,warn
use constants, only: fv,zero,one,max_varname_length
use constants, only: kPa_per_Pa,Pa_per_kPa
use constants, only: constoz
use constants, only: grav
use constants, only: rearth
use gridmod, only: nlon,nlat,lon2,lat2,nsig,idsl5
use gridmod, only: ak5,bk5
use gsi_bundlemod, only: gsi_bundlegetpointer
use gsi_metguess_mod, only: gsi_metguess_bundle
use gsi_metguess_mod, only: gsi_metguess_get
use gsi_metguess_mod, only: gsi_metguess_create_grids
use gsi_metguess_mod, only: gsi_metguess_destroy_grids
use mod_vtrans, only: nvmodes_keep,create_vtrans
use mod_strong, only: l_tlnmc
use strong_fast_global_mod, only: init_strongvars
implicit none
private
!
public :: ges_prsi
public :: ges_prsl
public :: ges_tsen
public :: ges_qsat
public :: ges_teta
public :: ges_prslavg 
public :: ges_psfcavg

public :: geop_hgtl
public :: isli2
public :: fact_tv
public :: tropprs

public :: gsiguess_init
public :: gsiguess_final
public :: gsiguess_get_ref_gesprs
public :: gsiguess_set
public :: gsiguess_bkgcov_init
public :: gsiguess_bkgcov_final

public :: nfldsig
public :: ntguessig

public :: ifilesig

public :: tsensible
logical, parameter ::  tsensible = .false.   ! jfunc: here set as in jfunc
                          !        gsi handles this completely
                          !        incorrectly - this should
                          !        just be controlled in the
                          !        cv table tv for virt. t; t
                          !        for sensible t - would need
                          !        to generalize the spots
                          !        where cold thinks only temp
                          !        var in cv is tv to be tv and t
logical, parameter ::  use_compress = .true.   ! wired for now

integer(i_kind) :: nfldsig
integer(i_kind) :: ntguessig
integer(i_kind),allocatable, dimension(:)::ifilesig

real(r_kind),allocatable,dimension(:,:,:,:):: ges_prsl
real(r_kind),allocatable,dimension(:,:,:,:):: ges_prsi
real(r_kind),allocatable,dimension(:,:,:,:):: ges_tsen
real(r_kind),allocatable,dimension(:,:,:,:):: ges_qsat
real(r_kind),allocatable,dimension(:,:,:,:):: ges_teta

real(r_kind):: ges_psfcavg
real(r_kind),allocatable,dimension(:):: ges_prslavg
real(r_kind),allocatable,dimension(:,:,:,:):: ges_lnprsl
real(r_kind),allocatable,dimension(:,:,:,:):: ges_lnprsi

real(r_kind),allocatable,dimension(:,:,:,:):: geop_hgtl
real(r_kind),allocatable,dimension(:,:,:,:):: geop_hgti
real(r_kind),allocatable,dimension(:,:,:):: fact_tv
real(r_kind),allocatable,dimension(:,:):: tropprs
integer(i_kind),allocatable,dimension(:,:):: isli2

real(r_kind),allocatable :: debugvar(:,:,:)

interface gsiguess_init; module procedure init_; end interface
interface gsiguess_final; module procedure final_; end interface
interface gsiguess_get_ref_gesprs; module procedure get_ref_gesprs_; end interface

interface gsiguess_set
  module procedure guess_basics2_
  module procedure guess_basics3_
end interface gsiguess_set

interface gsiguess_bkgcov_init  ! WARNING: this does not belong here
  module procedure bkgcov_init_
end interface gsiguess_bkgcov_init

interface gsiguess_bkgcov_final ! WARNING: this does not belong here
  module procedure bkgcov_final_
end interface gsiguess_bkgcov_final

logical, save :: gesgrid_initialized_ = .false.
logical, save :: gesgrid_iamset_ = .false.
logical :: debug_guess=.false.

character(len=*), parameter :: myname="guess_grids"
contains
!--------------------------------------------------------
subroutine init_(mockbkg)
  logical,optional :: mockbkg
  integer ier
  logical mockbkg_
  call create_metguess_grids_(mype,ier)
  mockbkg_=.false.
  if (present(mockbkg)) then
    if(mockbkg) mockbkg_ = .true.
  endif
  if(mockbkg_) then
    call guess_basics0_
    if (mype==0) then
       print *, "Generating mock guess-fields -- for testing only"
   endif
  else
    if (mype==0) then
       print *, "User expected to provide guess-fields (viz. gsiguess_set)"
    endif
  endif
end subroutine init_
!--------------------------------------------------------
subroutine other_set_(need)
  use compact_diffs, only: cdiff_created
  use compact_diffs, only: cdiff_initialized
  use compact_diffs, only: create_cdiff_coefs
  use compact_diffs, only: inisph
  use xhat_vordivmod, only: xhat_vordiv_calc2
  implicit none
  character(len=*), optional, intent(inout) :: need(:)
  character(len=*), parameter :: myname_ = myname//'*other_set_'
  integer it,ier,istatus
  real(r_kind),dimension(:,:,:),pointer :: ges_u=>NULL()
  real(r_kind),dimension(:,:,:),pointer :: ges_v=>NULL()
  real(r_kind),dimension(:,:,:),pointer :: ges_div=>NULL()
  real(r_kind),dimension(:,:,:),pointer :: ges_vor=>NULL()
! this if alloc below are here only because saber does not delete its obj properly
  if(.not.allocated(ges_tsen)) allocate(ges_tsen(lat2,lon2,nsig,nfldsig))
  if(.not.allocated(ges_prsi)) allocate(ges_prsi(lat2,lon2,nsig+1,nfldsig))
  if(.not.allocated(ges_prsl)) allocate(ges_prsl(lat2,lon2,nsig,nfldsig))
  if(.not.allocated(ges_lnprsi)) allocate(ges_lnprsi(lat2,lon2,nsig+1,nfldsig))
  if(.not.allocated(ges_lnprsl)) allocate(ges_lnprsl(lat2,lon2,nsig,nfldsig))
  if(.not.allocated(ges_qsat)) allocate(ges_qsat(lat2,lon2,nsig,nfldsig))
  if(.not.allocated(ges_teta)) allocate(ges_teta(lat2,lon2,nsig,nfldsig))
  if(.not.allocated(geop_hgtl)) allocate(geop_hgtl(lat2,lon2,nsig,nfldsig))
  if(.not.allocated(geop_hgti)) allocate(geop_hgti(lat2,lon2,nsig+1,nfldsig))
  if(.not.allocated(isli2)) allocate(isli2(lat2,lon2))
  if(.not.allocated(fact_tv)) allocate(fact_tv(lat2,lon2,nsig))
  if(.not.allocated(tropprs)) allocate(tropprs(lat2,lon2))
  if(.not.allocated(ges_prslavg)) allocate(ges_prslavg(nsig))
  ges_tsen=zero
  ges_prsl=zero
  ges_qsat=zero
  ges_teta=zero
  geop_hgtl=zero
  geop_hgti=zero
  ges_prsi=zero
  ges_lnprsi=zero
  ges_lnprsl=zero
  tropprs=zero
  fact_tv=one
  ges_prslavg=zero
  if (nfldsig /= size(GSI_MetGuess_Bundle)) then
     call die (myname_,': inconsistent time index in metguess',99)
  endif
  ! better fix units here?
  if (present(need)) then
    if(mype==0) then
       print *, 'vars still needing to be filled ', need
    endif
    if (size(need)<1) then
        gesgrid_iamset_ = .true.
        return
    endif
  endif
  if (present(need)) then
    if (any(need=='tsen')) then
       call load_guess_tsen_
       where(need=='tsen')
          need='filled-'//need
       endwhere
    endif
    if (any(need=='tv')) then
       call load_guess_tv_
       where(need=='tv')
          need='filled-'//need
       endwhere
    endif
  else
    call load_guess_tsen_(mock=.true.)
  endif
  if (present(need)) then
    if (any(need(1:8)=='unfilled')) then
      if(mype==0) then
         print *, 'some vars still not filled: ', need
      endif
      call die (myname_,': not all needed GSI guess fields present',99)
    endif
  endif
  call load_prsges_
  call load_geop_hgt_
  if (present(need)) then
    if (any(need=='vor').or.any(need=='div')) then
!      if(.not.cdiff_created()) call create_cdiff_coefs()
!      if(.not.cdiff_initialized()) call inisph(rearth,rlats(2),wgtlats(2),nlon,nlat-2)
       do it=1,nfldsig
         ier=0
         call GSI_BundleGetPointer ( GSI_MetGuess_Bundle(it), 'u', ges_u, &
                                     istatus );ier=ier+istatus
         call GSI_BundleGetPointer ( GSI_MetGuess_Bundle(it), 'v', ges_v, &
                                     istatus );ier=ier+istatus
         call GSI_BundleGetPointer ( GSI_MetGuess_Bundle(it), 'vor', ges_vor, &
                                     istatus );ier=ier+istatus
         call GSI_BundleGetPointer ( GSI_MetGuess_Bundle(it), 'div', ges_div, &
                                     istatus );ier=ier+istatus
         if(ier==0) then
            call xhat_vordiv_calc2 (ges_u,ges_v,ges_vor,ges_div)
         endif
         where(need=='vor')
            need='filled-'//need
         endwhere
         where(need=='div')
            need='filled-'//need
         endwhere
!        call write_bkgvars_grid(ges_u,ges_v,ges_vor,ges_div(:,:,1),&
!                               'wind.grd',mype) ! debug
         enddo
    endif
  endif
! fill in land-water-ice mask
  do it=1,nfldsig
     call lwi_mask_(it)
  enddo

  gesgrid_iamset_ = .true.
end subroutine other_set_
!--------------------------------------------------------
subroutine bkgcov_init_(need)
  implicit none
  character(len=*), optional, intent(inout) :: need(:)
  logical, save :: init_pass = .true.
  call other_set_(need=need)  ! a little out of place, but ...
  call compute_derived(mype,init_pass) ! this belongs in a state set
  if (l_tlnmc .and. nvmodes_keep>0) then
     call create_vtrans(mype,ntguessig)
!    if(regional) then
!       if(reg_tlnmc_type==1) call zrnmi_initialize(mype)
!       if(reg_tlnmc_type==2) call fmg_initialize_e(mype)
!    else
        call init_strongvars(mype)
!    end if
  end if
  init_pass = .false.
  gesgrid_initialized_ = .true.
end subroutine bkgcov_init_
!--------------------------------------------------------
subroutine bkgcov_final_
  use m_mpimod, only: mype
  implicit none
  integer ier
  gesgrid_initialized_ = .false.
  gesgrid_iamset_ = .false.
end subroutine bkgcov_final_
!--------------------------------------------------------
subroutine other_unset_
  if(allocated(tropprs)) deallocate(tropprs)
  if(allocated(fact_tv)) deallocate(fact_tv)
  if(allocated(isli2)) deallocate(isli2)
  if(allocated(geop_hgti)) deallocate(geop_hgti)
  if(allocated(geop_hgtl)) deallocate(geop_hgtl)
  if(allocated(ges_qsat)) deallocate(ges_qsat)
  if(allocated(ges_teta)) deallocate(ges_teta)
  if(allocated(ges_prsl)) deallocate(ges_prsl)
  if(allocated(ges_prsi)) deallocate(ges_prsi)
  if(allocated(ges_tsen)) deallocate(ges_tsen)
end subroutine other_unset_
!--------------------------------------------------------
subroutine final_
  use m_mpimod, only: mype
  implicit none
  integer ier
  call other_unset_
  call destroy_metguess_grids_(mype,ier)
end subroutine final_
!-------------------------------------------------------------------------
!    NOAA/NCEP, National Centers for Environmental Prediction GSI        !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE: load_geop_hgt_ --- Populate guess geopotential height
!
! !INTERFACE:
!
  subroutine load_geop_hgt_

! !USES:

    use constants, only: one,eps, rd, grav, half, t0c, fv
    use constants, only: cpf_a0, cpf_a1, cpf_a2, cpf_b0, cpf_b1, cpf_c0, cpf_c1, cpf_d, cpf_e
    use constants, only: psv_a, psv_b, psv_c, psv_d
    use constants, only: ef_alpha, ef_beta, ef_gamma
    use gridmod,   only: lat2, lon2, nsig, twodvar_regional

    implicit none

! !INPUT PARAMETERS:


! !DESCRIPTION: populate guess geopotential height
!
! !REVISION HISTORY:
!   2003-10-15  treadon
!   2004-05-14  kleist, documentation
!   2004-07-15  todling, protex-compliant prologue
!   2004-10-28  treadon - replace "tiny" with "tiny_r_kind"
!   2004-12-15  treadon - replace use of Paul van Delst's Geopotential
!                         function with simple integration of hydrostatic
!                         equation (done to be consistent with Lidia
!                         Cucurull's GPS work)
!   2005-05-24  pondeca - add regional surface analysis option
!   2010-08-27  cucurull - add option to compute and use compressibility factors in geopot heights
!
! !REMARKS:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
! !AUTHOR:
!   treadon          org: w/nmc20      date: 2003-10-15
!
!EOP
!-------------------------------------------------------------------------

    character(len=*),parameter::myname_=myname//'*load_geop_hgt_'
    real(r_kind),parameter:: thousand = 1000.0_r_kind

    integer(i_kind) i,j,k,jj,ier,istatus
    real(r_kind) h,dz,rdog
    real(r_kind),dimension(nsig+1):: height
    real(r_kind) cmpr, x_v, rl_hm, fact, pw, tmp_K, tmp_C, prs_sv, prs_a, ehn_fct, prs_v
    real(r_kind),dimension(:,:,:),pointer::ges_tv=>NULL()
    real(r_kind),dimension(:,:,:),pointer::ges_q=>NULL()
    real(r_kind),dimension(:,:  ),pointer::ges_zz=>NULL()

    if (twodvar_regional) return

    rdog = rd/grav

    if (use_compress) then

!     Compute compressibility factor (Picard et al 2008) and geopotential heights at midpoint 
!     of each layer

       do jj=1,nfldsig
          ier=0
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'z' ,ges_zz ,istatus)
          ier=ier+istatus
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'q' ,ges_q ,istatus)
          ier=ier+istatus
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv' ,ges_tv ,istatus)
          ier=ier+istatus
          if(ier/=0) exit
          do j=1,lon2
             do i=1,lat2
                k  = 1
                fact    = one + fv * ges_q(i,j,k)
                pw      = eps + ges_q(i,j,k)*( one - eps )
                tmp_K   = ges_tv(i,j,k) / fact
                tmp_C   = tmp_K - t0c
                prs_sv  = exp(psv_a*tmp_K**2 + psv_b*tmp_K + psv_c + psv_d/tmp_K)  ! Pvap sat, eq A1.1 (Pa)
                prs_a   = thousand * exp(half*(log(ges_prsi(i,j,k,jj)) + log(ges_prsl(i,j,k,jj))))     ! (Pa) 
                ehn_fct = ef_alpha + ef_beta*prs_a + ef_gamma*tmp_C**2 ! enhancement factor (eq. A1.2)
                prs_v   = ges_q(i,j,k) * prs_a / pw   ! vapor pressure (Pa)
                rl_hm   = prs_v / prs_sv    ! relative humidity
                x_v     = rl_hm * ehn_fct * prs_sv / prs_a     ! molar fraction of water vapor (eq. A1.3)
 
                ! Compressibility factor (eq A1.4 from Picard et al 2008)
                cmpr = one - (prs_a/tmp_K) * (cpf_a0 + cpf_a1*tmp_C + cpf_a2*tmp_C**2 &
                           + (cpf_b0 + cpf_b1*tmp_C)*x_v + (cpf_c0 + cpf_c1*tmp_C)*x_v**2 ) &
                           + (prs_a**2/tmp_K**2) * (cpf_d + cpf_e*x_v**2)

                h  = rdog * ges_tv(i,j,k)
                dz = h * cmpr * log(ges_prsi(i,j,k,jj)/ges_prsl(i,j,k,jj))
                height(k) = ges_zz(i,j) + dz   

                do k=2,nsig
                   fact    = one + fv * half * (ges_q(i,j,k-1)+ges_q(i,j,k))
                   pw      = eps + half * (ges_q(i,j,k-1)+ges_q(i,j,k)) * (one - eps)
                   tmp_K   = half * (ges_tv(i,j,k-1)+ges_tv(i,j,k)) / fact
                   tmp_C   = tmp_K - t0c
                   prs_sv  = exp(psv_a*tmp_K**2 + psv_b*tmp_K + psv_c + psv_d/tmp_K)  ! eq A1.1 (Pa)
                   prs_a   = thousand * exp(half*(log(ges_prsl(i,j,k-1,jj))+log(ges_prsl(i,j,k,jj))))   ! (Pa)
                   ehn_fct = ef_alpha + ef_beta*prs_a + ef_gamma*tmp_C**2 ! enhancement factor (eq. A1.2)
                   prs_v   = half*(ges_q(i,j,k-1)+ges_q(i,j,k) ) * prs_a / pw   ! (Pa)
                   rl_hm   = prs_v / prs_sv    ! relative humidity
                   x_v     = rl_hm * ehn_fct * prs_sv / prs_a     ! molar fraction of water vapor (eq. A1.3)
                   cmpr    = one - (prs_a/tmp_K) * ( cpf_a0 + cpf_a1*tmp_C + cpf_a2*tmp_C**2 &
                             + (cpf_b0 + cpf_b1*tmp_C)*x_v + (cpf_c0 + cpf_c1*tmp_C)*x_v**2 ) &
                             + (prs_a**2/tmp_K**2) * (cpf_d + cpf_e*x_v**2)
                   h       = rdog * half * (ges_tv(i,j,k-1)+ges_tv(i,j,k))
                   dz      = h * cmpr * log(ges_prsl(i,j,k-1,jj)/ges_prsl(i,j,k,jj))
                   height(k) = height(k-1) + dz
                end do

                do k=1,nsig
                   geop_hgtl(i,j,k,jj)=height(k) - ges_zz(i,j)
                end do
             enddo
          enddo
       enddo
       if(ier/=0) return

!      Compute compressibility factor (Picard et al 2008) and geopotential heights at interface
!      between layers

       do jj=1,nfldsig
          ier=0
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'z'  ,ges_zz ,istatus)
          ier=ier+istatus
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'q'  ,ges_q ,istatus)
          ier=ier+istatus
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv' ,ges_tv ,istatus)
          ier=ier+istatus
          if(ier/=0) exit
          do j=1,lon2
             do i=1,lat2
                k=1
                height(k) = ges_zz(i,j)

                do k=2,nsig
                   fact    = one + fv * ges_q(i,j,k-1)
                   pw      = eps + ges_q(i,j,k-1)*(one - eps)
                   tmp_K   = ges_tv(i,j,k-1) / fact
                   tmp_C   = tmp_K - t0c
                   prs_sv  = exp(psv_a*tmp_K**2 + psv_b*tmp_K + psv_c + psv_d/tmp_K)  ! eq A1.1 (Pa)
                   prs_a   = thousand * exp(half*(log(ges_prsi(i,j,k-1,jj))+log(ges_prsi(i,j,k,jj)))) 
                   ehn_fct = ef_alpha + ef_beta*prs_a + ef_gamma*tmp_C**2 ! enhancement factor (eq. A1.2)
                   prs_v   = ges_q(i,j,k-1) * prs_a / pw   ! vapor pressure (Pa)
                   rl_hm   = prs_v / prs_sv    ! relative humidity
                   x_v     = rl_hm * ehn_fct * prs_sv / prs_a     ! molar fraction of water vapor (eq. A1.3)
                   cmpr    = one - (prs_a/tmp_K) * ( cpf_a0 + cpf_a1*tmp_C + cpf_a2*tmp_C**2 &
                            + (cpf_b0 + cpf_b1*tmp_C)*x_v + (cpf_c0 + cpf_c1*tmp_C)*x_v**2 ) &
                            + (prs_a**2/tmp_K**2) * (cpf_d + cpf_e*x_v**2)
                   h       = rdog * ges_tv(i,j,k-1)
                   dz      = h * cmpr * log(ges_prsi(i,j,k-1,jj)/ges_prsi(i,j,k,jj))
                   height(k) = height(k-1) + dz
                enddo

                k=nsig+1
                fact    = one + fv* ges_q(i,j,k-1)
                pw      = eps + ges_q(i,j,k-1)*(one - eps)
                tmp_K   = ges_tv(i,j,k-1) / fact
                tmp_C   = tmp_K - t0c
                prs_sv  = exp(psv_a*tmp_K**2 + psv_b*tmp_K + psv_c + psv_d/tmp_K)  ! eq A1.1 (Pa)
                prs_a   = thousand * exp(half*(log(ges_prsi(i,j,k-1,jj))+log(ges_prsl(i,j,k-1,jj))))     ! (Pa)
                ehn_fct = ef_alpha + ef_beta*prs_a + ef_gamma*tmp_C**2 ! enhancement factor (eq. A1.2)
                prs_v   = ges_q(i,j,k-1) * prs_a / pw  
                rl_hm   = prs_v / prs_sv    ! relative humidity
                x_v     = rl_hm * ehn_fct * prs_sv / prs_a     ! molar fraction of water vapor (eq. A1.3)
                cmpr    = one - (prs_a/tmp_K) * ( cpf_a0 + cpf_a1*tmp_C + cpf_a2*tmp_C**2 &
                          + (cpf_b0 + cpf_b1*tmp_C)*x_v + (cpf_c0 + cpf_c1*tmp_C)*x_v**2 ) &
                          + (prs_a**2/tmp_K**2) * (cpf_d + cpf_e*x_v**2)
                h       = rdog * ges_tv(i,j,k-1)
                dz      = h * cmpr * log(ges_prsi(i,j,k-1,jj)/ges_prsl(i,j,k-1,jj))
                height(k) = height(k-1) + dz
 
                do k=1,nsig+1
                   geop_hgti(i,j,k,jj)=height(k) - ges_zz(i,j)
                end do
             enddo
          enddo
       enddo
       if(ier/=0) return

    else

!      Compute geopotential height at midpoint of each layer
       do jj=1,nfldsig
          ier=0
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'z'  ,ges_zz  ,istatus)
          ier=ier+istatus
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv' ,ges_tv ,istatus)
          ier=ier+istatus
          if(ier/=0) exit
          where(ges_zz<zero) ges_zz=zero ! debug (RTod: odd to find <0)
          do j=1,lon2
             do i=1,lat2
                k  = 1
                h  = rdog * ges_tv(i,j,k)
                dz = h * log(ges_prsi(i,j,k,jj)/ges_prsl(i,j,k,jj))
                height(k) = ges_zz(i,j) + dz
 
                do k=2,nsig
                   h  = rdog * half * (ges_tv(i,j,k-1)+ges_tv(i,j,k))
                   dz = h * log(ges_prsl(i,j,k-1,jj)/ges_prsl(i,j,k,jj))
                   height(k) = height(k-1) + dz
                end do

                do k=1,nsig
                   geop_hgtl(i,j,k,jj)=height(k) - ges_zz(i,j)
                end do
             end do
          end do
       end do
       if(ier/=0) return
       
!      Compute geopotential height at interface between layers
       do jj=1,nfldsig
          ier=0
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'z'  ,ges_zz  ,istatus)
          ier=ier+istatus
          call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv' ,ges_tv ,istatus)
          ier=ier+istatus
          if(ier/=0) exit
          do j=1,lon2
             do i=1,lat2
                k=1
                height(k) = ges_zz(i,j)

                do k=2,nsig
                   h  = rdog * ges_tv(i,j,k-1)
                   dz = h * log(ges_prsi(i,j,k-1,jj)/ges_prsi(i,j,k,jj))
                   height(k) = height(k-1) + dz
                end do

                k=nsig+1
                h = rdog * ges_tv(i,j,k-1)
                dz = h * log(ges_prsi(i,j,k-1,jj)/ges_prsl(i,j,k-1,jj))
                height(k) = height(k-1) + dz

                do k=1,nsig+1
                   geop_hgti(i,j,k,jj)=height(k) - ges_zz(i,j)
                end do
             end do
          end do
       end do

    endif

    return
  end subroutine load_geop_hgt_

!-------------------------------------------------------------------------
!    NOAA/NCEP, National Centers for Environmental Prediction GSI        !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE: load_prsges --- Populate guess pressure arrays
!
! !INTERFACE:
!
  subroutine load_prsges_

! !USES:

    use constants,only: zero,one,rd_over_cp,one_tenth,half,ten,rd,r1000
    use gridmod,  only: lat2,lon2,nsig,idvc5
    use gridmod,  only: ck5,tref5
    use gridmod, only: regional,aeta2_ll,fv3_regional,mpas_regional,aeta1_ll,eta2_ll
    implicit none

! !DESCRIPTION: populate guess pressure arrays
!
! !REVISION HISTORY:
!   2003-10-15  kleist
!   2004-03-22  parrish, regional capability added
!   2004-05-14  kleist, documentation
!   2004-07-15  todling, protex-compliant prologue; added onlys
!   2004-07-28  treadon - remove subroutine call list, pass variables via modules
!   2005-05-24  pondeca - add regional surface analysis option
!   2006-04-14  treadon - unify global calculations to use ak5,bk5
!   2006-04-17  treadon - add ges_psfcavg and ges_prslavg for regional
!   2006-07-31  kleist  - use ges_ps instead of ln(ps)
!   2007-05-08  kleist  - add fully generalized coordinate for pressure calculation
!   2011-07-07  todling - add cap for log(pressure) calculation
!   2017-03-23  Hu      - add code to use hybrid vertical coodinate in WRF MASS
!                         core
!
! !REMARKS:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
! !AUTHOR:
!   kleist          org: w/nmc20     date: 2003-10-15
!
!EOP
!-------------------------------------------------------------------------

!   Declare local parameter
    character(len=*),parameter::myname_=myname//'*load_prsges'
    real(r_kind),parameter:: r1013=1013.0_r_kind

!   Declare local variables
    real(r_kind) kap1,kapr,trk
    real(r_kind),dimension(:,:)  ,pointer::ges_ps=>NULL()
    real(r_kind),dimension(:,:,:),pointer::ges_tv=>NULL()
    real(r_kind) pinc(lat2,lon2)
    integer(i_kind) i,j,k,ii,jj,itv,ips,kp
    logical ihaveprs(nfldsig)

    kap1=rd_over_cp+one
    kapr=one/rd_over_cp

    ihaveprs=.false.
    do jj=1,nfldsig
       call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'ps' ,ges_ps,ips)
       if(ips/=0) call die(myname_,': ps not available in guess, abort',ips)
       call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv' ,ges_tv,itv)
       if(idvc5==3) then
          if(itv/=0) call die(myname_,': tv must be present when idvc5=3, abort',itv)
       endif

!!!!!!!!!!!!  load delp to ges_prsi in read_fv3_netcdf_guess !!!!!!!!!!!!!!!!!
    if (fv3_regional ) then
       do j=1,lon2
          do i=1,lat2
             pinc(i,j)=(ges_ps(i,j)-ges_prsi(i,j,1,jj))
          enddo
       enddo
       do k=1,nsig+1
          do j=1,lon2
             do i=1,lat2
                ges_prsi(i,j,k,jj)=ges_prsi(i,j,k,jj)+eta2_ll(k)*pinc(i,j)
             enddo
          enddo
       enddo
    endif

       do k=1,nsig+1
          do j=1,lon2
             do i=1,lat2
                   if (idvc5==1 .or. idvc5==2) then
                      ges_prsi(i,j,k,jj)=ak5(k)+(bk5(k)*ges_ps(i,j))
                   else if (idvc5==3) then
                      if (k==1) then
                         ges_prsi(i,j,k,jj)=ges_ps(i,j)
                      else if (k==nsig+1) then
                         ges_prsi(i,j,k,jj)=zero
                      else
                         trk=(half*(ges_tv(i,j,k-1)+ges_tv(i,j,k))/tref5(k))**kapr
                         ges_prsi(i,j,k,jj)=ak5(k)+(bk5(k)*ges_ps(i,j))+(ck5(k)*trk)
                         call die(myname_,'opt removed ',99)
                      end if
                   end if
                ges_prsi(i,j,k,jj)=max(ges_prsi(i,j,k,jj),zero)
                ges_lnprsi(i,j,k,jj)=log(max(ges_prsi(i,j,k,jj),0.0001_r_kind))
             end do
          end do
       end do
       ihaveprs(jj)=.true.
    end do

       if (fv3_regional) then
          do jj=1,nfldsig
             do k=1,nsig
                 kp=k+1
                do j=1,lon2
                   do i=1,lat2
                      ges_prsl(i,j,k,jj)=(ges_prsi(i,j,k,jj)+ges_prsi(i,j,kp,jj))*half
                      ges_lnprsl(i,j,k,jj)=log(ges_prsl(i,j,k,jj))

                   end do
                end do
             end do
          end do
       end if   ! end if fv3 regional

!      load mid-layer pressure by using phillips vertical interpolation
       if (idsl5/=2) then
          do jj=1,nfldsig
             if(.not.ihaveprs(jj)) then
                call tell(myname,'3d pressure has not been calculated somehow',99)
                exit ! won't die ...
             endif
             do j=1,lon2
                do i=1,lat2
                   do k=1,nsig
                      ges_prsl(i,j,k,jj)=((ges_prsi(i,j,k,jj)**kap1-ges_prsi(i,j,k+1,jj)**kap1)/&
                           (kap1*(ges_prsi(i,j,k,jj)-ges_prsi(i,j,k+1,jj))))**kapr
                   end do
                end do
             end do
          end do

!      load mid-layer pressure by simple averaging
       else
          do jj=1,nfldsig
             if(.not.ihaveprs(jj)) then
                call tell(myname,'3d pressure has not been calculated somehow',99)
                exit ! won't die ...
             endif
             do j=1,lon2
                do i=1,lat2
                   do k=1,nsig
                      ges_prsl(i,j,k,jj)=(ges_prsi(i,j,k,jj)+ges_prsi(i,j,k+1,jj))*half
                   end do
                end do
             end do
          end do
       endif

! For regional applications only, load variables containing mean
! surface pressure and pressure profile at the layer midpoints
    if (regional) then
       ges_psfcavg = r1013
       if (fv3_regional) then
          do k=1,nsig
             ges_prslavg(k)=aeta1_ll(k)*ten+r1013*aeta2_ll(k)
          end do
       endif
       if (mpas_regional) then
          open(10,file="mpas_pave.txt")
          do k=1,nsig
            read(10,*)ges_prslavg(k)
          enddo
          close(10)
       endif

    endif


    return
  end subroutine load_prsges_

!-------------------------------------------------------------------------
!    NOAA/NCEP, National Centers for Environmental Prediction GSI        !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE: load_prsges --- Populate guess pressure arrays
!
! !INTERFACE:

  subroutine get_ref_gesprs_(prs)

! !USES: 

  use constants, only: zero,one_tenth,r100,stndrd_atmos_ps,ten
  use gridmod, only: idvc5
  use gridmod, only: nsig
  implicit none

! !INPUT PARAMETERS:

  real(r_kind), dimension(nsig+1), intent(out) :: prs

! !DESCRIPTION: get reference pressures
!
! !REVISION HISTORY:
!   2020-05-11  Todling  - bug fix for idvc5=1,2,3: ak5 are in cbar, thus 
!                          needed multiply by 10 to be in mb
!
! !REMARKS:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
! !AUTHOR:
!   unknonw       org: w/nmc20     date: 2003-10-15
!
!EOP
!-------------------------------------------------------------------------

  integer(i_kind) k
  real(r_kind) :: pstd

  pstd = stndrd_atmos_ps/r100

! get some reference-like pressure levels
  do k=1,nsig+1
        if (idvc5==1 .or. idvc5==2) then
           prs(k)=ten*ak5(k)+(bk5(k)*pstd)
        else if (idvc5==3) then
           if (k==1) then
              prs(k)=pstd
           else if (k==nsig+1) then
              prs(k)=zero
           else
              prs(k)=ten*ak5(k)+(bk5(k)*pstd)! +(ck5(k)*trk)
           end if
        end if
  enddo
  end subroutine get_ref_gesprs_

  subroutine lwi_mask_(it)
! this is very GEOS-centric
  implicit none
  integer, intent(in) :: it
  character(len=*), parameter :: myname_ = myname//'*lwi_mask_'
  real(r_kind),pointer :: slmsk   (:,:)=>NULL()
  real(r_kind),pointer :: frocean (:,:)=>NULL()
  real(r_kind),pointer :: frlake  (:,:)=>NULL()
  real(r_kind),pointer :: frseaice(:,:)=>NULL()
  real(r_kind),pointer :: tskin   (:,:)=>NULL()
  real(r_kind),pointer :: ps      (:,:)=>NULL()
  real(r_kind),pointer :: z       (:,:)=>NULL()
  integer :: ic,its,ier,istatus
  logical :: fromges

  fromges=.false.
  isli2=zero ! ocean
  istatus=0
  
  call gsi_bundlegetpointer(gsi_metguess_bundle(it),'ts'    ,tskin,its)
  call gsi_bundlegetpointer(gsi_metguess_bundle(it),'slmsk' ,slmsk,ier)
  if(ier==0) then
    isli2 = nint(slmsk)
    if(mype==0) write(6,'(2a)') myname_, ': ges-filled LWI'
    fromges=.true.
  else
    call gsi_bundlegetpointer(gsi_metguess_bundle(it),'frocean' ,frocean,ier)
          istatus=ier+istatus
    call gsi_bundlegetpointer(gsi_metguess_bundle(it),'frseaice',frseaice,ier)
          istatus=ier+istatus
    call gsi_bundlegetpointer(gsi_metguess_bundle(it),'frlake'  ,frlake ,ier)
          istatus=ier+istatus
    if (istatus/=0) then
       if(mype==0) &
       call warn(myname_, ': not enough to fill LWI, all Ocean')
       return
    endif
                                             isli2 = 1  ! Land
    where (  frocean+frlake >= 0.6         ) isli2 = 0  ! Water
    where (  isli2==0 .and. frseaice > 0.5 ) isli2 = 2  ! Ice
    if(its==0) then
      where( isli2==0 .and. tskin  < 271.4 ) isli2 = 2  ! Ice
      if(mype==0) write(6,'(2a)') myname_, ': frac-filled LWI'
    else
      if(mype==0) write(6,'(2a)') myname_, ': frac-filled LWI (no T-skin)'
    endif
  endif

! debug
  if(debug_guess) then
     allocate(debugvar(lat2,lon2,nsig))
     debugvar=zero
     call gsi_bundlegetpointer(gsi_metguess_bundle(it),'ps',ps,its)
     call gsi_bundlegetpointer(gsi_metguess_bundle(it),'z',z,its)
     ic=0
     if(fromges) then
       ic=ic+1; debugvar(:,:,ic) = slmsk
     else
       ic=ic+1; debugvar(:,:,ic) = frocean
       ic=ic+1; debugvar(:,:,ic) = frlake
       ic=ic+1; debugvar(:,:,ic) = frseaice
     endif
     ic=ic+1; debugvar(:,:,ic) = tskin
     ic=ic+1; debugvar(:,:,ic) = z
     call write_bkgvars_grid(debugvar,debugvar,debugvar,tskin,'skin.grd',mype) ! debug
     deallocate(debugvar)
  endif

  end subroutine lwi_mask_

  subroutine load_guess_tsen_(mock)
  implicit none
  logical,optional,intent(in) :: mock
  character(len=*), parameter :: myname_ = myname//'*load_guess_tsen_'
  real(r_kind),dimension(:,:,:),pointer::tsen=>NULL()
  real(r_kind),dimension(:,:,:),pointer::tv=>NULL()
  real(r_kind),dimension(:,:,:),pointer::q =>NULL()
  integer jj,ier,istatus
  logical gesgrid_iamset,mock_
  mock_=.false. 
  gesgrid_iamset=.true.
  if (present(mock)) then
     if(mock) mock_=.true.
  endif
  do jj=1,nfldsig
     istatus=0
     if (mock_) then
        call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv',tv,ier); istatus=ier+istatus
        call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'q' , q,ier); istatus=ier+istatus
        if (istatus/=0) then
           ! call die(myname_,'cannot retrieve pointers',istatus)
           gesgrid_iamset=.false.
           exit
        else
           ges_tsen(:,:,:,jj) = tv/(one+fv*q)
        endif
     else
        call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tsen',tsen,ier)
        if(ier==0) then
!          ges_tsen(:,:,:,jj) = tsen ! warning: assumes this has been filled in properly in JEDI
!          cycle
!       else
           call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv',tv,ier); istatus=ier+istatus
           call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'q' , q,ier); istatus=ier+istatus
           if (istatus/=0) then
              ! call die(myname_,'cannot retrieve pointers',istatus)
              gesgrid_iamset=.false.
              exit
           else
              ges_tsen(:,:,:,jj) = tv/(one+fv*q)
           endif
        endif
     endif
  enddo
  if(.not.gesgrid_iamset) then
    if (mype==0) call tell (myname_, ': warning, tsen pointer not set, could be an issue')
  endif
  end subroutine load_guess_tsen_

  subroutine load_guess_tv_
  implicit none
  character(len=*), parameter :: myname_ = myname//'*get_guess_tv_'
  real(r_kind),dimension(:,:,:),pointer::tsen=>NULL()
  real(r_kind),dimension(:,:,:),pointer::tv=>NULL()
  real(r_kind),dimension(:,:,:),pointer::q =>NULL()
  integer jj,ier,istatus
  logical gesgrid_iamset
  gesgrid_iamset=.true.
  do jj=1,nfldsig
     istatus=0
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv',tv,ier); istatus=ier+istatus
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'q' , q,ier); istatus=ier+istatus
     if (istatus/=0) then
        gesgrid_iamset=.false.
        cycle
        !call die(myname_,'cannot retrieve pointers',istatus)
     endif
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tsen',tsen,ier)
     if (ier==0) then
        if(allocated(ges_tsen)) ges_tsen(:,:,:,jj) = tsen  ! make sure this is local array
        tv=tsen*(one+fv*q)
     else
        if(allocated(ges_tsen)) then
           tv=ges_tsen(:,:,:,jj)*(one+fv*q)
        else
           gesgrid_iamset=.false.
           cycle
           !call die(myname_,': cannot define ges_tsen',99)
        endif
     endif
  enddo
  if(.not.gesgrid_iamset) then
    if(mype==0) call tell (myname_, ': warning, tv pointer not set, could be an issue')
  endif
  end subroutine load_guess_tv_

!-------------------------------------------------------------------------
!    NOAA/NCEP, National Centers for Environmental Prediction GSI        !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE: create_metguess_grids --- initialize meterological guess
!
! !INTERFACE:
!
  subroutine create_metguess_grids_(mype,istatus)

! !USES:
  use gridmod, only: lat2,lon2,nsig
  implicit none

! !INPUT PARAMETERS:

  integer(i_kind), intent(in)  :: mype

! !OUTPUT PARAMETERS:

  integer(i_kind), intent(out) :: istatus

! !DESCRIPTION: initialize meteorological background fields beyond 
!               the standard ones - wired-in this module.
!
! !REVISION HISTORY:
!   2011-04-29  todling
!   2013-10-30  todling - update interface
!
! !REMARKS:
!   language: f90
!   machine:  ibm rs/6000 sp; Linux Cluster
!
! !AUTHOR: 
!   todling         org: w/nmc20     date: 2011-04-29
!
!EOP
!-------------------------------------------------------------------------
   character(len=*),parameter::myname_=myname//'*create_metguess_grids_'
   integer(i_kind) :: nmguess                   ! number of meteorol. fields (namelist)
   character(len=max_varname_length),allocatable:: mguess(:)   ! names of meterol. fields

   istatus=0
  
!  When proper connection to ESMF is complete,
!  the following will not be needed here
!  ------------------------------------------
   call gsi_metguess_get('dim',nmguess,istatus)
   if(istatus/=0) then
      if(mype==0) write(6,*) myname_, ': trouble getting number of met-guess fields'
      return
   endif
   if(nmguess==0) return
   if (nmguess>0) then
       allocate (mguess(nmguess))
       call gsi_metguess_get('gsinames',mguess,istatus)
       if(istatus/=0) then
          if(mype==0) write(6,*) myname_, ': trouble getting name of met-guess fields'
          return
       endif
       deallocate (mguess)

!      Allocate memory for guess fields
!      --------------------------------
       call gsi_metguess_create_grids(lat2,lon2,nsig,nfldsig,istatus)
       if(istatus/=0) then
          if(mype==0) write(6,*) myname_, ': trouble allocating mem for met-guess'
          return
       endif
   endif

  end subroutine create_metguess_grids_

!-------------------------------------------------------------------------
!    NOAA/NCEP, National Centers for Environmental Prediction GSI        !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE: destroy_metguess_grids --- destroy meterological background
!
! !INTERFACE:
!
  subroutine destroy_metguess_grids_(mype,istatus)
! !USES:
  implicit none
! !INPUT PARAMETERS:
  integer(i_kind),intent(in)::mype
! !OUTPUT PARAMETERS:
  integer(i_kind),intent(out)::istatus
! !DESCRIPTION: destroy meterological background
!
! !REVISION HISTORY:
!   2011-04-29  todling
!   2013-10-30  todling - update interface
!
! !REMARKS:
!   language: f90
!   machine:  ibm rs/6000 sp; Linux Cluster
!
! !AUTHOR: 
!   todling         org: w/nmc20     date: 2011-04-29
!
!EOP
  character(len=*),parameter::myname_=myname//'destroy_metguess_grids'
  istatus=0
  call gsi_metguess_destroy_grids(istatus)
       if(istatus/=0) then
          if(mype==0) write(6,*) myname_, ': trouble deallocating mem for met-guess'
          return
       endif
  end subroutine destroy_metguess_grids_

  subroutine guess_basics0_
  real(r_kind),dimension(:,:,:),pointer::tv=>NULL()
  real(r_kind),dimension(:,:,:),pointer::tsen=>NULL()
  real(r_kind),dimension(:,:,:),pointer::u =>NULL()
  real(r_kind),dimension(:,:,:),pointer::v =>NULL()
  real(r_kind),dimension(:,:,:),pointer::q =>NULL()
  real(r_kind),dimension(:,:,:),pointer::oz=>NULL()
  real(r_kind),dimension(:,:  ),pointer::ps=>NULL()
  real(r_kind),dimension(:,:  ),pointer::z =>NULL()
  integer jj,ier
  do jj=1,nfldsig
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'u',u,ier)
     if (ier==0) then
        u = 20. ! m/s
     endif
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'v',v,ier)
     if (ier==0) then
        v = 20. ! m/s
     endif
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tv',tv,ier)
     if (ier==0) then
        tv = 300. ! K
     endif
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'tsen',tsen,ier)
     if (ier==0) then
        tsen = 300. ! K
     endif
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'q' , q,ier)
     if (ier==0) then
        q = 1.e-6 ! kg/kg
     endif
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'oz',oz,ier)
     if (ier==0) then
        oz = 0.25/constoz ! mol/mol
     endif
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'ps',ps,ier)
     if (ier==0) then
        ps = 100000. * kPa_per_Pa ! cbar(=kPa)
     endif
     call gsi_bundlegetpointer(gsi_metguess_bundle(jj),'phis',z,ier)
     if (ier==0) then
        z = 100. 
     endif
  enddo
  end subroutine guess_basics0_
!--------------------------------------------------------
  subroutine guess_basics2_(vname,islot,var)
  character(len=*),intent(in) :: vname
  integer(i_kind), intent(in) :: islot
  real(r_kind),dimension(:,:) :: var
  character(len=*), parameter :: myname_ = myname//'*guess_basics2_'
  real(r_kind),dimension(:,:),pointer::ptr
  integer jj,ier
  jj=islot
  call gsi_bundlegetpointer(gsi_metguess_bundle(jj),trim(vname),ptr,ier)
  if (ier/=0) then
    call die(myname_,'pointer to '//trim(vname)//" not found",ier)
  endif
  ptr=var
  if ( trim(vname) == 'ps' ) ptr=kPa_per_Pa*ptr ! RT_TBD: is this the best place for this?
  if ( trim(vname) == 'z'  ) ptr=ptr/grav       ! RT_TBD: is this the best place for this?
  end subroutine guess_basics2_
!--------------------------------------------------------
  subroutine guess_basics3_(vname,islot,var)
  character(len=*),intent(in)   :: vname
  integer(i_kind), intent(in) :: islot
  real(r_kind),dimension(:,:,:) :: var
  character(len=*), parameter :: myname_ = myname//'*guess_basics3_'
  real(r_kind),dimension(:,:,:),pointer::ptr
  character(len=80) :: uvar
  integer jj,ier
  jj=islot
  call gsi_bundlegetpointer(gsi_metguess_bundle(jj),trim(vname),ptr,ier)
  if (ier/=0) then
    call die(myname_,'pointer to '//trim(vname)//" not found",ier)
  endif
  ptr=var
  if ( trim(vname) == 'oz' ) then
      call gsi_metguess_get ( 'usrvar::o3ppmv', uvar, ier )
      if (trim(uvar)=='o3ppmv') then
         ptr=ptr/constoz   ! RT_TBD: is this the best place for this?
      endif
  endif
  end subroutine guess_basics3_
!--------------------------------------------------------
end module guess_grids
