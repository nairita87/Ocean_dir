! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.com/license.html
!
!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  ocn_vel_vadv
!
!> \brief MPAS ocean vertical advection
!> \author Mark Petersen
!> \date   September 2011
!> \details
!>  This module contains the routine for computing
!>  tendencies for vertical advection.
!>
!
!-----------------------------------------------------------------------

module ocn_vel_vadv

   use mpas_timer
   use mpas_derived_types
   use mpas_pool_routines
   use ocn_constants

   implicit none
   private
   save

   !--------------------------------------------------------------------
   !
   ! Public parameters
   !
   !--------------------------------------------------------------------

   !--------------------------------------------------------------------
   !
   ! Public member functions
   !
   !--------------------------------------------------------------------

   public :: ocn_vel_vadv_tend, &
             ocn_vel_vadv_init

   !--------------------------------------------------------------------
   !
   ! Private module variables
   !
   !--------------------------------------------------------------------

   logical :: velVadvOn


!***********************************************************************

contains

!***********************************************************************
!
!  routine ocn_vel_vadv_tend
!
!> \brief   Computes tendency term for vertical advection
!> \author  Mark Petersen
!> \date    September 2011
!> \details
!>  This routine computes the vertical advection tendency for momentum
!>  based on current state.
!
!-----------------------------------------------------------------------

   subroutine ocn_vel_vadv_tend(meshPool, normalVelocity, layerThicknessEdge, vertAleTransportTop, tend, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      real (kind=RKIND), dimension(:,:), intent(in) :: &
         normalVelocity    !< Input: Horizontal velocity
      real (kind=RKIND), dimension(:,:), intent(in) :: &
         layerThicknessEdge,&!< Input: thickness at edge
         vertAleTransportTop  !< Input: Vertical velocity on top layer

      type (mpas_pool_type), intent(in) :: &
         meshPool          !< Input: mesh information

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      real (kind=RKIND), dimension(:,:), intent(inout) :: &
         tend          !< Input/Output: velocity tendency

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      integer :: iEdge, cell1, cell2, k, nEdges
      integer, pointer :: nVertLevels
      integer, dimension(:), pointer :: nEdgesArray
      integer, dimension(:), pointer :: maxLevelEdgeTop
      integer, dimension(:,:), pointer :: cellsOnEdge, edgeMask

      real (kind=RKIND) :: vertAleTransportTopEdge
      real (kind=RKIND), dimension(:), allocatable :: w_dudzTopEdge

      if (.not. velVadvOn) return

      call mpas_timer_start("vel vadv")

      err = 0

      call mpas_pool_get_dimension(meshPool, 'nVertLevels', nVertLevels)
      call mpas_pool_get_dimension(meshPool, 'nEdgesArray', nEdgesArray)
      call mpas_pool_get_array(meshPool, 'maxLevelEdgeTop', maxLevelEdgeTop)
      call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
      call mpas_pool_get_array(meshPool, 'edgeMask', edgeMask)

      allocate(w_dudzTopEdge(nVertLevels+1))
      w_dudzTopEdge = 0.0_RKIND

      nEdges = nEdgesArray( 1 )

      !$omp do schedule(runtime)
      do iEdge = 1, nEdges
        cell1 = cellsOnEdge(1,iEdge)
        cell2 = cellsOnEdge(2,iEdge)

        do k = 2, maxLevelEdgeTop(iEdge)
          ! Average w from cell center to edge
          vertAleTransportTopEdge = 0.5_RKIND*(vertAleTransportTop(k,cell1) + vertAleTransportTop(k,cell2))

          ! compute dudz at vertical interface with first order derivative.
          w_dudzTopEdge(k) = vertAleTransportTopEdge * (normalVelocity(k-1,iEdge)-normalVelocity(k,iEdge)) &
                       / (0.5_RKIND*(layerThicknessEdge(k-1,iEdge) + layerThicknessEdge(k,iEdge)))
        end do
        w_dudzTopEdge(maxLevelEdgeTop(iEdge)+1) = 0.0_RKIND
        ! Average w*du/dz from vertical interface to vertical middle of cell
        do k = 1, maxLevelEdgeTop(iEdge)

          tend(k,iEdge) = tend(k,iEdge) - edgeMask(k, iEdge) * 0.5 * (w_dudzTopEdge(k) + w_dudzTopEdge(k+1))
        enddo
      enddo
      !$omp end do

      deallocate(w_dudzTopEdge)

      call mpas_timer_stop("vel vadv")

   !--------------------------------------------------------------------

   end subroutine ocn_vel_vadv_tend!}}}

!***********************************************************************
!
!  routine ocn_vel_vadv_init
!
!> \brief   Initializes ocean momentum vertical advection
!> \author  Mark Petersen
!> \date    September 2011
!> \details
!>  This routine initializes a variety of quantities related to
!>  vertical velocity advection in the ocean.
!
!-----------------------------------------------------------------------

   subroutine ocn_vel_vadv_init(err)!{{{

   !--------------------------------------------------------------------

      !-----------------------------------------------------------------
      !
      ! Output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      character (len=StrKIND), pointer :: config_vert_coord_movement
      logical, pointer :: config_disable_vel_vadv

      err = 0

      call mpas_pool_get_config(ocnConfigs, 'config_vert_coord_movement', config_vert_coord_movement)
      call mpas_pool_get_config(ocnConfigs, 'config_disable_vel_vadv', config_disable_vel_vadv)

      velVadvOn = .false.

      if (config_vert_coord_movement .ne.'impermeable_interfaces') then
          velVadvOn = .true.
      end if

      if ( config_disable_vel_vadv ) velVadvOn = .false.

   !--------------------------------------------------------------------

   end subroutine ocn_vel_vadv_init!}}}

!***********************************************************************

end module ocn_vel_vadv

!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
! vim: foldmethod=marker
