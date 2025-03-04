!v Test the indexing of cells
program test_square_mesh_indices

  use testing_lib

  use ccs_base, only: bnd_names_default
  use meshing, only: create_cell_locator, get_global_index, get_local_num_cells, get_global_num_cells
  use meshing, only: get_total_num_cells
  use meshing, only: set_mesh_object, nullify_mesh_object
  use mesh_utils, only: build_square_mesh

  implicit none

  real(ccs_real) :: l
  integer(ccs_int) :: n

  integer(ccs_int) :: nlocal
  integer(ccs_int) :: nglobal
  integer(ccs_int) :: ntotal
  integer(ccs_int) :: i

  type(cell_locator) :: loc_p
  integer(ccs_int) :: global_index

  integer(ccs_int), dimension(7) :: m = (/4, 8, 16, 20, 40, 80, 100/)
  integer(ccs_int) :: mctr

  call init()

  do mctr = 1, size(m)
    n = m(mctr)
    l = parallel_random(par_env)
    mesh = build_square_mesh(par_env, shared_env, n, l, &
         bnd_names_default(1:4))
    call set_mesh_object(mesh)

    call get_local_num_cells(nlocal)
    call get_total_num_cells(ntotal)
    call get_global_num_cells(nglobal)
    do i = 1, nlocal
      call create_cell_locator(i, loc_p)
      call get_global_index(loc_p, global_index)
      if ((global_index < 1) .or. (global_index > nglobal)) then
        if (global_index /= -1) then
          write (message, *) "FAIL: expected global index 1 <= idx <= ", nglobal, " got ", global_index
          call stop_test(message)
        end if
        exit
      end if
    end do

    call nullify_mesh_object()
  end do

  call fin()

end program test_square_mesh_indices
