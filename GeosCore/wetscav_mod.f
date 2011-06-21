!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!     
! !MODULE: wetscav_mod
!     
! !DESCRIPTION: Module WETSCAV\_MOD contains routines and variables used in 
!  the wet scavenging of tracer in cloud updrafts, rainout, and washout. 
!\\   
!\\   
! !INTERFACE: 
!
      MODULE WETSCAV_MOD
!
! !USES:
!
      IMPLICIT NONE
      PRIVATE
!
! !PUBLIC DATA MEMBERS:
!
      REAL*8, PUBLIC, ALLOCATABLE :: H2O2s(:,:,:)   ! Save H2O2 and SO2 [v/v]
      REAL*8, PUBLIC, ALLOCATABLE :: SO2s(:,:,:)    !  for sulfate chemistry
!
! !PUBLIC MEMBER FUNCTIONS:
!
      PUBLIC  :: CLEANUP_WETSCAV
      PUBLIC  :: COMPUTE_F
      PUBLIC  :: DO_WETDEP
      PUBLIC  :: GET_WETDEP_IDWETD
      PUBLIC  :: GET_WETDEP_NMAX
      PUBLIC  :: GET_WETDEP_NSOL
      PUBLIC  :: INIT_WETSCAV
      PUBLIC  :: WETDEPID
      PUBLIC  :: WASHOUT
      PUBLIC  :: LS_K_RAIN
      PUBLIC  :: LS_F_PRIME
!
! !PRIVATE MEMBER FUNCTIONS:
!
      PRIVATE :: COMPUTE_L2G
      PRIVATE :: CONV_F_PRIME
      PRIVATE :: E_ICE
      PRIVATE :: RAINOUT
      PRIVATE :: GET_RAINFRAC
      PRIVATE :: SAFETY
      PRIVATE :: WASHFRAC_AEROSOL
      PRIVATE :: WASHFRAC_LIQ_GAS
!
! !REMARKS:
!  References:
!  ============================================================================
!  (1 ) Liu,H., D.J. Jacob, I. Bey and R.M. Yantosca, "Constraints from 210Pb 
!        and 7Be on wet deposition and transport in a global three-dimensional
!        chemical tracer model driven by assimilated meteorological fields", 
!        JGR, Vol 106, pp 12109-12128, 2001.
!  (2 ) D.J. Jacob, H. Liu, C. Mari, and R. M. Yantosca, "Harvard wet 
!        deposition scheme for GMI", Harvard Atmospheric Chemistry Modeling 
!        Group, March 2000.
!  (3 ) Chin, M., D.J. Jacob, G.M. Gardner, M.S. Foreman-Fowler, and P.A. 
!        Spiro, "A global three-dimensional model of tropospheric sulfate", 
!        J. Geophys. Res., 101, 18667-18690, 1996.
!  (4 ) Balkanski, Y  D.J. Jacob, G.M. Gardner, W.C. Graustein, and K.K.
!        Turekian, "Transport and Residence Times of Tropospheric Aerosols
!        from a Global Three-Dimensional Simulation of 210Pb", JGR, Vol 98, 
!        (D11) pp 20573-20586, 1993.  
!  (5 ) Giorgi, F, & W.L. Chaimedes, "Rainout Lifetimes of Highly Soluble
!        Aerosols and Gases as Inferred from Simulations With a General
!        Circulation Model", JGR, Vol 86 (D13) pp 14367-14376, 1986.  
!
! !REVISION HISTORY:
!  (1 ) Now trap allocation errors with routine ALLOC_ERR. (bmy, 7/11/00)
!  (2 ) Moved routine MAKE_QQ here from "dao_mod.f" (bmy, 10/12/00)
!  (3 ) Reordered arguments in INIT_PRECIP (bmy, 10/12/00)
!  (4 ) Updated comments (bmy, 9/4/01)
!  (5 ) Bug fix in MAKE_QQ: BXHEIGHT is sized IIPAR,JJPAR,LLPAR (bmy, 10/4/01)
!  (6 ) Removed obsolete, commented-out code from 10/01 (bmy, 11/26/01)
!  (7 ) Now divide module header into MODULE PRIVATE, MODULE VARIABLES, and
!        MODULE ROUTINES sections.  Updated comments (bmy, 5/28/02)
!  (8 ) Now zero allocatable arrays (bmy, 8/5/02)
!  (9 ) Bug fix: ND39 diagnostic now closes the budget.  Also bundled several
!        standalone routines into this module.  Now references F90 module
!        "tracerid_mod.f".  Also set NSOLMAX=10 since we now have sulfate
!        tracers for wetdep.   Now prevent out-of-bounds errors in routine
!        WETDEP.  Added GET_WETDEP_NMAX function to return max # of soluble
!        tracers for allocating diagnostic arrays.  Added functions 
!        GET_WETDEP_NSOL and GET_WETDEP_IDWETD.  Now init H2O2s and SO2s
!        to the initial H2O2 and SO2 from STT.  Updated comments. 
!        (qli, bmy, 1/14/03)
!  (10) Improvements for SO2/SO4 scavenging (rjp, bmy, 3/23/03)
!  (11) Now references "time_mod.f".  Added driver routine DO_WETDEP to
!        remove cumbersome calling sequence from MAIN program.  Also declared
!        WETDEP and MAKE_QQ PRIVATE to this module. (bmy, 3/27/03)
!  (11) Add parallelization to routine WETDEP (bmy, 3/17/04)
!  (12) Added carbon and dust aerosol tracers (rjp, tdf, bmy, 4/5/04)
!  (13) Added seasalt aerosol tracers (rjp, bec, bmy, 4/20/04)
!  (14) Added secondary organic aerosol tracers (rjp, bmy, 7/13/04)
!  (15) Now references "logical_mod.f" and "tracer_mod.f".  Now move all 
!        internal routines to the module and pass arguments explicitly in
!        order to facilitate parallelization on the Altix. (bmy, 7/20/04)
!  (16) Updated for mercury aerosol tracers (eck, bmy, 12/9/04)
!  (17) Updated for AS, AHS, LET, NH4aq, SO4aq.  Also now pass Hg2 wetdep loss
!        to "ocean_mercury_mod.f". (cas, sas, bmy, 1/20/05)
!  (18) Bug fix to avoid numerical blowup in WETDEP.  Now use analytical
!        function for E_ICE(T). (bmy, 3/7/05)
!  (19) Added SO4s, NITs.  Increased NSOLMAX to 31.  Also block out 
!        parallel loop in WETDEP for SGI MIPS compiler. (bec, bmy, 5/5/05)
!  (20) Now make sure all USE statements are USE, ONLY (bmy, 10/3/05)
!  (21) Bug fixes: do not over-deplete H2O2s.  Also include updates for
!        tagged Hg simulation. (dkh, rjp, eck, cdh, bmy, 1/6/06)
!  (22) Now wet deposit SOG4, SOA4. Remove unnecessary variables in WETDEP.
!        (dkh, bmy, 5/18/06)
!  (23) Bug fixes in COMPUTE_F (bmy, 7/26/06)
!  (24) Resize DSTT array in WETDEP to save memory.  Added fixes for GEOS-5
!        wet deposition per Hongyu Liu's suggestions. (bmy, 3/5/08)
!  (25) Add wet scavenging of GLYX, MGLY, GLYC, SOAG, SOAM (tmf, 1/7/09)
!  (26) Effective Henry's law constant and coefficient from 
!       Sander, R, 1999, Compilation of Henry's Law Constants for 
!          Inorganic and Organic Species of Potential Importance in 
!          Environmental Chemistry.
!          http://www.mpch-mainz.mpg.de/~sander/res/henry.html
!       (tmf, 1/7/09)
!  (27) Remove support for SGI compiler.  Bug fix in RAINOUT. (bmy, 7/20/09)
!  (28) Update mercury simulation. (ccc, 5/17/10)
!  (29) Add LGTMM as condition to output AD39. (ccc, 11/18/09)
!  (30) Add snow scavenging, different washout/rainout ratio 
!       (wqq, ccc, 7/13/10)
!  13 Aug 2010 - R. Yantosca - Add modifications for MERRA (treat like GEOS-5)
!  16 Sep 2010 - R. Yantosca - Added ProteX headers
!  20 Sep 2010 - H. Amos, R. Yantosca - Implement new algorithms for MERRA
!  08 Oct 2010 - H. Amos - WASHFRAC_LIQ_GAS is now a subroutine
!  08 Oct 2010 - H. Amos - Various other modifications in WETDEP_MERRA
!  14 Jan 2011 - H. Amos - Bug fix for function WASHFRAC_LIQ_GAS
!  14 Jan 2011 - H. Amos - Updated comments
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !DEFINED PARAMETERS:
!
      INTEGER, PARAMETER   :: NSOLMAX = 50      ! Max # of soluble tracers
      REAL*8,  PARAMETER   :: EPSILON = 1d-32   ! A very small positive #
!
! !LOCAL VARIABLES:
!
      ! Scalars
      INTEGER              :: NSOL              ! # of soluble species

      ! Arrays
      INTEGER              :: IDWETD(NSOLMAX)   ! Index array for WETDEP
      REAL*8,  ALLOCATABLE :: Vud(:,:)          ! Updraft velocity [m/s]
      REAL*8,  ALLOCATABLE :: C_H2O(:,:,:)      ! Mixing ratio of H2O [v/v]
      REAL*8,  ALLOCATABLE :: CLDICE(:,:,:)     ! Cloud ice mixing ratio
                                                !  [cm3 ice/cm3 air]
      REAL*8,  ALLOCATABLE :: CLDLIQ(:,:,:)     ! Cloud liquid water mix rat
                                                !  [cm3 H2O/cm3 air]

      REAL*8,  ALLOCATABLE :: PDOWN(:,:,:)      ! Precipitation thru the
                                                !  bottom of the grid box 
                                                !  [cm3 H2O/cm2 area/s]
      REAL*8,  ALLOCATABLE :: QQ(:,:,:)         ! Rate of new precip formation
                                                !   [cm3 H2O/cm3 air/s]
      CONTAINS
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_wetdep
!
! !DESCRIPTION: Subroutine DO\_WETDEP is a driver for the wet deposition code, 
!  called from the MAIN program.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE DO_WETDEP
!
! !USES:
!
      USE ERROR_MOD,   ONLY : DEBUG_MSG
      USE LOGICAL_MOD, ONLY : LPRT

#     include "CMN_SIZE"    ! Size parameters
! 
! !REMARKS:
!  NOTE FROM HONGYU LIU (hyl@nianet.org) -- 3/5/08
!                                                                             .
!  Rainout and washout from convective precipitation for previous GEOS 
!  archives were intended to represent precipitation from cloud anvils 
!  [Liu et al., 2001]. For GEOS-5 (as archived at Harvard), the cloud anvil 
!  precipitation was already included in the large-scale precipitation. 
!                                                                             .
!  Therefore, we insert a #if block to ensure that call MAKE_QQ and WETDEP 
!  are not called for convective precip in GEOS-5. (hyl, bmy, 3/5/08)
!
! !REVISION HISTORY: 
!  27 Mar 2003 - R. Yantosca - Initial version
!  (1 ) Now references LPRT from "logical_mod.f" (bmy, 7/20/04)
!  (2 ) Don't do rainout/washout for conv precip for GEOS-5 (hyl, bmy, 3/5/08)
!  13 Aug 2010 - R. Yantosca - Treat GEOS-5 like MERRA
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!  20 Sep 2010 - R. Yantosca - Rewrote #if block structure for clarity
!EOP
!------------------------------------------------------------------------------
!BOC

#if   defined( MERRA )

      !=================================================================
      ! MERRA: Only do wet deposition for large-scale + anvil precip
      !=================================================================

      ! Create precip fields
      CALL MAKE_QQ( LS=.TRUE. )
      IF ( LPRT ) CALL DEBUG_MSG( '### DO_WETDEP: before LS wetdep' )

      ! Do wet deposition
      CALL WETDEP_MERRA(  LS=.TRUE. )
      IF ( LPRT ) CALL DEBUG_MSG( '### DO_WETDEP: after LS wetdep' )

#elif defined( GEOS_5 )

      !=================================================================
      ! GEOS5: Only do wet deposition for large-scale + anvil precip
      !=================================================================

      ! Create precip fields
      CALL MAKE_QQ( LS=.TRUE. )
      IF ( LPRT ) CALL DEBUG_MSG( '### DO_WETDEP: before LS wetdep' )

      ! Do wet deposition
      CALL WETDEP(  LS=.TRUE. )
      IF ( LPRT ) CALL DEBUG_MSG( '### DO_WETDEP: after LS wetdep' )

#else

      !=================================================================
      ! Other met fields: Do wetdep for both LS & convective precip
      !=================================================================

      !---------------------
      ! Large-scale precip
      !---------------------

      ! Create precip fields
      CALL MAKE_QQ( LS=.TRUE. )
      IF ( LPRT ) CALL DEBUG_MSG( '### DO_WETDEP: before LS wetdep' )

      ! Do wet deposition
      CALL WETDEP(  LS=.TRUE. )
      IF ( LPRT ) CALL DEBUG_MSG( '### DO_WETDEP: after LS wetdep' )

      !---------------------
      ! Convective precip
      !---------------------

      ! Create precip fields
      CALL MAKE_QQ( LS=.FALSE. )
      IF ( LPRT ) CALL DEBUG_MSG( '### DO_WETDEP: before conv wetdep' )

      !  Do wet deposition
      CALL WETDEP(  LS=.FALSE. )
      IF ( LPRT ) CALL DEBUG_MSG( '### DO_WETDEP: after conv wetdep' )

#endif

      END SUBROUTINE DO_WETDEP
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: make_qq
!
! !DESCRIPTION: Subroutine MAKE\_QQ computes the large-scale or convective 
!  precipitation fields for use with WETDEP
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE MAKE_QQ( LS )
!
! !USES:
!
      USE DAO_MOD,   ONLY : AIRDEN,  BXHEIGHT, DQRLSAN
      USE DAO_MOD,   ONLY : MOISTQ,  PFLLSAN,  PFILSAN
      USE DAO_MOD,   ONLY : PREACC,  PRECON,   REEVAPLS
      USE ERROR_MOD, ONLY : ALLOC_ERR
      
#     include "CMN_SIZE"          ! Size parameters
!
! !INPUT PARAMETERS: 
!
      LOGICAL, INTENT(IN) :: LS   ! =T, denotes large scale precip
                                  ! =F, denotes convective precip
! 
! !REMARKS:
!  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!  %%%%%          FOR MERRA MET FIELDS ONLY         %%%%%
!  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                             .
!  Now construct QQ and PDOWN directly from MERRA met fields.
!                                                                             .
!  This only applies to large-scale precip, as the #if defined
!  block in routine DO_WETDEP prevents the wet deposition
!  routines from being called if it is convective precip.
!                                                                             .
!  MERRA met fields:
!  =================
!  DQRLSAN   = 3-D precip production rate  (LS+anvil) [kg/kg/s]
!  PFILSAN   = Dwnwd flux of ice precip    (LS+anvil) [kg/m2/s]
!  PFLLSAN   = Dwnwd flux of liquid precip (LS+anvil) [kg/m2/s]
!  REEVAPLS  = Evap of precip'ing LS+anvil condensate [kg/kg/s]
!                                                                             .
!  Unit conversion for QQ:
!  =======================
! 
!      kg H2O   |   m^3 H2O   | AIRDEN kg air       m^3 H2O
!   ------------+-------------+--------------- = -------------   
!    kg air * s | 1000 kg H2O |    m^3 air        m^3 air * s
! 
!  and [m^3 H2O/m3 air] = [cm^3 H2O/cm3 air] because the same conversion 
!  factor from m^3 -> cm^3 is in both the numerator and the denominator.
!                                                                             .
!  Unit conversion for PDOWN:
!  ==========================
!                                                                             .
!      kg H2O |   m^3 H2O   | 1e6 cm^3 |  m^2       
!   ----------+-------------+----------+--------- +
!     m^2 * s | 1000 kg H2O |   m^3    | 1e4 cm2 
!                                                                             .
!      kg ice |   m^3 ice   | 1e6 cm^3 |  m^2
!   ----------+-------------+----------+---------
!     m^2 * s |  917 kg ice |   m^3    | 1e4 cm2 
!                                                                             .
!  = [ (PFILSAN/1000) * 100 ] + [ (PFILSAN/1000) * 100]
!                                                                             .
!  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
!  %%%%%    FOR ALL OTHER MET FIELDS EXCEPT MERRA   %%%%%
!  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
!                                                                             .
!  If there is total precipitation in the (I,J) column, then:
!                                                                             .
!  (1) Compute FRAC, the large scale fraction (if LS = .TRUE.) or 
!      convective fraction (if LS = .FALSE.) total precipitation.  
!      FRAC is computed from PREACC and PRECON.
!                                                                             .
!  (2) Compute QQ, the rate of formation of precipitation 
!      [cm3 H2O/cm3 air/s].  From MOISTQ [kg H2O/kg air/s], 
!      the unit conversion is: 
!                                                                             .
!      kg H2O   |   m^3 H2O   | AIRDEN kg air         m^3 H2O
!   ------------+-------------+--------------- ==> -------------   
!    kg air * s | 1000 kg H2O |    m^3 air          m^3 air * s
!                                                                             .
!  and
!                                                                             .
!          m^3 H2O                         cm^3 H2O
!       -------------  is equivalent to  -------------- 
!        m^3 air * s                      cm^3 air * s!
!                                                                             .
!  since the same conversion factor (10^6 cm^3/m^3) is in both
!  the numerator and the denominator.
! 
!  Therefore, the equation for QQ is:
! 
!    QQ(L,I,J) = FRAC * MOISTQ(L,I,J) * AIRDEN(L,I,J) / 1000.0
!      
!  (3) Compute PDOWN, the column precipitation 
!      [cm3 H2O/cm2 air/s], by multiplying QQ(L,I,J) by 
!      BXHEIGHT(I,J,L) * 100 cm.  
! 
!  (4) The reason why we do not force PTEMP to be positive is 
!      that PREACC is the integral of the MOISTQ field.  MOISTQ 
!      contains both negative (evap) and positive (precip) 
!      values.  If we forced PTEMP to be positive, then we would
!      be adding extra precipitation to PDOWN (hyl, bmy, 3/6/99).
!
! !REVISION HISTORY: 
!  29 Feb 2000 - H. Liu, R. Yantosca - Initial version
!  (1 ) Now we partition MOISTQ into large-scale and convective parts, using
!        total precipitation PREACC and convective precipitation PRECON (both
!        are vertical integral amounts). The precipitation field at altitudes
!        (PDOWN) is also made (hyl, djj, 10/17/98).
!  (2 ) MAKE_QQ is written in Fixed-Form Fortran 90. (bmy, 4/2/99)!
!  (3 ) AIRDEN, MOISTQ, QQ, and PDOWN are dimensioned (LLPAR,IIPAR,JJPAR) 
!       in order to maximize loop efficiency when processing an (I,J) 
!       column layer by layer. (bmy, 3/14/00)
!  (4 ) MOISTQ is originally [g H2O/kg air/day], and is converted in
!        READ_A6 to [kg H2O/kg air/s]. (bmy, 3/14/00)
!  (5 ) Now reference PREACC, PRECON from "dao_mod.f" instead of from
!        common block header file "CMN_PRECIP" (bmy, 6/26/00)
!  (6 ) Now pass BXHEIGHT as an argument.  Also added to "dao_mod.f". 
!        (bmy, 6/26/00)
!  (7 ) Moved from "dao_mod.f" to "wetscav_mod.f".  Also made PREACC
!        and PRECON into arguments. (bmy, 10/12/00)
!  (8 ) Updated comments (bmy, 9/4/01)
!  (9 ) BXHEIGHT is now sized (IIPAR,JJPAR,LLPAR) (bmy, 10/4/01)
!  (10) Removed obsolete, commented-out code from 10/01 (bmy, 11/26/01)
!  (11) Now reference met field arrays directly from "dao_mod.f" (bmy, 11/8/02)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!  16 Sep 2010 - R. Yantosca - Compute QQ and PDOWN from MERRA met fields
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER :: I, J, L, AS
      REAL*8  :: PTEMP, FRAC
      LOGICAL :: FIRST = .TRUE.

      !=================================================================
      ! MAKE_QQ begins here!
      !=================================================================
      IF ( FIRST ) THEN

         ! Allocate PDOWN on first call
         ALLOCATE( PDOWN( LLPAR, IIPAR, JJPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'PDOWN' )
         PDOWN = 0d0
      
         ! Allocate QQ on first call
         ALLOCATE( QQ( LLPAR, IIPAR, JJPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'QQ' )
         QQ = 0d0
         
         ! Reset flag
         FIRST = .FALSE.
      ENDIF

      !=================================================================
      ! Loop over surface grid boxes
      !=================================================================
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, FRAC, L, PTEMP )
!$OMP+SCHEDULE( DYNAMIC )
      DO J = 1, JJPAR
      DO I = 1, IIPAR

#if   defined( MERRA )

         !==============================================================
         ! %%%%% FOR MERRA MET FIELDS ONLY %%%%%  
         !==============================================================

         ! Loop over vertical levels
         DO L = 1, LLPAR

            ! Rate of new precipitation formation in grid box (I,J,L)
            ! [cm3 H2O/cm3 air/s]
            QQ(L,I,J)    = ( DQRLSAN(I,J,L)                   )
     &                   * ( AIRDEN(L,I,J)  / 1000d0          )

            ! Column precipitation [cm3 H2O/cm2 air/s]
            PDOWN(L,I,J) = ( ( PFLLSAN(I,J,L) / 1000d0 ) 
     &                   +   ( PFILSAN(I,J,L) /  917d0 ) ) * 100d0

         ENDDO

#else 

         !==============================================================
         ! %%%%% FOR ALL OTHER MET FIELDS EXCEPT MERRA %%%%%
         !==============================================================
         IF ( PREACC(I,J) > 0d0 ) THEN

            ! Large scale or convective fraction of precipitation
            IF ( LS ) THEN
               FRAC = ( PREACC(I,J) - PRECON(I,J) ) / PREACC(I,J) 
            ELSE
               FRAC = PRECON(I,J) / PREACC(I,J)
            ENDIF

            ! Start at the top of the atmosphere
            L = LLPAR

            ! Compute QQ and PDOWN.  Keep PTEMP for the next level
            QQ(L,I,J)    = FRAC * MOISTQ(L,I,J) * AIRDEN(L,I,J) / 1d3
            PTEMP        = QQ(L,I,J) * BXHEIGHT(I,J,L) * 1d2
            PDOWN(L,I,J) = PTEMP

            ! PDOWN cannot be negative
            IF ( PDOWN(L,I,J) < 0d0 ) PDOWN(L,I,J) = 0.d0

            ! Loop down from LLPAR to the surface
            DO L = LLPAR-1, 1, -1
               
               ! Compute QQ and PDOWN.  Keep PTEMP for the next level.
               QQ(L,I,J)    = FRAC * MOISTQ(L,I,J) * AIRDEN(L,I,J) / 1d3
               PDOWN(L,I,J) = PTEMP + QQ(L,I,J) * BXHEIGHT(I,J,L) * 1d2  
               PTEMP        = PDOWN(L,I,J)

               ! PDOWN cannot be negative
               IF ( PDOWN(L,I,J) < 0.0d0 ) PDOWN(L,I,J) = 0.d0
            ENDDO
  
         !==============================================================
         ! If there is no precipitation reaching the surface in the 
         ! (I,J) column, then assume any precipitation at altitude to 
         ! be large-scale.
         ! 
         ! (1) Assume the large scale fraction = 1d0, 
         !                convective fraction  = 0d0
         ! (2) Compute QQ as described above
         ! (3) Compute PDOWN as described above
         !==============================================================
         ELSE

            ! Assume large-scale precipitation!
            IF ( LS ) THEN
               FRAC = 1d0
            ELSE         
               FRAC = 0d0
            ENDIF

            ! Start at the top of the atmosphere
            L = LLPAR

            ! Compute QQ and PDOWN.  Keep PTEMP for the next level
            QQ(L,I,J)    = FRAC * MOISTQ(L,I,J) * AIRDEN(L,I,J) / 1d3
            PTEMP        = QQ(L,I,J) * BXHEIGHT(I,J,L) * 1d2
            PDOWN(L,I,J) = PTEMP
           
            ! PDOWN cannot be negative
            IF( PDOWN(L,I,J) < 0d0 ) PDOWN(L,I,J) = 0.d0

            ! Loop down from LLPAR to the surface
            DO L = LLPAR-1, 1, -1
              
               ! Compute QQ and PDOWN.  Keep PTEMP for the next level
               QQ(L,I,J)    = FRAC * MOISTQ(L,I,J) * AIRDEN(L,I,J) / 1d3
               PDOWN(L,I,J) = PTEMP + QQ(L,I,J) * BXHEIGHT(I,J,L) * 1d2 
               PTEMP        = PDOWN(L,I,J)

               ! PDOWN cannot be negative
               IF ( PDOWN(L,I,J) < 0.0d0 ) PDOWN(L,I,J) = 0.d0
            ENDDO
         ENDIF

#endif

      ENDDO  
      ENDDO
!$OMP END PARALLEL DO

      END SUBROUTINE MAKE_QQ
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: e_ice
!
! !DESCRIPTION: Subroutine E\_ICE computes Eice(T), the saturation vapor 
!  pressure of ice at a given Celsius temperature. 
!\\
!\\
! !INTERFACE:
!
      FUNCTION E_ICE( TK ) RESULT( VALUE )
!
! !INPUT PARAMETERS: 
!
      REAL*8, INTENT(IN) :: TK      ! Temperature [K] 
!
! !RETURN VALUE:
!
      REAL*8             :: VALUE   ! Saturation vapor pressure [hPa]
!
! !REMARKS:
!  Marti & Mauersberber (GRL '93) formulation of saturation 
!  vapor pressure of ice [Pa] is: log P = A/TK + B
! 
! !REVISION HISTORY: 
!  08 Feb 2005 - R. Yantosca - Initial version
!  (1 ) Now use the same analytic function as the Goddard CTM (bmy, 2/8/05)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !DEFINED PARAMETERS:
!
      REAL*8, PARAMETER  :: A = -2663.5d0
      REAL*8, PARAMETER  :: B =  12.537d0

      !=================================================================
      ! E_ICE begins here!
      !=================================================================
      
      ! Saturation vap press of Ice [Pa] -- divide by 100 for [hPa]
      VALUE = ( 10d0**( A/TK + B ) ) / 100d0 

      END FUNCTION E_ICE
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: compute_l2g
!
! !DESCRIPTION: Subroutine COMPUTE\_L2G computes the ratio L2G = Cliq / Cgas, 
!  which is the mixing ratio of tracer in the liquid phase, divided by the 
!  mixing ratio of tracer in the gas phase.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE COMPUTE_L2G( Kstar298, H298_R, TK, H2OLIQ, L2G )
!
! !INPUT PARAMETERS: 
!
      REAL*8, INTENT(IN)  :: KStar298    ! Henry's law constant @ 298 K   
                                         !  [M/atm]
      REAL*8, INTENT(IN)  :: H298_R      ! Molar heat of formation @ 298 K / R 
                                         !  [K]
      REAL*8, INTENT(IN)  :: TK          ! Temperature [K]
      REAL*8, INTENT(IN)  :: H2OLIQ      ! Liquid water content 
                                         !  [cm3 H2O/cm3 air]
!
! !OUTPUT PARAMETERS:
!
      REAL*8, INTENT(OUT) :: L2G         ! Cliq/Cgas ratio for given tracer  
                                         !  [unitless]
!
! !REMARKS:
!  The ratio Cliq / Cgas is obtained via Henry's law.  The appropriate 
!  values of Kstar298 and H298_R must be supplied for each tracer.  
!  (cf Jacob et al 2000, p. 3)
! 
! !REVISION HISTORY: 
!  23 Feb 2000 - R. Yantosca - Initial version
!  (1 ) Bundled into "wetscav_mod.f" (bmy, 11/8/02)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!  10-Jan-2011 - H. Amos - Corrected the units on KStar298 from moles/atm
!                          to M/atm
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      REAL*8              :: Kstar
!
! !DEFINED PARAMETERS:
!
      ! R = universal gas constant [L*atm/mol/K]
      REAL*8, PARAMETER   :: R = 8.32d-2

      ! INV_T0 = 1/298 K
      REAL*8, PARAMETER   :: INV_T0 = 1d0 / 298d0

      !=================================================================
      ! COMPUTE_L2G begins here!
      !=================================================================

      ! Get Kstar, the effective Henry's law constant for temperature TK
      Kstar = Kstar298 * EXP( -H298_R * ( ( 1d0 / TK ) - INV_T0 ) )

      ! Use Henry's Law to get the ratio:
      ! [ mixing ratio in liquid phase / mixing ratio in gas phase ]
      L2G   = Kstar * H2OLIQ * R * TK

      END SUBROUTINE COMPUTE_L2G
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: compute_f 
!
! !DESCRIPTION: Subroutine COMPUTE\_F computes F, the fraction of soluble 
!  tracer lost by scavenging in convective cloud updrafts.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE COMPUTE_F( N, F, ISOL )
!
! !USES:
!
      USE DAO_MOD,      ONLY : BXHEIGHT, T
      USE TRACERID_MOD, ONLY : IDTPB,    IDTBE7,   IDTHNO3, IDTH2O2 
      USE TRACERID_MOD, ONLY : IDTCH2O,  IDTMP,    IDTSO2,  IDTSO4  
      USE TRACERID_MOD, ONLY : IDTSO4s,  IDTSO4aq, IDTMSA,  IDTNH3   
      USE TRACERID_MOD, ONLY : IDTNH4,   IDTNH4aq, IDTNIT,  IDTNITs  
      USE TRACERID_MOD, ONLY : IDTAS,    IDTAHS,   IDTLET,  IDTBCPI 
      USE TRACERID_MOD, ONLY : IDTOCPI,  IDTBCPO,  IDTOCPO, IDTDST1 
      USE TRACERID_MOD, ONLY : IDTDST2,  IDTDST3,  IDTDST4, IDTSALA 
      USE TRACERID_MOD, ONLY : IDTSALC,  IDTALPH,  IDTLIMO, IDTALCO 
      USE TRACERID_MOD, ONLY : IDTSOG1,  IDTSOG2,  IDTSOG3, IDTSOG4
      USE TRACERID_MOD, ONLY : IDTSOA1,  IDTSOA2,  IDTSOA3, IDTSOA4
      USE TRACERID_MOD, ONLY : IS_Hg2,   IS_HgP
      USE TRACERID_MOD, ONLY : IDTGLYX,  IDTMGLY,  IDTGLYC      
      USE TRACERID_MOD, ONLY : IDTSOAG,  IDTSOAM
      USE TRACERID_MOD, ONLY : IDTSOA5,  IDTSOG5
      USE TRACERID_MOD, ONLY : IDTMOBA,  IDTPROPNN
      USE TRACERID_MOD, ONLY : IDTISOPN, IDTMMN
      USE TRACERID_MOD, ONLY : IDTIEPOX, IDTRIP
      USE TRACERID_MOD, ONLY : IDTMAP
      USE OCEAN_MERCURY_MOD,  ONLY : LHg_WETDasHNO3 

#     include "CMN_SIZE"    ! Size parameters
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN)  :: N                      ! Tracer number
!
! !OUTPUT PARAMETERS:
!
      INTEGER, INTENT(OUT) :: ISOL                   ! Index for ND38 diag
      REAL*8,  INTENT(OUT) :: F(IIPAR,JJPAR,LLPAR)   ! Fraction of tracer
                                                     !  scavenged in cloud
                                                     !  updraft [unitless]
!
! !REVISION HISTORY: 
!  23 Feb 2000 - H. Liu, R. Yantosca - Initial version
!  (1 ) Currently works computes scavenging fractions for either full
!        chemistry simulation (NSRCX == 3) or Rn-Pb-Be chemistry simulation
!        (NSRCX == 1).  Set the scavenging fraction to zero for other
!        simulations which do not carry soluble tracers. (bmy, 3/2/00)
!  (2 ) Need to call INIT_SCAV to initialize the Vud, C_H2O, CLDLIQ, 
!        and CLDICE fields once per timestep. (bmy, 2/23/00)
!  (3 ) For aerosols only: now apply Eq. 2 for all temperatures.  Also
!        use the distance between the grid box centers in Eq. 2.  Updated
!        comments and made some cosmetic changes (hyl, bmy, 6/18/01)
!  (4 ) Remove IREF, JREF -- these are obsolete.  T is now dimensioned
!        (IIPAR,JJPAR,LLPAR).  T(IREF,JREF,L) is now T(I,J,L). (bmy, 9/27/01)
!  (5 ) Removed obsolete code from 9/01 (bmy, 10/23/01)
!  (6 ) Fix 2 bugs for aerosol scavenging in Rn-Pb-Be simulation: 
!        (a) set F(:,:,1) = 0 since we don't do any scavenging there.  
!        (b) DO L = 2, LLPAR to avoid any subscript range out of bounds 
!        errors (rjp, hyl, bmy, 1/10/02)
!  (7 ) Now set F=0 in the first level for all tracers.  Also now
!        compute the distance between grid box centers and use that in 
!        in Eq. 10 from Jacob et al, 2000 to compute F. (hyl, bmy, 1/24/02)
!  (8 ) Eliminated obsolete code from 1/02 (bmy, 2/27/02)
!  (9 ) Now reference T from "dao_mod.f" instead of from "CMN".  Also reference
!        BXHEIGHT from "dao_mod.f" instead of from "CMN_NOX".  Now bundled
!        into "wetscav_mod.f".  Now references IDTHNO3, IDTH2O2, etc, from
!        F90 module "tracerid_mod.f".  Added internal routines F_AEROSOL
!        and GET_ISOL.  Rewritten so that we don't duplicate code for 
!        different chemistry simulations. (bmy, 1/17/03)
!  (10) Now compute F for SO2 in the same way for both fullchem and offline 
!        simulations (rjp, bmy, 3/23/03)
!  (11) Added slots for carbon aerosol & dust tracers.  Now modified internal
!        routine GET_ISOL so it's not hardwired anymore. (rjp, bmy, 4/5/04)
!  (12) Added slots for sea salt aerosol tracers (rjp, bec, bmy, 4/20/04)
!  (13) Added slots for secondary organic aerosol tracers (rjp, bmy, 7/13/04)
!  (14) Remove reference to CMN, it's not needed.  Made internal routine
!        F_AEROSOL a module procedure rather than an internal routine to
!        COMPUTE_F in order to facilitate parallelization on the Altix.  Also
!        now pass all arguments explicitly to F_AEROSOL. (bmy, 7/20/04)
!  (15) Now wet scavenge mercury aerosol tracers (eck, bmy, 12/9/04)
!  (16) Updated for AS, AHS, LET, NH4aq, SO4aq.  Also condensed the IF
!        statement by combining branches for aerosols. (cas, bmy, 12/20/04)
!  (17) Updated for SO4s, NITs (bec, bmy, 4/25/05)
!  (18) Now make sure all USE statements are USE, ONLY (bmy, 10/3/05)
!  (19) Bug fix: Now do not over-deplete H2O2s.  Also change Henry's law
!        constant for Hg2 to 1.0d+14. Now use functions IS_Hg2 and IS_HgP to 
!        determine if a tracer is an Hg2 or HgP tagged tracer. 
!        (dkh, rjp, eck, cdh, bmy, 1/6/06)
!  (20) Updated for SOG4 and SOA4 (dkh, bmy, 5/18/06)
!  (21) Bug fix: now use separate conversion factors for H2O2 and NH3.
!        (havala, bmy, 7/26/06)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!  10-Jan-2011 - H.Amos - Changed Hg2 Henry's law constant from 1.0d14 (no 
!                         citation) to 1.4d6 M/atm (HgCl2, Lindqvist & Rhode, 
!                         1985). Henry's law constant in wetscav_mod.f is 
!                         now consistent with what's used in mercury_mod.f
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER              :: I, J, L, NN
      REAL*8               :: L2G, I2G, C_TOT, F_L, F_I, K, TMP, SO2LOSS
