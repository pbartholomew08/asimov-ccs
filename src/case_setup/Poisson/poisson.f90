!v Program file for Poisson case
!
!  Based on prototype/ex3 a port of PETSc ksp/tutorial/ex3.c to ASiMoV-CCS style code.
!  This case demonstrates setting up a linear system and solving it with ASiMoV-CCS, note
!  the code is independent of PETSc.
!  The example case solves the equation
!  \[
!    {\nabla^2} p = f
!  \]
!  in the unit square with Dirichlet boundary conditions
!  \[
!    p\left(\boldsymbol{x}\right) = y,\ \boldsymbol{x}\in\partial\Omega
!  \]

module problem_setup

  use constants, only: ndim
  use kinds, only: ccs_int, ccs_real
  use types, only: ccs_mesh, cell_locator, face_locator
  use parallel, only: create_new_par_env

  use meshing, only: create_face_locator, create_cell_locator, get_centre

  implicit none

  private

  public :: eval_solution
  public :: eval_cell_rhs

  !> Interface to evaluate exact solution.
  interface eval_solution
    module procedure eval_solution_cell
    module procedure eval_solution_face
  end interface eval_solution

contains

  !v Evaluate the exact solution.
  !
  !  Used to set the Dirichlet BCs and also the reference solution for testing the numerical
  !  solution. Thus this should reflect changes to the forcing function.
  function eval_solution_coordinates(x) result(r)

    real(ccs_real), dimension(:), intent(in) :: x
    real(ccs_real) :: r

    associate (y => x(2))
      r = y
    end associate

  end function eval_solution_coordinates

  function eval_solution_cell(loc_p) result(r)

    type(cell_locator), intent(in) :: loc_p
    real(ccs_real) :: r

    real(ccs_real), dimension(ndim) :: x

    call get_centre(loc_p, x)
    r = eval_solution_coordinates(x)

  end function eval_solution_cell

  function eval_solution_face(loc_f) result(r)

    type(face_locator), intent(in) :: loc_f
    real(ccs_real) :: r

    real(ccs_real), dimension(ndim) :: x

    call get_centre(loc_f, x)
    r = eval_solution_coordinates(x)

  end function eval_solution_face

  !> Apply forcing function
  pure subroutine eval_cell_rhs(x, y, H, r)

    real(ccs_real), intent(in) :: x, y, H
    real(ccs_real), intent(out) :: r

    r = 0.0_ccs_real &
        + 0.0_ccs_real * (x + y + H) ! Silence unused dummy argument error

  end subroutine eval_cell_rhs

end module problem_setup

module poisson_discretisation

  use constants, only: ndim, add_mode, insert_mode
  use kinds, only: ccs_int, ccs_real
  use types, only: ccs_vector, vector_values, &
                   ccs_matrix, matrix_values_spec, matrix_values, &
                   ccs_mesh, cell_locator, neighbour_locator, face_locator

  use mat, only: create_matrix_values, set_matrix_values_spec_ncols, set_matrix_values_spec_nrows
  use meshing, only: get_local_num_cells, create_cell_locator, get_centre, get_volume, &
                     get_global_index, count_neighbours, create_neighbour_locator, get_boundary_status, &
                     create_face_locator, get_face_area
  use utils, only: clear_entries, set_mode, set_col, set_row, set_entry, set_values
  use vec, only: create_vector_values

  use problem_setup, only: eval_solution

  implicit none

  private

  public :: discretise_poisson
  public :: apply_dirichlet_bcs

  interface
    module subroutine discretise_poisson(mesh, M)
      type(ccs_mesh), intent(in) :: mesh    !< The mesh the problem is defined upon
      class(ccs_matrix), intent(inout) :: M !< The system matrix
    end subroutine discretise_poisson

    module subroutine apply_dirichlet_bcs(mesh, M, b)
      type(ccs_mesh), intent(in) :: mesh    !< The mesh the problem is defined upon
      class(ccs_matrix), intent(inout) :: M !< The system matrix
      class(ccs_vector), intent(inout) :: b !< The system righthand side vector
    end subroutine apply_dirichlet_bcs
  end interface

end module poisson_discretisation

