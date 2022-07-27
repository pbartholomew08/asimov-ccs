!>  boundary conditions module
!
!>  Various BC related functionality. Need to expand.

module boundary_conditions
#include "ccs_macros.inc"

  use utils, only: exit_print
  use types, only: bc_config, field
  use kinds, only: ccs_int, ccs_real
  use yaml, only: parse, error_length
  use read_config, only: get_bc_field
  use bc_constants
  
  implicit none

  private
  public :: read_bc_config
  public :: set_bc_attribute
  public :: allocate_bc_arrays
  public :: get_bc_index

  interface set_bc_attribute
    module procedure set_bc_real_attribute
    module procedure set_bc_string_attribute
    module procedure set_bc_id
  end interface

  contains

  !>  Reads config file and assigns data to BC structure
  subroutine read_bc_config(filename, bc_field, phi) 
    character(len=*), intent(in) :: filename  !< name of the config file
    character(len=*), intent(in) :: bc_field  !< string denoting which field we want to read in
    class(field), intent(inout) :: phi        !< the bc struct of the corresponding field

    class(*), pointer :: config_file
    character(len=error_length) :: error

    config_file => parse(filename, error=error)
    if (error/='') then
      call error_abort(trim(error))
    endif

    call get_bc_field(config_file, "name", phi)
    call get_bc_field(config_file, "id", phi)
    call get_bc_field(config_file, "type", phi, required=.false.)
    call get_bc_field(config_file, "value", phi, required=.false.)
    call get_bc_field(config_file, bc_field, phi)
  end subroutine read_bc_config
  
  !> Sets the appropriate integer values for strings with given by the key-value pair attribute, value
  subroutine set_bc_string_attribute(boundary_index, attribute, value, bcs)
    integer(ccs_int), intent(in) :: boundary_index  !< Index of the boundary within bcs struct arrays 
    character(len=*), intent(in) :: attribute       !< string giving the attribute name
    character(len=*), intent(in) :: value           !< string giving the attribute value
    type(bc_config), intent(inout) :: bcs           !< bcs struct

    select case (attribute)
    case ("name")
      select case (value)
      case ("left")
        bcs%names(boundary_index) = bc_region_left
      case ("right")
        bcs%names(boundary_index) = bc_region_right
      case ("bottom")
        bcs%names(boundary_index) = bc_region_bottom
      case ("top")
        bcs%names(boundary_index) = bc_region_top
      end select
    case ("type")
      select case (value)
      case ("periodic")
        bcs%bc_types(boundary_index) = bc_type_periodic
      case ("sym")
        bcs%bc_types(boundary_index) = bc_type_sym
      case ("dirichlet")
        bcs%bc_types(boundary_index) = bc_type_dirichlet
      case ("neumann")
        bcs%bc_types(boundary_index) = bc_type_neumann
      case ("extrapolate")
        bcs%bc_types(boundary_index) = bc_type_extrapolate
      case ("const_grad")
        bcs%bc_types(boundary_index) = bc_type_const_grad
      case ("wall")
        bcs%bc_types(boundary_index) = bc_type_wall
      end select
    case default
      call error_abort("invalid bc attribute " // attribute // " " // value)
    end select

  end subroutine set_bc_string_attribute
  
  !> Sets the bc struct's value field to the given integer value
  subroutine set_bc_id(boundary_index, value, bcs)
    integer(ccs_int), intent(in) :: boundary_index  !< index of the boundary within the bc struct's arrays
    integer(ccs_int), intent(in) :: value           !< the value to set 
    type(bc_config), intent(inout) :: bcs           !< the bcs struct

    bcs%ids(boundary_index) = value
  end subroutine set_bc_id

  !> Sets the bc struct's value field to the given real value
  subroutine set_bc_real_attribute(boundary_index, value, bcs)
    integer(ccs_int), intent(in) :: boundary_index  !< index of the boundary within the bc struct's arrays
    real(ccs_real), intent(in) :: value             !< the value to set 
    type(bc_config), intent(inout) :: bcs           !< the bcs struct

    bcs%values(boundary_index) = value
  end subroutine set_bc_real_attribute

  !> Allocates arrays of the appropriate size for the name, type and value of the bcs
  subroutine allocate_bc_arrays(n_boundaries, bcs)
    integer(ccs_int), intent(in) :: n_boundaries  !< the number of boundaries 
    type(bc_config), intent(inout) :: bcs         !< the bc struct

    if (.not. allocated(bcs%names)) then
      allocate(bcs%names(n_boundaries))
    end if
    if (.not. allocated(bcs%ids)) then
      allocate(bcs%ids(n_boundaries))
    end if
    if (.not. allocated(bcs%bc_types)) then
      allocate(bcs%bc_types(n_boundaries))
    end if
    if (.not. allocated(bcs%values)) then
      allocate(bcs%values(n_boundaries))
    end if
  end subroutine allocate_bc_arrays

  !> Gets the index of the given boundary condition within the bc struct arrays
  subroutine get_bc_index(phi, index_nb, index_bc)
    class(field), intent(in) :: phi             !< The field whose bc we're getting
    integer(ccs_int), intent(in) :: index_nb    !< The index of the neighbouring boundary cell
    integer(ccs_int), intent(out) :: index_bc   !< The index of the appropriate boundary in the bc struct

    ! Local variable
    integer(ccs_int), dimension(1) :: index_tmp ! The intrinsic returns a rank-1 array ...
    
    index_tmp = findloc(phi%bcs%ids, -index_nb) ! Hardcoded for square mesh
    index_bc = index_tmp(1)
  end subroutine get_bc_index
end module boundary_conditions
