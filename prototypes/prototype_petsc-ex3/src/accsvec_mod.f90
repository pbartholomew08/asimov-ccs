!> @brief Module file accsvec.mod
!>
!> @details An interface to operations on vector objects (creation, destruction, setting and
!>          getting, ...)

module accsvec

  use accs_types, only : vector, vector_init_data
  
  implicit none

  private

  public :: create_vector, free_vector, set_vector_values

  interface
     module subroutine create_vector(vec_dat, v)
       !> @brief Creates a vector given the local or global size.
       !>
       !> @param[in] vector_init_data vec_dat - Data structure containing the global and local sizes
       !>                                       of the vector, -1 is interpreted as unset. If both
       !>                                       are set the local size is used.
       !> @param[out] vector v - The vector returned allocated, but (potentially) uninitialised.
       type(vector_init_data), intent(in) :: vec_dat
       class(vector), allocatable, intent(out) :: v
     end subroutine

     module subroutine free_vector(v)
       !> @brief Interface to destroy a vector class object.
       !>
       !> @param[in] vector v - The vector to be destroyed.
       class(vector), intent(inout) :: v
     end subroutine

     module subroutine set_vector_values(val_dat, v)

       class(*), intent(in) :: val_dat
       class(vector), intent(inout) :: v

     end subroutine
     
  end interface
  
end module accsvec