program poisson

  use poisson_discretisation
  use problem_setup

  ! ASiMoV-CCS uses
  use ccs_base, only: mesh
  use constants, only: ndim, add_mode, insert_mode, ccs_split_type_shared, ccs_split_type_low_high, ccs_split_undefined
  use kinds, only: ccs_real, ccs_int
  use case_config, only: velocity_solver_method_name, velocity_solver_precon_name, &
                         pressure_solver_method_name, pressure_solver_precon_name
  use types, only: vector_spec, ccs_vector, matrix_spec, ccs_matrix, &
                   equation_system, linear_solver, ccs_mesh, cell_locator, face_locator, &
                   neighbour_locator, vector_values, matrix_values, matrix_values_spec
  use meshing, only: create_cell_locator, create_face_locator, create_neighbour_locator, get_local_num_cells
  use meshing, only: set_mesh_object, nullify_mesh_object
  use vec, only: create_vector
  use mat, only: create_matrix, set_nnz, create_matrix_values, set_matrix_values_spec_nrows, &
                 set_matrix_values_spec_ncols
  use solver, only: create_solver, solve, set_equation_system, axpy, norm, &
                    set_solver_method, set_solver_precon
  use utils, only: update, begin_update, end_update, finalise, initialise, &
                   set_size, &
                   set_values, clear_entries, set_values, set_row, set_col, set_entry, set_mode
  use vec, only: create_vector_values
  use mesh_utils, only: build_square_mesh
  use meshing, only: get_face_area, get_centre, get_volume, get_global_index, &
                     count_neighbours, get_boundary_status
  use parallel_types, only: parallel_environment
  use parallel, only: initialise_parallel_environment, &
                      cleanup_parallel_environment, &
                      read_command_line_arguments, &
                      timer, sync, create_new_par_env

  implicit none

  class(parallel_environment), allocatable, target :: par_env
  class(parallel_environment), allocatable, target :: shared_env
  class(ccs_vector), allocatable, target :: u, b
  class(ccs_vector), allocatable :: u_exact
  class(ccs_matrix), allocatable, target :: M
  class(linear_solver), allocatable :: poisson_solver

  type(vector_spec) :: vec_properties
  type(matrix_spec) :: mat_properties
  type(equation_system) :: poisson_eq

  integer(ccs_int) :: cps = 10 !< Default value for cells per side

  real(ccs_real) :: err_norm
  logical :: use_mpi_splitting

  double precision :: start_time
  double precision :: end_time

  call initialise_parallel_environment(par_env)
  use_mpi_splitting = .false.
  call create_new_par_env(par_env, ccs_split_type_low_high, use_mpi_splitting, shared_env)
  call read_command_line_arguments(par_env, cps=cps)

  ! set solver and preconditioner info
  velocity_solver_method_name = "gmres"
  velocity_solver_precon_name = "bjacobi"
  pressure_solver_method_name = "cg"
  pressure_solver_precon_name = "gamg"

  call sync(par_env)
  call timer(start_time)

  call initialise_poisson(par_env, shared_env)

  ! Initialise with default values
  call initialise(vec_properties)
  call initialise(mat_properties)
  call initialise(poisson_eq)

  ! Create stiffness matrix
  call set_size(par_env, mesh, mat_properties)
  call set_nnz(5, mat_properties)
  call create_matrix(mat_properties, M)

  call discretise_poisson(mesh, M)

  call begin_update(M) ! Start the parallel assembly for M

  ! Create right-hand-side and solution vectors
  call set_size(par_env, mesh, vec_properties)
  call create_vector(vec_properties, b)
  call create_vector(vec_properties, u_exact)
  call create_vector(vec_properties, u)

  call begin_update(u) ! Start the parallel assembly for u

  ! Evaluate right-hand-side vector
  call eval_rhs(mesh, b)

  call begin_update(b) ! Start the parallel assembly for b
  call end_update(M) ! Complete the parallel assembly for M
  call end_update(b) ! Complete the parallel assembly for b

  ! Modify matrix and right-hand-side vector to apply Dirichlet boundary conditions
  call apply_dirichlet_bcs(mesh, M, b)
  call begin_update(b) ! Start the parallel assembly for b
  call finalise(M)

  call end_update(u) ! Complete the parallel assembly for u
  call end_update(b) ! Complete the parallel assembly for b

  ! Create linear solver & set options
  call set_equation_system(par_env, b, u, M, poisson_eq)
  call create_solver(poisson_eq, poisson_solver)
  call set_solver_method(pressure_solver_method_name, poisson_solver)
  call set_solver_precon(pressure_solver_precon_name, poisson_solver)
  call solve(poisson_solver)

  ! Check solution
  call set_exact_sol(u_exact)
  call axpy(-1.0_ccs_real, u_exact, u)

  err_norm = norm(u, 2) * mesh%geo%h
  if (par_env%proc_id == par_env%root) then
    print *, "Norm of error = ", err_norm
  end if

  ! Clean up
  deallocate (u)
  deallocate (b)
  deallocate (u_exact)
  deallocate (M)
  deallocate (poisson_solver)

  call timer(end_time)

  if (par_env%proc_id == par_env%root) then
    print *, "Elapsed time = ", (end_time - start_time)
  end if

  call cleanup_parallel_environment(par_env)

