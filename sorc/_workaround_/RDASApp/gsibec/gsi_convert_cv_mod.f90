module gsi_convert_cv_mod
use m_kinds, only: r_kind
use constants, only: epsilon=>fv
use constants, only: zero,one
private

public :: gsi_t_to_tv_tl
public :: gsi_t_to_tv_ad
public :: gsi_tv_to_t_tl
public :: gsi_tv_to_t_ad

interface gsi_t_to_tv_tl
   module procedure t_to_tv_tl_
end interface
interface gsi_t_to_tv_ad
   module procedure t_to_tv_ad_
end interface
interface gsi_tv_to_t_tl
   module procedure tv_to_t_tl_
end interface
interface gsi_tv_to_t_ad
   module procedure tv_to_t_ad_
end interface

contains

subroutine t_to_tv_tl_(t,t_tl,q,q_tl,tv_tl)

 implicit none
 real(r_kind), intent(in ) ::     t(:,:,:)
 real(r_kind), intent(in ) ::  t_tl(:,:,:)
 real(r_kind), intent(in ) ::     q(:,:,:)
 real(r_kind), intent(in ) ::  q_tl(:,:,:)
 real(r_kind), intent(out) :: tv_tl(:,:,:)

 tv_tl = t_tl*(one + epsilon*q) + t*epsilon*q_tl

end subroutine t_to_tv_tl_

!----------------------------------------------------------------------------

subroutine t_to_tv_ad_(t,t_ad,q,q_ad,tv_ad)

 implicit none
 real(r_kind), intent(in   ) ::     t(:,:,:)
 real(r_kind), intent(inout) ::  t_ad(:,:,:)
 real(r_kind), intent(in   ) ::     q(:,:,:)
 real(r_kind), intent(inout) ::  q_ad(:,:,:)
 real(r_kind), intent(inout) :: tv_ad(:,:,:)

 t_ad = t_ad + tv_ad * (one + epsilon*q)
 q_ad = q_ad + tv_ad *        epsilon*t
 tv_ad= zero

end subroutine t_to_tv_ad_

subroutine tv_to_t_tl_(tv,tv_tl,q,q_tl,t_tl,t)

 implicit none
 real(r_kind), intent(in   ) ::    tv(:,:,:)
 real(r_kind), intent(in   ) :: tv_tl(:,:,:)
 real(r_kind), intent(in   ) ::     q(:,:,:)
 real(r_kind), intent(in   ) ::  q_tl(:,:,:)
 real(r_kind), intent(inout) ::  t_tl(:,:,:)
 real(r_kind), intent(in   ) ::     t(:,:,:)

 integer :: i,j,k
 real(r_kind), parameter :: rmiss_th = -1.0e30

 do k = 1, size(t_tl,3)
   do j = 1, size(t_tl,2)
     do i = 1, size(t_tl,1)
 
       if(t(i,j,k) < rmiss_th) then
         t_tl(i,j,k) = zero
         cycle
       endif

       t_tl(i,j,k)= (tv_tl(i,j,k)*(one+epsilon*q(i,j,k))-tv(i,j,k)*epsilon*q_tl(i,j,k))/(one+epsilon*q(i,j,k))**2

     enddo
   enddo
 enddo

end subroutine tv_to_t_tl_

!----------------------------------------------------------------------------

subroutine tv_to_t_ad_(tv,tv_ad,q,q_ad,t_ad,t)

 implicit none
 real(r_kind), intent(in   ) ::    tv(:,:,:)
 real(r_kind), intent(inout) :: tv_ad(:,:,:)
 real(r_kind), intent(in   ) ::     q(:,:,:)
 real(r_kind), intent(inout) ::  q_ad(:,:,:)
 real(r_kind), intent(inout) ::  t_ad(:,:,:)
 real(r_kind), intent(in   ) ::     t(:,:,:)

 real(r_kind),allocatable :: temp(:,:,:)

 integer :: i,j,k
 real(r_kind), parameter :: rmiss_th = -1.0e30

 allocate(temp(size(t_ad,1),size(t_ad,2),size(t_ad,3)))

 do k = 1, size(t_ad,3)
   do j = 1, size(t_ad,2)
     do i = 1, size(t_ad,1)

       if(t(i,j,k) < rmiss_th) then
         tv_ad(i,j,k) = zero
         q_ad(i,j,k) = zero
         t_ad(i,j,k) = zero
         cycle
       endif

       temp(i,j,k) = t_ad(i,j,k)/(epsilon*q(i,j,k)+one)

       tv_ad(i,j,k) = tv_ad(i,j,k) + temp(i,j,k)
       q_ad(i,j,k)  = q_ad(i,j,k)  - tv(i,j,k)*epsilon*temp(i,j,k)/(epsilon*q(i,j,k)+one)
       t_ad(i,j,k) = zero
     enddo
   enddo
 enddo
 
 deallocate(temp)

end subroutine tv_to_t_ad_

end module gsi_convert_cv_mod
