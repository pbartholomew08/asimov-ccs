!> @brief Test the mesh generator creates a closed mesh.
!
!> @description A valid mesh should be "closed" that is the surface integral should be zero. The
!!              same is true of mesh cells.
program test_mesh_closed

  use testing_lib

  use constants

  use ccs_base, only: bnd_names_default
  use meshing, only: create_face_locator, get_face_normal, get_face_area, get_local_num_cells
  use meshing, only: set_mesh_object, nullify_mesh_object
  use mesh_utils, only: build_mesh

  implicit none

  type(face_locator) :: loc_f

  integer(ccs_int) :: n, nx, ny, nz
  real(ccs_real) :: l

  real(ccs_real), dimension(ndim) :: S
  real(ccs_real), dimension(ndim) :: norm
  real(ccs_real) :: A

  integer(ccs_int) :: local_num_cells
  integer(ccs_int) :: i, j

  real(ccs_real) :: A_expected

  integer(ccs_int), dimension(4) :: m = (/4, 8, 16, 20/)
  integer(ccs_int) :: mctr

  call init()

  ! XXX: use smaller size than 2D test - 20^3 ~= 100^2
  do mctr = 1, size(m)
    n = m(mctr)

    nx = n
    ny = n
    nz = n

    l = parallel_random(par_env)
    mesh = build_mesh(par_env, shared_env, nx, nz, ny, l, &
         bnd_names_default)
    call set_mesh_object(mesh)

    A_expected = (l / n)**2

    ! Loop over cells
    call get_local_num_cells(local_num_cells)
    do i = 1, local_num_cells
      S(:) = 0.0_ccs_real

      ! Loop over neighbours/faces
      do j = 1, mesh%topo%num_nb(i)

        call create_face_locator(i, j, loc_f)
        call get_face_area(loc_f, A)
        call get_face_normal(loc_f, norm)
        S(:) = S(:) + norm(:) * A

        if (abs(A - A_expected) > 1.0e-8) then
          write (message, *) "FAIL: expected face area ", A_expected, " got ", A
          call stop_test(message)
        end if
      end do

      ! Loop over axes
      do j = 1, ndim
        print *, S(j), j
        if (abs(S(j) - 0.0_ccs_real) > eps) then
          write (message, *) "FAIL: expected", 0.0_ccs_real, " got ", S(j)
          call stop_test(message)
        end if
      end do
    end do

    call nullify_mesh_object()
  end do

  call fin()

end program test_mesh_closed