contains

  subroutine set_exact_sol(u_exact)

    class(ccs_vector), intent(inout) :: u_exact

    type(vector_values) :: vec_values
    integer(ccs_int) :: i, local_num_cells

    type(cell_locator) :: loc_p
    integer(ccs_int) :: global_index_p
    integer(ccs_int) :: nrows_working_set

    nrows_working_set = 1_ccs_int
    call create_vector_values(nrows_working_set, vec_values)
    call set_mode(insert_mode, vec_values)

    call get_local_num_cells(local_num_cells)
    do i = 1, local_num_cells
      call clear_entries(vec_values)
      call create_cell_locator(i, loc_p)
      call get_global_index(loc_p, global_index_p)

      call set_row(global_index_p, vec_values)
      call set_entry(eval_solution(loc_p), vec_values)
      call set_values(vec_values, u_exact)
    end do
    deallocate (vec_values%global_indices)
    deallocate (vec_values%values)

    call update(u_exact)
  end subroutine set_exact_sol

  subroutine initialise_poisson(par_env, shared_env)

    use ccs_base, only: bnd_names_default

    class(parallel_environment), allocatable :: par_env
    class(parallel_environment), allocatable :: shared_env

    mesh = build_square_mesh(par_env, shared_env, cps, 1.0_ccs_real, &
                             bnd_names_default(1:4))
    call set_mesh_object(mesh)

  end subroutine initialise_poisson

  !> Forcing function
  subroutine eval_rhs(mesh, b)

    type(ccs_mesh), intent(in) :: mesh
    class(ccs_vector), intent(inout) :: b

    integer(ccs_int) :: nloc
    integer(ccs_int) :: i
    real(ccs_real) :: r

    type(vector_values) :: val_dat

    type(cell_locator) :: loc_p
    real(ccs_real), dimension(ndim) :: cc
    real(ccs_real) :: V
    integer(ccs_int) :: global_index_p
    integer(ccs_int) :: nrows_working_set

    nrows_working_set = 1_ccs_int
    call create_vector_values(nrows_working_set, val_dat)
    call set_mode(add_mode, val_dat)

    call get_local_num_cells(nloc)
    associate (h => mesh%geo%h)
      ! this is currently setting 1 vector value at a time
      ! consider changing to doing all the updates in one go
      ! to do only 1 call to eval_cell_rhs and set_values
      do i = 1, nloc
        call clear_entries(val_dat)

        call create_cell_locator(i, loc_p)
        call get_centre(loc_p, cc)
        call get_volume(loc_p, V)
        call get_global_index(loc_p, global_index_p)
        associate (x => cc(1), y => cc(2))
          call eval_cell_rhs(x, y, h**2, r)
          r = V * r
          call set_row(global_index_p, val_dat)
          call set_entry(r, val_dat)
          call set_values(val_dat, b)
        end associate
      end do
    end associate

    deallocate (val_dat%global_indices)
    deallocate (val_dat%values)

  end subroutine eval_rhs

end program poisson
