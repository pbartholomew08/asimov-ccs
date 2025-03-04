!v Test that the diffusion coefficient is being calculated correctly
!
!  Currently hard-coded result, waiting for better treatment of diffusion
program test_diffusion_coeff

  use testing_lib
  use ccs_base, only: bnd_names_default
  use meshing, only: create_cell_locator, create_neighbour_locator, get_boundary_status
  use meshing, only: set_mesh_object, nullify_mesh_object
  use mesh_utils, only: build_square_mesh
  use fv, only: calc_diffusion_coeff

  real(ccs_real), parameter :: L = 1.0_ccs_real ! Domain length
  integer(ccs_int), parameter :: cps = 50       ! Grid cells per side
  real(ccs_real) :: coeff

  integer(ccs_int) :: index_p
  integer(ccs_int) :: j
  logical :: is_boundary

  type(cell_locator) :: loc_p
  type(neighbour_locator) :: loc_nb

  real(ccs_real) :: dx                             ! Grid spacing
  real(ccs_real) :: A                              ! Face area
  real(ccs_real), parameter :: D = 1.0e-2_ccs_real ! Diffusion coefficient

  real(ccs_real) :: expected_coeff
  real(ccs_real) :: visp, visnb        ! viscosity
  real(ccs_real) :: dens_p, dens_nb    ! density
  real(ccs_real), parameter :: SchmidtNo = 1.0_ccs_real

  call init()

  mesh = build_square_mesh(par_env, shared_env, cps, L, &
       bnd_names_default(1:4))
  call set_mesh_object(mesh)

  index_p = 1
  j = 1
  visp = SchmidtNo * D
  visnb = SchmidtNo * D
  dens_p = 1.0_ccs_real
  dens_nb = 1.0_ccs_real
  call calc_diffusion_coeff(index_p, j, .false., visp, visnb, dens_p, dens_nb, SchmidtNo, coeff)

  call create_cell_locator(index_p, loc_p)
  call create_neighbour_locator(loc_p, j, loc_nb)
  call get_boundary_status(loc_nb, is_boundary)

  dx = L / real(cps, ccs_real)
  A = dx
  if (is_boundary) then
    dx = dx / 2.0_ccs_real
  end if
  expected_coeff = -D * (A / dx)

  call assert_eq(coeff, expected_coeff, "Incorrect diffusion coefficient computed")

  call nullify_mesh_object()
  call fin()

end program test_diffusion_coeff
