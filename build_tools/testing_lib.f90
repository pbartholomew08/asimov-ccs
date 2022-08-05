!>  Testing library
module testing_lib

  use MPI

  use kinds
  use types
  use parallel
  use parallel_types
  use parallel_types_mpi

  implicit none

  public :: assert_eq

  interface assert_eq
    procedure assert_eq_integer_rank0
    procedure assert_eq_integer_rank1
    procedure assert_eq_real_rank0
    procedure assert_eq_real_rank1
    procedure assert_eq_string
  end interface

  interface a_eq
    procedure a_eq_integer
    procedure a_eq_real
  end interface
  
  class(parallel_environment), allocatable, target :: par_env
  integer(ccs_err) :: ierr
  integer :: real_type
  character(1024) :: message

  real(ccs_real), parameter :: eps = epsilon(0.0_ccs_real)

contains

  !>  Test initialisation
  !
  !> @description Performs initialisation for the test (setting up parallel environment, etc.)
  subroutine init()

    integer, allocatable :: seed(:)
    integer :: n

    if (kind(0.0_ccs_real) == kind(0.0d0)) then
      real_type = MPI_DOUBLE
    else
      real_type = MPI_FLOAT
    end if

    call initialise_parallel_environment(par_env)

    ! XXX: This would be a good candidate for a testing library
    call random_seed(size=n)
    allocate(seed(n))
    call random_seed(get=seed)
    if (par_env%proc_id == par_env%root) then
      print *, "Using seed: ", seed
      print *, "----------------------------------"
    end if
    deallocate(seed)

    select type(par_env)
    type is(parallel_environment_mpi)
      call MPI_Barrier(par_env%comm, ierr)
    class default
      print *, "ERROR: Unknown parallel environment!"
      stop 1
    end select
    
  end subroutine init

  !>  Test finalisation
  !
  !> @description Performs finalisation for the test (tearing down parallel environment, etc.)
  subroutine fin()

    call cleanup_parallel_environment(par_env)

  end subroutine fin

  !>  Helper function to get a random number in parallel
  !
  !> @description Generates a random number and broadcasts the value on the root of the parallel
  !! environment, ensuring a uniform value is used.
  !
  !> @note Does this belong in the parallel module?
  real(ccs_real) function parallel_random(par_env)

    class(parallel_environment), intent(in) :: par_env

    call random_number(parallel_random)

    select type(par_env)
    type is(parallel_environment_mpi)
      call MPI_Bcast(parallel_random, 1, real_type, par_env%root, par_env%comm, ierr)
    class default
      print *, "ERROR: Unknown parallel environment!"
      stop 1
    end select
    
  end function parallel_random

  !>  Test failure stop
  !
  !> @description Stop a test, provide an error message, do cleanup etc.
  subroutine stop_test(message)

    character(*), intent(in) :: message
    character(len=32) :: id_str

    write (id_str, "(I0)") par_env%proc_id
    print *, "("//trim(id_str)//") ", trim(message)

    ! other PEs might not have encountered a test failure
    ! fin()

    stop 1
  end subroutine stop_test
 


  !>  Assertion for integer equality
  !
  !> @description Check whether input integers are equal. If not, construct message, print and stop.
  subroutine assert_eq_integer_rank0(test_value, reference_value, msg_format)

    integer(ccs_int), intent(in) :: test_value       !< Test value
    integer(ccs_int), intent(in) :: reference_value  !< reference value
    character(*), intent(in) :: msg_format           !< Error message 
    character(1024) :: message

    if (.not. a_eq(test_value, reference_value)) then
      write (message, msg_format) test_value, reference_value
      call stop_test(message)
    end if

  end subroutine assert_eq_integer_rank0
  subroutine assert_eq_integer_rank1(test_value, reference_value, msg_format)

    integer(ccs_int), dimension(:), intent(in) :: test_value       !< Test value
    integer(ccs_int), dimension(:), intent(in) :: reference_value  !< reference value
    character(*), intent(in) :: msg_format                         !< Error message 
    character(1024) :: message

    if (.not. all(a_eq(test_value, reference_value))) then
      write (message, msg_format) test_value, reference_value
      call stop_test(message)
    end if

  end subroutine assert_eq_integer_rank1
 


  !>  assertion for real equality
  !
  !> @description check whether input reals are equal. if not, construct message, print and stop.
  subroutine assert_eq_real_rank0(test_value, reference_value, msg_format)

    real(ccs_real), intent(in) :: test_value      !< Test value
    real(ccs_real), intent(in) :: reference_value !< reference value
    character(*), intent(in) :: msg_format        !< Error message 
    character(1024) :: message

    if (.not. a_eq(test_value, reference_value)) then
      write (message, msg_format) test_value, reference_value
      call stop_test(message)
    end if

  end subroutine assert_eq_real_rank0
  subroutine assert_eq_real_rank1(test_value, reference_value, msg_format)

    real(ccs_real), dimension(:), intent(in) :: test_value      !< Test value
    real(ccs_real), dimension(:), intent(in) :: reference_value !< reference value
    character(*), intent(in) :: msg_format                      !< Error message 
    character(1024) :: message

    if (.not. all(a_eq(test_value, reference_value))) then
      write (message, msg_format) test_value, reference_value
      call stop_test(message)
    end if

  end subroutine assert_eq_real_rank1
 


  !>  assertion for string equality
  !
  !> @description check whether input strings are equal. if not, construct message, print and stop.
  subroutine assert_eq_string(test_value, reference_value, msg_format)

    character(*), intent(in) :: test_value      !< Test value
    character(*), intent(in) :: reference_value !< reference value
    character(*), intent(in) :: msg_format      !< Error message 
    character(1024) :: message

    if (test_value /= reference_value) then
      write (message, msg_format) test_value, reference_value
      call stop_test(message)
    end if

  end subroutine assert_eq_string
 




  

  elemental logical function a_eq_integer(a, b) result(comparison)
    integer(ccs_int), intent(in) :: a 
    integer(ccs_int), intent(in) :: b 

    comparison = a == b
  end function a_eq_integer
  
  elemental logical function a_eq_real(a, b) result(comparison)
    real(ccs_real), intent(in) :: a 
    real(ccs_real), intent(in) :: b 

    comparison = (abs(a - b) < epsilon(b) * abs(b))
  end function a_eq_real



end module testing_lib
