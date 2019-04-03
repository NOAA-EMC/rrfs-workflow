!=======================================================================
program mosaic_file
!=======================================================================

  use netcdf

  implicit none

  integer, parameter:: dp=kind(1.0d0)

  integer, parameter :: ntiles = 1
  integer, parameter :: string = 255

  logical :: file_exists
  integer :: num_args, i, ncid, &
             ntiles_dimid, string_dimid, &
             mosaic_varid, gridlocation_varid, &
             gridfiles_varid, gridtiles_varid
  integer, dimension(1) :: dimids1D
  integer, dimension(2) :: dimids2D
  integer, dimension(ntiles) :: tile_inds
  character(len=string) :: mosaic_fn, mosaic, gridlocation, CRES, tmp_str
!
!=======================================================================
!
! Create the grid mosaic file that FV3 expects to be present in the IN-
! PUT subdirectory of the run directory.
!
!=======================================================================
!
  num_args = command_argument_count()
  if (num_args == 1) then
    call get_command_argument(1, CRES)
  else
    WRITE(*,500)
    WRITE(*,500) "Exactly one argument must be specified to program mosaic_file."
    WRITE(*,500) "Usage:"
    WRITE(*,500)
    WRITE(*,500) "  mosaic_file  CRES"
    WRITE(*,500)
    WRITE(*,500) "where CRES is the cubed-sphere grid resolution that will"
    WRITE(*,500) "be used to form the name of the grid specification file(s)"
    WRITE(*,500) "stored in the variable gridfiles in the grid mosaic file."
    WRITE(*,500) "Actual number of specified command line arguments is:"
    WRITE(*,510) "  num_args = ", num_args
    WRITE(*,500) "Stopping."
500 FORMAT(A)
510 FORMAT(A, I3)
    STOP
  end if
!
!=======================================================================
!
! Create the grid mosaic file that FV3 expects to be present in the IN-
! PUT subdirectory of the run directory.  Then create dimensions, varia-
! bles, and attributes within it.
!
!=======================================================================
!
  mosaic_fn = trim(CRES) // "_mosaic.nc"

  call check( nf90_create(mosaic_fn, NF90_64BIT_OFFSET, ncid) )
  call check( nf90_def_dim(ncid, "ntiles", ntiles, ntiles_dimid) )
  call check( nf90_def_dim(ncid, "string", string, string_dimid) )

  dimids1D = (/ string_dimid /)
  call check( nf90_def_var(ncid, "mosaic", NF90_CHAR, dimids1D, mosaic_varid) )
  call check( nf90_put_att(ncid, mosaic_varid, "standard_name", "grid_mosaic_spec") )
  call check( nf90_put_att(ncid, mosaic_varid, "children", "gridtiles"))
  call check( nf90_put_att(ncid, mosaic_varid, "contact_regions", "contacts") )
  call check( nf90_put_att(ncid, mosaic_varid, "grid_descriptor", "") )

  dimids1D = (/ string_dimid /)
  call check( nf90_def_var(ncid, "gridlocation", NF90_CHAR, dimids1D, gridlocation_varid) )
  call check( nf90_put_att(ncid, gridlocation_varid, "standard_name", "grid_file_location") )

  dimids2D = (/ string_dimid, ntiles_dimid /)
  call check( nf90_def_var(ncid, "gridfiles", NF90_CHAR, dimids2D, gridfiles_varid) )
  call check( nf90_def_var(ncid, "gridtiles", NF90_CHAR, dimids2D, gridtiles_varid) )

  call check( nf90_put_att(ncid, NF90_GLOBAL, "grid_version", "") )
  call check( nf90_put_att(ncid, NF90_GLOBAL, "code_version", "") )
  call check( nf90_put_att(ncid, NF90_GLOBAL, "history", "") )

  call check( nf90_enddef(ncid) )
!
!=======================================================================
!
! Assign values to variables in the grid mosaic file.  The only one that
! seems to be read by the FV3 code (at least in regional mode) is the
! string variable "gridfiles" that contains the name of the grid speci-
! fication file.
!
!=======================================================================
!
  mosaic = mosaic_fn
  gridlocation = "/path/to/directory"

  call check( nf90_put_var(ncid, mosaic_varid, trim(mosaic)) )
  call check( nf90_put_var(ncid, gridlocation_varid, trim(gridlocation)))

  tile_inds(1) = 7
  do i=1, ntiles
    write(tmp_str, 520) "tile", tile_inds(i)
    call check( nf90_put_var(ncid, gridtiles_varid, trim(tmp_str), start=(/1,i/)) )
    tmp_str = trim(CRES) // "_grid." // trim(tmp_str) // ".nc"
    call check( nf90_put_var(ncid, gridfiles_varid, trim(tmp_str), start=(/1,i/)) )
  end do
520 FORMAT(A, I1)
530 FORMAT(4A)

  call check( nf90_close(ncid) )

end program mosaic_file


subroutine check(status)
  use netcdf
  integer,intent(in) :: status
!
  if(status /= nf90_noerr) then
    write(0,*) ' check netcdf status = ', status
    write(0,'("error ", a)') trim(nf90_strerror(status))
    stop "Stopped"
  endif
end subroutine check
