C     -------------------------------------------
      SUBROUTINE OEI( XI, RG, Z, NSYM, NCL, NGL )
C     -------------------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
C*
      COMMON/BFINF/
     &       NBF, NKUMI, KUMI( 2, 19810 ), KNOT( 2, 19810 )
      COMMON/RPNT/
     &       RINV( 15728 ), R( 15728 )
      COMMON/CDVAL/
     &       CDV( 3302240 ), CDD( 3302240 ), CD2( 3302240 ),
     &       IRCDV( 3302240 )

      COMMON/DKPOT/
     &       S( 500500 ), H( 500500, 7 ), 
     &       V( 500500, 7 ), V2( 500500, 7 )
Caa     &       S( 500500 ), H( 500500, 6 ), 
Caa     &       V( 500500, 6 ), V2( 500500, 6 )
C*
c     DIMENSION H1( 500500 ), H2( 500500 ), U( 500500 )
c     DIMENSION U1( 500500 ), U2( 500500 )
C*
c     CALL DCLEAR( 500500, H1 )
c     CALL DCLEAR( 500500, H2 )
c     CALL DCLEAR( 500500, U  )
c     CALL DCLEAR( 500500, U1 )
c     CALL DCLEAR( 500500, U2 )
C*
      CALL DCLEAR( 500500,      S )
      CALL DCLEAR( 500500*NSYM, H )
      CALL DCLEAR( 500500*NSYM, V )
      CALL DCLEAR( 500500*NSYM, V2 )
C*
      IC = 0
      DO 10 I = 1, NKUMI
        NS = KNOT( 1, I )
        NE = KNOT( 2, I )
        SI = 0.D0
        TI = 0.D0
        VI = 0.D0
        CI = 0.D0
        VI1 = 0.D0
        VI2 = 0.D0
        DO 20 J = NS, NE
          DO 30 K = 1, NGL
            IC = IC + 1
            W = CDV( IC )
            IRADD = IRCDV( IC )
            RI = RINV( IRADD )
            SI = SI + W
            CI = CI + W * RI ** 2
            TI = TI + CDD( IC )
C*
            IF( NCL .EQ. 0 ) THEN
              VI = VI + W * RI
C             VI1 = VI1 + ( CDD( IC ) * RI - CD2( IC ) * RI**2 )
              VI1 = VI1 + CDD( IC ) * RI
     &                  - CD2( IC ) * RI**2
     &                  + CDV( IC ) * RI**3
              VI2 = VI2 + CDV( IC ) * RI**3
            ELSE IF( NCL .EQ. 1 ) THEN
              FACT = ERF( XI * R( IRADD ) )
              VI = VI + W * RI * FACT
              VI1 = VI1 + ( CDD( IC ) * RI
     &                    - CD2( IC ) * RI**2
     &                    + CDV( IC ) * RI**3 ) * FACT
              VI2 = VI2 + CDV( IC ) * RI**3 * FACT
            ELSE
              RA = R( IRADD )
              VI = VI + W * FCA( XI, RG, RA )
     &                + W * RI * FCB( XI, RG, RA )
              W = CDD( IC ) - CD2( IC ) * RI + CDV( IC ) * RI**2
              VI1 = VI1 + W * FCA( XI, RG, RA )
     &                  + W * RI * FCB( XI, RG, RA )
              VI2 = VI2 + CDV( IC ) * RI**2 * FCA( XI, RG, RA )
     &                  + CDV( IC ) * RI**3 * FCB( XI, RG, RA )
            END IF
   30     CONTINUE
   20   CONTINUE
        IJ = KUMI( 1, I ) * ( KUMI( 1, I ) - 1 ) / 2 + KUMI( 2, I )
        S( IJ ) = SI
C*
CCC     U( IJ ) = Z * VI
CCC     H1( IJ ) = 0.5D0 * TI
CCC     H2( IJ ) = CI
CCC     U1( IJ ) = - Z * VI1
CCC     U2( IJ ) = - Z * VI2
C*
        DO 40 L = 1, NSYM
          CL2 = DBLE( L * ( L - 1 ) )
          CL =  CL2 * 0.5D0
          H( IJ, L )  = 0.5D0 * TI + CL * CI
          V( IJ, L )  = - Z * VI
          V2( IJ, L ) = - Z * ( VI1 + CL2 * VI2 )
   40   CONTINUE
   10 CONTINUE
C*
CCC   DO 40 L = 1, NSYM
CCC     CL2 = DBLE( L * ( L - 1 ) )
CCC     CL =  CL2 * 0.5D0
CCC     DO 50 I = 1, LSV
CCC       H( I, L ) = H1( I ) + CL * H2( I )
CCC       V( I, L ) = - U( I )
CCC       V2( I, L ) = U1( I ) + CL2 * U2( I )
CCC50   CONTINUE
CCC40 CONTINUE
C*
      RETURN
      END
C     --------------------------------
      REAL*8 FUNCTION FCA( XI, RG, X )
C     --------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
      PARAMETER( PI = 2.D0 * 3.1415926535897D0 )
C*
      FCA = PI * RG * DEXP( - XI * X*X ) / XI
C*
      RETURN
      END
C     --------------------------------
      REAL*8 FUNCTION FCB( XI, RG, X )
C     --------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
      PARAMETER( PI = 2.D0 * 3.1415926535897D0 )
C*
      FCB = PI * RG * ( DGAMM( 1.5D0 ) - DICGAM( 1.5D0, XI*X*X ) )
     &    / XI**1.5D0
C*
      RETURN
      END