!
! !DEFINED PARAMETERS:
!
      ! Kc is the conversion rate from cloud condensate to precip [s^-1]
      REAL*8, PARAMETER    :: KC        = 5d-3

      ! CONV_H2O2 = 0.6 * SQRT( 1.9 ), used for the ice to gas ratio for H2O2
      ! 0.6 is ( sticking  coeff H2O2  / sticking  coeff  water )
      ! 1.9 is ( molecular weight H2O2 / molecular weight water )
      REAL*8, PARAMETER    :: CONV_H2O2 = 8.27042925126d-1

      ! CONV_NH3 = 0.6 * SQRT( 0.9 ), used for the ice to gas ratio for NH3
      ! 0.6 is ( sticking  coeff  NH3 / sticking  coeff  water )
      ! 0.9 is ( molecular weight NH3 / molecular weight water )
      REAL*8, PARAMETER    :: CONV_NH3  = 5.69209978831d-1

      !=================================================================
      ! COMPUTE_F begins here!
      !
      ! For aerosol tracers, compute F with internal routine F_AEROSOL.
      ! ISOL = tracer index for the ND38 diagnostic.
      !=================================================================

      !-------------------------------
      ! 210Pb and 7Be (aerosols)
      !-------------------------------
      IF ( N == IDTPb .or. N == IDTBe7 ) THEN
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! HNO3 (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTHNO3 ) THEN
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N ) 

      !-------------------------------
      ! H2O2 (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTH2O2 ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Start scavenging at level 2
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute ice to gas ratio for H2O2 by co-condensation
            ! (Eq. 9, Jacob et al, 2000)
            IF ( C_H2O(I,J,L) > 0d0 ) THEN 
               I2G = ( CLDICE(I,J,L) / C_H2O(I,J,L) ) * CONV_H2O2
            ELSE
               I2G = 0d0
            ENDIF

            ! Compute liquid to gas ratio for H2O2, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            CALL COMPUTE_L2G( 8.3d4,    -7.4d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of H2O2 in liquid & ice phases
            ! (Eqs. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G + I2G
            F_L   = L2G / C_TOT
            F_I   = I2G / C_TOT

            ! Compute the rate constant K.  The retention factor for 
            ! liquid H2O2 is 0.05 for 248 K < T < 268 K and 1.0 for 
            ! T >= 268 K. (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * ( F_L + F_I )
 
            ELSE IF ( T(I,J,L) > 248d0  .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( ( 5d-2 * F_L ) + F_I ) 

            ELSE
               K = KC * F_I
                  
            ENDIF

            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 
            
            ! Compute F, the fraction of scavenged H2O2.
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO
            
         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! CH2O (liquid phase only)
      !-------------------------------
      ELSE IF ( N == IDTCH2O ) THEN 

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for CH2O, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            CALL COMPUTE_L2G( 3.0d3,    -7.2d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of CH2O in liquid phase 
            ! NOTE: CH2O does not exist in the ice phase!
            ! (Eqs. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  The retention factor 
            ! for liquid CH2O is 0.0 for T <= 248K and 0.02 for 
            ! 248 K < T < 268 K. (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 

            ELSE
               K = 0d0

            ENDIF

            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 
               
            ! F is the fraction of CH2O scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N ) 

      ! Update GLYX and MGLY Henry's Law Const calculations (tmf, 9/13/06)  
      !-------------------------------
      ! GLYX (liquid phase only)
      !-------------------------------
      ELSE IF ( N == IDTGLYX ) THEN 

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for GLYX, using
            ! (1) Zhou and Mopper (1990): Kstar298 = 3.6e5 M/atm 
            ! (2) Schweitzer et al. (1998) showed that the temperature 
            ! dependence for CH2O works well for glyoxal, so we use the 
            ! same H298_R as CH2O
            CALL COMPUTE_L2G( 3.6d5,   -7.2d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of GLYX in liquid phase 
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! assume same retention factor as CH2O
            ! Compute the rate constant K.  The retention factor 
            ! for liquid CH2O is 0.0 for T <= 248K and 0.02 for 
            ! 248 K < T < 268 K. (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 

            ELSE
               K = 0d0

            ENDIF

            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 
               
            ! F is the fraction of GLYX scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N ) 

      !-------------------------------
      ! MGLY (liquid phase only)
      !-------------------------------
      ELSE IF ( N == IDTMGLY ) THEN 

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for MGLY, using
            ! the appropriate parameters for Henry's law
            ! from Betterton and Hoffman 1988): Kstar298 = 3.71d3 M/atm;  
            ! H298_R = -7.5d3 K
            CALL COMPUTE_L2G( 3.7d3,    -7.5d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of MGLY in liquid phase 
            ! NOTE: CH2O does not exist in the ice phase!
            ! (Eqs. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! assume same retention factor as CH2O
            ! Compute the rate constant K.  The retention factor 
            ! for liquid CH2O is 0.0 for T <= 248K and 0.02 for 
            ! 248 K < T < 268 K. (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 

            ELSE
               K = 0d0

            ENDIF

            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 
               
            ! F is the fraction of MGLY scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N ) 

      !-------------------------------
      ! GLYC (liquid phase only)
      !-------------------------------
      ELSE IF ( N == IDTGLYC ) THEN 

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for GLYC, using
            ! the appropriate parameters for Henry's law
            ! from Betterton and Hoffman 1988): 
            ! Kstar298 = 4.1d4 M/atm;  H298_R = -4600 K
            CALL COMPUTE_L2G( 4.1d4,    -4.6d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of MGLY in liquid phase 
            ! NOTE: CH2O does not exist in the ice phase!
            ! (Eqs. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! assume same retention factor as CH2O
            ! Compute the rate constant K.  The retention factor 
            ! for liquid CH2O is 0.0 for T <= 248K and 0.02 for 
            ! 248 K < T < 268 K. (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 

            ELSE
               K = 0d0

            ENDIF

            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 
               
            ! F is the fraction of MGLY scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N ) 

      !-------------------------------
      ! CH3OOH (liquid phase only)
      !-------------------------------
      ELSE IF ( N == IDTMP ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Start scavenging at level 2
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for CH3OOH, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            CALL COMPUTE_L2G( 3.1d2,    -5.2d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of CH3OOH in liquid phase
            ! NOTE: CH3OOH does not exist in the ice phase!
            ! (Eq. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  The retention factor  
            ! for liquid CH3OOH is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of CH3OOH scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N )

      !------------------------------
      ! SO2 (aerosol)
      !------------------------------
      ELSE IF ( N == IDTSO2 ) THEN

         ! Compute fraction of SO2 scavenged
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N )

         !==============================================================
         ! Coupled full chemistry/aerosol simulation:
         ! Use the wet scavenging formula of Chin et al [1996], 
         ! such that a soluble fraction of SO2 is limited by the
         ! availability of H2O2 in the precipitating grid box. 
         ! Scavenge the soluble SO2 at the same rate as the sulfate.
         ! Update H2O2_sav and SO2_sav for use in RAINOUT, WASHOUT
         !==============================================================
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Make sure to deplete H2O2s the same as SO2s. 
            ! (dkh, rjp, bmy, 11/17/05)
            IF ( SO2s(I,J,L) > EPSILON ) THEN
       
               ! Limit F
               SO2LOSS      = MIN( H2O2s(I,J,L), SO2s(I,J,L) )
               F(I,J,L)     = F(I,J,L) * SO2LOSS / SO2s(I,J,L)
               F(I,J,L)     = MAX(F(I,J,L), 0d0)
        
               ! Update saved H2O2 concentration
               H2O2s(I,J,L) = H2O2s(I,J,L) - ( SO2s(I,J,L) * F(I,J,L) )
               H2O2s(I,J,L) = MAX( H2O2s(I,J,L), EPSILON )
        
            ELSE

               ! Set F = 0 if SO2s < EPSILON (dkh, rjp, bmy, 11/17/05) 
               F(I,J,L)     = 0d0
        
            ENDIF

            ! Update SO2
            SO2s(I,J,L)     = SO2s(I,J,L) * ( 1d0 - F(I,J,L) )
            SO2s(I,J,L)     = MAX( SO2s(I,J,L), EPSILON )
              
         ENDDO
         ENDDO
         ENDDO

      !-------------------------------
      ! SO4   (gaseous aerosol) or
      ! SO4aq (aqueous aerosol)
      !-------------------------------
      ELSE IF ( N == IDTSO4 .or. N == IDTSO4s .or. N == IDTSO4aq ) THEN

         CALL F_AEROSOL( KC, F ) 
         ISOL = GET_ISOL( N ) 

      !-------------------------------
      ! MSA (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTMSA ) THEN
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! NH3 (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTNH3 ) THEN
         
         ! No scavenging at surface
         F(:,:,1) = 0d0

         ! Start scavenging at level 2
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute ice to gas ratio for NH3 by co-condensation
            ! (Eq. 9, Jacob et al, 2000)
            IF ( C_H2O(I,J,L) > 0d0 ) THEN 
               I2G = ( CLDICE(I,J,L) / C_H2O(I,J,L) ) * CONV_NH3
            ELSE
               I2G = 0d0
            ENDIF

            ! Compute liquid to gas ratio for NH3, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            CALL COMPUTE_L2G( 3.3d6,    -4.1d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of NH3 in liquid & ice phases
            ! (Eqs. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G + I2G
            F_L   = L2G / C_TOT
            F_I   = I2G / C_TOT

            ! Compute the rate constant K.  The retention factor  
            ! for liquid NH3 is 0.0 for T <= 248 K and 0.05 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * ( F_L + F_I )
                  
            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( ( 5d-2 * F_L ) + F_I )
                  
            ELSE
               K = KC * F_I

            ENDIF
  
            ! F is the fraction of NH3 scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * BXHEIGHT(I,J,L) / Vud(I,J) )
         ENDDO
         ENDDO
         ENDDO
       
         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! NH4   (gaseous aerosol) or
      ! NH4aq (aqueous aerosol)
      !-------------------------------
      ELSE IF ( N == IDTNH4 .or. N == IDTNH4aq ) THEN
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N )
         
      !-------------------------------
      ! NIT / LET / AS / AHS (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTNIT  .or. N == IDTNITs .or.
     &          N == IDTAS   .or. N == IDTAHS  .or. 
     &          N == IDTLET ) THEN 
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! BC HYDROPHILIC (aerosol) or
      ! OC HYDROPHILIC (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTBCPI .or. N == IDTOCPI ) THEN
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! BC HYDROPHOBIC (aerosol) or
      ! OC HYDROPHOBIC (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTBCPO .or. N == IDTOCPO ) THEN

         ! Force not to be lost in convective updraft for now
         F    = 0d0
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! DST1/DST2/DST3/DST4 (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTDST1 .or. N == IDTDST2 .or.
     &          N == IDTDST3 .or. N == IDTDST4 ) THEN
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! Accum  mode seasalt (aerosol)
      ! Coarse mode seasalt (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTSALA .or. N == IDTSALC ) THEN
         CALL F_AEROSOL( KC, F )
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! ALPH (liquid phase only)
      !-------------------------------
      ELSE IF ( N == IDTALPH ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Start scavenging at level 2
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for ALPH, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            CALL COMPUTE_L2G( 0.023d0, 0.d0, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of ALPH in liquid phase
            ! (Eq. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid ALPH is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of ALPH scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ISOL = GET_ISOL( N )

      !-------------------------------
      ! LIMO (liquid phase only)
      !-------------------------------
      ELSE IF ( N == IDTLIMO ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Start scavenging at level 2
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for LIMO, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            CALL COMPUTE_L2G( 0.07d0, 0.d0, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of LIMO in liquid phase
            ! (Eq. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid LIMO is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of LIMO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! ALCO (liquid phase only)
      !-------------------------------
      ELSE IF ( N == IDTALCO ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Start scavenging at level 2
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for ALCO, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            CALL COMPUTE_L2G( 54.d0, 0.d0, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of ALCO in liquid phase
            ! (Eq. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid ALCO is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of ALCO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N )

      !-----------------------------------
      ! SOG[1,2,3,4] (liquid phase only)
      !-----------------------------------
      ! Add SOG5 (dkh, 03/26/07)  
      ! add PMNN assuming it behaves like SOG4 FP_ISOP 10/09
      !ELSE IF ( N == IDTSOG1 .or. N == IDTSOG2  .or. 
      !&          N == IDTSOG3 .or. N == IDTSOG4 ) THEN
      ELSE IF ( N == IDTSOG1 .or. N == IDTSOG2  .or. 
     &          N == IDTSOG3 .or. N == IDTSOG4  .or. 
     &          N == IDTSOG5                     ) THEN


         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Start scavenging at level 2
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for GAS1, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            CALL COMPUTE_L2G( 1.0d5, -6.039d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )

            ! Fraction of GAS1 in liquid phase
            ! (Eq. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid GAS1 is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of GAS1 scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N )

      !------------------------------------------
      ! SOA[1,2,3,4] (aerosol)
      ! Scavenging efficiency for SOA is 0.8
      !------------------------------------------
      ! Add SOA5 (dkh, 03/26/07)  
      !ELSE IF ( N == IDTSOA1 .or. N == IDTSOA2  .or. 
      !&          N == IDTSOA3 .or. N == IDTSOA4 ) THEN
      ELSE IF ( N == IDTSOA1 .or. N == IDTSOA2  .or. 
     &          N == IDTSOA3 .or. N == IDTSOA4  .or. 
     &          N == IDTSOA5                    ) THEN
         CALL F_AEROSOL( KC, F )

         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR
            F(I,J,L) = 0.8d0 * F(I,J,L)
         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N )


      !------------------------------------------
      ! SOAG, SOAM (aerosol)
      ! Scavenging efficiency for SOA is 0.8
      !------------------------------------------
      ELSE IF ( N == IDTSOAG .or. N == IDTSOAM ) THEN
         CALL F_AEROSOL( KC, F )

         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR
            F(I,J,L) = 0.8d0 * F(I,J,L)
         ENDDO
         ENDDO
         ENDDO

         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! Hg2 (liquid phase only)
      !-------------------------------
      ELSE IF ( IS_Hg2( N ) ) THEN
         

         ! Begin CDH Changes (5/20/2009)
         ! Allow user to choose how precip occurs
         IF (LHg_WETDasHNO3) THEN

            ! Assume that all Hg2 is in cloud water (liquid or frozen), 
            ! in analogy to aerosols and HNO3
            CALL F_AEROSOL( KC, F )
            ISOL = GET_ISOL( N ) 

         ELSE

            ! Calculate gas-liquid partitioning from Henry's law
            ! then assume Hg2 is scavenged only by liquid precip

            ! No scavenging at the surface
            F(:,:,1) = 0d0

            ! Apply scavenging in levels 2 and higher
            DO L = 2, LLPAR
            DO J = 1, JJPAR
            DO I = 1, IIPAR

               ! Compute liquid to gas ratio for HgCl2, using
               ! the appropriate parameters for Henry's law
               ! (Refs: INSERT HERE)
               !
!----------------------------------------------------------------------------
! Prior to 1/10/11:
! hma, 10-Jan-2011, Henry's law constant for HgCl2 = 1.4d+6 M/atm
! Ref: Lindqvist and Rhode, 1985
!               CALL COMPUTE_L2G( 1.0d+14, -8.4d3, 
!     &                           T(I,J,L), CLDLIQ(I,J,L), L2G )
!----------------------------------------------------------------------------
               CALL COMPUTE_L2G( 1.4d+6, -8.4d3, 
     &                           T(I,J,L), CLDLIQ(I,J,L), L2G )

               ! Fraction of HgCl2 in liquid phase 
               ! Assume that HgCl2 is not present in ice phase
               ! (Eqs. 4, 5, 6, Jacob et al, 2000)
               C_TOT = 1d0 + L2G
               F_L   = L2G / C_TOT

               ! Compute the rate constant K. 
               !CDH allow scavening during riming (8/7/2009
               !Scavenging at all temperatures
               IF ( T(I,J,L) >= 248d0 ) THEN
                  K = KC * F_L  
               ELSE 
                  K = 0d0
               ENDIF

               ! Distance between grid box centers [m]
               TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 
               
               ! F is the fraction of HgCl2 scavenged out of the updraft
               ! (Eq. 2, Jacob et al, 2000)
               F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

            ENDDO
            ENDDO
            ENDDO

            ! ND38 index
            ISOL = GET_ISOL( N )

         ENDIF
         ! END CDH Changes

      !-------------------------------
      ! HgP (treat like aerosol)
      !-------------------------------
      ELSE IF ( IS_HgP( N ) ) THEN

         CALL F_AEROSOL( KC, F ) 
         ISOL = GET_ISOL( N )

      ! Additional tracers for isoprene
      ! (fp, 06/09)
      !Use temperature of limonene
      !Use numbers of Sander 
      !  (http://www.mpch-mainz.mpg.de/~sander/res/henry.html)
      !-------------------------------
      ! MOBA (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTMOBA ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for LIMO, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
            !FP_ISOP
            !based on methacrylic acid with acetic acid T dependance
            ! pKa = 4.1 - pH=5

            CALL COMPUTE_L2G( 2.3d4, -6.3d3, T(I,J,L), 
     &                          CLDLIQ(I,J,L), L2G )

            ! Fraction of LIMO in liquid phase
            ! (Eq. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid LIMO is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of LIMO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO
            
         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! ISOPN (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTISOPN ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for LIMO, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)


            !FP ISOP : BUG FIX FOR CONSISTENCY WITH DRY DEP MODULE
            !USE ITO NUMBER
            CALL COMPUTE_L2G( 17D3, -9.2d3, T(I,J,L), 
     &                          CLDLIQ(I,J,L), L2G )

            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid LIMO is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of LIMO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO
            
         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! MMN (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTMMN ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for LIMO, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)

            !FP ISOP : BUG FIX FOR CONSISTENCY WITH DRY DEP MODULE
            !USE ITO NUMBER
            CALL COMPUTE_L2G( 17D3, -9.2d3, T(I,J,L), 
     &                          CLDLIQ(I,J,L), L2G )

            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid LIMO is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of LIMO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO
            
         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! PROPNN (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTPROPNN ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            ! Compute liquid to gas ratio for LIMO, using
            ! the appropriate parameters for Henry's law
            ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)

            !NITROOXYACETONE IN SANDER TABLE
            CALL COMPUTE_L2G( 1.0d3, 0.0d0, T(I,J,L), 
     &                          CLDLIQ(I,J,L), L2G )


            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid LIMO is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of LIMO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO
            
         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! RIP (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTRIP ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            CALL COMPUTE_L2G( 8.3d4, -7.4d3, T(I,J,L), !USE H2O2
     &                          CLDLIQ(I,J,L), L2G )

            ! Fraction of LIMO in liquid phase
            ! (Eq. 4, 5, 6, Jacob et al, 2000)
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume retention factor  
            ! for liquid LIMO is 0.0 for T <= 248 K and 0.02 for 
            ! 248 K < T < 268 K.  (Eq. 1, Jacob et al, 2000)
            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of LIMO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO
            
         ! ND38 index
         ISOL = GET_ISOL( N )

      !-------------------------------
      ! MAP (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTMAP ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            CALL COMPUTE_L2G( 8.4d2, -5.3d3, T(I,J,L), !USE H2O2
     &                          CLDLIQ(I,J,L), L2G )

            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of LIMO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO
            
         ! ND38 index
         ISOL = GET_ISOL( N )


      !-------------------------------
      ! IEPOX (liquid & ice phases)
      !-------------------------------
      ELSE IF ( N == IDTIEPOX ) THEN

         ! No scavenging at the surface
         F(:,:,1) = 0d0

         ! Apply scavenging in levels 2 and higher
         DO L = 2, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR

            CALL COMPUTE_L2G( 8.3d4,    -7.4d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )    !USE H2O2

            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            IF ( T(I,J,L) >= 268d0 ) THEN
               K = KC * F_L  

            ELSE IF ( T(I,J,L) > 248d0 .and. T(I,J,L) < 268d0 ) THEN
               K = KC * ( 2d-2 * F_L ) 
                  
            ELSE
               K = 0d0

            ENDIF
               
            ! Distance between grid box centers [m]
            TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 

            ! F is the fraction of LIMO scavenged out of the updraft
            ! (Eq. 2, Jacob et al, 2000)
            F(I,J,L) = 1d0 - EXP( -K * TMP / Vud(I,J) )

         ENDDO
         ENDDO
         ENDDO
            
         ! ND38 index
         ISOL = GET_ISOL( N )

      !----------------------------
      ! Insoluble tracer, set F=0
      !----------------------------
      ELSE
         F(:,:,:) = 0d0
         ISOL     = 0

      ENDIF

      END SUBROUTINE COMPUTE_F
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: f_aerosol
!
! !DESCRIPTION: Subroutine F\_AEROSOL returns the fraction of aerosol 
!  scavenged in updrafts
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE F_AEROSOL( KC, F ) 
!
! !USES:
!
      USE DAO_MOD, ONLY : BXHEIGHT

#     include "CMN_SIZE"   ! Size parameters
!
! !INPUT PARAMETERS: 
!
      ! Conversion rate from cloud condensate to precip [1/s]
      REAL*8, INTENT(IN)  :: KC
!
! !OUTPUT PARAMETERS:
!
      ! Fraction of aerosol scavenged in updrafts [unitless]
      REAL*8, INTENT(OUT) :: F(IIPAR,JJPAR,LLPAR)
! 
! !REVISION HISTORY: 
!  07 Nov 2002 - R. Yantosca - Initial version
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER             :: I, J, L
      REAL*8              :: TMP
     
      !=================================================================
      ! F_AEROSOL begins here!
      !
      ! Aerosol tracers are 100% in the cloud condensate phase, so 
      ! we set K = Kc, and compute F accordingly (cf Jacob et al 2000 )    
      !=================================================================
      
      ! Turn off scavenging in the first level by setting F = 0
      F(:,:,1) = 0d0
 
      ! Apply scavenging in levels 2 and higher
      DO L = 2, LLPAR
      DO J = 1, JJPAR
      DO I = 1, IIPAR
                
         ! Distance between grid box centers [m]
         TMP = 0.5d0 * ( BXHEIGHT(I,J,L-1) + BXHEIGHT(I,J,L) ) 
       
         ! (Eq. 2, Jacob et al, 2000, with K = Kc)
         F(I,J,L) = 1d0 - EXP( -KC * TMP / Vud(I,J) )
            
      ENDDO
      ENDDO
      ENDDO

      END SUBROUTINE F_AEROSOL 
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_isol
!
! !DESCRIPTION: Function GET\_ISOL returns the value of ISOL (tracer index for 
!  ND38) for all simulation types.
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_ISOL( N_TEST ) RESULT( VALUE )
!
! !USES:
!
      USE TRACER_MOD, ONLY : N_TRACERS

#     include "CMN_SIZE"               ! Size parameters
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN) :: N_TEST    ! Tracer number to look up
!
! !RETURN VALUE:
!
      INTEGER             :: VALUE     ! Index for ND38 diagnostic

!
! !REVISION HISTORY: 
!  05 Apr 2004 - R. Yantosca - Initial version
!  (1 ) Now initializes a lookup table for faster execution.  Now made into
!        an EXTERNAL function. (rjp, bmy, 4/5/04)
!  (2 ) Now references N_TRACERS from "tracer_mod.f" (bmy, 7/20/04)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      LOGICAL, SAVE :: FIRST = .TRUE.
      INTEGER, SAVE :: NSOL_INDEX(NNPAR)
      INTEGER       :: I, L, N

      !=================================================================
      ! GET_ISOL begins here!
      !=================================================================

      ! Initialize lookup table on the first call
      IF ( FIRST ) THEN
      
         ! Initialize
         NSOL_INDEX(:) = 0
   
         ! Loop over tracers
         DO N = 1, N_TRACERS
            
            ! Loop over soluble tracers
            DO L = 1, NSOL

               ! Test if tracer N is among the soluble tracers
               IF ( IDWETD(L) == N ) THEN

                  ! Save location into the lookup table
                  NSOL_INDEX(N) = L 

                  !Go to next N
                  EXIT
               ENDIF
            ENDDO
         ENDDO

         ! Reset first-time flag
         FIRST = .FALSE.
      ENDIF

      ! Return value
      VALUE = NSOL_INDEX(N_TEST)

      END FUNCTION GET_ISOL
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: rainout
!
! !DESCRIPTION: Subroutine RAINOUT computes RAINFRAC, the fraction of soluble 
!  tracer lost to rainout events in precipitation.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE RAINOUT( I, J, L, N, K_RAIN, DT, F, RAINFRAC )
!
! !USES:
!
      USE DAO_MOD,      ONLY : T
      USE ERROR_MOD,    ONLY : ERROR_STOP
      USE TRACERID_MOD, ONLY : IDTPB,   IDTBE7,   IDTHNO3, IDTH2O2 
      USE TRACERID_MOD, ONLY : IDTCH2O, IDTMP,    IDTSO2,  IDTSO4  
      USE TRACERID_MOD, ONLY : IDTSO4s, IDTSO4aq, IDTMSA,  IDTNH3   
      USE TRACERID_MOD, ONLY : IDTNH4,  IDTNH4aq, IDTNIT,  IDTNITs  
      USE TRACERID_MOD, ONLY : IDTAS,   IDTAHS,   IDTLET,  IDTBCPI 
      USE TRACERID_MOD, ONLY : IDTOCPI, IDTBCPO,  IDTOCPO, IDTDST1 
      USE TRACERID_MOD, ONLY : IDTDST2, IDTDST3,  IDTDST4, IDTSALA 
      USE TRACERID_MOD, ONLY : IDTSALC, IDTALPH,  IDTLIMO, IDTALCO 
      USE TRACERID_MOD, ONLY : IDTSOG1, IDTSOG2,  IDTSOG3, IDTSOG4
      USE TRACERID_MOD, ONLY : IDTSOA1, IDTSOA2,  IDTSOA3, IDTSOA4
      USE TRACERID_MOD, ONLY : IDTSOA5, IDTSOG5
      USE TRACERID_MOD, ONLY : IS_Hg2,  IS_HgP
      USE TRACERID_MOD, ONLY : IDTGLYX, IDTMGLY,  IDTGLYC
      USE TRACERID_MOD, ONLY : IDTSOAG, IDTSOAM
      USE TRACERID_MOD, ONLY : IDTMOBA,  IDTPROPNN
      USE TRACERID_MOD, ONLY : IDTISOPN, IDTMMN
      USE TRACERID_MOD, ONLY : IDTIEPOX, IDTRIP, IDTMAP
      USE TRACER_MOD,   ONLY : ITS_A_MERCURY_SIM 
      USE OCEAN_MERCURY_MOD,  ONLY : LHg_WETDasHNO3

#     include "CMN_SIZE"   ! Size parameters
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN)  :: I          ! Longitude index
      INTEGER, INTENT(IN)  :: J          ! Latitude index
      INTEGER, INTENT(IN)  :: L          ! Level index
      INTEGER, INTENT(IN)  :: N          ! Tracer number
      REAL*8,  INTENT(IN)  :: K_RAIN     ! Rainout rate constant [1/s]
      REAL*8,  INTENT(IN)  :: DT         ! Timestep for rainout event [s]
      REAL*8,  INTENT(IN)  :: F          ! Fraction of grid box that is
                                         !  precipitating [unitless]
!
! !OUTPUT PARAMETERS:
!
      REAL*8,  INTENT(OUT) :: RAINFRAC   ! Fraction of tracer lost 
                                         !  to rainout [unitless]
! 
! !REVISION HISTORY: 
!  28 Feb 2000 - R. Yantosca - Initial version
!  (1 ) Currently works for either full chemistry simulation (NSRCX == 3) 
!        or Rn-Pb-Be chemistry simulation (NSRCX == 1).  Other simulations
!        do not carry soluble tracer, so set RAINFRAC = 0. (bmy, 2/28/00)
!  (2 ) Need to call INIT_SCAV to initialize the Vud, C_H2O, CLDLIQ, 
!        and CLDICE fields once per dynamic timestep. (bmy, 2/28/00)
!  (3 ) K_RAIN, the rainout rate constant, and F, the areal fraction of the 
!        grid box undergoing precipitiation, are computed according to 
!        Giorgi & Chaimedes, as described in Jacob et al, 2000.
!  (4 ) Now no longer suppress scavenging of HNO3 and aerosol below 258K.
!        Updated comments, cosmetic changes.  Now set TK = T(I,J,L) since
!        T is now sized (IIPAR,JJPAR,LLPAR) in "CMN". (djj, hyl, bmy, 1/24/02)
!  (5 ) Eliminated obsolete code (bmy, 2/27/02)
!  (6 ) Now reference T from "dao_mod.f".  Updated comments.  Now bundled 
!        into "wetscav_mod.f". Now refererences "tracerid_mod.f".  Also 
!        removed reference to CMN since we don't need NSRCX. (bmy, 11/8/02)
!  (7 ) Now updated for carbon & dust aerosol tracers (rjp, bmy, 4/5/04)
!  (8 ) Now updated for seasalt aerosol tracers (rjp, bec, bmy, 4/20/04)
!  (9 ) Now updated for secondary aerosol tracers (rjp, bmy, 7/13/04)
!  (10) Now treat rainout of mercury aerosol tracers (eck, bmy, 12/9/04)
!  (11) Updated for AS, AHS, LET, NH4aq, SO4aq.  Also condensed the IF
!        statement by grouping blocks together. (cas, bmy, 12/20/04)
!  (12) Updated for SO4s, NITs (bec, bmy, 4/25/05)
!  (13) Now make sure all USE statements are USE, ONLY (bmy, 10/3/05)
!  (14) Change Henry's law constant for Hg2 to 1.0d+14.  Now use functions
!        IS_Hg2 and IS_HgP to determine if the tracer is a tagged Hg0 or
!        HgP tracer. (eck, cdh, bmy, 1/6/06)
!  (15) Updated for SOG4 and SOA4 (dkh, bmy, 5/18/06)
!  (16) For GEOS-5, suppress rainout when T < 258K (hyl, bmy, 3/5/08)
!  (17) Bug fix: need to use separate conversion parameters for H2O2 and
!        NH3.  This was the same fix as in COMPUTE_F but until now we had
!        overlooked this. (havala, bmy, 7/20/09)
!  25 Aug 2010 - R. Yantosca - Treat MERRA in the same way as GEOS-5
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      REAL*8            :: L2G, I2G, C_TOT, F_L, F_I, K, TK, SO2LOSS
!
! !DEFINED PARAMETERS:
!
      ! CONV_H2O2 = 0.6 * SQRT( 1.9 ), used for the ice to gas ratio for H2O2
      ! 0.6 is ( sticking  coeff H2O2  / sticking  coeff  water )
      ! 1.9 is ( molecular weight H2O2 / molecular weight water )
      REAL*8, PARAMETER :: CONV_H2O2 = 8.27042925126d-1

      ! CONV_NH3 = 0.6 * SQRT( 0.9 ), used for the ice to gas ratio for NH3
      ! 0.6 is ( sticking  coeff  NH3 / sticking  coeff  water )
      ! 0.9 is ( molecular weight NH3 / molecular weight water )
      REAL*8, PARAMETER :: CONV_NH3  = 5.69209978831d-1

      !==================================================================
      ! RAINOUT begins here!
      !
      ! For aerosols, set K = K_RAIN and compute RAINFRAC according
      ! to Eq. 10 of Jacob et al 2000.  Call function GET_RAINFRAC.
      !==================================================================

      ! Save the local temperature in TK for convenience
      TK = T(I,J,L)

#if   defined( GEOS_5 ) || defined( MERRA )
      !------------------------------------------------------------------
      ! NOTE FROM HONGYU LIU (hyl@nianet.org) -- 3/5/08
      !
      ! Lead-210 (210Pb) and Beryllium-7 (7Be) simulations indicate 
      ! that we can improve the GEOS-5 simulation by (1) turning off
      ! rainout/washout for convective precip (see DO_WETDEP) 
      ! and (2) suppressing rainout for large-scale precip at  
      ! temperatures below 258K.
      !
      ! Place an #if block here to set RAINFRAC=0 when T < 258K for 
      ! GEOS-5 met.  This will suppress rainout. (hyl, bmy, 3/5/08)
      !
      ! Allow scavenging at cold temperatures for Hg simulation,
      ! except when we want to use Selin (2007) scheme (LHg_WETDasHNO3=FALSE
      ! (cdh, 4/16/09, 5/20/09)
      !-------------------------------------------------------------------   
! CDH 8/7/2009, 10/27/2009. All temperature dependence for Hg handled below
      IF ( TK < 258d0 .AND. (.NOT. ITS_A_MERCURY_SIM() ) ) THEN
         RAINFRAC = 0d0
         RETURN
      ENDIF
#endif

      !------------------------------
      ! 210Pb and 7Be (aerosol)
      !------------------------------
      IF ( N == IDTPb .or. N == IDTBe7 ) THEN 
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )
         
      !------------------------------
      ! HNO3 (aerosol)
      !------------------------------
      ELSE IF ( N == IDTHNO3 ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

      !------------------------------
      ! H2O2 (liquid & ice phases)
      !------------------------------
      ELSE IF ( N == IDTH2O2 ) THEN

         ! Compute ice to gas ratio for H2O2 by co-condensation
         ! (Eq. 9, Jacob et al, 2000)
         IF ( C_H2O(I,J,L) > 0d0 ) THEN 
            I2G = ( CLDICE(I,J,L) / C_H2O(I,J,L) ) * CONV_H2O2
         ELSE
            I2G = 0d0
         ENDIF

         ! Compute liquid to gas ratio for H2O2, using
         ! the appropriate parameters for Henry's law
         ! (Eqs. 7, 8 and Table 1, Jacob et al, 2000)
         CALL COMPUTE_L2G( 8.3d4, -7.4d3, TK, CLDLIQ(I,J,L), L2G )

         ! Fraction of H2O2 in liquid & ice phases
         ! (Eqs. 4, 5, 6, Jacob et al, 2000)
         C_TOT = 1d0 + L2G + I2G
         F_L   = L2G / C_TOT
         F_I   = I2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid H2O2 is 0.05 for 248 K < T < 268 K, and 
         ! 1.0 for T >= 268 K.  (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * ( F_L + F_I ) 
               
         ELSE IF ( TK > 248d0  .and. TK < 268d0 ) THEN
            K = K_RAIN * ( ( 5d-2 * F_L ) + F_I ) 

         ELSE 
            K = K_RAIN * F_I

         ENDIF

         ! Compute RAINFRAC, the fraction of rained-out H2O2
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      !------------------------------
      ! CH2O (liquid phase only)
      !------------------------------     
      ELSE IF ( N == IDTCH2O ) THEN 
                  
         ! Compute liquid to gas ratio for CH2O, using
         ! the appropriate parameters for Henry's law
         ! (Eqs. 7, 8 and Table 1, Jacob et al, 2000)
         CALL COMPUTE_L2G( 3.0d3, -7.2d3, TK, CLDLIQ(I,J,L), L2G )
            
         ! Fraction of CH2O in liquid phase 
         ! NOTE: CH2O does not exist in the ice phase!
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH2O is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L 

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )
               
         ELSE
            K = 0d0

         ENDIF

         ! Compute RAINFRAC, the fraction of rained-out CH2O
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      ! Update GLYX and MGLY Henry's Law Const calculations (tmf, 9/13/06) 
      !------------------------------
      ! GLYX (liquid phase only)
      !------------------------------     
      ELSE IF ( N == IDTGLYX ) THEN 

         ! Compute liquid to gas ratio for GLYX, using
         ! (1) Zhou and Mopper (1990): Kstar298 = 3.6e5 M/atm 
         ! (2) Schweitzer et al. (1998) showed that the temperature dependence 
         ! for CH2O works well for glyoxal, so we use the same H298_R as CH2O
         CALL COMPUTE_L2G( 3.6d5,   -7.2d3, 
     &                     T(I,J,L), CLDLIQ(I,J,L), L2G )

         ! Fraction of GLYX in liquid phase 
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! assume same retention factor as CH2O
         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH2O is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L 

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )
               
         ELSE
            K = 0d0

         ENDIF

         ! Compute RAINFRAC, the fraction of rained-out GLYX
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      !------------------------------
      ! MGLY (liquid phase only)
      !------------------------------     
      ELSE IF ( N == IDTMGLY ) THEN 

         ! Compute liquid to gas ratio for MGLY, using
         ! the appropriate parameters for Henry's law
         ! from Betterton and Hoffman 1988): 
         ! Kstar298 = 3.71d3 M/atm;  H298_R = -7.5d3 K
         CALL COMPUTE_L2G( 3.7d3,    -7.5d3, 
     &                     T(I,J,L), CLDLIQ(I,J,L), L2G )

            
         ! Fraction of MGLY in liquid phase 
         ! NOTE: CH2O does not exist in the ice phase!
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! assume same retention factor as CH2O
         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH2O is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L 

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )
               
         ELSE
            K = 0d0

         ENDIF

         ! Compute RAINFRAC, the fraction of rained-out MGLY
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      !------------------------------
      ! GLYC (liquid phase only)
      !------------------------------     
      ELSE IF ( N == IDTGLYC ) THEN 

         ! Compute liquid to gas ratio for GLYC, using
         ! the appropriate parameters for Henry's law
         ! from Betterton and Hoffman 1988): 
         ! Kstar298 = 4.1d4 M/atm;  H298_R = -4.6d3 K
         CALL COMPUTE_L2G( 4.1d4,    -4.6d3, 
     &                     T(I,J,L), CLDLIQ(I,J,L), L2G )

            
         ! Fraction of GLYC in liquid phase 
         ! NOTE: CH2O does not exist in the ice phase!
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! assume same retention factor as CH2O
         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH2O is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L 

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )
               
         ELSE
            K = 0d0

         ENDIF

         ! Compute RAINFRAC, the fraction of rained-out MGLY
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

  
      !------------------------------
      ! CH3OOH (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTMP ) THEN

         ! Compute liquid to gas ratio for CH3OOH, using
         ! the appropriate parameters for Henry's law
         ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
         CALL COMPUTE_L2G( 3.1d2, -5.2d3, TK, CLDLIQ(I,J,L), L2G )

         ! Fraction of CH3OOH in liquid phase
         ! NOTE: CH3OOH does not exist in the ice phase!
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH3OOH is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L  

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )  
            
         ELSE
            K = 0d0
               
         ENDIF
  
         ! Compute RAINFRAC, the fraction of rained-out CH3OOH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT ) 

      !!!!!!!!!
      !FP_ISOP!
      !!!!!!!!!

      !------------------------------
      ! MOBA (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTMOBA ) THEN
         
         !based on methacrylic acid
         CALL COMPUTE_L2G( 2.3d4, -6.3d3, TK, CLDLIQ(I,J,L), L2G )

         ! Fraction of methacrylic acid in liquid phase
         ! Assume: methacrylic acid does not exist in the ice phase!
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH3OOH is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L  

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )  
            
         ELSE
            K = 0d0
               
         ENDIF
  
         ! Compute RAINFRAC, the fraction of rained-out CH3OOH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT ) 

      !------------------------------
      ! ISOPN (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTISOPN ) THEN

         !Based on 2-pentyl nitrate

         CALL COMPUTE_L2G( 17D3, -9.2d3, TK, CLDLIQ(I,J,L), L2G )

         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH3OOH is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L  

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )  
            
         ELSE
            K = 0d0
               
         ENDIF
  
         ! Compute RAINFRAC, the fraction of rained-out CH3OOH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT ) 

      !------------------------------
      ! MMN (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTMMN ) THEN

         !Ito 2007
         CALL COMPUTE_L2G( 17d3, -9.2d3, TK, CLDLIQ(I,J,L), L2G )


         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH3OOH is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L  

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )  
            
         ELSE
            K = 0d0
               
         ENDIF
  
         ! Compute RAINFRAC, the fraction of rained-out CH3OOH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT ) 

      !------------------------------
      ! PROPNN (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTPROPNN ) THEN

         CALL COMPUTE_L2G( 1.0d3, 0.0d0, TK, CLDLIQ(I,J,L), L2G )


         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH3OOH is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L  

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )  
            
         ELSE
            K = 0d0
               
         ENDIF
  
         ! Compute RAINFRAC, the fraction of rained-out CH3OOH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT ) 

      !------------------------------
      ! RIP
      !------------------------------
      ELSE IF ( N == IDTRIP ) THEN

         !USE H2O2 
         CALL COMPUTE_L2G( 8.3d4, -7.4d3, T(I,J,L),CLDLIQ(I,J,L), L2G )

         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH3OOH is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L  

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )  
            
         ELSE
            K = 0d0
               
         ENDIF
  
         ! Compute RAINFRAC, the fraction of rained-out CH3OOH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT ) 

      !------------------------------
      ! MAP
      !------------------------------
      ELSE IF ( N == IDTMAP ) THEN

         !USE H2O2 
         CALL COMPUTE_L2G( 8.4d2, -5.3d3, T(I,J,L),CLDLIQ(I,J,L), L2G )

         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH3OOH is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L  

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )  
            
         ELSE
            K = 0d0
               
         ENDIF
  
         ! Compute RAINFRAC, the fraction of rained-out CH3OOH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT ) 

      !------------------------------
      ! IEPOX
      !------------------------------
      ELSE IF ( N == IDTIEPOX ) THEN

         !USE H2O2 
         CALL COMPUTE_L2G( 8.3d4, -7.4d3, TK, CLDLIQ(I,J,L), L2G )


         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid CH3OOH is 0.02 for 248 K < T < 268 K, and 
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L  

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )  
            
         ELSE
            K = 0d0
               
         ENDIF
  
         ! Compute RAINFRAC, the fraction of rained-out CH3OOH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT ) 

      !!!!! end FP additional tracers for ISOP (6/2009)

      !------------------------------
      ! SO2
      !------------------------------
      ELSE IF ( N == IDTSO2 ) THEN

         !==============================================================
         ! NOTE: SO2 and H2O2 are in [v/v] and here RAINFRAC contains 
         ! the amount of SO2 lost due to rainout normalized by the
         ! total SO2 -- so that in WETDEP routine mulitiplying SO2 in 
         ! [kg] will produce correct amount.  Need to verify this. 
         ! (rjp, 01/16/02)
         !==============================================================

         ! Treat SO2 as an aerosol
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

         ! Update SO2 and H2O2
         IF ( SO2s(I,J,L) > EPSILON ) THEN 
         
            ! Limit RAINFRAC 
            SO2LOSS      = MIN( SO2s(I,J,L), H2O2s(I,J,L) )
            RAINFRAC     = SO2LOSS * RAINFRAC / SO2s(I,J,L)
            RAINFRAC     = MAX( RAINFRAC, 0d0 )
         
            ! Update saved H2O2 concentration
            H2O2s(I,J,L) = H2O2s(I,J,L) - ( SO2s(I,J,L) * RAINFRAC )
            H2O2s(I,J,L) = MAX( H2O2s(I,J,L), EPSILON )
         
         ELSE
            RAINFRAC = 0D0
         
         ENDIF
         
         ! Update saved SO2 concentration
         SO2s(I,J,L) = SO2s(I,J,L) * ( 1.D0 - RAINFRAC )
         SO2s(I,J,L) = MAX( SO2s(I,J,L), EPSILON )         

      !----------------------------
      ! SO4 and SO4aq (aerosol)
      !----------------------------
      ELSE IF ( N == IDTSO4 .or. N == IDTSO4s .or. N == IDTSO4aq ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

      !------------------------------
      ! MSA (aerosol)
      !------------------------------
      ELSE IF ( N == IDTMSA ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

      !------------------------------
      ! NH3 (liquid & ice phases)
      !------------------------------
      ELSE IF ( N == IDTNH3 ) THEN

         ! Compute ice to gas ratio for NH3 by co-condensation
         ! (Eq. 9, Jacob et al, 2000)
         IF ( C_H2O(I,J,L) > 0d0 ) THEN 
            I2G = ( CLDICE(I,J,L) / C_H2O(I,J,L) ) * CONV_NH3
         ELSE
            I2G = 0d0
         ENDIF
                  
         ! Compute liquid to gas ratio for NH3, using
         ! the appropriate parameters for Henry's law
         ! (Seinfeld and Pandis, p343 eq. 6.8)
         ! PH    = 4.5  ! Assumed PH for typical cloud drop
         ! Hstar = 1.054d11 * (10.**(-PH)) == 3.3d6
         CALL COMPUTE_L2G( 3.3d6, -4.1d3, TK, CLDLIQ(I,J,L), L2G )

         ! Fraction of NH3 in liquid & ice phases
         ! (Eqs. 4, 5, 6, Jacob et al, 2000)
         C_TOT = 1d0 + L2G + I2G
         F_L   = L2G / C_TOT
         F_I   = I2G / C_TOT

         ! Compute the rate constant K.  The retention factor  
         ! for liquid NH3 is 0.05 for 248 K < T < 268 K, and 
         ! 1.0 for T >= 268 K.  (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * ( F_L + F_I ) 

         ELSE IF ( TK > 248d0  .and. TK < 268d0 ) THEN
            K = K_RAIN * ( ( 5d-2 * F_L ) + F_I ) 

         ELSE 
            K = K_RAIN * F_I

         ENDIF

         ! Compute RAINFRAC, the fraction of rained-out NH3
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      !------------------------------
      ! NH4 and NH4aq (aerosol)
      !------------------------------
      ELSE IF ( N == IDTNH4 .or. N == IDTNH4aq ) THEN

         ! NOTE: NH4aq may have a henry's law constant; 
         !       Carine will investigate (cas, bmy, 12/20/04)
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

      !------------------------------
      ! NIT/AS/AHS/LET (aerosol)
      !------------------------------
      ELSE IF ( N == IDTNIT .or. N == IDTNITs .or.
     &          N == IDTAS  .or. N == IDTAHS  .or. 
     &          N == IDTLET ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

      !------------------------------
      ! BC HYDROPHILIC (aerosol) or
      ! OC HYDROPHILIC (aerosol)
      !------------------------------
      ELSE IF ( N == IDTBCPI .or. N == IDTOCPI) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

      !-------------------------------
      ! BC HYDROPHOBIC (aerosol) or
      ! OC HYDROPHOBIC (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTBCPO .or. N == IDTOCPO ) THEN

         ! No rainout 
         RAINFRAC = 0.0D0                  

      !-------------------------------
      ! DUST all size bins (aerosol)
      !-------------------------------
      ELSE IF ( N == IDTDST1 .or. N == IDTDST2 .or.
     &          N == IDTDST3 .or. N == IDTDST4 ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

      !------------------------------
      ! Accum  seasalt (aerosol) or
      ! Coarse seasalt (aerosol)
      !------------------------------
      ELSE IF ( N == IDTSALA .or. N == IDTSALC ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )      

      !------------------------------
      ! ALPH (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTALPH ) THEN

         ! Compute liquid to gas ratio for ALPH, using
         ! the appropriate parameters for Henry's law
         ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
         CALL COMPUTE_L2G( 0.023d0, 0.d0, TK, CLDLIQ(I,J,L), L2G )

         ! Fraction of ALPH in liquid phase
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  Assume that the retention factor
         ! for liquid ALPH is 0.02 for 248 K < T < 268 K, and
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )

         ELSE
            K = 0d0

         ENDIF
 
         ! Compute RAINFRAC, the fraction of rained-out ALPH
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      !------------------------------
      ! LIMO (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTLIMO ) THEN

         ! Compute liquid to gas ratio for LIMO, using
         ! the appropriate parameters for Henry's law
         ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
         CALL COMPUTE_L2G( 0.07d0, 0.d0, TK, CLDLIQ(I,J,L), L2G )

         ! Fraction of LIMO in liquid phase
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  Assume that the retention factor
         ! for liquid LIMO is 0.02 for 248 K < T < 268 K, and
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )

         ELSE
            K = 0d0

         ENDIF

         ! Compute RAINFRAC, the fraction of rained-out LIMO
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      !------------------------------
      ! ALCO (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTALCO ) THEN

         ! Compute liquid to gas ratio for ALCO, using
         ! the appropriate parameters for Henry's law
         ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
         CALL COMPUTE_L2G( 54.d0, 0.d0, TK, CLDLIQ(I,J,L), L2G )

         ! Fraction of ALCO in liquid phase
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  Assume that the retention factor
         ! for liquid ALCO is 0.02 for 248 K < T < 268 K, and
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )

         ELSE
            K = 0d0

         ENDIF

         ! Compute RAINFRAC, the fraction of rained-out ALCO
         ! (Eq. 10, Jacob et al, 2000)   
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      !----------------------------------
      ! SOG[1,2,3,4,5] (liquid phase only)
      !----------------------------------
      ELSE IF ( N == IDTSOG1 .or. N == IDTSOG2  .or. 
     &          N == IDTSOG3 .or. N == IDTSOG4  .or. 
     &          N == IDTSOG5                    ) THEN  

         ! Compute liquid to gas ratio for GAS1, using
         ! the appropriate parameters for Henry's law
         ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
         CALL COMPUTE_L2G( 1.0d5, -6.039d3, TK, CLDLIQ(I,J,L), L2G )

         ! Fraction of GAS1 in liquid phase
         ! (Eqs. 4, 5, Jacob et al, 2000)
         C_TOT = 1d0 + L2G
         F_L   = L2G / C_TOT

         ! Compute the rate constant K.  Assume that the retention factor
         ! for liquid GAS1 is 0.02 for 248 K < T < 268 K, and
         ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
         IF ( TK >= 268d0 ) THEN
            K = K_RAIN * F_L

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            K = K_RAIN * ( 2d-2 * F_L )

         ELSE
            K = 0d0

         ENDIF
 
         ! Compute RAINFRAC, the fraction of rained-out SOG{1,2,3}
         ! (Eq. 10, Jacob et al, 2000)
         RAINFRAC = GET_RAINFRAC( K, F, DT )

      !--------------------------------------
      ! SOA[1,2,3,4,5] (aerosol)
      ! Scavenging efficiency for SOA is 0.8
      !--------------------------------------
      ELSE IF ( N == IDTSOA1 .or. N == IDTSOA2  .or. 
     &          N == IDTSOA3 .or. N == IDTSOA4  .or. 
     &          N == IDTSOA5                    ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )
         RAINFRAC = RAINFRAC * 0.8d0

      !--------------------------------------
      ! SOAG and SOAM (aerosol)
      ! Scavenging efficiency for SOA is 0.8
      !--------------------------------------
      ELSE IF ( N == IDTSOAG .OR. N == IDTSOAM ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )
         RAINFRAC = RAINFRAC * 0.8d0

      !------------------------------
      ! Hg2 (liquid phase only)
      !------------------------------
      ELSE IF ( IS_Hg2( N ) ) THEN 

         ! Begin CDH Changes (5/20/2009)
         ! Allow user to choose how precip occurs
         IF (LHg_WETDasHNO3) THEN
            
            ! Assume that all Hg2 is in cloud water (liquid or frozen), 
            ! in analogy to aerosols and HNO3
            RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

         ELSE

            ! Compute liquid to gas ratio for HgCl2, using
            ! the appropriate parameters for Henry's law
            ! (Refs: INSERT HERE)
!---------------------------------------------------------------------------
! Prior to 1/10/11:
! hma, 10-Jan-2011, Henry's law constant for HgCl2 = 1.4d+6 M/atm for 
! HgCl2 (Lindqvist and Rodhe, 1985)
!           CALL COMPUTE_L2G( 1.0d+14, -8.4d3, 
!     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )
!---------------------------------------------------------------------------
           CALL COMPUTE_L2G( 1.4d+6, -8.4d3, 
     &                        T(I,J,L), CLDLIQ(I,J,L), L2G )
         
            ! Fraction of HgCl2 in liquid phase
            ! Assume no HgCl2 in the ice phase
            C_TOT = 1d0 + L2G
            F_L   = L2G / C_TOT

            ! Compute the rate constant K.  Assume the retention factor  
            ! for liquid HgCl2 is 0 for T < 268 K, and 
            ! 1.0 for T > 268 K. (Eq. 1, Jacob et al, 2000)
            IF ( TK >= 248d0 ) THEN
               K = K_RAIN * F_L  
            ELSE
               K = 0d0               
            ENDIF
  
            ! Compute RAINFRAC, the fraction of rained-out HgCl2
            ! (Eq. 10, Jacob et al, 2000)
            RAINFRAC = GET_RAINFRAC( K, F, DT ) 

         ENDIF
         ! END CDH Changes

      !------------------------------
      ! HgP (treat like aerosol)
      !------------------------------
      ELSE IF ( IS_HgP( N ) ) THEN
         RAINFRAC = GET_RAINFRAC( K_RAIN, F, DT )

         ! CDH 9/28/2009
!         IF ( TK < 248d0 ) RAINFRAC = 0d0

      !------------------------------
      ! ERROR: insoluble tracer!
      !------------------------------
      ELSE
         CALL ERROR_STOP( 'Invalid tracer!', 'RAINOUT (wetscav_mod.f)' )

      ENDIF
      
      END SUBROUTINE RAINOUT
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_rainfrac
!
! !DESCRIPTION: Function GET\_RAINFRAC computes the fraction of tracer 
!  lost to rainout according to Jacob et al 2000.
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_RAINFRAC( K, F, DT ) RESULT( RAINFRAC )
!
! !INPUT PARAMETERS: 
!
      REAL*8, INTENT(IN) :: K          ! Rainout rate constant [1/s]
      REAL*8, INTENT(IN) :: F          ! Timestep for rainout event [s]
      REAL*8, INTENT(IN) :: DT         ! Fraction of grid box that is
                                       !  undergoing precipitation [unitless]
!
! !RETURN VALUE:
!
      REAL*8             :: RAINFRAC   ! Fraction of tracer lost to rainout
!
! !REVISION HISTORY: 
!  08 Nov 2002 - R. Yantosca - Initial version
!  (1 ) Now move internal routines GET_RAINFRAC to the module and pass all 
!        arguments explicitly.  This facilitates parallelization on the 
!        Altix platform (bmy, 7/20/04) 
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! GET_RAINFRAC begins here!
      !=================================================================

      ! (Eq. 10, Jacob et al, 2000 ) 
      RAINFRAC = F * ( 1 - EXP( -K * DT ) )

      END FUNCTION GET_RAINFRAC
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: washout
!
! !DESCRIPTION: Subroutine WASHOUT computes WASHFRAC, the fraction of 
!  soluble tracer lost to washout events in precipitation.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE WASHOUT( L,  N, BXHEIGHT, TK,   PP, 
     &                    DT, F, H2O2s,    SO2s, WASHFRAC, AER )
!
! !USES:
!
      USE ERROR_MOD,    ONLY : ERROR_STOP
      USE TRACERID_MOD, ONLY : IDTPB,    IDTBE7,   IDTHNO3, IDTH2O2 
      USE TRACERID_MOD, ONLY : IDTCH2O,  IDTMP,    IDTSO2,  IDTSO4  
      USE TRACERID_MOD, ONLY : IDTSO4s,  IDTSO4aq, IDTMSA,  IDTNH3   
      USE TRACERID_MOD, ONLY : IDTNH4,   IDTNH4aq, IDTNIT,  IDTNITs  
      USE TRACERID_MOD, ONLY : IDTAS,    IDTAHS,   IDTLET,  IDTBCPI 
      USE TRACERID_MOD, ONLY : IDTOCPI,  IDTBCPO,  IDTOCPO, IDTDST1 
      USE TRACERID_MOD, ONLY : IDTDST2,  IDTDST3,  IDTDST4, IDTSALA 
      USE TRACERID_MOD, ONLY : IDTSALC,  IDTALPH,  IDTLIMO, IDTALCO 
      USE TRACERID_MOD, ONLY : IDTSOG1,  IDTSOG2,  IDTSOG3, IDTSOG4
      USE TRACERID_MOD, ONLY : IDTSOA1,  IDTSOA2,  IDTSOA3, IDTSOA4
      USE TRACERID_MOD, ONLY : IDTSOA5,  IDTSOG5
      USE TRACERID_MOD, ONLY : IS_Hg2,   IS_HgP
      USE TRACERID_MOD, ONLY : IDTGLYX,  IDTMGLY,  IDTGLYC
      USE TRACERID_MOD, ONLY : IDTSOAG,  IDTSOAM
      USE TRACERID_MOD, ONLY : IDTMOBA,  IDTPROPNN
      USE TRACERID_MOD, ONLY : IDTISOPN, IDTMMN
      USE TRACERID_MOD, ONLY : IDTIEPOX, IDTRIP, IDTMAP
      USE OCEAN_MERCURY_MOD,  ONLY : LHg_WETDasHNO3 ! (cdh 5/20/09)

#     include "CMN_SIZE"   ! Size parameters
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN)    :: L          ! Level index
      INTEGER, INTENT(IN)    :: N          ! Tracer number
      REAL*8,  INTENT(IN)    :: BXHEIGHT   ! Grid box height [m]
      REAL*8,  INTENT(IN)    :: TK         ! Temperature [K]
      REAL*8,  INTENT(IN)    :: PP         ! Precip rate thru  bottom of grid
                                           !  box (I,J,L)  [cm3 H2O/cm2 air/s]
      REAL*8,  INTENT(IN)    :: DT         ! Timestep for rainout event [s]
      REAL*8,  INTENT(IN)    :: F          ! Fraction of grid box that is 
                                           !   precipitating [unitless]
! !INPUT/OUTPUT PARAMETERS:
!
      REAL*8,  INTENT(INOUT) :: H2O2s      ! H2O2 [v/v] and SO2 [v/v] 
      REAL*8,  INTENT(INOUT) :: SO2s       ! concentrations after aqueous rxns 
                                           ! are applied.  These are computed 
                                           ! in the sulfate chemistry module
                                           ! and passed here as arguments. 
!
! !OUTPUT PARAMETERS:
!
      REAL*8,  INTENT(OUT)   :: WASHFRAC   ! Fraction of tracer lost to 
                                           !  washout [unitless]
      LOGICAL, INTENT(OUT)   :: AER        ! =T if the tracer is an aerosol
                                           ! =F otherwise
!
! !REVISION HISTORY: 
!  28 Feb 2000 - R. Yantosca - Initial version
!  (1 ) Currently works for either full chemistry simulation (NSRCX == 3) 
!        or Rn-Pb-Be chemistry simulation (NSRCX == 1).  Other simulations
!        do not carry soluble tracers, so set WASHFRAC = 0. 
!  (2 ) K_WASH, the rainout rate constant, and F, the areal fraction of the 
!        grid box undergoing precipitiation, are computed according to 
!        Giorgi & Chaimedes, as described in Jacob et al, 2000.
!  (3 ) Washout is only done for T >= 268 K, when the cloud condensate is
!        in the liquid phase. 
!  (4 ) T(I+I0,J+J0,L) is now T(I,J,L).  Removed IREF, JREF -- these are 
!        obsolete.  Updated comments. (bmy, 9/27/01)
!  (5 ) Removed obsolete commented out code from 9/01 (bmy, 10/24/01)
!  (6 ) Now reference BXHEIGHT, T from "dao_mod.f".  Also remove reference
!        to "CMN_NOX".  Updated comments.  Now bundled into "wetscav_mod.f".
!        Now also references "tracerid_mod.f".  Added internal routines
!        WASHFRAC_AEROSOL and WASHFRAC_LIQ_GAS.  Also removed reference to
!        CMN since we don't need to use NSRCX here. (bmy, 11/6/02)
!  (7 ) Updated for carbon aerosol and dust tracers (rjp, bmy, 4/5/04)
!  (8 ) Updated for seasalt aerosol tracers (rjp, bec, bmy, 4/20/04)
!  (9 ) Updated for secondary organic aerosol tracers (rjp, bmy, 7/13/04)
!  (10) Now move internal routines WASHFRAC_AEROSOL and WASHFRAC_LIQ_GAS
!        to the module and pass all arguments explicitly.  This facilitates
!        parallelization on the Altix platform (bmy, 7/20/04)
!  (11) Now handle washout of mercury aerosol tracers (eck, bmy, 12/9/04)
!  (13) Updated for AS, AHS, LET, NH4aq, SO4aq.  Also condensed the IF
!        statement by grouping blocks together (cas, bmy, 12/20/04)
!  (14) Updated for SO4s, NITs (bec, bmy, 4/25/05)
!  (15) Now make sure all USE statements are USE, ONLY (bmy, 10/3/05)
!  (16) Bug fix: Deplete H2O2s the same as SO2s.  Also change Henry's law
!        constant for Hg2 to 1.0d+14. Now use functions IS_Hg2 and IS_HgP to 
!        determine if a tracer is a tagged Hg0 or HgP tracer.
!        (dkh, rjp, eck, cdh, bmy, 1/6/06)
!  (17) Updated for SOG4 and SOA4 (bmy, 5/18/06)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!  30 Sep 2010 - H. Amos     - WASHFRAC_LIQ_GAS now a subroutine (was an 
!                              external function)
!  14 Oct 2010 - H. Amos     - Remove dependence on I, J. That means removing
!                              I, J as input arguments and adding T, BXHEIGHT,
!                              H2O2s, and SO4s and input arguments.
!  14 Jan 2011 - H. Amos     - Don't pass AER to WASHFRAC_LIQ_GAS
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      REAL*8            :: L2G, DZ, SO2LOSS
!
! !DEFINED PARAMETERS:
!
      ! First order washout rate constant for HNO3, aerosols = 1 cm^-1
      REAL*8, PARAMETER :: K_WASH = 1d0

      !=================================================================
      ! WASHOUT begins here!
      !
      ! Call either WASHFRAC_AEROSOL or WASHFRAC_LIQ_GAS to compute the
      ! fraction of tracer lost to washout according to Jacob et al 2000
      !=================================================================

      ! DZ is the height of the grid box in cm
      DZ = BXHEIGHT * 1d2

      !------------------------------
      ! 210Pb or 7Be (aerosol)
      !------------------------------
      IF ( N == IDTPb .or. N == IDTBe7 ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! HNO3 (aerosol)
      !------------------------------
      ELSE IF ( N == IDTHNO3 ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! H2O2 (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTH2O2 ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 8.3d4, -7.4d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! CH2O (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTCH2O ) THEN 
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 3.0d3, -7.2d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! GLYX (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTGLYX ) THEN 

         ! Compute liquid to gas ratio for GLYX, using
         ! (1) Zhou and Mopper (1990): Kstar298 = 3.6e5 M/atm 
         ! (2) Schweitzer et al. (1998) showed that the temperature 
         ! dependence for CH2O works well for glyoxal,
         !      so we use the same H298_R as CH2O
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 3.6d5, -7.2d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )


      !------------------------------
      ! MGLY (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTMGLY ) THEN 
         ! Compute liquid to gas ratio for MGLY, using
         ! the appropriate parameters for Henry's law
         ! from Betterton and Hoffman 1988): Kstar298 = 3.71d3 M/atm;  
         ! H298_R = -7.5d3 K
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 3.7d3, -7.5d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! GLYC (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTGLYC ) THEN 
         ! Compute liquid to gas ratio for GLYC, using
         ! the appropriate parameters for Henry's law
         ! from Betterton and Hoffman 1988): Kstar298 = 4.6d4 M/atm;  
         ! H298_R = -4.6d3 K
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 4.1d4, -4.6d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! MP (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTMP ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 3.1d2, -5.2d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! MOBA (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTMOBA ) THEN       
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 2.6d4, -6.3d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! ISOPN (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTISOPN ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS(17d3, -9.2d3 , PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! MMN (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTMMN ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 17d3, -9.2d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! PROPNN (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTPROPNN ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 1.0d3, 0.0d0, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! RIP (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTRIP ) THEN
         !USE H2O2 
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 8.3d4, -7.4d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! MAP   (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTMAP ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 8.4d2, -5.3d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! IEPOX (liquid phase only)
      !------------------------------
      ELSE IF ( N == IDTIEPOX ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 8.3d4, -7.4d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! SO2 (aerosol treatment)
      !------------------------------
      ELSE IF ( N == IDTSO2 ) THEN

         !==============================================================
         ! NOTE: Even though SO2 is not an aerosol we treat it as SO4 in
         ! wet scavenging.  When evaporation occurs, it returns to SO4.
         !==============================================================
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

         !==============================================================
         ! Use the wet-scavenging following [Chin et al, 1996] such 
         ! that a soluble fraction of SO2 is limited by the availability 
         ! of H2O2 in the precipitating grid box.  Then scavenge the 
         ! soluble SO2 at the same rate as sulfate.
         !==============================================================
         IF ( TK >= 268d0 .AND. SO2s  > EPSILON ) THEN
         
            ! Adjust WASHFRAC
            SO2LOSS  = MIN( SO2s, H2O2s )
            WASHFRAC = SO2LOSS * WASHFRAC / SO2s
            WASHFRAC = MAX( WASHFRAC, 0d0 )
                  
            ! Deplete H2O2s the same as SO2s (dkh, rjp, bmy, 11/17/05)
            H2O2s = H2O2s - ( SO2s * WASHFRAC )
            H2O2s = MAX( H2O2s, EPSILON )

         ELSE
            WASHFRAC = 0d0
         
         ENDIF
         
         ! Update saved SO2 concentration 
         SO2s = SO2s * ( 1d0 - WASHFRAC )
         SO2s = MAX( SO2s, EPSILON ) 
          
      !------------------------------
      ! SO4 and SO4aq (aerosol)
      !------------------------------
      ELSE IF ( N == IDTSO4 .or. N == IDTSO4s .or. N == IDTSO4aq ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! MSA (aerosol)
      !------------------------------
      ELSE IF ( N == IDTMSA ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! NH3 (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTNH3 ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 3.3d6, -4.1d3, PP, DT, 
     &                                F,      DZ,    TK, K_WASH )

      !------------------------------
      ! NH4 and NH4aq (aerosol)
      !------------------------------
      ELSE IF ( N == IDTNH4 .or. N == IDTNH4aq ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! NIT/AS/AHS/LET (aerosol)
      !------------------------------
      ELSE IF ( N == IDTNIT  .or. N == IDTNITs .or.
     &          N == IDTAS   .or. N == IDTAHS  .or. 
     &          N == IDTLET ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! BC HYDROPHILIC (aerosol) or
      ! OC HYDROPHILIC (aerosol) or
      ! BC HYDROPHOBIC (aerosol) or
      ! OC HYDROPHOBIC (aerosol) 
      !------------------------------
      ELSE IF ( N == IDTBCPI .or. N == IDTOCPI  .or.
     &          N == IDTBCPO .or. N == IDTOCPO ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! DUST all size bins (aerosol)
      !------------------------------
      ELSE IF ( N == IDTDST1 .or. N == IDTDST2  .or.
     &          N == IDTDST3 .or. N == IDTDST4 ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! Accum  seasalt (aerosol) or
      ! Coarse seasalt (aerosol)
      !------------------------------
      ELSE IF ( N == IDTSALA .or. N == IDTSALC ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! ALPH (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTALPH ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 0.023d0, 0.d0, PP, DT, 
     &                                F,       DZ,   TK, K_WASH )

      !------------------------------
      ! LIMO (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTLIMO ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 0.07d0, 0.d0, PP, DT, 
     &                                F,      DZ,   TK, K_WASH )

      !------------------------------
      ! ALCO (liquid & gas phases)
      !------------------------------
      ELSE IF ( N == IDTALCO ) THEN
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 54.d0, 0.d0, PP, DT, 
     &                                F,     DZ,   TK, K_WASH )

      !---------------------------------
      ! SOG[1,2,3,4] (liq & gas phases)
      !---------------------------------
      ELSE IF ( N == IDTSOG1 .or. N == IDTSOG2  .or. 
     &          N == IDTSOG3 .or. N == IDTSOG4  .or.  
     &          N == IDTSOG5                    ) THEN   
         AER      = .FALSE.
         WASHFRAC = WASHFRAC_LIQ_GAS( 1.0d5, -6.039d3, PP, DT, 
     &                                F,      DZ,      TK, K_WASH )

      !------------------------------
      ! SOA[1,2,3,4,5] (aerosol)
      !------------------------------
      ELSE IF ( N == IDTSOA1 .or. N == IDTSOA2  .or. 
     &          N == IDTSOA3 .or. N == IDTSOA4  .or.  
     &          N == IDTSOA5                    ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! SOAG and SOAM (aerosol)
      !------------------------------
      ELSE IF ( N == IDTSOAG .or. N == IDTSOAM ) THEN
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! Hg2 (liquid & gas phases)
      !------------------------------
      ELSE IF ( IS_Hg2( N ) ) THEN

         ! Begin CDH Changes (5/20/2009)
         ! Allow user to choose how precip occurs
         IF ( LHg_WETDasHNO3 ) THEN

            ! Assume that Hg2 behaves like HNO3 and aerosols 
            AER      = .TRUE.
            WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )
            
         ELSE

            ! Assume Hg2 is in gas phase and equilibrates with precip
            ! according to Henry's law
            AER      = .FALSE.
!---------------------------------------------------------------------------
! Prior to 1/10/11:
! hma, 10-Jan-2011, Henry's law constant for HgCl2 = 1.4d+6 M/atm
! Ref: Lindqvist and Rhode, 1985
!            WASHFRAC = WASHFRAC_LIQ_GAS( 1.0d+14, -8.4d3, PP, DT, 
!     &                                   F,        DZ,    TK, K_WASH )
!---------------------------------------------------------------------------
            WASHFRAC = WASHFRAC_LIQ_GAS( 1.4d+6, -8.4d3, PP, DT, 
     &                                   F,       DZ,    TK, K_WASH )

         ENDIF
      
      !------------------------------
      ! HgP (treat like aerosol) 
      !------------------------------
      ELSE IF ( IS_HgP( N ) ) THEN 
         AER      = .TRUE.
         WASHFRAC = WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK )

      !------------------------------
      ! ERROR: Insoluble tracer
      !------------------------------
      ELSE 
         CALL ERROR_STOP( 'Invalid tracer!', 'WASHOUT (wetscav_mod.f)' )

      ENDIF

      END SUBROUTINE WASHOUT
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: washfrac_aerosol
!
! !DESCRIPTION: Function WASHFRAC\_AEROSOL returns the fraction of soluble 
!  aerosol tracer lost to washout.
!\\
!\\
! !INTERFACE:
!
      FUNCTION WASHFRAC_AEROSOL( DT, F, K_WASH, PP, TK ) 
     &         RESULT( WASHFRAC )
!
! !USES:
!
      USE TRACER_MOD, ONLY : ITS_A_MERCURY_SIM
!
! !INPUT PARAMETERS: 
!
      REAL*8, INTENT(IN) :: DT         ! Timestep of washout event [s]
      REAL*8, INTENT(IN) :: F          ! Fraction of grid box that is
                                       !  precipitating [unitless]
      REAL*8, INTENT(IN) :: K_WASH     ! 1st order washout rate constant [1/cm]
      REAL*8, INTENT(IN) :: PP         ! Precip rate thru bottom of grid 
                                       !  box (I,J,L)  [cm3 H2O/cm2 air/s]
      REAL*8, INTENT(IN) :: TK         ! Temperature in grid box [K]
!
! !RETURN VALUE:
!
      REAL*8             :: WASHFRAC   ! Fraction of soluble tracer 
                                       !  lost to washout
! 
! !REVISION HISTORY: 
!  08 Nov 2002 - R. Yantosca - Initial version
!  (1 ) WASHFRAC_AEROSOL used to be an internal function to subroutine WASHOUT.
!        This caused NaN's in the parallel loop on Altix, so we moved it to
!        the module and now pass Iall arguments explicitly (bmy, 7/20/04)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! WASHFRAC_AEROSOL begins here!
      !=================================================================

      ! Washout only happens at or above 268 K
      ! Now allow washout of Hg aerosols (cdh, 4/16/09)
      IF ( ( TK >= 268d0 ) .OR. ITS_A_MERCURY_SIM() ) THEN
         WASHFRAC = F * ( 1d0 - EXP( -K_WASH * ( PP / F ) * DT ) )
      ELSE
         WASHFRAC = 0d0
      ENDIF

      END FUNCTION WASHFRAC_AEROSOL
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: washfrac_liq_gas
!
! !DESCRIPTION: Function WASHFRAC\_LIQ\_GAS returns the fraction of soluble 
!  liquid/gas phase tracer lost to washout.
!\\
!\\
! !INTERFACE:
!
      FUNCTION WASHFRAC_LIQ_GAS( Kstar298, H298_R, PP, DT, 
     &                           F,        DZ,     TK, K_WASH ) 
     &         RESULT( WASHFRAC ) 
!
! !INPUT PARAMETERS: 
!
      REAL*8,  INTENT(IN)  :: Kstar298   ! Effective Henry's law constant 
                                         !  @ 298 K  [moles/atm]
      REAL*8,  INTENT(IN)  :: H298_R     ! Henry's law coefficient [K]
      REAL*8,  INTENT(IN)  :: PP         ! Precip rate thru bottom of the
                                         !  grid box [cm3 H2O/cm2 air/s]
      REAL*8,  INTENT(IN)  :: DT         ! Timestep for washout event [s]
      REAL*8,  INTENT(IN)  :: F          ! Fraction of grid box that is
                                         !  precipitating [unitless]
      REAL*8,  INTENT(IN)  :: DZ         ! Height of grid box [cm]
      REAL*8,  INTENT(IN)  :: TK         ! Temperature in grid box [K]
      REAL*8,  INTENT(IN)  :: K_WASH     ! 1st order washout rate const [1/cm]
!
! !FUNCTION VALUE:
!
      REAL*8               :: WASHFRAC   ! Fraction of tracer lost to washout
!
! !REVISION HISTORY: 
!  20 Jul 2004 - R. Yantosca - Initial version
!  (1 ) WASHFRAC_LIQ_GAS used to be an internal function to subroutine WASHOUT.
!        This caused NaN's in the parallel loop on Altix, so we moved it to
!        the module and now pass all arguments explicitly (bmy, 7/20/04)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers 
!  10 Jan 2011 - H. Amos     - Remove AER from the argument list
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      REAL*8 :: L2G, LP, WASHFRAC_F_14

      !=================================================================
      ! WASHFRAC_LIQ_GAS begins here!
      !=================================================================

      ! Suppress washout below 268 K
      IF ( TK >= 268d0 ) THEN

         ! Rainwater content in the grid box (Eq. 17, Jacob et al, 2000)
         LP = ( PP * DT ) / ( F * DZ ) 

         ! Compute liquid to gas ratio for H2O2, using the appropriate 
         ! parameters for Henry's law -- also use rainwater content Lp
         ! (Eqs. 7, 8, and Table 1, Jacob et al, 2000)
         CALL COMPUTE_L2G( Kstar298, H298_R, TK, LP, L2G )

         ! Washout fraction from Henry's law (Eq. 16, Jacob et al, 2000)
         WASHFRAC = L2G / ( 1d0 + L2G )

         ! Washout fraction / F from Eq. 14, Jacob et al, 2000
         WASHFRAC_F_14 = 1d0 - EXP( -K_WASH * ( PP / F ) * DT )

         ! Do not let the Henry's law washout fraction exceed
         ! ( washout fraction / F ) from Eq. 14 -- this is a cap
         IF ( WASHFRAC > WASHFRAC_F_14 ) WASHFRAC = WASHFRAC_F_14
            
      ELSE
         WASHFRAC = 0d0
            
      ENDIF

      END FUNCTION WASHFRAC_LIQ_GAS
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: wetdep
!
! !DESCRIPTION: Subroutine WETDEP computes the downward mass flux of tracer 
!  due to washout and rainout of aerosols and soluble tracers in a column.  
!  The timestep is the dynamic timestep.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE WETDEP( LS )
!
! !USES:
!
      USE DAO_MOD,           ONLY : BXHEIGHT
      USE LOGICAL_MOD,       ONLY : LDYNOCEAN
      USE DEPO_MERCURY_MOD,  ONLY : ADD_Hg2_WD
      USE DEPO_MERCURY_MOD,  ONLY : ADD_HgP_WD
      USE TIME_MOD,          ONLY : GET_TS_DYN
      USE TRACER_MOD,        ONLY : ITS_A_MERCURY_SIM
      USE TRACER_MOD,        ONLY : STT
      USE TRACERID_MOD,      ONLY : IDTSO2
      USE TRACERID_MOD,      ONLY : IDTSO4
      USE TRACERID_MOD,      ONLY : IS_Hg2
      USE TRACERID_MOD,      ONLY : IS_HgP
      USE DEPO_MERCURY_MOD,  ONLY : ADD_Hg2_SNOWPACK
      USE LOGICAL_MOD,       ONLY : LGTMM

#     include "CMN_SIZE"          ! Size parameters
#     include "CMN_DIAG"          ! Diagnostic arrays and switches 
!
! !INPUT PARAMETERS: 
!
      LOGICAL, INTENT(IN) :: LS   ! =T denotes large-scale precip
                                  ! =F denotes convective precip
!
! !REMARKS:
!  Precipitation fields:
!  =====================
!                                                                             .
!       Layer        Formation of       Precipitation
!                     New Precip        falling down
!      ==================================================== Top of Atm.
!        LM           QQ(L,I,J)         PDOWN(LM,I,J)
!                         |                   |
!      ----------------------------------------------------
!        LM-1         QQ(L,I,J)         PDOWN(LM-1,I,J)    
!                         |                   |
!      -------------------V-------------------V------------
!                        ...                 ...     
!                         |                   |
!      -------------------V-------------------V------------
!        3            QQ(L,I,J)         PDOWN(3,I,J)
!                         |                   |
!      -------------------V--------------------------------
!        2            QQ(L,I,J)         PDOWN(2,I,J) 
!                         |                   |
!      ----------------------------------------------------
!        1            QQ(L,I,J)         PDOWN(1,I,J) 
!                         |                   |
!      ===================V===================V============ Ground
!                                                                             .
!  Where:
!    (a) New formation forming in grid box (I,J,L) = QQ(L,I,J)
!    (b) Precip coming in  thru top    of layer L  = PDOWN(L+1,I,J)
!    (c) Precip going  out thru bottom of layer L  = PDOWN(L,  I,J) 
!                                                                             .
!  Rainout:
!  ========   
!  Rainout occurs when there is more precipitation in grid box (I,J,L) than
!  in grid box (I,J,L+1).  In other words, rainout occurs when the amount of 
!  rain falling through the bottom of grid box (I,J,L) is more than the amount
!  of rain coming in through the top of grid box (I,J,L). 
!                                                                             .
!  Soluble gases/aerosols are incorporated into the raindrops and are 
!  completely removed from grid box (I,J,LLPAR).  There is no evaporation 
!  and "resuspension" of aerosols during a rainout event.
!                                                                             .
!  For large-scale (a.k.a. stratiform) precipitation, the first order rate 
!  constant for rainout in the grid box (I,J,L=LLPAR) (cf. Eq. 12, Jacob 
!  et al, 2000) is given by:
!                                                                             .
!                           Q        
!       K_RAIN = K_MIN + -------    [units: s^-1]
!                         L + W    
!                                                                             .
!  and the areal fraction of grid box (I,J,L=LLPAR) that is actually 
!  experiencing large-scale precipitation (cf. Eq. 11, Jacob et al, 2000) 
!  is given by: 
!                                                                             .
!                         Q               
!       F'     =  -------------------   [unitless]
!                  K_RAIN * ( L + W )    
!                                                                             .
!  Where:
!                                                                             .
!       K_MIN  = minimum value for K_RAIN         
!              = 1.0e-4 [s^-1]
!                                                                             .
!       L + W  = condensed water content in cloud 
!              = 1.5e-6 [cm3 H2O/cm3 air]
!                                                                             .
!       Q = QQ = rate of precipitation formation 
!                [ cm3 H2O / cm3 air / s ]
!                                                                             .
!  For convective precipitation, K_RAIN = 5.0e-3 [s^-1], and the expression 
!  for F' (cf. Eq. 13, Jacob et al, 2000) becomes:
!                                                                             .
!                                       { DT        }
!                         FMAX * Q * MIN{ --- , 1.0 }
!                                       { TAU       }
!       F' = ------------------------------------------------------
!                    { DT        }
!             Q * MIN{ --- , 1.0 }  +  FMAX * K_RAIN * ( L + W )
!                    { TAU       } 
!                                                                             .
!  Where:
!                                                                             .
!       Q = QQ = rate of precipitation formation 
!              [cm3 H2O/cm3 air/s]
!                                                                             .
!       FMAX   = maximum value for F' 
!              = 0.3
!                                                                             .
!       DT     = dynamic time step from the CTM [s]
!                                                                             .
!       TAU    = duration of rainout event 
!              = 1800 s (30 min)
!                                                                             .
!       L + W  = condensed water content in cloud 
!              = 2.0e-6 [cm3 H2O/cm3 air]
!                                                                             .
!  K_RAIN and F' are needed to compute the fraction of tracer in grid box 
!  (I,J,L=LLPAR) lost to rainout.  This is done in module routine RAINOUT.
!                                                                             .
!  Washout:
!  ========   
!  Washout occurs when we have evaporation (or no precipitation at all) at 
!  grid box (I,J,L), but have rain coming down from grid box (I,J,L+1).

! !REVISION HISTORY: 
!  02 Apr 1999 - H. Liu, I. Bey, R. Yantosca - Initial version
!  (1 ) WETDEP should be called twice, once with LS = .TRUE. and once
!        with LS = .FALSE.  This will handle both large-scale and
!        convective precipitation. (bmy, 2/28/00)
!  (2 ) Call subroutine MAKE_QQ to construct the QQ and PDOWN precipitation
!        fields before calling WETDEP. (bmy, 2/28/00)
!  (3 ) Since we are working with an (I,J) column, the ordering of the
!        loops goes J - I - L - N.  Dimension arrays DSTT, PDOWN, QQ
!        to take advantage of this optimal configuration (bmy, 2/28/00)
!  (4 ) Use double-precision exponents to force REAL*8 accuracy
!        (e.g. 1d0, bmy, 2/28/00)
!  (5 ) Diagnostics ND16, ND17, ND18, and ND39 use allocatable arrays 
!        from "diag_mod.f"  (bmy, bey, 3/14/00)
!  (6 ) WETDEP only processes soluble tracers and/or aerosols, as are
!        defined in the NSOL and IDWETD arrays (bmy, 3/14/00)
!  (7 ) Add kludge to prevent wet deposition in the stratosphere (bmy, 6/21/00)
!  (8 ) Removed obsolete code from 10/27/00 (bmy, 12/21/00)
!  (9 ) Remove IREF, JREF -- they are obsolete (bmy, 9/27/01)
!  (10) Removed obsolete commented out code from 9/01 (bmy, 10/24/01)
!  (11) Replaced all instances of IM with IIPAR and JM with JJPAR, in order
!        to prevent namespace confusion for the new TPCORE (bmy, 6/25/02)
!  (12) Now reference BXHEIGHT from "dao_mod.f".  Also references routine
!        GEOS_CHEM_STOP from "error_mod.f".  Also fix ND39 diagnostic so that
!        the budget of tracer lost to wetdep is closed.  Now bundled into
!        "wetscav_mod.f".  Now only save to AD16, AD17, AD18, AD39 if L<=LD16,
!        L<=LD17, L<=LD18, and L<=LD39 respectively; this avoids out-of-bounds
!        array errors. Updated comments, cosmetic changes. (qli, bmy, 11/26/02)
!  (13) References IDTSO2, IDTSO4 from "tracerid_mod.f". SO2 in sulfate 
!        chemistry is wet-scavenged on the raindrop and converted to SO4 by 
!        aqueous chem. If evaporation occurs then SO2 comes back as SO4.
!        (rjp, bmy, 3/23/03)  
!  (14) Now use function GET_TS_DYN() from "time_mod.f" (bmy, 3/27/03)
!  (15) Now parallelize over outermost J-loop.  Also move internal routines
!        LS_K_RAIN, LS_F_PRIME, CONV_F_PRIME, and SAFETY to the module, since
!        we cannot call internal routines from w/in a parallel loop. 
!        (bmy, 3/18/04)
!  (16) Now references STT & N_TRACERS from "tracer_mod.f".  Also now make
!        DSTT a 4-d internal array so as to facilitate -C checking on the
!        SGI platform. (bmy, 7/20/04)
!  (17) Now references IDTHg2 from "tracerid_mod.f".  Now pass the amt of
!        Hg2 wet scavenged out of the column to "ocean_mercury_mod.f" via
!        routine ADD_Hg2_WD. (sas, bmy, 1/19/05)
!  (18) Bug fix: replace line that can cause numerical blowup with a safer
!        analytical expression. (bmy, 2/23/05)
!  (19) Block out parallel loop with #ifdef statements for SGI_MIPS compiler.
!        For some reason this causes an error. (bmy, 5/5/05)
!  (20) Now use function IS_Hg2 to determine if a tracer is a tagged Hg2 
!        tracer.  Now also pass N to ADD_Hg2_WD.  Now references LDYNOCEAN
!        from "logical_mod.f".  Now do not call ADD_Hg2_WD if we are not
!        using the dynamic ocean model. (eck, sas, cdh, bmy, 2/27/06)
!  (21) Eliminate unnecessary variables XDSTT, L_PLUS_W.  Also zero all 
!        unused variables for each grid box. (bmy, 5/24/06)
!  (22) Redimension DSTT with NSOL instead of NSOLMAX. In many cases, NSOL is
!        less than NSOLMAX and this will help to save memory especially when
!        running at 2x25 or greater resolution. (bmy, 1/31/08)
!  (23) Remove reference to SGI_MIPS (bmy, 7/8/09)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!  27 May 2011 - R. Yantosca - Now pass F_RAINOUT to DO_WASHOUT_ONLY
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      LOGICAL, SAVE      :: FIRST = .TRUE.
      LOGICAL            :: IS_Hg
      LOGICAL            :: AER
                         
      INTEGER            :: I, IDX, J, L, N, NN
                         
      REAL*8             :: Q,     QDOWN,  DT,        DT_OVER_TAU
      REAL*8             :: K,     K_MIN,  K_RAIN,    RAINFRAC
      REAL*8             :: F,     FTOP,   F_PRIME,   WASHFRAC
      REAL*8             :: LOST,  GAINED, MASS_WASH, MASS_NOWASH
      REAL*8             :: ALPHA, ALPHA2, WETLOSS,   TMP
      REAL*8             :: F_RAINOUT,     F_WASHOUT

      ! DSTT is the accumulator array of rained-out 
      ! soluble tracer for a given (I,J) column
      REAL*8             :: DSTT(NSOL,LLPAR,IIPAR,JJPAR)
 
      CHARACTER(LEN=255) :: ERRMSG

      !=================================================================
      ! (1)  I n i t i a l i z e   V a r i a b l e s
      !=================================================================

      ! Is this a mercury simulation with dynamic online ocean?
      IS_Hg = ( ITS_A_MERCURY_SIM() .and. LDYNOCEAN )

      ! Dynamic timestep [s]
      DT    = GET_TS_DYN() * 60d0
      
      ! Select index for diagnostic arrays -- will archive either
      ! large-scale or convective rainout/washout fractions
      IF ( LS ) THEN
         IDX = 1
      ELSE
         IDX = 2
      ENDIF

      !=================================================================
      ! (2)  L o o p   O v e r   (I, J)   S u r f a c e   B o x e s
      !=================================================================
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I,       J,      FTOP,      ERRMSG,    F          )
!$OMP+PRIVATE( F_PRIME, K_RAIN, L,         Q,         QDOWN      )
!$OMP+PRIVATE( NN,      N,      F_RAINOUT, F_WASHOUT             )
!$OMP+SCHEDULE( DYNAMIC )   
      DO J = 1, JJPAR
      DO I = 1, IIPAR

         ! Zero FTOP
         FTOP = 0d0

         ! Zero accumulator array
         DO L  = 1, LLPAR
         DO NN = 1, NSOL
            DSTT(NN,L,I,J) = 0d0
         ENDDO
         ENDDO

         !==============================================================
         ! (3)  R a i n o u t   F r o m   T o p   L a y e r  (L = LLPAR) 
         !
         ! Assume that rainout is happening in the top layer if 
         ! QQ(LLPAR,I,J) > 0.  In other words, if any precipitation 
         ! forms in grid box (I,J,LLPAR), assume that all of it falls 
         ! down to lower levels.
         !==============================================================

         ! Zero variables for this level
         ERRMSG    = 'RAINOUT: Top of atm'
         F         = 0d0
         F_PRIME   = 0d0
         F_RAINOUT = 0d0      
         F_WASHOUT = 0d0      
         K_RAIN    = 0d0
         Q         = 0d0
         QDOWN     = 0d0

         ! Start at the top of the atmosphere
         L = LLPAR

         ! If precip forms at (I,J,L), assume it all rains out
         IF ( QQ(L,I,J) > 0d0 ) THEN

            ! Q is the new precip that is forming within grid box (I,J,L)
            Q = QQ(L,I,J)

            ! Compute K_RAIN and F' for either large-scale or convective
            ! precipitation (cf. Eqs. 11-13, Jacob et al, 2000) 
            IF ( LS ) THEN
               K_RAIN  = LS_K_RAIN( Q )
               F_PRIME = LS_F_PRIME( Q, K_RAIN )
            ELSE
               K_RAIN  = 1.5d-3
               F_PRIME = CONV_F_PRIME( Q, K_RAIN, DT )
            ENDIF
            
            ! Set F = F', since there is no FTOP at L = LLPAR
            F = F_PRIME

            ! Only compute rainout if F > 0. 
            ! This helps to eliminate unnecessary CPU cycles.
            IF ( F > 0d0 ) THEN 
               CALL DO_RAINOUT_ONLY( LS,  I,      J,   L,   
     &                               IDX, ERRMSG, F,   K_RAIN, 
     &                               DT,  STT,    DSTT         )
            ENDIF

            ! Save FTOP for the next lower level 
            FTOP = F
         ENDIF

         !==============================================================
         ! (4)  R a i n o u t   i n   t h e   M i d d l e   L e v e l s
         ! 
         ! Rainout occurs when there is more precipitation in grid box 
         ! (I,J,L) than in grid box (I,J,L+1).  In other words, rainout 
         ! occurs when the amount of rain falling through the bottom of 
         ! grid box (I,J,L) is more than the amount of rain coming in 
         ! through the top of grid box (I,J,L). 
         !
         ! Thus ( PDOWN(L,I,J) > 0 and QQ(L,I,J) > 0 ) is the 
         ! criterion for Rainout.
         !==============================================================
         DO L = LLPAR-1, 2, -1

            ! Zero variables for each level
            F         = 0d0
            F_PRIME   = 0d0
            F_RAINOUT = 0d0 
            F_WASHOUT = 0d0 
            K_RAIN    = 0d0
            Q         = 0d0
            QDOWN     = 0d0

            ! If there is new precip forming w/in the grid box ...
            IF ( QQ(L,I,J) > 0d0 ) THEN

               ! Compute K_RAIN and F' for either large-scale or convective
               ! precipitation (cf. Eqs. 11-13, Jacob et al, 2000) 
               IF ( LS ) THEN
                  K_RAIN  = LS_K_RAIN( QQ(L,I,J) )
                  F_PRIME = LS_F_PRIME( QQ(L,I,J), K_RAIN )
               ELSE
                  K_RAIN  = 1.5d-3
                  F_PRIME = CONV_F_PRIME( QQ(L,I,J), K_RAIN, DT )
               ENDIF
               
            ELSE
               
               F_PRIME = 0d0
 
            ENDIF

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!%%% NOTE from Chris Holmes (8/21/10)
!%%%
!%%% Qiaoqiao Wang implemented several changes to wet scavenging that I 
!%%% know of:
!%%% 1. Scavenging by snow has different collection efficiency to rain
!%%% 2. Allow both washout and rainout when QQ>0 and FTOP >F_PRIME.
!%%%    Previously only rainout occurred when QQ>0. Qiaoqiao reasoned that if
!%%%    QQ>0 is very small and there is a lot of rain from above, then most of
!%%%    the box should experience washout and only some of the box should
!%%%    experience rainout.
!%%% 3. Specific improvements for BC and OC.
!%%%
!%%% TO ENABLE QIAOQIAO'S "ITEM #2" MODIFICATION, UNCOMMENT THESE LINES:
!%%%
            ! The following block implements Qiaoqiao's changes
            ! Calculate the fractional areas subjected to rainout and
            ! washout. If PDOWN = 0, then all dissolved tracer returns
            ! to the atmosphere. (cdh, 7/13/10)
            IF ( PDOWN(L,I,J) > 0d0 ) THEN
               F_RAINOUT = F_PRIME
               ! Washout occurs where there is no rainout
               F_WASHOUT = MAX( FTOP - F_RAINOUT, 0d0 )
            ELSE
               F_RAINOUT = 0d0
               F_WASHOUT = 0d0
            ENDIF

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!%%% NOTE from Chris Holmes (8/21/10)
!%%% 
!%%% I reorganized the code so that Qiaoqiao's changes for Item 2 could be 
!%%% enabled or disabled by commenting just a few lines that Bob has 
!%%% highlighted:
!%%%
!%%% TO DISABLE QIAOQIAO'S MODIFICATION "ITEM #2" AND RESTORE THE
!%%% SAME ALGORITHM USED IN v8-03-01, UNCOMMENT THESE LINES:
!%%%
!            ! Zero
!            F_RAINOUT = 0d0
!            F_WASHOUT = 0d0
!
!            ! If there is downward-falling precip from the level above ...
!            IF ( PDOWN(L,I,J) > 0d0 ) THEN
!               
!               ! ... and if there is new precip forming in this level,
!               ! then we have a rainout condition.  F_RAINOUT is the
!               ! fraction of the grid box that where rainout occurs
!               IF ( QQ(L,I,J) > 0d0 ) THEN
!                  F_RAINOUT = MAX( FTOP, F_PRIME )
!               ENDIF 
!
!               ! The rest of the precipitating part of the box is
!               ! undergoing washout.  Store this fraction in F_WASHOUT.
!               F_WASHOUT = MAX( FTOP - F_RAINOUT, 0d0 )
!
!            ENDIF
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            ! F is the effective area of precip seen by grid box (I,J,L) 
            F = MAX( F_PRIME, FTOP )

            ! If there is rainout occurring ...
            IF ( F_RAINOUT > 0d0  ) THEN

               ! Error msg for stdout
               ERRMSG = 'RAINOUT: Middle levels'

               ! Do rainout if we meet the above criteria
               CALL DO_RAINOUT_ONLY( LS,  I,      J,         L,   
     &                               IDX, ERRMSG, F_RAINOUT, K_RAIN,  
     &                               DT,  STT,    DSTT               )
            ENDIF

            !==============================================================
            ! (5)  W a s h o u t   i n   t h e   m i d d l e   l e v e l s
            !
            ! Washout occurs when we have evaporation (or no precipitation 
            ! at all) at grid box (I,J,L), but have rain coming down from 
            ! grid box (I,J,L+1).
            !==============================================================
            IF ( F_WASHOUT > 0d0 ) THEN

               ! QDOWN is the precip leaving thru the bottom of box (I,J,L)
               ! Q     is the new precip that is forming within box (I,J,L)
               QDOWN = PDOWN(L,I,J)
               Q     = QQ(L,I,J)

               ! Also test if we have rainout happening simultaneously
               IF ( F_RAINOUT > 0d0 ) THEN

                  ! The precipitation causing washout is the precip entering
                  ! the top
                  QDOWN = PDOWN(L+1,I,J)

                  ! The amount of precipitating water entering from above 
                  ! which evaporates. If there is rainout (new precip
                  ! forming) then we have no way to estimate this, so assume
                  ! zero for now. Consequently there will be no resuspended
                  ! aerosol.
                  Q = 0d0
               ENDIF

               ! Error msg for stdout
               ERRMSG = 'WASHOUT: Middle levels'

               ! Do the washout
               CALL DO_WASHOUT_ONLY( LS,        I,    J,     
     &                               L,         IDX,  ERRMSG, 
     &                               QDOWN,     Q,    F_WASHOUT, 
     &                               F_RAINOUT, DT,   PDOWN,     
     &                               STT,       DSTT             )
            ENDIF

            !===========================================================
            ! (6)  N o   D o w n w a r d   P r e c i p i t a t i o n 
            !
            ! If there is no precipitation leaving grid box (I,J,L), 
            ! then  set F, the effective area of precipitation in grid 
            ! box (I,J,L), to zero.
            !
            ! Also, all of the previously rained-out tracer that is now 
            ! coming down from grid box (I,J,L+1) will evaporate and 
            ! re-enter the atmosphere in the gas phase in grid box 
            ! (I,J,L).  This is called "resuspension".
            !===========================================================
            IF ( F_WASHOUT == 0d0 .and. F_RAINOUT == 0d0 ) THEN

               ! No precipitation at grid box (I,J,L), thus F = 0
               F = 0d0
               
               ! Error message
               ERRMSG = 'RESUSPENSION in middle levels'

               ! Re-evaporate all of the rain
               CALL DO_COMPLETE_REEVAP( LS,  I,      J,  L,  
     &                                  IDX, ERRMSG, DT, STT, DSTT  )
            ENDIF 

            ! Save FTOP for next level
            FTOP = F_RAINOUT + F_WASHOUT
             
         ENDDO               

         !==============================================================
         ! (7)  W a s h o u t   i n   L e v e l   1
         !
         ! Assume all of the tracer precipitating down from grid box 
         ! (I,J,L=2) to grid box (I,J,L=1) gets washed out in grid box 
         ! (I,J,L=1).
         !==============================================================

         ! Zero variables for this level
         ERRMSG  = 'WASHOUT: at surface'
         F       = 0d0
         F_PRIME = 0d0
         K_RAIN  = 0d0
         Q       = 0d0
         QDOWN   = 0d0
         
         ! We are at the surface, set L = 1
         L = 1

         ! Washout at level 1 criteria
         IF ( PDOWN(L+1,I,J) > 0d0 ) THEN

            ! QDOWN is the precip leaving thru the bottom of box (I,J,L+1)
            QDOWN = PDOWN(L+1,I,J)

            ! Since no precipitation is forming within grid box (I,J,L),
            ! F' = 0, and F = MAX( F', FTOP ) reduces to F = FTOP.
            F = FTOP

            ! Only compute washout if F > 0.
            IF ( F > 0d0 ) THEN
               CALL DO_WASHOUT_AT_SFC( LS,  I,      J,     L,         
     &                                 IDX, ERRMSG, QDOWN, F,   
     &                                 DT,  STT,    DSTT      )
            ENDIF    
         ENDIF

         !==============================================================
         ! (8)  M e r c u r y   S i m u l a t i o n   O n l y 
         !
         ! For the mercury simulation, we need to archive the amt of 
         ! Hg2 [kg] that is scavenged out of the column.  Also applies
         ! to the tagged Hg simulation.
         !
         ! NOTES:
         ! (a) Now moved outside the loop above for clarity and to 
         !      fix a bug where HgP scavenging was not recorded. 
         ! (b) The values of DSTT in the first layer accumulates all 
         !      scavenging and washout in the column
         ! (c) Updates from cdh. (ccc, 5/17/10)
         !==============================================================
         IF ( IS_Hg ) THEN

            ! Loop over soluble tracers and/or aerosol tracers
            DO NN = 1, NSOL
               N = IDWETD(NN)

               ! Check if it is a gaseous Hg2 tag
               IF ( IS_Hg2( N ) ) THEN

                  CALL ADD_Hg2_WD      ( I, J, N, DSTT(NN,1,I,J) )
                  CALL ADD_Hg2_SNOWPACK( I, J, N, DSTT(NN,1,I,J) )

               ! Check if it is a HgP tag
               ELSE IF ( IS_HgP( N ) ) THEN
                  
                  CALL ADD_HgP_WD      ( I, J, N, DSTT(NN,1,I,J) )
                  CALL ADD_Hg2_SNOWPACK( I, J, N, DSTT(NN,1,I,J) )
                  
               ENDIF

            ENDDO
            
         ENDIF

      ENDDO	
      ENDDO	
!$OMP END PARALLEL DO

      END SUBROUTINE WETDEP
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: wetdep_merra
!
! !DESCRIPTION: Subroutine WETDEP_MERRA computes the downward mass flux of 
!  tracer due to washout and rainout of aerosols and soluble tracers in a 
!  column.  This subroutine implements a new algorithm in which the 
!  precipitation fields come directly from the MERRA archive.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE WETDEP_MERRA( LS )
!
! !USES:
!
      USE DAO_MOD,           ONLY : BXHEIGHT
      USE DAO_MOD,           ONLY : AIRDEN     
      USE DAO_MOD,           ONLY : DQRLSAN
      USE DAO_MOD,           ONLY : REEVAPLS
      USE LOGICAL_MOD,       ONLY : LDYNOCEAN
      USE DEPO_MERCURY_MOD,  ONLY : ADD_Hg2_WD
      USE DEPO_MERCURY_MOD,  ONLY : ADD_HgP_WD
      USE TIME_MOD,          ONLY : GET_TS_DYN
      USE TRACER_MOD,        ONLY : ITS_A_MERCURY_SIM
      USE TRACER_MOD,        ONLY : STT
      USE TRACERID_MOD,      ONLY : IDTSO2
      USE TRACERID_MOD,      ONLY : IDTSO4
      USE TRACERID_MOD,      ONLY : IS_Hg2
      USE TRACERID_MOD,      ONLY : IS_HgP
      USE DEPO_MERCURY_MOD,  ONLY : ADD_Hg2_SNOWPACK
      USE LOGICAL_MOD,       ONLY : LGTMM


#     include "CMN_SIZE"          ! Size parameters
#     include "CMN_DIAG"          ! Diagnostic arrays and switches 
!
! !INPUT PARAMETERS: 
!
      LOGICAL, INTENT(IN) :: LS   ! =T denotes large-scale precip
                                  ! =F denotes convective precip
!
! !REMARKS:
!  Precipitation fields:
!  =====================
!                                                                             .
!       Layer        Formation of       Precipitation
!                     New Precip        falling down
!      ==================================================== Top of Atm.
!        LM           QQ(L,I,J)         PDOWN(LM,I,J)
!                         |                   |
!      ----------------------------------------------------
!        LM-1         QQ(L,I,J)         PDOWN(LM-1,I,J)    
!                         |                   |
!      -------------------V-------------------V------------
!                        ...                 ...     
!                         |                   |
!      -------------------V-------------------V------------
!        3            QQ(L,I,J)         PDOWN(3,I,J)
!                         |                   |
!      -------------------V--------------------------------
!        2            QQ(L,I,J)         PDOWN(2,I,J) 
!                         |                   |
!      ----------------------------------------------------
!        1            QQ(L,I,J)         PDOWN(1,I,J) 
!                         |                   |
!      ===================V===================V============ Ground
!                                                                             .
!  Where:
!    (a) New formation forming in grid box (I,J,L) = QQ(L,I,J)
!    (b) Precip coming in  thru top    of layer L  = PDOWN(L+1,I,J)
!    (c) Precip going  out thru bottom of layer L  = PDOWN(L,  I,J) 
!                                                                             .
!  Rainout:
!  ========   
!  Rainout occurs when there is more precipitation in grid box (I,J,L) than
!  in grid box (I,J,L+1).  In other words, rainout occurs when the amount of 
!  rain falling through the bottom of grid box (I,J,L) is more than the amount
!  of rain coming in through the top of grid box (I,J,L). 
!                                                                             .
!  Soluble gases/aerosols are incorporated into the raindrops and are 
!  completely removed from grid box (I,J,LLPAR).  There is no evaporation 
!  and "resuspension" of aerosols during a rainout event.
!                                                                             .
!  For large-scale (a.k.a. stratiform) precipitation, the first order rate 
!  constant for rainout in the grid box (I,J,L=LLPAR) (cf. Eq. 12, Jacob 
!  et al, 2000) is given by:
!                                                                             .
!                           Q        
!       K_RAIN = K_MIN + -------    [units: s^-1]
!                         L + W    
!                                                                             .
!  and the areal fraction of grid box (I,J,L=LLPAR) that is actually 
!  experiencing large-scale precipitation (cf. Eq. 11, Jacob et al, 2000) 
!  is given by: 
!                                                                             .
!                         Q               
!       F'     =  -------------------   [unitless]
!                  K_RAIN * ( L + W )    
!                                                                             .
!  Where:
!                                                                             .
!       K_MIN  = minimum value for K_RAIN         
!              = 1.0e-4 [s^-1]
!                                                                             .
!       L + W  = condensed water content in cloud 
!              = 1.5e-6 [cm3 H2O/cm3 air]
!                                                                             .
!       Q = QQ = rate of precipitation formation 
!                [ cm3 H2O / cm3 air / s ]
!                                                                             .
!  For convective precipitation, K_RAIN = 5.0e-3 [s^-1], and the expression 
!  for F' (cf. Eq. 13, Jacob et al, 2000) becomes:
!                                                                             .
!                                       { DT        }
!                         FMAX * Q * MIN{ --- , 1.0 }
!                                       { TAU       }
!       F' = ------------------------------------------------------
!                    { DT        }
!             Q * MIN{ --- , 1.0 }  +  FMAX * K_RAIN * ( L + W )
!                    { TAU       } 
!                                                                             .
!  Where:
!                                                                             .
!       Q = QQ = rate of precipitation formation 
!              [cm3 H2O/cm3 air/s]
!                                                                             .
!       FMAX   = maximum value for F' 
!              = 0.3
!                                                                             .
!       DT     = dynamic time step from the CTM [s]
!                                                                             .
!       TAU    = duration of rainout event 
!              = 1800 s (30 min)
!                                                                             .
!       L + W  = condensed water content in cloud 
!              = 2.0e-6 [cm3 H2O/cm3 air]
!                                                                             .
!  K_RAIN and F' are needed to compute the fraction of tracer in grid box 
!  (I,J,L=LLPAR) lost to rainout.  This is done in module routine RAINOUT.
!                                                                             .
!  Washout:
!  ========   
!  Washout occurs when we have evaporation (or no precipitation at all) at 
!  grid box (I,J,L), but have rain coming down from grid box (I,J,L+1).
!
! !REVISION HISTORY: 
!  20 Sep 2010 - R. Yantosca - Initial version, based on WETDEP
!  28 Sep 2010 - H. Amos     - Now define Q, QDOWN directly from MERRA met
!  08 Oct 2010 - R. Yantosca - Adjusted OpenMP do loop
!  09-Dec-2010 - H. Amos     - Added PDOWN(L+1) > 0 to criterion for IS_WASHOUT
!  09-Dec-2010 - H. Amos     - SAFETY now prints PDOWN(L+1) instead of PDOWN(L)
!  31-Dec-2010 - H. Amos     - Clean up code, remove obsolete code
!  31-Dec-2010 - H. Amos     - Added comments
!  27 May 2011 - R. Yantosca - Now pass F_RAINOUT to DO_WASHOUT_ONLY
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      LOGICAL, SAVE      :: FIRST = .TRUE.
      LOGICAL            :: IS_Hg
      LOGICAL            :: AER
      LOGICAL            :: IS_RAINOUT, IS_WASHOUT, IS_BOTH
                         
      INTEGER            :: I, IDX, J, L, N, NN
                         
      REAL*8             :: Q,     QDOWN,  DT,        DT_OVER_TAU
      REAL*8             :: K,     K_MIN,  K_RAIN,    RAINFRAC
      REAL*8             :: F,     FTOP,   F_PRIME,   WASHFRAC
      REAL*8             :: LOST,  GAINED, MASS_WASH, MASS_NOWASH
      REAL*8             :: ALPHA, ALPHA2, WETLOSS,   TMP
      REAL*8             :: F_RAINOUT,     F_WASHOUT 

      ! DSTT is the accumulator array of rained-out 
      ! soluble tracer for a given (I,J) column
      REAL*8             :: DSTT(NSOL,LLPAR,IIPAR,JJPAR)
 
      CHARACTER(LEN=255) :: ERRMSG

      !=================================================================
      ! (1)  I n i t i a l i z e   V a r i a b l e s
      !=================================================================

      ! Is this a mercury simulation with dynamic online ocean?
      IS_Hg = ( ITS_A_MERCURY_SIM() .and. LDYNOCEAN )

      ! Dynamic timestep [s]
      DT    = GET_TS_DYN() * 60d0
      
      ! Select index for diagnostic arrays -- will archive either
      ! large-scale or convective rainout/washout fractions
      IF ( LS ) THEN
         IDX = 1
      ELSE
         IDX = 2
      ENDIF

      !=================================================================
      ! (2)  L o o p   O v e r   (I, J)   S u r f a c e   B o x e s
      !=================================================================
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I,           J,          FTOP,        L          )    
!$OMP+PRIVATE( NN,          ERRMSG,     F,           F_PRIME    )
!$OMP+PRIVATE( F_RAINOUT,   F_WASHOUT,  K_RAIN,      Q          )       
!$OMP+PRIVATE( QDOWN,       IS_RAINOUT, IS_WASHOUT,  N          ) 
!$OMP+SCHEDULE( DYNAMIC )   
      DO J = 1, JJPAR
      DO I = 1, IIPAR

         ! Zero FTOP
         FTOP = 0d0

         ! Zero accumulator array
         DO L  = 1, LLPAR
         DO NN = 1, NSOL
            DSTT(NN,L,I,J) = 0d0
         ENDDO
         ENDDO

         !==============================================================
         ! (3)  R a i n o u t   F r o m   T o p   L a y e r  (L = LLPAR) 
         !==============================================================

         ! Zero variables for this level
         ERRMSG      = 'RAINOUT: Top of atm'
         F           = 0d0
         F_PRIME     = 0d0
         F_RAINOUT   = 0d0      
         F_WASHOUT   = 0d0      
         K_RAIN      = 0d0
         Q           = 0d0     

         ! Start at the top of the atmosphere
         L = LLPAR

         ! If precip forms at (I,J,L), assume it all rains out
         IF ( QQ(L,I,J) > 0d0 ) THEN

            ! Q is the new precip that is forming within grid box (I,J,L)
            Q = QQ(L,I,J)

            ! Compute K_RAIN and F_RAINOUT for large-scale 
            ! precipitation (cf. Eqs. 11-13, Jacob et al, 2000) 
            K_RAIN  = LS_K_RAIN( Q )
            F_RAINOUT = LS_F_PRIME( Q, K_RAIN )
            
            ! Set F = F_RAINOUT, since there is no FTOP at L = LLPAR
            F = F_RAINOUT

            ! Only compute rainout if F > 0. 
            ! This helps to eliminate unnecessary CPU cycles.
            IF ( F > 0d0 ) THEN 
               CALL DO_RAINOUT_ONLY( LS,  I,      J,   L,   
     &                               IDX, ERRMSG, F,   K_RAIN, 
     &                               DT,  STT,    DSTT         )
            ENDIF

            ! Save FTOP for the next lower level 
            FTOP = F

         ENDIF         

         !==============================================================
         ! (4)  R a i n o u t   a n d   W a s h o u t 
         !      i n   t h e   M i d d l e   L e v e l s
         !==============================================================
         DO L = LLPAR-1, 2, -1

            ! Zero variables for each level
            F           = 0d0
            F_PRIME     = 0d0
            F_RAINOUT   = 0d0 
            F_WASHOUT   = 0d0 
            K_RAIN      = 0d0
            Q           = 0d0
            QDOWN       = 0d0

            ! If there is new precip forming w/in the grid box ...
            IF ( QQ(L,I,J) > 0d0 ) THEN

               ! Compute K_RAIN and F_RAINOUT for large-scale 
               ! precipitation (cf. Eqs. 11-13, Jacob et al, 2000) 
               ! F_RAINOUT is the fraction of grid box (I,J,L) 
               ! experiencing rainout.
               K_RAIN  = LS_K_RAIN( QQ(L,I,J) )
               F_PRIME = LS_F_PRIME( QQ(L,I,J), K_RAIN )
               
            ELSE
               
               F_PRIME = 0d0
 
            ENDIF

            ! The following block implements Qiaoqiao's changes
            ! Calculate the fractional areas subjected to rainout and
            ! washout. If PDOWN = 0, then all dissolved tracer returns
            ! to the atmosphere. (cdh, 7/13/10)
            IF ( PDOWN(L,I,J) > 0d0 ) THEN
               F_RAINOUT = F_PRIME
               ! Washout occurs where there is no rainout
               F_WASHOUT = MAX( FTOP - F_RAINOUT, 0d0 )
            ELSE
               F_RAINOUT = 0d0
               F_WASHOUT = 0d0
            ENDIF


            IF ( F_WASHOUT > 0d0 ) THEN    

               ! QDOWN is the precip leaving thru the bottom of box (I,J,L)
               ! Q     is the new precip that is forming within box (I,J,L)
               QDOWN = PDOWN(L,I,J)
               Q     = QQ(L,I,J)

               !  Define PDOWN and p
               IF ( F_RAINOUT > 0d0 ) THEN

                  ! The precipitation causing washout 
                  ! is the precip entering thru the top
                  QDOWN = PDOWN(L+1,I,J)            
                            
                  ! The amount of precipitating water entering from above 
                  ! which evaporates. If there is rainout (new precip
                  ! forming) then we have no way to estimate this, so assume
                  ! zero for now. Consequently there will be no resuspended
                  ! aerosol.
                  Q = 0d0
               ENDIF

            ENDIF 

            !-----------------------------------------------------------
            ! Determine if we have the following conditions:
            !
            ! (a) Rainout 
            ! (b) Washout 
            !
            ! Note that rainout and washout can happen in the same 
            ! grid box.
            !-----------------------------------------------------------

            ! If a non-zero fraction of the grid box is 
            ! experiencing rainout...
            IS_RAINOUT = ( F_RAINOUT > 0d0 )

            ! If a non-zero fraction of the grid box is 
            ! experiencing washout...
            IS_WASHOUT = ( F_WASHOUT > 0d0 )

            IF ( IS_RAINOUT ) THEN

               !--------------------------------------------------------
               ! RAINOUT 
               !--------------------------------------------------------

               ! Error msg for stdout
               ERRMSG = 'RAINOUT'

               ! Do rainout if we meet the above criteria
               CALL DO_RAINOUT_ONLY( LS,  I,      J,         L,   
     &                               IDX, ERRMSG, F_RAINOUT, K_RAIN,  
     &                               DT,  STT,    DSTT               )
            ENDIF  

            IF ( IS_WASHOUT ) THEN 

               !--------------------------------------------------------
               ! WASHOUT ONLY
               !--------------------------------------------------------

               ! Error msg for stdout
               ERRMSG = 'WASHOUT'

               ! Do the washout
               CALL DO_WASHOUT_ONLY( LS,        I,   J,     
     &                               L,         IDX, ERRMSG,   
     &                               QDOWN,     Q,   F_WASHOUT, 
     &                               F_RAINOUT, DT,  PDOWN,     
     &                               STT,       DSTT            )

            ENDIF

            !===========================================================
            ! (6)  N o   D o w n w a r d   P r e c i p i t a t i o n 
            !
            ! If there is no precipitation leaving grid box (I,J,L), 
            ! then  set F, the effective area of precipitation in grid 
            ! box (I,J,L), to zero.
            !
            ! Also, all of the previously rained-out tracer that is now 
            ! coming down from grid box (I,J,L+1) will evaporate and 
            ! re-enter the atmosphere in the gas phase in grid box 
            ! (I,J,L).  This is called "resuspension".
            !===========================================================

            ! Check if there is precip entering grid box, but not
            ! leaving grid box
            IF ( F_WASHOUT == 0d0 .and. F_RAINOUT == 0d0 ) THEN

               ! No precipitation at grid box (I,J,L), thus F = 0
               F = 0d0
               
               ! Error message
               ERRMSG = 'RESUSPENSION in middle levels'

               ! Re-evaporate all of the rain
               CALL DO_COMPLETE_REEVAP( LS,  I,      J,  L,  
     &                                  IDX, ERRMSG, DT, STT, DSTT  )
            ENDIF 

            ! Save FTOP for next level
            FTOP = F_RAINOUT + F_WASHOUT

         ENDDO               

         !==============================================================
         ! (7)  W a s h o u t   i n   L e v e l   1
         !==============================================================

         ! Zero variables for this level
         ERRMSG  = 'WASHOUT: at surface'
         F       = 0d0
         F_PRIME = 0d0
         K_RAIN  = 0d0
         Q       = 0d0
         QDOWN   = 0d0
         
         ! We are at the surface, set L = 1
         L = 1

         ! Washout at level 1 criteria
         IF ( PDOWN(L+1,I,J) > 0d0 ) THEN

            ! QDOWN is the precip leaving thru the bottom of box (I,J,L+1)
            QDOWN = PDOWN(L+1,I,J)

            ! Since no precipitation is forming within grid box (I,J,L),
            ! F' = 0, and F = MAX( F', FTOP ) reduces to F = FTOP.
            F = FTOP

            ! Only compute washout if F > 0.
            IF ( F > 0d0 ) THEN
               CALL DO_WASHOUT_AT_SFC( LS,  I,      J,     L,         
     &                                 IDX, ERRMSG, QDOWN, F,   
     &                                 DT,  STT,    DSTT      )
            ENDIF    
         ENDIF

         !==============================================================
         ! (8)  M e r c u r y   S i m u l a t i o n   O n l y 
         !
         ! For the mercury simulation, we need to archive the amt of 
         ! Hg2 [kg] that is scavenged out of the column.  Also applies
         ! to the tagged Hg simulation.
         !
         ! NOTES:
         ! (a) Now moved outside the loop above for clarity and to 
         !      fix a bug where HgP scavenging was not recorded. 
         ! (b) The values of DSTT in the first layer accumulates all 
         !      scavenging and washout in the column
         ! (c) Updates from cdh. (ccc, 5/17/10)
         !==============================================================
         IF ( IS_Hg ) THEN

            ! Loop over soluble tracers and/or aerosol tracers
            DO NN = 1, NSOL
               N = IDWETD(NN)

               ! Check if it is a gaseous Hg2 tag
               IF ( IS_Hg2( N ) ) THEN

                  CALL ADD_Hg2_WD      ( I, J, N, DSTT(NN,1,I,J) )
                  CALL ADD_Hg2_SNOWPACK( I, J, N, DSTT(NN,1,I,J) )

               ! Check if it is a HgP tag
               ELSE IF ( IS_HgP( N ) ) THEN
                  
                  CALL ADD_HgP_WD      ( I, J, N, DSTT(NN,1,I,J) )
                  CALL ADD_Hg2_SNOWPACK( I, J, N, DSTT(NN,1,I,J) )
                  
               ENDIF

            ENDDO
            
         ENDIF
         
      ENDDO	
      ENDDO	
!$OMP END PARALLEL DO

      END SUBROUTINE WETDEP_MERRA
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: ls_k_rain
!
! !DESCRIPTION: Function LS\_K\_RAIN computes K\_RAIN, the first order 
!  rainout rate constant for large-scale (a.k.a. stratiform) precipitation.
!\\
!\\
! !INTERFACE:
!
      FUNCTION LS_K_RAIN( Q ) RESULT( K_RAIN )
!
! !INPUT PARAMETERS: 
!
      REAL*8, INTENT(IN) :: Q        ! Rate of precipitation formation 
                                     !  [cm3 H2O/cm3 air/s]
!
! !RETURN VALUE:
!
      REAL*8             :: K_RAIN   ! 1st order rainout rate constant [1/s]
!
! !REVISION HISTORY: 
!  18 Mar 2004 - R. Yantosca - Initial version
!  (1 ) Now made into a MODULE routine since we cannot call internal routines
!        from w/in a parallel loop.  Updated comments. (bmy, 3/18/04)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !==================================================================
      ! LS_K_RAIN begins here!
      !==================================================================

      ! Compute rainout rate constant K in s^-1 (Eq. 12, Jacob et al, 2000).
      ! 1.0d-4 = K_MIN, a minimum value for K_RAIN 
      ! 1.5d-6 = L + W, the condensed water content (liq + ice) in the cloud
      K_RAIN = 1.0d-4 + ( Q / 1.5d-6 ) 
      
      END FUNCTION LS_K_RAIN
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: ls_f_prime
!
! !DESCRIPTION: Function LS\_F\_PRIME computes F', the fraction of the 
!  grid box that is precipitating during large scale (a.k.a. stratiform) 
!  precipitation.
!\\
!\\
! !INTERFACE:
!
      FUNCTION LS_F_PRIME( Q, K_RAIN ) RESULT( F_PRIME )
!
! !INPUT PARAMETERS: 
!
      REAL*8, INTENT(IN) :: Q         ! Rate of precipitation formation 
                                      !  [cm3 H2O/cm3 air/s]
      REAL*8, INTENT(IN) :: K_RAIN    ! 1st order rainout rate constant [1/s]
!
! !REMARKS:
! 
      REAL*8             :: F_PRIME   ! Fraction of grid box undergoing 
                                      !  large-scale precipitation [unitless]
! 
! !REVISION HISTORY: 
!  18 Mar 2004 - R. Yantosca - Initial version
!  (1 ) Now made into a MODULE routine since we cannot call internal routines
!        from w/in a parallel loop.  Updated comments. (bmy, 3/18/04)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! LS_F_PRIME begins here!
      !=================================================================

      ! Compute F', the area of the grid box undergoing precipitation
      ! 1.5d-6 = L + W, the condensed water content [cm3 H2O/cm3 air]
      F_PRIME = Q / ( K_RAIN * 1.5d-6 )

      END FUNCTION LS_F_PRIME
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: conv_f_prime
!
! !DESCRIPTION: Function CONV\_F\_PRIME computes F', the fraction of the 
!  grid box that is precipitating during convective precipitation.
!\\
!\\
! !INTERFACE:
!
      FUNCTION CONV_F_PRIME( Q, K_RAIN, DT ) RESULT( F_PRIME )
!
! !INPUT PARAMETERS: 
!
      REAL*8, INTENT(IN) :: Q         ! Rate of precipitation formation 
                                      !  [cm3 H2O/cm3 air/s]
      REAL*8, INTENT(IN) :: K_RAIN    ! 1st order rainout rate constant [1/s]
      REAL*8, INTENT(IN) :: DT        ! Wet deposition timestep [s]
!
! !RETURN VALUE:
!
      REAL*8             :: F_PRIME   ! Frac. of grid box undergoing
                                      !  convective precipitation [unitless]
! 
! !REVISION HISTORY: 
!  18 Mar 2004 - R. Yantosca - Initial version
!  (1 ) Now made into a MODULE routine since we cannot call internal routines
!        from w/in a parallel loop.  Updated comments. (bmy, 3/18/04)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      REAL*8 :: TIME

      !=================================================================
      ! CONV_F_PRIME begins here!
      !=================================================================
      
      ! Assume the rainout event happens in 30 minutes (1800 s)
      ! Compute the minimum of DT / 1800s and 1.0
      TIME = MIN( DT / 1800d0, 1d0 )

      ! Compute F' for convective precipitation (Eq. 13, Jacob et al, 2000)
      ! 0.3  = FMAX, the maximum value of F' for convective precip
      ! 2d-6 = L + W, the condensed water content [cm3 H2O/cm3 air]
      F_PRIME = ( 0.3d0 * Q * TIME ) / 
     &          ( ( Q * TIME ) + ( 0.3d0 * K_RAIN * 2d-6 ) )

      END FUNCTION CONV_F_PRIME
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_rainout_only
!
! !DESCRIPTION: Subroutine DO\_RAINOUT\_ONLY removes tracer by rainout.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE DO_RAINOUT_ONLY( LS,  I,      J,         L,   
     &                            IDX, ERRMSG, F_RAINOUT, K_RAIN, 
     &                            DT,  STT,    DSTT               )
!
! !USES:
!
      USE DAO_MOD,     ONLY : BXHEIGHT                 ! Grid box height [m]
      USE DIAG_MOD,    ONLY : AD16                     ! ND16 diag array
      USE DIAG_MOD,    ONLY : AD17                     ! ND17 diag array
      USE DIAG_MOD,    ONLY : AD39                     ! ND39 diag array
      USE DIAG_MOD,    ONLY : CT16                     ! ND16 diag counter
      USE DIAG_MOD,    ONLY : CT17                     ! ND17 diag counter
      USE ERROR_MOD,   ONLY : IT_IS_NAN                ! Test for NaN
      USE LOGICAL_MOD, ONLY : LGTMM                    ! Use GTMM for Hg sim?

#     include "CMN_SIZE"                               ! Size parameters
#     include "CMN_DIAG"                               ! Diagnostic flags etc
!
! !INPUT PARAMETERS: 
!     
      LOGICAL,          INTENT(IN)    :: LS            ! =T denotes LS precip
      INTEGER,          INTENT(IN)    :: I             ! Longitude index
      INTEGER,          INTENT(IN)    :: J             ! Latitude index
      INTEGER,          INTENT(IN)    :: L             ! Level index
      INTEGER,          INTENT(IN)    :: IDX           ! ND38 index
      REAL*8,           INTENT(IN)    :: F_RAINOUT     ! Fraction of grid box 
                                                       !  undergoing rainout
      REAL*8,           INTENT(IN)    :: K_RAIN        ! Rainout constant
      REAL*8,           INTENT(IN)    :: DT            ! Rainout timestep [s]
      CHARACTER(LEN=*), INTENT(IN)    :: ERRMSG        ! Error message
!
! !INPUT/OUTPUT PARAMETERS: 
!
      REAL*8,           INTENT(INOUT) :: STT (:,:,:,:) ! Tracer array [kg]
      REAL*8,           INTENT(INOUT) :: DSTT(:,:,:,:) ! Accumulator array [kg]
! 
! !REMARKS:
!  The modifications for the MERRA met fields require calling this same 
!  sequence of code more than once.  The expedient solution was to just move
!  the relevant code into this this subroutine.
!                                                                             .
!  An IF statement in WETDEP decides if this rainout is to be done (and thus
!  if this routine will be called.  The criteria for rainout is:
!                                                                             .
!  FOR MERRA MET FIELDS: 
!     There is rainout if there is new precip formation in the grid box 
!     (i.e. DQRLSAN(I,J,L) > 0) and the fraction of the grid box experiencing 
!     rainout (i.e. F_RAINOUT) is greater than or equal to the fraction of 
!     the grid box directly overhead experiencing precip (i.e. FTOP).
!        -- Helen Amos (9/10/10)
!                                                                             .
!  FOR ALL OTHER MET FIELDS:
!     We use a simple test: if the rainout fraction in this grid box 
!     (i.e. F_RAINOUT) is nonzero, do rainout.  Don't compare to the grid 
!     box immediately above us (i.e. FTOP).
!
! !REVISION HISTORY: 
!  16 Sep 2010 - R. Yantosca - Initial version
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER :: N,        NN
      REAL*8  :: RAINFRAC, WETLOSS

      !=================================================================
      ! DO_RAINOUT_ONLY begins here!
      !=================================================================

      ! ND16 diagnostic...save F 
      IF ( ND16 > 0 .and. L <= LD16 ) THEN
         AD16(I,J,L,IDX) = AD16(I,J,L,IDX) + F_RAINOUT
         CT16(I,J,L,IDX) = CT16(I,J,L,IDX) + 1 
      ENDIF

      ! ND17 diagnostic...increment counter
      IF ( ND17 > 0 .and. L <= LD17 ) THEN
         CT17(I,J,L,IDX) = CT17(I,J,L,IDX) + 1
      ENDIF

      !-----------------------------------------------------------------
      ! Loop over all wet deposition species
      !-----------------------------------------------------------------
      DO NN = 1, NSOL

         ! Tracer # corresponding to wetdep species #
         N = IDWETD(NN)
                  
         ! Call subroutine RAINOUT to comptue the fraction
         ! of tracer lost to rainout in grid box (I,J,L) 
         CALL RAINOUT( I, J, L, N, K_RAIN, DT, F_RAINOUT, RAINFRAC )

         ! WETLOSS is the amount of tracer in grid box 
         ! (I,J,L) that is lost to rainout.
         WETLOSS = STT(I,J,L,N) * RAINFRAC

         ! Subtract the rainout loss in grid box (I,J,L) from STT
         STT(I,J,L,N) = STT(I,J,L,N) - WETLOSS

         IF ( L == LLPAR ) THEN
           
            ! DSTT is an accumulator array for rained-out tracers.  
            ! The tracers in DSTT are in the liquid phase and will 
            ! precipitate to the levels below until a washout occurs.
            ! Initialize DSTT at (I,J,L=LLPAR) with WETLOSS.
            DSTT(NN,L,I,J) = WETLOSS

         ELSE
                                 
            ! Add to DSTT the tracer lost to rainout in grid box        
            ! (I,J,L) plus the tracer lost to rainout from grid box 
            ! (I,J,L+1), which has by now precipitated down into 
            ! grid box (I,J,L).  DSTT will continue to accumulate 
            ! rained out tracer in this manner until a washout 
            ! event occurs.
            DSTT(NN,L,I,J) = DSTT(NN,L+1,I,J) + WETLOSS

         ENDIF

         !--------------------------------------------------------------
         ! Archive diagnostics for each tracer
         !--------------------------------------------------------------

         ! ND17 diagnostic...rainout fractions [unitless]
         IF ( ND17 > 0 .and. L <= LD17 ) THEN
            AD17(I,J,L,NN,IDX) = 
     &           AD17(I,J,L,NN,IDX) + RAINFRAC / F_RAINOUT
         ENDIF

         ! ND39 diag -- save rainout losses in [kg/s]
         ! Add LGTMM in condition for AD39 (ccc, 11/18/09)
         IF ( ( ND39 > 0 .or. LGTMM ) .and. L <= LD39 ) THEN
            AD39(I,J,L,NN) = AD39(I,J,L,NN) + WETLOSS / DT
         ENDIF

         !--------------------------------------------------------------
         ! Error checks
         !--------------------------------------------------------------
         IF ( IT_IS_NAN( STT(I,J,L,N) )   .or.
     &        STT(I,J,L,N)   < 0d0        .or.
     &        DSTT(NN,L,I,J) < 0d0      ) THEN

            ! Print error message and stop simulaton
            CALL SAFETY( I, J, L, N, ERRMSG,
     &                   LS          = LS,             
     &                   PDOWN       = PDOWN(L,I,J),  
     &                   QQ          = QQ(L,I,J),      
     &                   ALPHA       = 0d0,       
     &                   ALPHA2      = 0d0,         
     &                   RAINFRAC    = RAINFRAC,     
     &                   WASHFRAC    = 0d0, 
     &                   MASS_WASH   = 0d0,
     &                   MASS_NOWASH = 0d0,
     &                   WETLOSS     = WETLOSS,
     &                   GAINED      = 0d0,         
     &                   LOST        = 0d0,         
     &                   DSTT        = DSTT(NN,:,I,J), 
     &                   STT         = STT(I,J,:,N)     )
         ENDIF
      ENDDO

      END SUBROUTINE DO_RAINOUT_ONLY
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_washout_only
!
! !DESCRIPTION: Subroutine DO\_WASHOUT\_ONLY removes tracer by washout.
!\\
!\\
!  The modifications for the MERRA met fields require calling this same 
!  sequence of code more than once.  The expedient solution was to just move
!  the relevant code into this this subroutine.

!\\
!\\
! !INTERFACE:
!
      SUBROUTINE DO_WASHOUT_ONLY( LS,        I,         J,      L,         
     &                            IDX,       ERRMSG,    QDOWN,  Q,    
     &                            F_WASHOUT, F_RAINOUT, DT,     PDOWN,  
     &                            STT,       DSTT,      REEVAP        )
!
! !USES:
!
      USE DAO_MOD,      ONLY : T                       ! air temperature [K]
      USE DAO_MOD,      ONLY : BXHEIGHT                ! Grid box height [m]  
      USE DAO_MOD,      ONLY : REEVAPLS                ! Evap of precip'ing
                                                       !  LS+anvil cloud
                                                       !  condensate [kg/kg/s]
      USE DIAG_MOD,     ONLY : AD16                    ! ND16 diag array
      USE DIAG_MOD,     ONLY : AD17                    ! ND17 diag array
      USE DIAG_MOD,     ONLY : AD18                    ! ND18 diag array
      USE DIAG_MOD,     ONLY : AD39                    ! ND39 diag array
      USE DIAG_MOD,     ONLY : CT16                    ! ND16 diag counter
      USE DIAG_MOD,     ONLY : CT17                    ! ND17 diag counter
      USE DIAG_MOD,     ONLY : CT18                    ! ND18 diag counter
      USE ERROR_MOD,    ONLY : IT_IS_NAN               ! Test for NaN
      USE TRACERID_MOD, ONLY : IDTSO2                  ! ID flag for SO2
      USE TRACERID_MOD, ONLY : IDTSO4                  ! ID flag for SO4
      USE LOGICAL_MOD,  ONLY : LGTMM                   ! Use GTMM w/ Hg sim?
      USE ERROR_MOD,    ONLY : IT_IS_NAN               ! Check for NaN 

#     include "CMN_SIZE"                               ! Size parameters
#     include "CMN_DIAG"                               ! Diagnostic flags, etc
!
! !INPUT PARAMETERS: 
!     
      LOGICAL,OPTIONAL, INTENT(IN)    :: REEVAP        ! Do re-evaporation?
      LOGICAL,          INTENT(IN)    :: LS            ! =T denotes LS precip
      INTEGER,          INTENT(IN)    :: I             ! Longitude index
      INTEGER,          INTENT(IN)    :: J             ! Latitude index
      INTEGER,          INTENT(IN)    :: L             ! Level index
      INTEGER,          INTENT(IN)    :: IDX           ! ND38 index
      CHARACTER(LEN=*), INTENT(IN)    :: ERRMSG        ! Error message
      REAL*8,           INTENT(IN)    :: QDOWN         ! Precip leaving thru
                                                       !  bottom of box (I,J,L)
      REAL*8,           INTENT(IN)    :: Q             ! New precip forming
                                                       !  in box (I,J,L)
      REAL*8,           INTENT(IN)    :: F_WASHOUT     ! Fraction of grid box 
                                                       !  undergoing washout
      REAL*8,           INTENT(IN)    :: F_RAINOUT     ! Fraction of grid box 
                                                       !  undergoing rainout
      REAL*8,           INTENT(IN)    :: DT            ! Rainout timestep [s]
      REAL*8,           INTENT(IN)    :: PDOWN(:,:,:)  ! Precip 
!
! !INPUT/OUTPUT PARAMETERS: 
!
      REAL*8,           INTENT(INOUT) :: STT (:,:,:,:) ! Tracer array [kg]
      REAL*8,           INTENT(INOUT) :: DSTT(:,:,:,:) ! Accumulator array [kg]
! 
! !REMARKS:
!  A fraction ALPHA of the raindrops falling down from grid 
!  box (I,J,L+1) to grid box (I,J,L) will evaporate along the 
!  way.  ALPHA is given by:
!   
!             precip leaving (I,J,L+1) - precip leaving (I,J,L)
!   ALPHA = ---------------------------------------------------
!                      precip leaving (I,J,L+1)
! 
! 
!                     -QQ(L,I,J) * DZ(I,J,L)
!         =         --------------------------
!                         PDOWN(L+1,I,J)
! 
!  We assume that a fraction ALPHA2 = 0.5 * ALPHA of the 
!  previously rained-out aerosols and HNO3 coming down from 
!  level (I,J,L+1) will evaporate and re-enter the atmosphere 
!  in the gas phase in grid box (I,J,L).  This process is 
!  called "resuspension".  
! 
!  For non-aerosol species, the amount of previously rained 
!  out mass coming down from grid box (I,J,L+1) to grid box 
!  (I,J,L) is figured into the total mass available for 
!  washout in grid box (I,J,L).  We therefore do not have to
!  use the fraction ALPHA2 to compute the resuspension.
! 
!  NOTE from Hongyu Liu about ALPHA (hyl, 2/29/00)
!  =============================================================
!  If our QQ field was perfect, the evaporated amount in grid 
!  box (I,J,L) would be at most the total rain amount coming 
!  from above (i.e. PDOWN(I,J,L+1) ). But this is not true for 
!  the MOISTQ field we are using.  Sometimes the evaporation in 
!  grid box (I,J,L) can be more than the rain amount from above.  
!  The reason is our "evaporation" also includes the effect of 
!  cloud detrainment.  For now we cannot find a way to 
!  distinguish betweeen the two. We then decided to release 
!  aerosols in both the detrained air and the evaporated air. 
! 
!  Therefore, we should use this term in the numerator:
!  
!                 -QQ(I,J,L) * BXHEIGHT(I,J,L) 
! 
!  instead of the term:
!  
!                 PDOWN(L+1)-PDOWN(L)
! 
!  Recall that in make_qq.f we have restricted PDOWN to 
!  positive values, otherwise, QQ would be equal to 
!  PDOWN(L+1)-PDOWN(L).           
! 
!
! !REVISION HISTORY: 
!  16 Sep 2010 - R. Yantosca - Initial version
!  20 Sep 2010 - R. Yantosca - Update definition of ALPHA if we are doing
!                              partial re-evaporation.
!  28 Sep 2010 - H. Amos     - Now check for NaN's with function IT_IS_NAN
!  31 Dec 2010 - H. Amos     - new variable, TK, for temperature
!  26 May 2011 - R. Yantosca - Bug fix: Only apply the error trap for the
!                              condition WASHFRAC < 1d-3 for MERRA met
!  25 May 2011 - Q. Wang     - new variable, TF, for total precip fraction
!  25 May 2011 - Q. Wang     - Also pass F_RAINOUT via the arg list
!  25 May 2011 - Q. Wang     - Correct the washfrac to make sure that washout 
!                              is applied the area of F_washout instead of 
!                              total area of (F_washout+F_rainout)
!  27 May 2011 - R. Yantosca - Added comments, readjusted IF statements to 
!                              avoid floating-point problems
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      LOGICAL :: AER,       DO_REEVAP
      INTEGER :: N,         NN
      REAL*8  :: ALPHA,     ALPHA2,      GAINED,   LOST
      REAL*8  :: MASS_WASH, MASS_NOWASH, WASHFRAC, WETLOSS
      REAL*8  :: TK,        TF  

      !=================================================================
      ! DO_WASHOUT_ONLY begins here!
      !=================================================================

      ! ND16 diagnostic...save F (fraction of grid box raining)
      IF ( ND16 > 0d0 .and. L <= LD16 ) THEN
         AD16(I,J,L,IDX) = AD16(I,J,L,IDX) + F_WASHOUT
         CT16(I,J,L,IDX) = CT16(I,J,L,IDX) + 1
      ENDIF

      ! ND18 diagnostic...increment counter
      IF ( ND18 > 0 .and. L <= LD18 ) THEN
         CT18(I,J,L,IDX) = CT18(I,J,L,IDX) + 1
      ENDIF

      ! air temperature [K]
      TK  = T(I,J,L)   

      ! TOTAL precipitation fraction
      TF  = F_WASHOUT + F_RAINOUT

      !-----------------------------------------------------------------
      ! Loop over all wet deposition species
      !-----------------------------------------------------------------
      DO NN = 1, NSOL

         ! zero local variables
         ALPHA       = 0d0
         ALPHA2      = 0d0
         WASHFRAC    = 0d0
         MASS_WASH   = 0d0
         MASS_NOWASH = 0d0
         WETLOSS     = 0d0
         GAINED      = 0d0
         LOST        = 0d0

         ! Tracer # corresponding to each wetdep species #
         N  = IDWETD(NN)

         ! Call WASHOUT to compute the fraction of 
         ! tracer lost to washout in grid box (I,J,L)
         CALL WASHOUT( L,         N,            BXHEIGHT(I,J,L), 
     &                 TK,        QDOWN,        DT,   
     &                 TF,        H2O2s(I,J,L), SO2s(I,J,L), 
     &                 WASHFRAC,  AER )

#if    defined( MERRA )
         !%%% BUG FIX: Only apply this section of when running
         !%%% GEOS-Chem with MERRA met fields.  (bmy, hamos, 5/26/11)
         !
         ! Check if WASHFRAC = NaN or WASHFRAC < 0.1 %
         ! 
         ! If WASHFRAC = NaN, then DSTT = NaN and SAFETY trips because 
         ! tracer concentrations must be finite.WASHFRAC = NaN when F = 0. 
         ! When less than 0.1% of a soluble tracer is available for washout
         ! DSTT < 0 and SAFETY trips.  (Helen Amos, 20100928)
         IF ( IT_IS_NAN( WASHFRAC ) ) THEN
            CYCLE
         ELSEIF ( WASHFRAC < 1D-3 ) THEN
            CYCLE
         ENDIF
#endif

         ! Adjust WASHFRAC accordingly for aerosols.  NOTE: TF is always 
         ! > 0 since DO_WASHOUT_ONLY is only called if F_WASHOUT > 0.  
         ! We will never get a div-by-zero error here. (bmy, 5/27/11)
         IF ( AER ) THEN
            WASHFRAC = WASHFRAC / TF * F_WASHOUT
         ENDIF
                  
         !--------------------------------------------------------------
         ! Washout of aerosol tracers -- 
         ! this is modeled as a kinetic process
         !--------------------------------------------------------------

         IF ( AER ) THEN

            ! Define ALPHA, the fraction of the raindrops that 
            ! re-evaporate when falling from (I,J,L+1) to (I,J,L)
            ALPHA = ( ABS( Q ) * BXHEIGHT(I,J,L) * 100d0 )
     &            / ( PDOWN(L+1,I,J)                     )

            ! Restrict ALPHA to be less than 1 (>1 is unphysical)
            ! (hma, 24-Dec-2010)
            ! NOTE: GEOS-5 should not produce any ALPHA > 1.
            IF ( ALPHA > 1d0 ) THEN 
               ALPHA = 1d0
            ENDIF

            ! ALPHA2 is the fraction of the rained-out aerosols
            ! that gets resuspended in grid box (I,J,L)
            ALPHA2  = 0.5d0 * ALPHA

            ! GAINED is the rained out aerosol coming down from 
            ! grid box (I,J,L+1) that will evaporate and re-enter 
            ! the atmosphere in the gas phase in grid box (I,J,L).
            GAINED  = DSTT(NN,L+1,I,J) * ALPHA2

            ! Amount of aerosol lost to washout in grid box
            ! (qli, bmy, 10/29/02)
            WETLOSS = STT(I,J,L,N) * WASHFRAC - GAINED

            ! Remove washout losses in grid box (I,J,L) from STT.
            ! Add the aerosol that was reevaporated in (I,J,L).
            ! SO2 in sulfate chemistry is wet-scavenged on the
            ! raindrop and converted to SO4 by aqeuous chem.
            ! If evaporation occurs then SO2 comes back as SO4
            ! (rjp, bmy, 3/23/03)
            IF ( N == IDTSO2 ) THEN
               STT(I,J,L,IDTSO4) = STT(I,J,L,IDTSO4) 
     &                           + GAINED * 96D0 / 64D0

               STT(I,J,L,N)      = STT(I,J,L,N) *
     &                                          ( 1d0 - WASHFRAC )
            ELSE
               STT(I,J,L,N)      = STT(I,J,L,N) - WETLOSS
            ENDIF

            ! LOST is the rained out aerosol coming down from
            ! grid box (I,J,L+1) that will remain in the liquid
            ! phase in grid box (I,J,L) and will NOT re-evaporate.
            LOST = DSTT(NN,L+1,I,J) - GAINED

            ! Add the washed out tracer from grid box (I,J,L) to 
            ! DSTT.  Also add the amount of tracer coming down
            ! from grid box (I,J,L+1) that does NOT re-evaporate.
            !---------------------------------------------------------------
            ! Prior to 5/27/11:
            ! Restructure IF statement to avoid floating point errors
            ! (bmy, 5/27/11)
            !IF ( F_RAINOUT == 0D0 ) THEN 
            !   DSTT(NN,L,I,J) = DSTT(NN,L+1,I,J) + WETLOSS
            !ELSE
            !   DSTT(NN,L,I,J) = DSTT(NN,L,I,J) + WETLOSS
            !ENDIF
            !---------------------------------------------------------------
            IF ( F_RAINOUT > 0d0 ) THEN 
               DSTT(NN,L,I,J) = DSTT(NN,L,  I,J) + WETLOSS
            ELSE
               DSTT(NN,L,I,J) = DSTT(NN,L+1,I,J) + WETLOSS
            ENDIF

            ! ND18 diagnostic...divide washout fraction by F
            IF ( ND18 > 0 .and. L <= LD18 ) THEN
               AD18(I,J,L,NN,IDX) = 
     &         AD18(I,J,L,NN,IDX) + ( WASHFRAC / F_WASHOUT )
            ENDIF

         !--------------------------------------------------------------
         ! Washout of non-aerosol tracers
         ! This is modeled as an equilibrium process
         !--------------------------------------------------------------
         ELSE
                  
            ! MASS_NOWASH is the amount of non-aerosol tracer in 
            ! grid box (I,J,L) that is NOT available for washout.
            MASS_NOWASH = ( 1d0 - F_WASHOUT ) * STT(I,J,L,N)
               
            ! MASS_WASH is the total amount of non-aerosol tracer
            ! that is available for washout in grid box (I,J,L).
            ! It consists of the mass in the precipitating
            ! part of box (I,J,L), plus the previously rained-out
            ! tracer coming down from grid box (I,J,L+1).
            ! (Eq. 15, Jacob et al, 2000).
            MASS_WASH = ( F_WASHOUT*STT(I,J,L,N) ) + DSTT(NN,L+1,I,J)

            ! WETLOSS is the amount of tracer mass in 
            ! grid box (I,J,L) that is lost to washout.
            ! (Eq. 16, Jacob et al, 2000)
            WETLOSS = MASS_WASH * WASHFRAC -DSTT(NN,L+1,I,J)

            ! The tracer left in grid box (I,J,L) is what was
            ! in originally in the non-precipitating fraction 
            ! of the box, plus MASS_WASH, less WETLOSS. 
            STT(I,J,L,N) = STT(I,J,L,N) - WETLOSS  
            
            ! Add washout losses in grid box (I,J,L) to DSTT 
            !-------------------------------------------------------------
            ! Prior to 5/27/11:
            ! Restructure IF statement to avoid floating point errors.
            ! (bmy, 5/27/11)
            !IF ( F_RAINOUT == 0d0 )THEN 
            !   DSTT(NN,L,I,J) = DSTT(NN,L+1,I,J) + WETLOSS
            !ELSE
            !   DSTT(NN,L,I,J) = DSTT(NN,L,I,J)   + WETLOSS
            !ENDIF
            !-------------------------------------------------------------
            IF ( F_RAINOUT > 0d0 ) THEN
               DSTT(NN,L,I,J) = DSTT(NN,L,  I,J) + WETLOSS
            ELSE
               DSTT(NN,L,I,J) = DSTT(NN,L+1,I,J) + WETLOSS
            ENDIF

            ! ND18 diagnostic...we don't have to divide the
            ! washout fraction by F since this is accounted for.
            IF ( ND18 > 0 .and. L <= LD18 ) THEN
               AD18(I,J,L,NN,IDX) = 
     &         AD18(I,J,L,NN,IDX) + WASHFRAC
            ENDIF
         ENDIF

         ! ND39 diag -- save rainout losses in [kg/s]
         ! Add LGTMM in condition for AD39 (ccc, 11/18/09)
         IF ( ( ND39 > 0 .or. LGTMM ) .and. L <= LD39 ) THEN
            AD39(I,J,L,NN) = AD39(I,J,L,NN) + WETLOSS / DT
         ENDIF
  
         !--------------------------------------------------------------
         ! Error checks
         !--------------------------------------------------------------
         IF ( IT_IS_NAN( STT(I,J,L,N) )   .or.
     &        STT(I,J,L,N)   < 0d0        .or. 
     &        DSTT(NN,L,I,J) < 0d0      ) THEN

            ! Print error message and stop simulaton
            CALL SAFETY( I, J, L, N, ERRMSG,
     &                   LS          = LS,           
     &                   PDOWN       = PDOWN(L+1,I,J),  
     &                   QQ          = QQ(L,I,J),      
     &                   ALPHA       = ALPHA,       
     &                   ALPHA2      = ALPHA2,         
     &                   RAINFRAC    = 0d0,     
     &                   WASHFRAC    = WASHFRAC, 
     &                   MASS_WASH   = MASS_WASH,
     &                   MASS_NOWASH = MASS_NOWASH,
     &                   WETLOSS     = WETLOSS,
     &                   GAINED      = GAINED,         
     &                   LOST        = LOST,         
     &                   DSTT        = DSTT(NN,:,I,J), 
     &                   STT         = STT(I,J,:,N)     )
         ENDIF
      ENDDO  
 
      END SUBROUTINE DO_WASHOUT_ONLY
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_complete_reevap
!
! !DESCRIPTION: Subroutine DO\_COMPLETE\_REEVAP re-evaporates all of the
!  soluble tracer back into the atmosphere.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE DO_COMPLETE_REEVAP( LS, I,   J, 
     &                               L,  IDX, ERRMSG, 
     &                               DT, STT, DSTT  )
!
! !USES:
!
      USE DAO_MOD,      ONLY : BXHEIGHT                ! Grid box height [m]  
      USE DIAG_MOD,     ONLY : AD16                    ! ND16 diag array
      USE DIAG_MOD,     ONLY : AD17                    ! ND17 diag array
      USE DIAG_MOD,     ONLY : AD18                    ! ND18 diag array
      USE DIAG_MOD,     ONLY : AD39                    ! ND39 diag array
      USE DIAG_MOD,     ONLY : CT16                    ! ND16 diag counter
      USE DIAG_MOD,     ONLY : CT17                    ! ND17 diag counter
      USE DIAG_MOD,     ONLY : CT18                    ! ND18 diag counter
      USE ERROR_MOD,    ONLY : IT_IS_NAN               ! Test for NaN
      USE TRACERID_MOD, ONLY : IDTSO2                  ! ID flag for SO2
      USE TRACERID_MOD, ONLY : IDTSO4                  ! ID flag for SO4
      USE LOGICAL_MOD,  ONLY : LGTMM                   ! Use GTMM w/ Hg sim?

#     include "CMN_SIZE"                               ! Size parameters
#     include "CMN_DIAG"                               ! Diagnostic flags, etc
!
! !INPUT PARAMETERS: 
!     
      LOGICAL,          INTENT(IN)    :: LS            ! =T denotes LS precip
      INTEGER,          INTENT(IN)    :: I             ! Longitude index
      INTEGER,          INTENT(IN)    :: J             ! Latitude index
      INTEGER,          INTENT(IN)    :: L             ! Level index
      INTEGER,          INTENT(IN)    :: IDX           ! ND38 index
      CHARACTER(LEN=*), INTENT(IN)    :: ERRMSG        ! Error message
      REAL*8,           INTENT(IN)    :: DT            ! Rainout timestep [s]
!
! !INPUT/OUTPUT PARAMETERS: 
!
      REAL*8,           INTENT(INOUT) :: STT (:,:,:,:) ! Tracer array [kg]
      REAL*8,           INTENT(INOUT) :: DSTT(:,:,:,:) ! Accumulator array [kg]
! 
! !REMARKS:
!  The modifications for the MERRA met fields require calling this same 
!  sequence of code more than once.  The expedient solution was to just move
!  the relevant code into this this subroutine.
!
! !REVISION HISTORY: 
!  16 Sep 2010 - R. Yantosca - Initial version
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER :: N, NN
      REAL*8  :: WETLOSS

      !=================================================================
      ! DO_COMPLETE_REEVAP begins here!
      !=================================================================

      ! Loop over wetdep species
      DO NN = 1, NSOL
 
         ! Tracer # corresponding to the wetdep species #
         N = IDWETD(NN) 

         ! WETLOSS is the amount of tracer in grid box (I,J,L) 
         ! that is lost to rainout. (qli, bmy, 10/29/02)
         WETLOSS = -DSTT(NN,L+1,I,J)

         ! All of the rained-out tracer coming from grid box
         ! (I,J,L+1) goes back into the gas phase at (I,J,L)
         ! In evap, SO2 comes back as SO4 (rjp, bmy, 3/23/03)
         IF ( N == IDTSO2 ) THEN
            STT(I,J,L,IDTSO4) = STT(I,J,L,IDTSO4) 
     &                        - ( WETLOSS * 96d0 / 64d0 )
         ELSE
            STT(I,J,L,N)      = STT(I,J,L,N) - WETLOSS
         ENDIF

         ! There is nothing rained out/washed out in grid box
         ! (I,J,L), so set DSTT at grid box (I,J,L) to zero.
	 DSTT(NN,L,I,J) = 0d0
         
         !--------------------------------------------------------------
         ! Diagnostics
         !--------------------------------------------------------------

         ! ND39 diag -- save rainout losses in [kg/s]
         ! Add LGTMM in condition for AD39 (ccc, 11/18/09)
         IF ( ( ND39 > 0 .or. LGTMM ) .and. L <= LD39 ) THEN
            AD39(I,J,L,NN) = AD39(I,J,L,NN) + ( WETLOSS / DT )
         ENDIF

         !--------------------------------------------------------------
         ! Error checks
         !--------------------------------------------------------------
         IF ( IT_IS_NAN( STT(I,J,L,N) )   .or.
     &        STT(I,J,L,N)   < 0d0        .or. 
     &        DSTT(NN,L,I,J) < 0d0      ) THEN

            ! Print error message and stop simulaton
            CALL SAFETY( I, J, L, N, ERRMSG,
     &                   LS          = LS,             
     &                   PDOWN       = 0d0,
     &                   QQ          = 0d0,      
     &                   ALPHA       = 0d0,       
     &                   ALPHA2      = 0d0,         
     &                   RAINFRAC    = 0d0,     
     &                   WASHFRAC    = 0d0, 
     &                   MASS_WASH   = 0d0,
     &                   MASS_NOWASH = 0d0,
     &                   WETLOSS     = WETLOSS,
     &                   GAINED      = 0d0,         
     &                   LOST        = 0d0,         
     &                   DSTT        = DSTT(NN,:,I,J), 
     &                   STT         = STT(I,J,:,N)     )
         ENDIF
      ENDDO

      END SUBROUTINE DO_COMPLETE_REEVAP
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_washout_at_sfc
!
! !DESCRIPTION: Subroutine DO\_WASHOUT_AT\_SFC washes out the tracer 
!  at the surface.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE DO_WASHOUT_AT_SFC( LS,  I,      J,     L,         
     &                              IDX, ERRMSG, QDOWN, F,   
     &                              DT,  STT,    DSTT      )
!
! !USES:
!
      USE DAO_MOD,      ONLY : T                       ! air temperature [K]
      USE DAO_MOD,      ONLY : BXHEIGHT                ! Grid box height [m]  
      USE DIAG_MOD,     ONLY : AD16                    ! ND16 diag array
      USE DIAG_MOD,     ONLY : AD17                    ! ND17 diag array
      USE DIAG_MOD,     ONLY : AD18                    ! ND18 diag array
      USE DIAG_MOD,     ONLY : AD39                    ! ND39 diag array
      USE DIAG_MOD,     ONLY : CT16                    ! ND16 diag counter
      USE DIAG_MOD,     ONLY : CT17                    ! ND17 diag counter
      USE DIAG_MOD,     ONLY : CT18                    ! ND18 diag counter
      USE ERROR_MOD,    ONLY : IT_IS_NAN               ! Test for NaN
      USE TRACERID_MOD, ONLY : IDTSO2                  ! ID flag for SO2
      USE TRACERID_MOD, ONLY : IDTSO4                  ! ID flag for SO4
      USE LOGICAL_MOD,  ONLY : LGTMM                   ! Use GTMM w/ Hg sim?

#     include "CMN_SIZE"                               ! Size parameters
#     include "CMN_DIAG"                               ! Diagnostic flags, etc
!
! !INPUT PARAMETERS: 
!     
      LOGICAL,          INTENT(IN)    :: LS            ! =T denotes LS precip
      INTEGER,          INTENT(IN)    :: I             ! Longitude index
      INTEGER,          INTENT(IN)    :: J             ! Latitude index
      INTEGER,          INTENT(IN)    :: L             ! Level index
      INTEGER,          INTENT(IN)    :: IDX           ! ND38 index
      CHARACTER(LEN=*), INTENT(IN)    :: ERRMSG        ! Error message
      REAL*8,           INTENT(IN)    :: QDOWN         ! Precip leaving thru
                                                       !  bottom of box (I,J,L)
      REAL*8,           INTENT(IN)    :: F             ! Fraction of grid box 
                                                       !  undergoing precip
      REAL*8,           INTENT(IN)    :: DT            ! Rainout timestep [s]
!
! !INPUT/OUTPUT PARAMETERS: 
!
      REAL*8,           INTENT(INOUT) :: STT (:,:,:,:) ! Tracer array [kg]
      REAL*8,           INTENT(INOUT) :: DSTT(:,:,:,:) ! Accumulator array [kg]
! 
! !REMARKS:
!  Assume all of the tracer precipitating down from grid box (I,J,L=2) to 
!  grid box (I,J,L=1) gets washed out in grid box (I,J,L=1).
!                                                                             .
!  The modifications for the MERRA met fields require calling this same 
!  sequence of code more than once.  The expedient solution was to just move
!  the relevant code into this this subroutine.
!
! !REVISION HISTORY: 
!  16 Sep 2010 - R. Yantosca - Initial version
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      LOGICAL :: AER
      INTEGER :: N,        NN
      REAL*8  :: WASHFRAC, WETLOSS, TMP
      REAL*8  :: TK   

      !=================================================================
      ! DO_WASHOUT_AT_SFC begins here!
      !=================================================================

      ! ND16 diagnostic...save F 
      IF ( ND16 > 0 .and. L <= LD16 ) THEN
         AD16(I,J,L,IDX) = AD16(I,J,L,IDX) + F
         CT16(I,J,L,IDX) = CT16(I,J,L,IDX) + 1
      ENDIF

      ! ND18 diagnostic...increment counter
      IF ( ND18 > 0 .and. L <= LD18 ) THEN
         CT18(I,J,L,IDX) = CT18(I,J,L,IDX) + 1
      ENDIF

      ! air temperature [K]
      TK = T(I,J,L)   

      !-----------------------------------------------------------------
      ! Loop over all wet deposition species
      !-----------------------------------------------------------------
      DO NN = 1, NSOL

         ! Tracer number corresponding to this wetdep species
         N = IDWETD(NN)

         ! Call WASHOUT to compute the fraction of tracer 
         ! in grid box (I,J,L) that is lost to washout.  
         CALL WASHOUT( L,        N,            BXHEIGHT(I,J,L), 
     &                 TK ,      QDOWN,        DT,   
     &                 F,        H2O2s(I,J,L), SO2s(I,J,L), 
     &                 WASHFRAC, AER )

         ! NOTE: for HNO3 and aerosols, there is an F factor
         ! already present in WASHFRAC.  For other soluble
         ! gases, we need to multiply by the F (hyl, bmy, 10/27/00)
         IF ( AER ) THEN
            WETLOSS = STT(I,J,L,N) * WASHFRAC
         ELSE
            WETLOSS = STT(I,J,L,N) * WASHFRAC * F
         ENDIF

         ! Subtract WETLOSS from STT
         STT(I,J,L,N) = STT(I,J,L,N) - WETLOSS     
      
         ! Add washout losses in grid box (I,J,L=1) to DSTT 
         ! (added cdh, 4/14/2009)
         DSTT(NN,L,I,J) = DSTT(NN,L+1,I,J) + WETLOSS

         !--------------------------------------------------------------
         ! Diagnostics
         !--------------------------------------------------------------

         ! ND18 diagnostic...LS and conv washout fractions [unitless]
         IF ( ND18 > 0 .and. L <= LD18 ) THEN

            ! Only divide WASHFRAC by F for aerosols, since
            ! for non-aerosols this is already accounted for
            IF ( AER ) THEN
               TMP = WASHFRAC / F
            ELSE
               TMP = WASHFRAC
            ENDIF
            
            AD18(I,J,L,NN,IDX) = AD18(I,J,L,NN,IDX) + TMP
         ENDIF

         ! ND39 diag -- save washout loss in [kg/s]
         ! Add LGTMM in condition for AD39 (ccc, 11/18/09)
         IF ( ( ND39 > 0 .or. LGTMM ) .and. L <= LD39 ) THEN
            AD39(I,J,L,NN) = AD39(I,J,L,NN) + WETLOSS / DT
         ENDIF

         !-----------------------------------------------------
         ! Dirty kludge to prevent wet deposition from removing 
         ! stuff from stratospheric boxes -- this can cause 
         ! negative tracer (rvm, bmy, 6/21/00)
         !
         IF ( STT(I,J,L,N) < 0d0 .and. L > 23 ) THEN
             WRITE ( 6, 101 ) I, J, L, N, 7
 101         FORMAT( 'WETDEP - STT < 0 at ', 3i4, 
     &               ' for tracer ', i4, 'in area ', i4 )
             PRINT*, 'STT:', STT(I,J,:,N)
             STT(I,J,L,N) = 0d0
         ENDIF
         !-----------------------------------------------------

         !--------------------------------------------------------------
         ! Error checks
         !--------------------------------------------------------------
         IF ( IT_IS_NAN( STT(I,J,L,N) )   .or.
     &        STT(I,J,L,N)   < 0d0        .or. 
     &        DSTT(NN,L,I,J) < 0d0      ) THEN

            PRINT*, 'WASHFRAC = ', WASHFRAC
            PRINT*, 'F        = ', F

            ! Print error message and stop simulaton
            CALL SAFETY( I, J, L, N, ERRMSG,
     &                   LS          = LS,             
     &                   PDOWN       = 0d0,
     &                   QQ          = 0d0,      
     &                   ALPHA       = 0d0,       
     &                   ALPHA2      = 0d0,         
     &                   RAINFRAC    = 0d0,     
     &                   WASHFRAC    = 0d0, 
     &                   MASS_WASH   = 0d0,
     &                   MASS_NOWASH = 0d0,
     &                   WETLOSS     = WETLOSS,
     &                   GAINED      = 0d0,         
     &                   LOST        = 0d0,         
     &                   DSTT        = DSTT(NN,:,I,J), 
     &                   STT         = STT(I,J,:,N)     )

         ENDIF
      ENDDO

      END SUBROUTINE DO_WASHOUT_AT_SFC
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: safety
!
! !DESCRIPTION: Subroutine SAFETY stops the run with debug output and an 
!  error message if negative tracers are found. 
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE SAFETY( I,         J,           L,        N,     
     &                   A,         LS,          PDOWN,    QQ,       
     &                   ALPHA,     ALPHA2,      RAINFRAC, WASHFRAC, 
     &                   MASS_WASH, MASS_NOWASH, WETLOSS,  GAINED,   
     &                   LOST,      DSTT,        STT )

!
! !USES:
!
      USE ERROR_MOD, ONLY : GEOS_CHEM_STOP

#     include "CMN_SIZE"
!
! !INPUT PARAMETERS: 
!
      ! Arguments
      LOGICAL,          INTENT(IN) :: LS            !
      INTEGER,          INTENT(IN) :: I             !
      INTEGER,          INTENT(IN) :: J             !
      INTEGER,          INTENT(IN) :: L             !
      INTEGER,          INTENT(IN) :: N             !
      CHARACTER(LEN=*), INTENT(IN) :: A             !
      REAL*8,           INTENT(IN) :: PDOWN         !
      REAL*8,           INTENT(IN) :: QQ            !
      REAL*8,           INTENT(IN) :: ALPHA         !
      REAL*8,           INTENT(IN) :: ALPHA2        !
      REAL*8,           INTENT(IN) :: RAINFRAC      !
      REAL*8,           INTENT(IN) :: WASHFRAC      ! 
      REAL*8,           INTENT(IN) :: MASS_WASH     !
      REAL*8,           INTENT(IN) :: MASS_NOWASH   !
      REAL*8,           INTENT(IN) :: WETLOSS       !
      REAL*8,           INTENT(IN) :: GAINED        !
      REAL*8,           INTENT(IN) :: LOST          !
      REAL*8,           INTENT(IN) :: DSTT(LLPAR)   !
      REAL*8,           INTENT(IN) :: STT(LLPAR)    !
! 
! !REVISION HISTORY: 
!  18 Mar 2004 - R. Yantosca - Initial version
!  (1 ) Now made into a MODULE routine since we cannot call internal routines
!        from w/in a parallel loop.  Updated comments. (bmy, 3/18/04)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! SAFETY begins here!
      !=================================================================
      
      ! Print line
      WRITE( 6, '(a)' ) REPEAT( '=', 79 )

      ! Write error message and stop the run
      WRITE ( 6, 100 ) I, J, L, N, TRIM( A )
 100  FORMAT( 'WETDEP: ERROR at ', 3i4, ' for tracer ', i4, 
     &        ' in area ', a )

      PRINT*, 'LS          : ', LS
      PRINT*, 'PDOWN       : ', PDOWN
      PRINT*, 'QQ          : ', QQ
      PRINT*, 'ALPHA       : ', ALPHA
      PRINT*, 'ALPHA2      : ', ALPHA2
      PRINT*, 'RAINFRAC    : ', RAINFRAC
      PRINT*, 'WASHFRAC    : ', WASHFRAC
      PRINT*, 'MASS_WASH   : ', MASS_WASH
      PRINT*, 'MASS_NOWASH : ', MASS_NOWASH
      PRINT*, 'WETLOSS     : ', WETLOSS
      PRINT*, 'GAINED      : ', GAINED
      PRINT*, 'LOST        : ', LOST
      PRINT*, 'DSTT(NN,:)  : ', DSTT(:)
      PRINT*, 'STT(I,J,:N) : ', STT(:)

      ! Print line
      WRITE( 6, '(a)' ) REPEAT( '=', 79 )

      ! DEALLOCATE memory and stop
      CALL GEOS_CHEM_STOP

      END SUBROUTINE SAFETY
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: wetdepid
!
! !DESCRIPTION: Subroutine WETDEPID sets up the index array of soluble 
!  tracers used in the WETDEP routine above.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE WETDEPID
!
! !USES:
!
      USE ERROR_MOD,    ONLY : ERROR_STOP
      USE TRACER_MOD,   ONLY : N_TRACERS, TRACER_NAME, TRACER_MW_G
      USE TRACERID_MOD, ONLY : IDTPB,     IDTBE7,    IDTHNO3, IDTH2O2 
      USE TRACERID_MOD, ONLY : IDTCH2O,   IDTMP,     IDTSO2,  IDTSO4  
      USE TRACERID_MOD, ONLY : IDTSO4s,   IDTSO4aq,  IDTMSA,  IDTNH3   
      USE TRACERID_MOD, ONLY : IDTNH4,    IDTNH4aq,  IDTNIT,  IDTNITs  
      USE TRACERID_MOD, ONLY : IDTAS,     IDTAHS,    IDTLET,  IDTBCPI 
      USE TRACERID_MOD, ONLY : IDTOCPI,   IDTBCPO,   IDTOCPO, IDTDST1 
      USE TRACERID_MOD, ONLY : IDTDST2,   IDTDST3,   IDTDST4, IDTSALA 
      USE TRACERID_MOD, ONLY : IDTSALC,   IDTALPH,   IDTLIMO, IDTALCO 
      USE TRACERID_MOD, ONLY : IDTSOG1,   IDTSOG2,   IDTSOG3, IDTSOG4
      USE TRACERID_MOD, ONLY : IDTSOA1,   IDTSOA2,   IDTSOA3, IDTSOA4
      USE TRACERID_MOD, ONLY : IDTSOA5,   IDTSOG5
      USE TRACERID_MOD, ONLY : IS_Hg2,    IS_HgP
      USE TRACERID_MOD, ONLY : IDTGLYX,   IDTMGLY,   IDTGLYC
      USE TRACERID_MOD, ONLY : IDTSOAG,   IDTSOAM
      USE TRACERID_MOD, ONLY : IDTMOBA,   IDTPROPNN
      USE TRACERID_MOD, ONLY : IDTISOPN,  IDTMMN
      USE TRACERID_MOD, ONLY : IDTIEPOX,  IDTRIP,    IDTMAP

#     include "CMN_SIZE"  ! Size parameters
! 
! !REVISION HISTORY: 
!  08 Nov 2002 - R. Yantosca - Initial version
!  (1 ) Now references "tracerid_mod.f".  Also references "CMN" in order to
!        pass variables NSRCX and NTRACE. (bmy, 11/8/02)
!  (2 ) Updated for carbon aerosol & dust tracers (rjp, bmy, 4/5/04)
!  (3 ) Updated for seasalt aerosol tracers.  Also added fancy output.
!        (rjp, bec, bmy, 4/20/04)
!  (4 ) Updated for secondary organic aerosol tracers (bmy, 7/13/04)
!  (5 ) Now references N_TRACERS, TRACER_NAME, TRACER_MW_KG from
!        "tracer_mod.f".  Removed reference to NSRCX.  (bmy, 7/20/04)
!  (6 ) Updated for mercury aerosol tracers (eck, bmy, 12/9/04)
!  (7 ) Updated for AS, AHS, LET, NH4aq, SO4aq (cas, bmy, 12/20/04)
!  (8 ) Updated for SO4s, NITs (bec, bmy, 4/25/05)
!  (9 ) Now make sure all USE statements are USE, ONLY (bmy, 10/3/05)
!  (10) Now use IS_Hg2 and IS_HgP to determine if a tracer is a tagged Hg2
!        or HgP tracer (bmy, 1/6/06)
!  (11) Now added SOG4 and SOA4 (dkh, bmy, 5/18/06)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER :: N, NN

      !=================================================================
      ! WETDEPID begins here!
      !=================================================================

      ! Zero NSOL
      NSOL = 0

      ! Sort soluble tracers into IDWETD
      DO N = 1, N_TRACERS

         !-----------------------------
         ! Rn-Pb-Be tracers
         !-----------------------------
         IF ( N == IDTPB ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTPB

         ELSE IF ( N == IDTBE7 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTBE7

         !-----------------------------
         ! Full chemistry tracers
         !-----------------------------
         ELSE IF ( N == IDTHNO3 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTHNO3

         ELSE IF ( N == IDTH2O2 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTH2O2

         ELSE IF ( N == IDTCH2O ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTCH2O

         ELSE IF ( N == IDTMP ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTMP

         ELSE IF ( N == IDTGLYX ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTGLYX

         ELSE IF ( N == IDTMGLY ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTMGLY

         ELSE IF ( N == IDTGLYC ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTGLYC

         !FP_ISOP (6/2009)
         
         ELSE IF ( N == IDTISOPN ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTISOPN

         ELSE IF ( N == IDTMMN ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTMMN

         ELSE IF ( N == IDTMOBA ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTMOBA

         ELSE IF ( N == IDTPROPNN ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTPROPNN

         ELSE IF ( N == IDTRIP ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTRIP

         ELSE IF ( N == IDTMAP ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTMAP

         ELSE IF ( N == IDTIEPOX ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTIEPOX
         ! end FP

         !-----------------------------
         ! Sulfate aerosol tracers
         !-----------------------------
         ELSE IF ( N == IDTSO2 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSO2

         ELSE IF ( N == IDTSO4 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSO4

         ELSE IF ( N == IDTSO4s ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSO4s

         ELSE IF ( N == IDTMSA ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTMSA

         ELSE IF ( N == IDTNH3 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTNH3

         ELSE IF ( N == IDTNH4 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTNH4
            
         ELSE IF ( N == IDTNIT ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTNIT

         ELSE IF ( N == IDTNITs ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTNITs
            
         !-----------------------------
         ! Crystal & Aqueous aerosols
         !-----------------------------
         ELSE IF ( N == IDTAS ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTAS

         ELSE IF ( N == IDTAHS ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTAHS

         ELSE IF ( N == IDTLET ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTLET

         ELSE IF ( N == IDTNH4aq ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTNH4aq

         ELSE IF ( N == IDTSO4aq ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSO4aq

         !-----------------------------
         ! Carbon & SOA aerosol tracers
         !-----------------------------
         ELSE IF ( N == IDTBCPI ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTBCPI

         ELSE IF ( N == IDTOCPI ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTOCPI

         ELSE IF ( N == IDTBCPO ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTBCPO

         ELSE IF ( N == IDTOCPO ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTOCPO

         ELSE IF ( N == IDTALPH ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTALPH

         ELSE IF ( N == IDTLIMO ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTLIMO

         ELSE IF ( N == IDTALCO ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTALCO

         ELSE IF ( N == IDTSOG1 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOG1

         ELSE IF ( N == IDTSOG2 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOG2

         ELSE IF ( N == IDTSOG3 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOG3

         ELSE IF ( N == IDTSOG4 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOG4

         ! Added SOG5 (dkh, 03/26/07)  
         ELSE IF ( N == IDTSOG5 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOG5
       
         ELSE IF ( N == IDTSOA1 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOA1

         ELSE IF ( N == IDTSOA2 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOA2

         ELSE IF ( N == IDTSOA3 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOA3

         ELSE IF ( N == IDTSOA4 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOA4

         ! added SOA5 (dkh, 03/26/07)  
         ELSE IF ( N == IDTSOA5 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOA5

         ELSE IF ( N == IDTSOAG ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOAG

         ELSE IF ( N == IDTSOAM ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSOAM

         !-----------------------------
         ! Dust aerosol tracers
         !-----------------------------
         ELSE IF ( N == IDTDST1 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTDST1

         ELSE IF ( N == IDTDST2 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTDST2

         ELSE IF ( N == IDTDST3 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTDST3

         ELSE IF ( N == IDTDST4 ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTDST4

         !-----------------------------
         ! Seasalt aerosol tracers
         !-----------------------------
         ELSE IF ( N == IDTSALA ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSALA

         ELSE IF ( N == IDTSALC ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = IDTSALC

         !-----------------------------
         ! Total and tagged Hg tracers 
         !-----------------------------
         ELSE IF ( IS_Hg2( N ) ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = N

         ELSE IF ( IS_HgP( N ) ) THEN
            NSOL         = NSOL + 1
            IDWETD(NSOL) = N

         ENDIF
      ENDDO

      ! Error check: Make sure that NSOL is less than NSOLMAX
      IF ( NSOL > NSOLMAX ) THEN
         CALL ERROR_STOP( 'NSOL > NSOLMAX!', 'WETDEPID (wetscav_mod.f)')
      ENDIF
      
      ! Also check to see if NSOL is larger than the maximum
      ! number of soluble tracers for a particular simulation
      IF ( NSOL > GET_WETDEP_NMAX() ) THEN
         CALL ERROR_STOP( 'NSOL > NMAX', 'WETDEPID (wetscav_mod.f)')
      ENDIF

      !=================================================================
      ! Echo list of soluble tracers to the screen
      !=================================================================
      WRITE( 6, '(/,a,/)' ) 'WETDEPID: List of soluble tracers: '
      WRITE( 6, '(a)  '   ) '  #             Name  Tracer Mol Wt'
      WRITE( 6, '(a)'     ) '                      Number g/mole'
      WRITE( 6, '(a)'     ) REPEAT( '-', 36 )

      DO NN = 1, NSOL
         N = IDWETD(NN)
         WRITE( 6, '(i3,3x,a14,3x,i3,3x,f6.1)' )
     &        NN, TRIM( TRACER_NAME(N) ), N, TRACER_MW_G(N)
      ENDDO
      
      END SUBROUTINE WETDEPID
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_wetdep_nmax
!
! !DESCRIPTION: Function GET\_WETDEP\_NMAX returns the maximum number of 
!  soluble tracers for a given type of simulation.  Primarily used for 
!  allocation of diagnostic arrays.
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_WETDEP_NMAX() RESULT ( NMAX )
!
! !USES:
!
      USE LOGICAL_MOD,  ONLY : LCARB,  LDUST, LSOA
      USE LOGICAL_MOD,  ONLY : LSSALT, LSULF, LSPLIT, LCRYST
      USE TRACER_MOD,   ONLY : ITS_A_FULLCHEM_SIM, ITS_AN_AEROSOL_SIM
      USE TRACER_MOD,   ONLY : ITS_A_RnPbBe_SIM,   ITS_A_MERCURY_SIM
      USE TRACERID_MOD, ONLY : IDTSOAG,  IDTSOAM

#     include "CMN_SIZE"     ! Size Parameters
!
! !RETURN VALUE:
!
      INTEGER :: NMAX        ! Max # of soluble tracers per simulation
! 
! !REMARKS:
!  NOTE: If you add tracers to a simulation, update as necessary
!
! !REVISION HISTORY: 
!  02 Dec 2002 - R. Yantosca - Initial version
!  (1 ) Modified to include carbon & dust aerosol tracers (rjp, bmy, 4/5/04)
!  (2 ) Modified to include seasalt aerosol tracers (rjp, bec, bmy, 4/20/04)
!  (3 ) Modified to include 2ndary organic aerosol tracers (rjp, bmy, 7/13/04)
!  (4 ) Now references ITS_A_FULLCHEM_SIM, ITS_AN_AEROSOL_SIM, and 
!        ITS_A_RnPbBe_SIM from "tracer_mod.f".  Now references LCARB, LDUST,
!        LSOA, LSSALT, LSULF from "logical_mod.f". (bmy, 7/20/04)
!  (5 ) Modified to include mercury aerosol tracers (eck, bmy, 12/14/04)
!  (6 ) Modified for AS, AHS, LET, NH4aq, SO4aq (cas, bmy, 12/20/04)
!  (7 ) Modified for SO4s, NITs (bec, bmy, 4/25/05)
!  (8 ) Modified for SOG4, SOA4 (dkh, bmy, 5/18/06)
!  (9 ) Added 9 new tracers for ISOPRENE species (fp, 6/2009)
!  (10) Added SOA5 and SOG5 (hotp, 6/15/09)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! GET_WETDEP_NMAX begins here!
      !
      ! NOTE: If you add tracers to a simulation, update as necessary
      !=================================================================
      IF ( ITS_A_FULLCHEM_SIM() ) THEN 
      
         !-----------------------
         ! Fullchem simulation
         !-----------------------
         NMAX = 14                              ! HNO3, H2O2, CH2O, MP, 
                                                ! GLYX, MGLY, GLYC
                                                ! MOBA
                                                ! ISOPN, MVKN, PROPNN
                                                ! RIP, IEPOX
                                                ! PMNN 

         IF ( LSULF )    NMAX = NMAX + 8        ! SO2, SO4, MSA, NH3, NH4, NIT
         IF ( LDUST  )   NMAX = NMAX + NDSTBIN  ! plus # of dust bins
         IF ( LSSALT )   NMAX = NMAX + 2        ! plus 2 seasalts

         IF ( LSOA ) THEN
            IF ( LCARB ) NMAX = NMAX + 17       ! carbon + SOA aerosols
            IF ( IDTSOAG /= 0 ) NMAX = NMAX + 1 ! SOAG deposition
            IF ( IDTSOAM /= 0 ) NMAX = NMAX + 1 ! SOAM deposition
         ELSE                                 
            IF ( LCARB ) NMAX = NMAX + 4        ! just carbon aerosols
         ENDIF

      ELSE IF ( ITS_AN_AEROSOL_SIM() ) THEN

         !-----------------------
         ! Offline simulation
         !-----------------------
         NMAX = 0
         IF ( LSULF  )   NMAX = NMAX + 9        ! add 9 sulfur species
         IF ( LCRYST )   NMAX = NMAX + 5        ! add 5 cryst & aq species
         IF ( LDUST  )   NMAX = NMAX + NDSTBIN  ! Add number of dust bins
         IF ( LSSALT )   NMAX = NMAX + 2        ! plus 2 seasalts

         IF ( LSOA ) THEN
            IF ( LCARB ) NMAX = NMAX + 15       ! carbon + SOA aerosols
         ELSE
            IF ( LCARB ) NMAX = NMAX + 4        ! just carbon aerosols
         ENDIF
               
      ELSE IF ( ITS_A_RnPbBe_SIM() ) THEN

         !-----------------------
         ! Rn-Pb-Be simulation
         !-----------------------
         NMAX = 2                               ! 210Pb, 7Be

      ELSE IF ( ITS_A_MERCURY_SIM() ) THEN

         !-----------------------
         ! Mercury simulation
         !-----------------------
         NMAX = 2                               ! Hg2, HgP
         IF ( LSPLIT ) NMAX = NMAX + 14         ! Tagged tracers

      ELSE 

         !-----------------------
         ! Everything else
         !-----------------------
         NMAX = 0

      ENDIF

      END FUNCTION GET_WETDEP_NMAX
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_wetdep_nsol
!
! !DESCRIPTION: Function GET\_WETDEP\_NSOL returns NSOL (# of soluble tracers) 
!  to a calling program outside WETSCAV_MOD.  This is so that we can keep 
!  NSOL declared as a PRIVATE variable.
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_WETDEP_NSOL() RESULT( N_SOLUBLE )
!
! !RETURN VALUE:
!
      INTEGER :: N_SOLUBLE   ! Number of soluble tracers
!
! !REVISION HISTORY: 
!  10 Jan 2003 - R. Yantosca - Initial version
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! GET_WETDEP_NSOL begins here!
      !=================================================================

      ! Get the # of soluble tracers
      N_SOLUBLE = NSOL
     
      END FUNCTION GET_WETDEP_NSOL
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_wetdep_idwetd
!
! !DESCRIPTION: Function GET\_WETDEP\_IDWETD returns the tracer number of 
!  wet deposition species NWET.  This is meant to be called outside of 
!  WETSCAV\_MOD so that IDWETD can be kept as a PRIVATE variable.
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_WETDEP_IDWETD( NWET ) RESULT( N )
!
! !USES:
!
      USE ERROR_MOD, ONLY : ERROR_STOP
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN) :: NWET   ! Wet deposition species #
!
! !RETURN VALUE:
!
      INTEGER             :: N      ! Tracer # corresponding to NWET
! 
! !REVISION HISTORY:
!  10 Jan 2003 - R. Yantosca - Initial version 
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! GET_WETDEP_IDWETD begins here!
      !=================================================================

      ! Make sure NWET is valid
      IF ( NWET < 1 .or. NWET > NSOLMAX ) THEN
         CALL ERROR_STOP( 'Invalid value of NWET!', 
     &                    'GET_N_WETDEP (wetscav_mod.f)' )
      ENDIF

      ! Get the tracer # for wet deposition species N
      N = IDWETD(NWET)
     
      END FUNCTION GET_WETDEP_IDWETD
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_wetscav
!
! !DESCRIPTION: Subroutine INIT\_WETSCAV initializes updraft velocity, cloud 
!  liquid water content, cloud ice content, and mixing ratio of water fields, 
!  which are used in the wet scavenging routines.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE INIT_WETSCAV
!
! !USES:
!
      USE DAO_MOD,      ONLY : T, IS_WATER
      USE ERROR_MOD,    ONLY : ALLOC_ERR
      USE PRESSURE_MOD, ONLY : GET_PCENTER
      USE TRACER_MOD,   ONLY : STT
      USE TRACERID_MOD, ONLY : IDTH2O2, IDTSO2

#     include "CMN_SIZE"     ! Size parameters
! 
! !REVISION HISTORY: 
!  23 Feb 2000 - R. Yantosca - Initial version
!  (1 ) References "e_ice.f" -- routine to compute Eice(T).
!  (2 ) Vud, CLDLIQ, CLDICE, C_H2O are all independent of tracer, so we
!        can compute them once per timestep, before calling the cloud 
!        convection and wet deposition routines.
!  (3 ) Set C_H2O = 0 below -120 Celsius.  E_ICE(T) has a lower limit of
!        -120 Celsius, so temperatures lower than this will cause a stop
!        with an error message. (bmy, 6/15/00)
!  (4 ) Replace {IJL}GLOB with IIPAR,JJPAR,LLPAR.  Also rename PW to P.
!        Remove IREF, JREF, these are obsolete.  Now reference IS_WATER
!        from "dao_mod.f" to determine water boxes. 
!  (5 ) Removed obsolete code from 9/01.  Updated comments and made
!        cosmetic changes. (bmy, 10/24/01)
!  (6 ) Now use routine GET_PCENTER from "pressure_mod.f" to compute the
!        pressure at the midpoint of grid box (I,J,L).  Also removed P and
!        SIG from the argument list (dsa, bdf, bmy, 8/20/02)
!  (7 ) Now reference T from "dao_mod.f".  Updated comments.  Now allocate
!        Vud, C_H2O, CLDLIQ and CLDICE here on the first call.  Now references
!        ALLOC_ERR from "error_mod.f".  Now set H2O2s and SO2s to the initial
!        values from for the first call to COMPUTE_F .  Now call WETDEPID
!        on the first call to initialize the wetdep index array. (bmy, 1/27/03)
!  (8 ) Now references STT from "tracer_mod.f".  Also now we call WETDEPID
!        from "input_mod.f" (bmy, 7/20/04)
!  (9 ) Now references new function E_ICE, which is an analytic function of 
!        Kelvin temperature instead of Celsius. (bmy, 3/7/05)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER       :: I, J, L, AS
      REAL*8        :: PL, TK
      LOGICAL, SAVE :: FIRST = .TRUE.      
            
      !=================================================================
      ! INIT_WETSCAV begins here!
      !=================================================================
      IF ( FIRST ) THEN

         ! Allocate Vud on first call
         ALLOCATE( Vud( IIPAR, JJPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'Vud' )
         Vud = 0d0

         ! Allocate C_H2O on first call
         ALLOCATE( C_H2O( IIPAR, JJPAR, LLPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'C_H2O' )
         C_H2O = 0d0

         ! Allocate CLDLIQ on first call
         ALLOCATE( CLDLIQ( IIPAR, JJPAR, LLPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'CLDLIQ' )
         CLDLIQ = 0d0

         ! Allocate CLDICE on first call
         ALLOCATE( CLDICE( IIPAR, JJPAR, LLPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'CLDICE' )
         CLDICE = 0d0

         ! Allocate H2O2s for wet deposition 
         ALLOCATE( H2O2s( IIPAR, JJPAR, LLPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'H2O2s' )

         ! Set H2O2s to the initial H2O2 from STT, so that we will have
         ! nonzero values for the first call to COMPUTE_F (bmy, 1/14/03)
         IF ( IDTH2O2 > 0 ) THEN
            H2O2s = STT(:,:,:,IDTH2O2)
         ELSE
            H2O2s = 0d0
         ENDIF

         ! Allocate SO2s for wet deposition
         ALLOCATE( SO2s( IIPAR, JJPAR, LLPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'SO2s' )

         ! Set SO2s to the initial SO2 from STT, so that we will have
         ! nonzero values for the first call to COMPUTE_F (bmy, 1/14/03)
         IF ( IDTSO2 > 0 ) THEN
            SO2s = STT(:,:,:,IDTSO2)
         ELSE
            SO2s = 0d0
         ENDIF

         ! Reset flag
         FIRST = .FALSE. 
      ENDIF

      !=================================================================
      ! Compute Vud, CLDLIQ, CLDICE, C_H2O, following Jacob et al, 2000.
      !=================================================================
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L, TK, PL )
!$OMP+SCHEDULE( DYNAMIC )
      DO L = 1, LLPAR
      DO J = 1, JJPAR
      DO I = 1, IIPAR

         ! Compute Temp [K] and Pressure [hPa]
         TK = T(I,J,L)
         PL = GET_PCENTER(I,J,L)

         !==============================================================
         ! Compute Vud -- 5 m/s over oceans, 10 m/s over land (or ice?)
         ! Assume Vud is the same at all altitudes; the array can be 2-D
         !==============================================================
         IF ( L == 1 ) THEN
            IF ( IS_WATER( I, J ) ) THEN
               Vud(I,J) = 5d0
            ELSE
               Vud(I,J) = 10d0
            ENDIF
         ENDIF

         !==============================================================
         ! CLDLIQ, the cloud liquid water content [cm3 H2O/cm3 air], 
         ! is a function of the local Kelvin temperature:
         !  
         !    CLDLIQ = 2e-6                    [     T >= 268 K    ]
         !    CLDLIQ = 2e-6 * ((T - 248) / 20) [ 248 K < T < 268 K ]
         !    CLDLIQ = 0                       [     T <= 248 K    ]
         !==============================================================
         IF ( TK >= 268d0 ) THEN
            CLDLIQ(I,J,L) = 2d-6

         ELSE IF ( TK > 248d0 .and. TK < 268d0 ) THEN
            CLDLIQ(I,J,L) = 2d-6 * ( ( TK - 248d0 ) / 20d0 )

         ELSE
            CLDLIQ(I,J,L) = 0d0
            
         ENDIF
           
         !=============================================================
         ! CLDICE, the cloud ice content [cm3 ice/cm3 air] is given by:
         !
         !    CLDICE = 2e-6 - CLDLIQ
         !=============================================================
         CLDICE(I,J,L) = 2d-6 - CLDLIQ(I,J,L)

         !=============================================================
         ! C_H2O is given by Dalton's Law as:
         !
         !       C_H2O = Eice( Tk(I,J,L) ) / P(I,J,L)
         !
         ! where P(L) = pressure in grid box (I,J,L)
         !
         ! and   Tk(I,J,L) is the Kelvin temp. of grid box (I,J,L).
         !
         ! and   Eice( Tk(I,J,L) ) is the saturation vapor pressure 
         !       of ice [hPa] at temperature Tk(I,J,L) -- computed in 
         !       routine E_ICE above.
         !==============================================================
         C_H2O(I,J,L) = E_ICE( TK ) / PL

      ENDDO
      ENDDO
      ENDDO
!$OMP END PARALLEL DO

      END SUBROUTINE INIT_WETSCAV
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: cleanup_wetscav
!
! !DESCRIPTION: Subroutine CLEANUP\_WETSCAV deallocates all module arrays.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE CLEANUP_WETSCAV
!
! !REVISION HISTORY: 
!  23 Feb 2000 - R. Yantosca - Initial version
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! CLEANUP_WETSCAV begins here!
      !=================================================================
      IF ( ALLOCATED( Vud    ) ) DEALLOCATE( Vud    )
      IF ( ALLOCATED( C_H2O  ) ) DEALLOCATE( C_H2O  )
      IF ( ALLOCATED( CLDLIQ ) ) DEALLOCATE( CLDLIQ )
      IF ( ALLOCATED( CLDICE ) ) DEALLOCATE( CLDICE )
      IF ( ALLOCATED( PDOWN  ) ) DEALLOCATE( PDOWN  )
      IF ( ALLOCATED( QQ     ) ) DEALLOCATE( QQ     )
      IF ( ALLOCATED( H2O2s  ) ) DEALLOCATE( H2O2s  )
      IF ( ALLOCATED( SO2s   ) ) DEALLOCATE( SO2s   )

      END SUBROUTINE CLEANUP_WETSCAV
!EOC
      END MODULE WETSCAV_MOD
